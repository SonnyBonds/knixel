class_name MoveTool extends Tool

var drag_start : Vector2i
var layer_start : Vector2i
var moving_layer : Layer

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
				layer_start = selected_layer.offset
				moving_layer = selected_layer
			elif not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				moving_layer = null
				canvas.document.end_undo_block()
	
	var motion := event as InputEventMouseMotion
	if motion and moving_layer:
		var image_control := canvas.get_node("%Image") as Control
		var image_mouse_pos = image_control.get_transform().affine_inverse() * motion.position
		moving_layer.offset = layer_start + Vector2i(image_mouse_pos) - drag_start
