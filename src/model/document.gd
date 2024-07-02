class_name Document extends KnixelResource

@export var size : Vector2i
@export var layers : Array[Layer] = []
@export var selected_layer_id : int = 0
@export var selected_effect_id : int = 0

var path : String
var last_export_path : String
var output_image : Image
var selection : Image
var selection_offset : Vector2i

var foreground_color := Color.WHITE
var background_color := Color.BLACK

var _undo_stack : Array[Document] = []
var _redo_stack : Array[Document] = []
var _undo_state : Document
var _undo_block_counter : int = 0

var _rendered_layers : Array[Layer]

func reset_undo() -> void:
	_undo_state.copy_from(self)
	_undo_stack.clear()
	_redo_stack.clear()

func _get_property_list() -> Array:
	var extra_props := []

	extra_props.append({
		"name": "output_image",
		"type": TYPE_OBJECT,
		"usage": PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NEVER_DUPLICATE,
		"hint": 0,
		"hint_string": "Image"
	})

	return extra_props

func compare(other : KnixelResource) -> bool:
	if !super(other):
		return false
	elif selection != other.selection:
		return false
	elif selection_offset != other.selection_offset:
		return false

	return true

func copy_from(other : KnixelResource) -> void:
	super(other)

	path = other.path
	last_export_path = other.last_export_path
	selection = other.selection
	selection_offset = other.selection_offset

func check() -> bool:
	var dirty := false
	if len(layers) != len(_rendered_layers):
		dirty = true
	else:
		for index in len(layers):
			if !layers[index].compare(_rendered_layers[index]):
				dirty = true
				break

	if !_undo_state:
		_undo_state = clone()

	if _undo_block_counter == 0:
		if !_undo_state.compare(self):
			_undo_state.compare(self)
			_undo_stack.push_back(_undo_state)
			_redo_stack.clear()
			_undo_state = clone()

	if dirty:
		_render()

	return dirty

func start_undo_block() -> void:
	_undo_block_counter += 1

func end_undo_block() -> void:
	assert(_undo_block_counter > 0)
	_undo_block_counter -= 1

func undo() -> void:
	if !_undo_stack.is_empty():
		_redo_stack.push_back(clone())
		_undo_state = _undo_stack.pop_back()
		copy_from(_undo_state)

func redo() -> void:
	if !_redo_stack.is_empty():
		_undo_stack.push_back(duplicate())
		_undo_state = _redo_stack.pop_back()
		copy_from(_undo_state)

func ensure_selection_rect(rect : Rect2i) -> void:
	# Always keep a border around, otherwise the outline
	# shader will not draw an outline at the border.
	# Maybe solve it differently in the shader sometime
	rect.position -= Vector2i(16, 16)
	rect.size += Vector2i(32, 32)

	if not selection:
		selection_offset = rect.position
		selection = Image.create(max(8, rect.size.x), max(8, rect.size.y), false, Image.FORMAT_R8)
		return

	var current_rect = Rect2i(selection_offset, selection.get_size())
	if current_rect.encloses(rect):
		return

	rect = rect.merge(current_rect)

	var new_selection = ImageProcessor.crop_or_extend(selection, rect, selection_offset)
	selection_offset = Vector2i(rect.position.x, rect.position.y)
	selection = new_selection

func select_all() -> void:
	# TODO: Make sure padding isn't required
	selection_offset = Vector2i(-16, -16)
	selection = Image.create(size.x+32, size.y+32, false, Image.FORMAT_R8)
	selection.fill_rect(Rect2i(16, 16, size.x, size.y), Color.WHITE)

func clear_selection() -> void:
	selection_offset = Vector2i.ZERO
	selection = null

func get_selected_layer() -> Layer:
	for layer in layers:
		if layer.id == selected_layer_id:
			return layer
	return null

func get_new_layer_name(prefix : String = "") -> String:
	var index := 1
	if prefix.is_empty():
		prefix = "Layer"
	while true:
		var suggested_name := prefix + " " + str(index)
		var collision := false
		for layer in layers:
			if layer.name == suggested_name:
				collision = true
				break
		if not collision:
			return suggested_name
		index += 1

	return "" # Godot doesn't understand this is unreachable

func delete_selection():
	if selection:
		var layer := get_selected_layer()
		if layer:
			layer.image = ImageProcessor.erase_mask(layer.image, selection, selection_offset-layer.offset)

func fill(color : Color):
	var layer := get_selected_layer()
	if layer:
		var selection_rect := selection.get_used_rect() if selection else Rect2i()
		if selection_rect.has_area():
			selection_rect.position += selection_offset
			var layer_rect := Rect2i(layer.offset, layer.image.get_size())
			var rect = layer_rect.merge(selection_rect)
			layer.image = ImageProcessor.crop_or_extend(layer.image, rect, layer.offset)
			layer.offset = rect.position
			layer.image = ImageProcessor.fill_mask(layer.image, selection, selection_offset-layer.offset, color)
		else:
			var layer_rect := Rect2i(layer.offset, layer.image.get_size())
			var document_rect := Rect2i(Vector2i(0, 0), size)
			var rect = layer_rect.merge(document_rect)
			layer.image = ImageProcessor.crop_or_extend(layer.image, rect, layer.offset)
			layer.offset = rect.position
			layer.image.fill_rect(Rect2i(-layer.offset, size), color)

func swap_colors():
	var tmp = foreground_color
	foreground_color = background_color
	background_color = tmp

func reset_colors():
	foreground_color = Color.WHITE
	background_color = Color.BLACK

func resize_image(new_size : Vector2i):
	var factor := Vector2(new_size) / Vector2(size)
	size = new_size
	for layer in layers:
		layer.rescale(factor)

static func load_from_file(file_path : String) -> Variant:
	var reader := KnixelResource.Reader.new()
	var err := reader.open(file_path)
	if err:
		return err

	var data = reader.read_blob("document.json")
	if not data:
		return Error.ERR_FILE_CORRUPT

	var dic = JSON.parse_string(data.get_string_from_utf8())
	if not dic is Dictionary:
		return Error.ERR_FILE_CORRUPT

	var result = KnixelResource.load(dic, reader, "document")

	reader.close()

	return result

# Things act weird if this is called just "save" for some reason
func save_to_file() -> void:
	var writer := KnixelResource.Writer.new()
	writer.open(path)

	var dict := save(writer)
	writer.write_blob("document.json", JSON.stringify(dict).to_utf8_buffer())

func _render():
	_rendered_layers.clear()

	var framebuffer_pool := ImageProcessor.FramebufferPool.new()

	var canvas_framebuffer = framebuffer_pool.get_framebuffer(size)
	var tmp_framebuffer = framebuffer_pool.get_framebuffer(size)

	var num_layers := len(layers)

	var last_output = tmp_framebuffer.texture

	for layer_index in num_layers:
		var layer := layers[layer_index]

		if layer.visible:
			var offset := layer.offset
		
			var layer_output := layer.render(framebuffer_pool)
			for effect : Effect in layer.effects:
				if effect.visible:
					var new_output := effect.render(framebuffer_pool, layer_output.texture)
					if new_output.texture != layer_output.texture:
						framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)
					layer_output = new_output
					offset += layer_output.offset

			var framebuffer = framebuffer_pool.get_framebuffer(size)
			ImageProcessor.blend_async(framebuffer, layer_output.texture, offset, last_output, Vector2i.ZERO, Color(1, 1, 1, layer.opacity), Rect2i(Vector2i.ZERO, framebuffer.size), layer.blend_mode)
			if layer_output.texture != last_output:
				framebuffer_pool.release_framebuffer_by_texture(last_output)
			last_output = framebuffer.texture
			framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)

		_rendered_layers.push_back(layer.clone())

	ImageProcessor.render_device.texture_copy(last_output, canvas_framebuffer.texture, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 0), 0, 0, 0, 0)
	framebuffer_pool.release_framebuffer_by_texture(last_output)

	ImageProcessor.render_device.submit()
	ImageProcessor.render_device.sync()

	var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(canvas_framebuffer.texture, 0)
	output_image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, byte_data)

	framebuffer_pool.release_framebuffer(canvas_framebuffer.framebuffer)
