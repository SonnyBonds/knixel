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
		var index = num_layers-1
		for item in layer_container.get_children():
			if item.layer != document.layers[index]:
				dirty = true
				break
			index -= 1

	if dirty:
		update()
		
func update():
	var existing_items := layer_container.get_children()
	for child in existing_items:
		layer_container.remove_child(child)

	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	var new_items := []
	if document:
		for layer in document.layers:
			var found_existing := false
			for item_index in len(existing_items):
				var existing_item := existing_items[item_index]
				if existing_item.document == document and existing_item.layer.id == layer.id:
					# Relink to new actual instance
					existing_item.layer = layer
					new_items.push_back(existing_item)
					existing_items.remove_at(item_index)
					found_existing = true
					break

			if found_existing:
				continue

			var item = preload("res://src/ui/layer_item.tscn").instantiate()
			item.document = document
			item.layer = layer
			item.set_drag_forwarding(
				func(from_position): return _layer_get_drag_data(layer, from_position),
				func(at_position, data): return _layer_can_drop_data(layer, at_position, data),
				func(at_position, data): _layer_drop_data(layer, at_position, data))
			new_items.push_back(item)
	
	new_items.reverse()
	for item in new_items:
		layer_container.add_child(item)

	for item in existing_items:
		item.queue_free()


func _calc_layer_drop_location(at_layer : Layer, above : bool):
	var document = main.active_canvas.document
	if not document:
		return {}

	var last_layer : Layer = null
	var index : int = 0
	for layer in document.layers:
		if (not above and layer == at_layer) or (above and last_layer == at_layer):
			return {"after": last_layer, "before": layer, "index": index}
		last_layer = layer
		index += 1
	
	return {"after": document.layers.back(), "before": null, "index": len(document.layers)}
	
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
	var can_drop := false

	# Need extra "is Layer" test because it might not even be an object (e.g. Dictionary)
	var dragged_layer := data as Layer if data is Layer else null
	if dragged_layer:
		var control := _find_layer_control(target_layer)
		if control:
			var above := at_position.y < control.size.y/2
			var drop_location = _calc_layer_drop_location(target_layer, above)
			if drop_location.after != dragged_layer and drop_location.before != dragged_layer:
				var offset := 0.0 if above else control.size.y
				drop_hint.position.y = control.global_position.y - global_position.y + offset
				drop_hint.visible = true
				can_drop = true
		
		if not can_drop:
			drop_hint.position.y = 0
			drop_hint.visible = false

		return true
	else:
		return false

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
	if drop_location.after == dragged_layer or drop_location.before == dragged_layer:
		return

	var current_index = document.layers.find(dragged_layer)
	if current_index == -1:
		return

	var new_index = drop_location.index
	if new_index > current_index:
		new_index -= 1
	document.layers.remove_at(current_index)
	document.layers.insert(new_index, dragged_layer)

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

	var layer := data as Layer if data is Layer else null
	if not layer:
		return

	var document = main.active_canvas.document
	if not document:
		return
	document.layers.erase(layer)
	document.layers.push_front(layer)

func _on_mouse_exited():
	drop_hint.visible = false
