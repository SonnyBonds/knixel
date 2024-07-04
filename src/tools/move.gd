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
		for entry in moving_layers:
			entry.layer.offset = entry.start + Vector2i(image_mouse_pos) - drag_start
