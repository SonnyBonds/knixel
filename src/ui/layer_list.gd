extends Control

@onready var main := get_tree().current_scene as Main
@onready var layer_container := %LayerContainer as Control
@onready var drop_hint := %DropHint as Control
var _hint_drop_layer : Layer

func _ready():
	mouse_exited.connect(_on_mouse_exited)

func _process(_delta):
	var dirty = false
	
	var num_layers = 0
	var document = main.active_canvas.document if main.active_canvas else null
	if document:
		num_layers = len(document.layers)

	if num_layers != layer_container.get_child_count():
		dirty = true
	else:
		var index = 0
		for item in layer_container.get_children():
			var indent = document.calc_layer_depth(document.layers[index])
			if item.layer != document.layers[index] or item.indent != indent:
				dirty = true
				break
			index += 1

	if dirty:
		update()
		
func update():
	var existing_items := layer_container.get_children()
	for child in existing_items:
		layer_container.remove_child(child)

	if not main.active_canvas:
		for item in existing_items:
			item.queue_free()
		return

	var document = main.active_canvas.document

	var new_items := []
	for layer in document.layers:
		var item : LayerItem = null
		for item_index in len(existing_items):
			var existing_item := existing_items[item_index]
			if existing_item.document == document and existing_item.layer.id == layer.id:
				existing_items.remove_at(item_index)
				item = existing_item
				break

		if not item:
			item = preload("res://src/ui/layer_item.tscn").instantiate()

		item.set_drag_forwarding(
			func(from_position): return _layer_get_drag_data(layer, from_position),
			func(at_position, data): return _layer_can_drop_data(layer, at_position, data),
			func(at_position, data): _layer_drop_data(layer, at_position, data))

		item.document = document
		item.layer = layer
		item.indent = document.calc_layer_depth(layer)
		new_items.push_back(item)
	
	for item in new_items:
		layer_container.add_child(item)

	for item in existing_items:
		item.queue_free()


func _calc_layer_drop_location(at_layer : Layer, above : bool):
	var document = main.active_canvas.document
	if not document:
		return {}

	# All this logic is pretty awful

	var last_layer : Layer = null
	var index : int = 0
	for layer in document.layers:
		if layer == at_layer:
			if above:
				return {"after": last_layer, "before": layer, "index": index, "parent": layer.parent_id}
			else:
				var parent := 0
				if layer is GroupLayer:
					parent = layer.id
				else:
					parent = layer.parent_id
				var next_layer = document.layers[index+1] if index+1 < len(document.layers) else null
				return {"after": layer, "before": next_layer, "index": index+1, "parent": parent}
		last_layer = layer
		index += 1
	
	assert(false)
	return {"after": document.layers.back(), "before": null, "index": len(document.layers), "parent": 0}
	
func _layer_get_drag_data(target_layer : Layer, _from_position : Vector2) -> Variant:
	var preview := PanelContainer.new()
	var label := Label.new()
	label.text = target_layer.name
	preview.add_child(label)
	set_drag_preview(preview)
	_hint_drop_layer = target_layer
	return target_layer

func _find_layer_control(layer : Layer) -> Control:
	for child in layer_container.get_children():
		if child.layer == layer:
			return child

	return null

func _layer_can_drop_data(target_layer : Layer, at_position : Vector2, data : Variant) -> bool:
	var document := main.active_canvas.document
	if not document:
		return false

	# Need extra "is Layer" test because it might not even be an object (e.g. Dictionary)
	var dragged_layer := data as Layer if data is Layer else null
	if not dragged_layer:
		return false

	var can_drop := true

	# All this logic is pretty awful

	var control := _find_layer_control(target_layer)
	if control:
		var above := at_position.y < control.size.y/2
		var drop_location = _calc_layer_drop_location(target_layer, above)
		var parent_layer : Layer = document.find_layer_by_id(drop_location.parent) if drop_location.parent != 0 else null
		if drop_location.parent == dragged_layer.parent_id and (drop_location.after == dragged_layer or drop_location.before == dragged_layer):
			can_drop = false
		elif parent_layer and (dragged_layer == parent_layer or document.is_layer_descendent_of_other(parent_layer, dragged_layer)):
			can_drop = false
		else:
			var offset := 0.0 if above else control.size.y
			drop_hint.position.y = control.global_position.y - global_position.y + offset
	else:
		can_drop = false
	
	if can_drop:
		drop_hint.visible = true
	else:
		drop_hint.position.y = 0
		drop_hint.visible = false

	return true

func _layer_drop_data(target_layer : Layer, at_position : Vector2, data : Variant) -> void:
	drop_hint.visible = false

	# Need extra "is Layer" test because it might not even be an object (e.g. Dictionary)
	var dragged_layer := data as Layer if data is Layer else null
	if not dragged_layer:
		return

	var document = main.active_canvas.document
	if not document:
		return

	var control := _find_layer_control(target_layer)
	if not control:
		return

	var above := at_position.y < control.size.y/2
	var drop_location = _calc_layer_drop_location(target_layer, above)
	if drop_location.parent == dragged_layer.parent_id and (drop_location.after == dragged_layer or drop_location.before == dragged_layer):
		return

	var parent_layer : Layer = document.find_layer_by_id(drop_location.parent) if drop_location.parent != 0 else null
	if parent_layer and (dragged_layer == parent_layer or document.is_layer_descendent_of_other(parent_layer, dragged_layer)):
		return

	var start_index = document.layers.find(dragged_layer)
	if start_index == -1:
		return

	var end_index = start_index+1

	if dragged_layer is GroupLayer:
		end_index = document.find_group_end(start_index)

	var new_index = drop_location.index
	assert(new_index <= start_index or new_index >= end_index)
	if new_index >= end_index:
		new_index -= end_index - start_index
	
	if new_index != start_index:
		var items : Array[Layer] = []
		for i in (end_index - start_index):
			items.push_back(document.layers.pop_at(start_index))
		for i in (end_index - start_index):
			document.layers.insert(new_index+i, items[i])
	dragged_layer.parent_id = drop_location.parent

func _can_drop_data(_at_position : Vector2, data : Variant) -> bool:
	# Need extra "is Layer" test because it might not even be an object (e.g. Dictionary)
	var dragged_layer := data as Layer if data is Layer else null
	if not dragged_layer:
		return false

	var control := layer_container.get_children().back() as Control
	if control.layer != dragged_layer:
		drop_hint.position.y = control.global_position.y - global_position.y + control.size.y
		drop_hint.visible = true
	else:
		drop_hint.position.y = 0
		drop_hint.visible = false

	return true

func _drop_data(_at_position : Vector2, data:Variant) -> void:
	drop_hint.visible = false

	var dragged_layer := data as Layer if data is Layer else null
	if not dragged_layer:
		return

	var document = main.active_canvas.document
	if not document:
		return

	var start_index = document.layers.find(dragged_layer)
	if start_index == -1:
		return

	var end_index = start_index+1

	if dragged_layer is GroupLayer:
		end_index = document.find_group_end(start_index)

	var items : Array[Layer] = []
	for i in (end_index - start_index):
		items.push_back(document.layers.pop_at(start_index))
	for i in (end_index - start_index):
		document.layers.push_back(items[i])
	dragged_layer.parent_id = 0


func _on_mouse_exited():
	drop_hint.visible = false
