class_name BrushToolBase extends Tool

@export_range(1, 500) var radius : int = 20
@export_range(0, 100) var hardness : int = 10

enum Mode { UNKNOWN, BRUSH, ERASER }

var _image_control : Control
var _overlay : Control
var _painting : bool
var _last_splat_point : Vector2
var _brush_texture : RID
var _brush_radius : int = 0
var _brush_hardness : int = 0
var _splat_queue : Array[Vector2]
var _paint_framebuffer : Dictionary
var _paint_framebuffer_copy_texture : RID
var _back_texture_offset : Vector2i
var _back_texture : RID
var _selection_texture_offset : Vector2i
var _selection_texture : RID
var _framebuffer_pool := ImageProcessor.FramebufferPool.new()
var _mode := Mode.UNKNOWN

func activate(canvas : Canvas) -> void:
	super(canvas)

	assert(_mode != Mode.UNKNOWN)

	canvas.gui_input.connect(_gui_event)
	_image_control = canvas.get_node("%Image")
	_overlay = canvas.get_node("%Overlay")
	_overlay.draw.connect(_draw_overlay)
	_overlay.queue_redraw()

	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS

func deactivate() -> void:
	canvas.gui_input.disconnect(_gui_event)
	_overlay.draw.disconnect(_draw_overlay)
	_overlay.queue_redraw()

	if _paint_framebuffer:
		_framebuffer_pool.release_framebuffer(_paint_framebuffer.framebuffer)

	if _paint_framebuffer_copy_texture:
		ImageProcessor.render_device.free_rid(_paint_framebuffer_copy_texture)
		_paint_framebuffer_copy_texture = RID()

	if _back_texture:
		ImageProcessor.render_device.free_rid(_back_texture)
		_back_texture = RID()

	if _selection_texture:
		ImageProcessor.render_device.free_rid(_selection_texture)
		_selection_texture = RID()

	if _brush_texture:
		ImageProcessor.render_device.free_rid(_brush_texture)
		_brush_texture = RID()

	_framebuffer_pool.flush()

	super()

func _gui_event(event: InputEvent) -> void:
	var button_event := event as InputEventMouseButton
	if button_event and button_event.button_index == MOUSE_BUTTON_LEFT:
		var layer = canvas.document.get_selected_layer() as ImageLayer
		if not layer:
			return
		if button_event.pressed:
			canvas.document.start_undo_block()
			_painting = true

			if _paint_framebuffer:
				_framebuffer_pool.release_framebuffer(_paint_framebuffer.framebuffer)
				_paint_framebuffer = {}

			if _paint_framebuffer_copy_texture:
				ImageProcessor.render_device.free_rid(_paint_framebuffer_copy_texture)
				_paint_framebuffer_copy_texture = RID()

			if _back_texture:
				ImageProcessor.render_device.free_rid(_back_texture)
				_back_texture = RID()

			if _selection_texture:
				ImageProcessor.render_device.free_rid(_selection_texture)
				_selection_texture = RID()

			if canvas.document.selection:
				_selection_texture = ImageProcessor.create_texture_from_image(canvas.document.selection)
				_selection_texture_offset = canvas.document.selection_offset

			_back_texture = ImageProcessor.create_texture_from_image(layer.image)
			_back_texture_offset = layer.offset
			_paint_framebuffer = _framebuffer_pool.get_framebuffer(canvas.document.size)
			ImageProcessor.render_device.texture_clear(_paint_framebuffer.texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
			_paint_framebuffer_copy_texture = ImageProcessor.create_texture(canvas.document.size, RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT)
			ImageProcessor.render_device.texture_clear(_paint_framebuffer_copy_texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
			_last_splat_point = canvas.pos_to_image(canvas.get_local_mouse_position())
			_update_brush()
			_splat_from_last(_last_splat_point, true)
			_update_blended_image()
		else:
			_process_queue()

			if _paint_framebuffer.framebuffer:
				_framebuffer_pool.release_framebuffer(_paint_framebuffer.framebuffer)
				_paint_framebuffer = {}

			if _paint_framebuffer_copy_texture:
				ImageProcessor.render_device.free_rid(_paint_framebuffer_copy_texture)
				_paint_framebuffer_copy_texture = RID()

			if _back_texture:
				ImageProcessor.render_device.free_rid(_back_texture)
				_back_texture = RID()

			_paint_framebuffer = {}
			canvas.document.end_undo_block()
			_painting = false

	var motion_event := event as InputEventMouseMotion
	if motion_event:
		if _painting:
			_splat_queue.push_back(canvas.pos_to_image(canvas.get_local_mouse_position()))

func _update_blended_image():
	var layer := canvas.document.get_selected_layer()
	if layer:
		var masked_framebuffer : Dictionary
		var final_paint_framebuffer : Dictionary
		if _selection_texture:
			masked_framebuffer = _framebuffer_pool.get_framebuffer(_paint_framebuffer.size)
			ImageProcessor.render_device.texture_clear(masked_framebuffer.texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
			ImageProcessor.blend_async(masked_framebuffer, 
				_selection_texture,
				_selection_texture_offset,
				_paint_framebuffer.texture, 
				Vector2i.ZERO,	
				Color.WHITE,
				Rect2i(Vector2i.ZERO, _paint_framebuffer.size),
				ImageProcessor.BlendMode.InternalApplySelectionMask)
			final_paint_framebuffer = masked_framebuffer
		else:
			final_paint_framebuffer = _paint_framebuffer

		var rect := Rect2i(_back_texture_offset, ImageProcessor.get_texture_size(_back_texture))
		var paint_rect := Rect2i(Vector2i.ZERO, ImageProcessor.get_texture_size(_paint_framebuffer.texture))
		var tiling := canvas.document.tiling
		var document_size := canvas.document.size
		var wrap_rect : Rect2i
		if tiling != Document.Tiling.HORIZONTAL and tiling != Document.Tiling.BOTH:
			if paint_rect.position.x < rect.position.x:
				rect.size.x += rect.position.x - paint_rect.position.x
				rect.position.x = paint_rect.position.x
			if paint_rect.end.x > rect.end.x:
				rect.end.x = paint_rect.end.x
		else:
			rect.size.x = max(rect.size.x, document_size.x)
			wrap_rect.size.x = rect.size.x
		if tiling != Document.Tiling.VERTICAL and tiling != Document.Tiling.BOTH:
			if paint_rect.position.y < rect.position.y:
				rect.size.y += rect.position.y - paint_rect.position.y
				rect.position.y = paint_rect.position.y
			if paint_rect.end.y > rect.end.y:
				rect.end.y = paint_rect.end.y
		else:
			rect.size.y = max(rect.size.y, document_size.y)
			wrap_rect.size.y = rect.size.y

		var blended_framebuffer := _framebuffer_pool.get_framebuffer(rect.size)
		ImageProcessor.blend_async(blended_framebuffer,
			final_paint_framebuffer.texture, 
			-rect.position,
			_back_texture, 
			_back_texture_offset - rect.position,
			Color.WHITE,
			Rect2i(Vector2i.ZERO, blended_framebuffer.size), 
			ImageProcessor.BlendMode.Erase if _mode == Mode.ERASER else ImageProcessor.BlendMode.Normal,
			wrap_rect)

		if masked_framebuffer:
			_framebuffer_pool.release_framebuffer(masked_framebuffer.framebuffer)

		ImageProcessor.render_device.submit()
		ImageProcessor.render_device.sync()

		var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(blended_framebuffer.texture, 0)
		layer.image = Image.create_from_data(rect.size.x, rect.size.y, false, Image.FORMAT_RGBAF, byte_data)
		layer.offset = rect.position
		_framebuffer_pool.release_framebuffer(blended_framebuffer.framebuffer)

func _update_brush():
	if not _brush_texture or _brush_hardness != hardness or _brush_radius != radius:
		if _brush_texture:
			ImageProcessor.render_device.free_rid(_brush_texture)

		var gradient := GradientTexture2D.new()
		gradient.gradient = Gradient.new()
		gradient.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
		gradient.gradient.set_color(0, Color.WHITE)
		gradient.gradient.set_color(1, Color.TRANSPARENT)
		gradient.gradient.add_point(lerp(0.001, 0.999, hardness*0.01), Color.WHITE)
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_to = Vector2(0.5, 0.0)
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.width = radius*2
		gradient.height = radius*2

		# TODO: Should probably be able to use the GradientTexture right away with get_rid 
		# or something, but couldn't manage getting that working so let's just copy it.
		# Actually, should generate the gradient ourselves to get RGBAF and better shape
		# control.
		var gradient_image := gradient.get_image()
		gradient_image.convert(Image.FORMAT_RGBAF)
		_brush_texture = ImageProcessor.create_texture_from_image(gradient_image)
		_brush_hardness = hardness
		_brush_radius = radius

func _process_queue():
	_update_brush()

	var layer = canvas.document.get_selected_layer() as ImageLayer
	if not layer:
		return

	if _splat_queue.is_empty():
		return

	for pos in _splat_queue:
		_splat_from_last(pos)
	_splat_queue.clear()

	_update_blended_image()

func _splat(pos : Vector2, color : Color):
	var brush_pos := Vector2i(pos) - Vector2i(_brush_radius, _brush_radius)
	var brush_rect := Rect2i(brush_pos, Vector2i(radius, radius)*2)

	brush_rect = brush_rect.intersection(Rect2i(Vector2i.ZERO, _paint_framebuffer.size))
	if brush_rect.has_area():
	
		# TODO: This blending can probably be done with premultiplied alpha instead
		# and use regular blend functions to avoid the texture copy back for each splat
		ImageProcessor.blend_async(
			_paint_framebuffer,
			_brush_texture,
			brush_pos,
			_paint_framebuffer_copy_texture,
			Vector2i.ZERO,
			color,
			brush_rect)

		ImageProcessor.render_device.texture_copy(
			_paint_framebuffer.texture, 
			_paint_framebuffer_copy_texture, 
			Vector3(brush_rect.position.x, brush_rect.position.y, 0), 
			Vector3(brush_rect.position.x, brush_rect.position.y, 0), 
			Vector3(brush_rect.size.x, brush_rect.size.y, 0), 0, 0, 0, 0)

func _splat_from_last(pos : Vector2, force : bool = false):
	var layer = canvas.document.get_selected_layer() as ImageLayer
	if not layer:
		return

	var splat_interval = radius * 0.25
	_update_brush()

	var splat_color := Color.WHITE if _mode == Mode.ERASER else canvas.document.foreground_color

	var h_offsets : Array
	var v_offsets : Array

	if canvas.document.tiling == Document.Tiling.HORIZONTAL or canvas.document.tiling == Document.Tiling.BOTH:
		h_offsets = [-canvas.document.size.x, 0, canvas.document.size.x]
	else:
		h_offsets = [0]

	if canvas.document.tiling == Document.Tiling.VERTICAL or canvas.document.tiling == Document.Tiling.BOTH:
		v_offsets = [-canvas.document.size.y, 0, canvas.document.size.y]
	else:
		v_offsets = [0]

	while _last_splat_point.distance_to(pos) > splat_interval or force:
		_last_splat_point = _last_splat_point.move_toward(pos, splat_interval)

		for h_offset in h_offsets:
			for v_offset in v_offsets:
				_splat(_last_splat_point + Vector2(h_offset, v_offset), splat_color)
		force = false

func _draw_overlay():
	var pos := _overlay.get_local_mouse_position()
	var scale := _image_control.scale.x
	_overlay.draw_circle(pos, radius * scale + 1, Color.BLACK, false, -1.0, true)
	_overlay.draw_circle(pos, radius * scale, Color.WHITE, false, -1.0, true)

func process():
	_process_queue()
	_overlay.queue_redraw()
