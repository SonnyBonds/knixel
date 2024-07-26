class_name BoxSelectTool extends Tool

var _image_control : Control
var _overlay : Control
var _drag_start : Vector2
var _drag_pos : Vector2
var _drag_state := State.NONE
var _drag_mode : Mode
var _selection_start : Vector2
var _drag_texture : RID
var _back_texture_offset : Vector2i
var _back_texture : RID
var _framebuffer_pool := ImageProcessor.FramebufferPool.new()

enum State { NONE, BOX, SELECTION }
enum Mode { ADD, SUBTRACT, REPLACE }

func activate(canvas : Canvas) -> void:
	super(canvas)
	canvas.gui_input.connect(_gui_event)
	_image_control = canvas.get_node("%Image")
	_overlay = canvas.get_node("%Overlay")
	_overlay.draw.connect(_draw_overlay)
	_overlay.queue_redraw()

	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS

func deactivate() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	canvas.gui_input.disconnect(_gui_event)
	_overlay.draw.disconnect(_draw_overlay)
	_overlay.queue_redraw()

	_framebuffer_pool.flush()

	_release_back_texture()
	_release_drag_texture()

	super()

func _release_drag_texture():
	if _drag_texture:
		ImageProcessor.render_device.free_rid(_drag_texture)
		_drag_texture = RID()

func _release_back_texture():
	if _back_texture:
		ImageProcessor.render_device.free_rid(_back_texture)
		_back_texture = RID()


func _hovers_selection(pos : Vector2i) -> bool:
	if not canvas.document.selection:
		return false
	pos = canvas.pos_to_selection(pos)
	var size := canvas.document.selection.get_size()
	if pos.x < 0 or pos.y < 0 or pos.x >= size.x or pos.y >= size.y:
		return false
	return canvas.document.selection.get_pixelv(pos).r > 0

func _gui_event(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			var hover := _hovers_selection(button.position)
			if hover:
				canvas.document.start_undo_block()
				_drag_start = button.position
				_drag_pos = _drag_start
				_selection_start = canvas.document.selection_offset
				_drag_state = State.SELECTION
				var layer := canvas.document.get_selected_layer()
				if layer:
					if button.ctrl_pressed:
						if not _drag_texture:
							var drag_image := ImageProcessor.crop_or_extend(layer.image, Rect2i(canvas.document.selection_offset - layer.offset, canvas.document.selection.get_size()))
							drag_image = ImageProcessor.apply_mask(drag_image, canvas.document.selection)
							_drag_texture = ImageProcessor.create_texture_from_image(drag_image)

							if not button.alt_pressed:
								canvas.document.delete_selection()

							_back_texture_offset = layer.offset
							_back_texture = ImageProcessor.create_texture_from_image(layer.image)

							_update_dragged_image()
						elif button.alt_pressed:
							_back_texture_offset = layer.offset
							_back_texture = ImageProcessor.create_texture_from_image(layer.image)
					else:
						_release_back_texture()
						_release_drag_texture()
				else:
					_release_back_texture()
					_release_drag_texture()
			else:
				canvas.document.start_undo_block()
				_release_back_texture()
				_release_drag_texture()
				_drag_start = button.position
				_drag_pos = _drag_start
				_drag_mode = Mode.REPLACE
				if button.shift_pressed:
					_drag_mode = Mode.ADD
				elif button.alt_pressed:
					_drag_mode = Mode.SUBTRACT
				if _drag_mode == Mode.REPLACE:
					canvas.document.clear_selection()
				_drag_state = State.BOX
				_overlay.queue_redraw()
		elif not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			if _drag_state == State.BOX:
				select_box(calc_rect(_drag_start, button.position), _drag_mode)
				_drag_state = State.NONE
				_overlay.queue_redraw()
				canvas.document.end_undo_block()
			elif _drag_state == State.SELECTION:
				_drag_state = State.NONE
				canvas.document.end_undo_block()

	var key := event as InputEventKey
	if key:
		_update_cursor()

	var motion := event as InputEventMouseMotion
	if motion:
		_update_cursor()
		if _drag_state == State.BOX:
			_drag_pos = motion.position
			_overlay.queue_redraw()
		elif _drag_state == State.SELECTION:
			_drag_pos = motion.position
			canvas.document.selection_offset = Vector2i(_selection_start + canvas.pos_to_selection(_drag_pos) - canvas.pos_to_selection(_drag_start))
			if _drag_texture:
				_update_dragged_image()

func _update_dragged_image():
	var layer := canvas.document.get_selected_layer()
	if layer:
		var dest_pos := canvas.document.selection_offset
		var rect := Rect2i(_back_texture_offset, ImageProcessor.get_texture_size(_back_texture))
		var drag_rect := Rect2i(dest_pos, ImageProcessor.get_texture_size(_drag_texture))
		var tiling := canvas.document.tiling
		var document_size := canvas.document.size
		var wrap_rect : Rect2i
		if tiling != Document.Tiling.HORIZONTAL and tiling != Document.Tiling.BOTH:
			if drag_rect.position.x < rect.position.x:
				rect.size.x += rect.position.x - drag_rect.position.x
				rect.position.x = drag_rect.position.x
			if drag_rect.end.x > rect.end.x:
				rect.end.x = drag_rect.end.x
		else:
			rect.size.x = max(rect.size.x, document_size.x)
			wrap_rect.size.x = rect.size.x
		if tiling != Document.Tiling.VERTICAL and tiling != Document.Tiling.BOTH:
			if drag_rect.position.y < rect.position.y:
				rect.size.y += rect.position.y - drag_rect.position.y
				rect.position.y = drag_rect.position.y
			if drag_rect.end.y > rect.end.y:
				rect.end.y = drag_rect.end.y
		else:
			rect.size.y = max(rect.size.y, document_size.y)
			wrap_rect.size.y = rect.size.y

		var blended_framebuffer := _framebuffer_pool.get_framebuffer(rect.size)
		ImageProcessor.blend_async(blended_framebuffer,
			_drag_texture,
			Vector2i(dest_pos) - rect.position,
			_back_texture, 
			_back_texture_offset - rect.position,
			Color.WHITE,
			Rect2i(Vector2i.ZERO, blended_framebuffer.size), 
			ImageProcessor.BlendMode.Normal,
			wrap_rect)

		ImageProcessor.render_device.submit()
		ImageProcessor.render_device.sync()

		var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(blended_framebuffer.texture, 0)
		layer.image = Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_RGBAF, byte_data)
		layer.offset = rect.position
		_framebuffer_pool.release_framebuffer(blended_framebuffer.framebuffer)
	
func _update_cursor():
	var hover := _hovers_selection(canvas.get_local_mouse_position())
	var cursor := Control.CURSOR_CROSS
	if hover and Input.is_key_pressed(KEY_CTRL):
		cursor = Control.CURSOR_POINTING_HAND
	elif hover and not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_ALT):
		cursor = Control.CURSOR_POINTING_HAND

	if canvas.mouse_default_cursor_shape != cursor:
		canvas.mouse_default_cursor_shape = cursor
		# TODO: Without this the cursor glitches when switching
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func calc_rect(v1 : Vector2i, v2 : Vector2i) -> Rect2i:
	v1 = canvas.pos_to_image(v1)
	v2 = canvas.pos_to_image(v2)
	var size := canvas.document.size

	var min_v = (Vector2i(min(v1.x, v2.x), min(v1.y, v2.y))).clamp(Vector2i(0, 0), size)
	var max_v = (Vector2i(max(v1.x, v2.x), max(v1.y, v2.y))).clamp(Vector2i(0, 0), size)
	return Rect2i(min_v, max_v-min_v)

func select_box(rect : Rect2i, mode : Mode) -> void:
	canvas.document.ensure_selection_rect(rect)
	canvas.document.selection = canvas.document.selection.duplicate()

	if mode == Mode.REPLACE:
		canvas.document.selection.fill(Color.BLACK)

	rect.position -= canvas.document.selection_offset
	canvas.document.selection.fill_rect(rect, Color.BLACK if mode == Mode.SUBTRACT else Color.WHITE)

func _draw_overlay():
	if _drag_state == State.BOX:
		var rect := calc_rect(_drag_start, _drag_pos)
		var v1 = canvas.pos_from_image(rect.position)
		var v2 = canvas.pos_from_image(Vector2(rect.position + rect.size))

		_overlay.draw_line(Vector2(v1.x, v1.y), Vector2(v2.x, v1.y), Color.BLACK)
		_overlay.draw_line(Vector2(v2.x, v1.y), Vector2(v2.x, v2.y), Color.BLACK)
		_overlay.draw_line(Vector2(v2.x, v2.y), Vector2(v1.x, v2.y), Color.BLACK)
		_overlay.draw_line(Vector2(v1.x, v2.y), Vector2(v1.x, v1.y), Color.BLACK)

		_overlay.draw_dashed_line(Vector2(v1.x, v1.y), Vector2(v2.x, v1.y), Color.WHITE)
		_overlay.draw_dashed_line(Vector2(v2.x, v1.y), Vector2(v2.x, v2.y), Color.WHITE)
		_overlay.draw_dashed_line(Vector2(v2.x, v2.y), Vector2(v1.x, v2.y), Color.WHITE)
		_overlay.draw_dashed_line(Vector2(v1.x, v2.y), Vector2(v1.x, v1.y), Color.WHITE)
