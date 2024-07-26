class_name MoveTool extends Tool

var drag_start : Vector2i
var moving_layers : Array

func activate(canvas : Canvas):
	super(canvas)
	canvas.gui_input.connect(_gui_event)

func deactivate():
	canvas.gui_input.disconnect(_gui_event)

	super()

func _gui_event(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		var selected_layer := canvas.document.get_selected_layer()
		if selected_layer:
			var image_control := canvas.get_node("%Image") as Control
			var image_mouse_pos = image_control.get_transform().affine_inverse() * button.position
			if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				canvas.document.start_undo_block()
				drag_start = image_mouse_pos
				var start_index = canvas.document.find_layer_index(selected_layer.id)
				var end_index = start_index+1
				if selected_layer is GroupLayer:
					end_index = canvas.document.find_group_end(start_index)

				moving_layers.clear()
				for layer_i in range(start_index, end_index):
					var layer := canvas.document.layers[layer_i]
					moving_layers.push_back({"layer": layer, "start": layer.offset})

			elif not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				moving_layers.clear()
				canvas.document.end_undo_block()
	
	var motion := event as InputEventMouseMotion
	if motion:
		var image_control := canvas.get_node("%Image") as Control
		var image_mouse_pos = image_control.get_transform().affine_inverse() * motion.position

		var canvas_size := canvas.document.size
		for entry in moving_layers:
			var wrap_rect := Rect2i(-100000, -100000, 200000, 200000)
			var clamp_rect := Rect2i(-100000, -100000, 200000, 200000)
			var layer_size : Vector2i = entry.layer.get_size()
			if canvas.document.tiling == Document.Tiling.HORIZONTAL or canvas.document.tiling == Document.Tiling.BOTH:
				wrap_rect.position.x = 0
				wrap_rect.size.x = max(canvas_size.x, layer_size.x)
			else:
				clamp_rect.position.x = -layer_size.x
				clamp_rect.size.x = canvas_size.x - clamp_rect.position.x

			if canvas.document.tiling == Document.Tiling.VERTICAL or canvas.document.tiling == Document.Tiling.BOTH:
				wrap_rect.position.y = 0
				wrap_rect.size.y = max(canvas_size.y, layer_size.y)
			else:
				clamp_rect.position.y = -layer_size.y
				clamp_rect.size.y = canvas_size.y - clamp_rect.position.y

			entry.layer.offset = entry.start + Vector2i(image_mouse_pos) - drag_start
			entry.layer.offset = ((entry.layer.offset - wrap_rect.position) % wrap_rect.size) + wrap_rect.position
			entry.layer.offset = entry.layer.offset.clamp(clamp_rect.position, clamp_rect.end)
