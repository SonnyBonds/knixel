@tool
extends Container

class_name TabDockContainer

@export var tabs_rearrange_group : int = 1

var _drop_area : Control
var _dragged_child : int = -1
var _drag_start : Vector2
var _child_size_start : float
var _next_child_size_start : float

func _ready():
	_drop_area = Control.new()
	_drop_area.visible = false
	_drop_area.size.y = 60
	
	var drop_hint := Panel.new()
	drop_hint.theme_type_variation = "DockDropHint"
	drop_hint.position.y = _drop_area.size.y-1
	drop_hint.anchor_right = 1
	drop_hint.size.y = 0
	_drop_area.add_child(drop_hint)

	_drop_area.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)

	mouse_default_cursor_shape = CursorShape.CURSOR_VSIZE

	add_child(_drop_area, false, Node.INTERNAL_MODE_BACK)

func _notification(what: int) -> void:
	var sash_gap := 4
	if what == NOTIFICATION_SORT_CHILDREN:
		var num_children = len(get_children())
		if num_children > 0:
			var y : float = 0
			var index := 0
			for child : Control in get_children():
				var h := child.size.y
				if index == num_children-1:
					h = size.y - y
				fit_child_in_rect(child, Rect2(0, y, size.x, h))
				y += h + sash_gap
				index += 1
		_drop_area.size.x = size.x
		queue_redraw()

func _get_tab_bar_from_drag_data(drag_data : Variant) -> TabBar:
	if not drag_data is Dictionary or not drag_data.has("from_path"):
		return null
	
	var tab_bar := get_node(drag_data.from_path) as TabBar
	if not tab_bar:
		return null
	
	if tab_bar.tabs_rearrange_group != tabs_rearrange_group:
		return null

	return tab_bar

func _process(_delta):
	var viewport := get_viewport()
	var drag_data = viewport.gui_get_drag_data()

	var num_docks := get_child_count()
	for child in get_children():
		if num_docks < 2:
			break
		if child.get_child_count() == 0:
			child.queue_free()
			num_docks -= 1

	var tab_bar = _get_tab_bar_from_drag_data(drag_data)
	if not tab_bar:
		_drop_area.visible = false
		return

	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x >= 0 and mouse_pos.x < size.x and mouse_pos.y > size.y - _drop_area.size.y:
		_drop_area.position.y = size.y - _drop_area.size.y
		_drop_area.visible = true
	else:
		_drop_area.visible = false	

func _can_drop_data(_at_position : Vector2, data : Variant) -> bool:
	var tab_bar := _get_tab_bar_from_drag_data(data)
	return tab_bar != null

func _drop_data(_at_position : Vector2, data:Variant) -> void:
	var source_tab_bar := _get_tab_bar_from_drag_data(data)
	if not source_tab_bar:
		return

	var source_tab_container := source_tab_bar.get_parent() as TabContainer
	var tab := source_tab_container.get_child(data.tab_index)
	source_tab_container.remove_child(tab)

	var new_tab_container := TabContainer.new()
	new_tab_container.size.y = 150
	new_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_tab_container.tabs_rearrange_group = tabs_rearrange_group
	new_tab_container.drag_to_rearrange_enabled = true
	new_tab_container.add_child(tab)

	get_children().back().size.y -= new_tab_container.size.y
	add_child(new_tab_container)

func _gui_input(event : InputEvent) -> void:
	var button_event := event as InputEventMouseButton
	if button_event and button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
		for i_child in get_child_count()-1:
			var child := get_child(i_child)
			var y = child.position.y + child.size.y + 2
			if abs(y - button_event.position.y) < 5:
				_dragged_child = i_child
				_drag_start = button_event.position
				_child_size_start = child.size.y
				_next_child_size_start = get_child(i_child+1).size.y
				break
	elif button_event and not button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
		_dragged_child = -1

	var motion_event := event as InputEventMouseMotion
	if motion_event and _dragged_child != -1:
		var child1 = get_child(_dragged_child) as Control
		var child2 = get_child(_dragged_child+1) as Control
		var diff := motion_event.position - _drag_start
		diff.y -= min(0, _child_size_start + diff.y - child1.get_minimum_size().y)
		diff.y += min(0, _next_child_size_start - diff.y - child2.get_minimum_size().y)
		child1.size.y = _child_size_start + diff.y
		child2.size.y = _next_child_size_start - diff.y
		queue_sort()

func _draw():
	var cx := size.x/2
	var x1 := cx - 10
	var x2 := cx + 10
	for i_child in get_child_count()-1:
		var child = get_child(i_child)
		var y = child.position.y + child.size.y + 2
		draw_line(Vector2(x1, y), Vector2(x2, y), Color.WHITE)
