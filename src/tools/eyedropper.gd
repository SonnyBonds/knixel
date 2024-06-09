class_name EyeDropperTool extends Tool

var _overlay : Control
var _picking : bool

func activate(canvas : Canvas) -> void:
	super(canvas)

	canvas.gui_input.connect(_gui_event)
	_overlay = canvas.get_node("%Overlay")
	_overlay.draw.connect(_draw_overlay)
	_overlay.queue_redraw()

	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS

func deactivate() -> void:
	canvas.gui_input.disconnect(_gui_event)
	_overlay.draw.disconnect(_draw_overlay)
	_overlay.queue_redraw()

	super()

func _gui_event(event: InputEvent) -> void:
	var button_event := event as InputEventMouseButton
	if button_event and button_event.button_index == MOUSE_BUTTON_LEFT:
		if button_event.pressed:
			canvas.document.start_undo_block()
			_picking = true
			_pick()
		else:
			canvas.document.end_undo_block()
			_picking = false

	var motion_event := event as InputEventMouseMotion
	if motion_event:
		if _picking:
			_pick()

func _pick():
	var pos := Vector2i(canvas.pos_to_image(canvas.get_local_mouse_position()))
	var image = canvas.document.output_image
	if image:
		if pos.x >= 0 and pos.y >= 0 and pos.x < image.get_width() and pos.y < image.get_height():
			canvas.document.foreground_color = image.get_pixel(pos.x, pos.y)

func _draw_overlay():
	pass