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
	if output_image == null or output_image.get_size() != size:
		dirty = true

	if not dirty:
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

func find_layer_by_id(layer_id : int) -> Layer:
	# TODO: Table lookup if this turns out too slow
	for layer in layers:
		if layer.id == layer_id:
			return layer

	return null

func find_layer_index(layer_id : int) -> int:
	var index := 0
	for layer in layers:
		if layer.id == layer_id:
			return index
		index += 1

	return -1

func find_group_end(group_index : int) -> int:
	var index := group_index+1
	var num_layers := len(layers)
	var stack := []
	var last_layer_id = layers[group_index].id
	while index < num_layers:
		if layers[index].parent_id == last_layer_id:
			stack.push_back(last_layer_id)

		while not stack.is_empty() and layers[index].parent_id != stack.back():
			stack.pop_back()

		if stack.is_empty():
			break

		last_layer_id = layers[index].id
		index += 1

	return index


func is_layer_descendent_of_other(layer : Layer, other : Layer) -> bool:
	var scan_layer := layer

	while scan_layer.parent_id != 0:
		scan_layer = find_layer_by_id(scan_layer.parent_id)
		if not scan_layer or scan_layer == layer:
			# Broken/cyclic tree
			# TODO: More complete test, this doesn't catch all
			# and can end up in infinite loop with broken data.
			assert(false)
			return false
		if scan_layer.id == other.id:
			return true

	return false

func calc_layer_depth(layer : Layer) -> int:
	var depth := 0

	var scan_layer := layer
	while scan_layer.parent_id != 0:
		depth += 1
		scan_layer = find_layer_by_id(scan_layer.parent_id)
		if not scan_layer or scan_layer == layer:
			# Broken/cyclic tree
			# TODO: More complete test, this doesn't catch all
			# and can end up in infinite loop with broken data.
			assert(false)
			return false

	return depth

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
		if layer and layer is ImageLayer:
			layer.image = ImageProcessor.erase_mask(layer.image, selection, selection_offset-layer.offset)

func fill(color : Color):
	var layer := get_selected_layer()
	if layer and layer is ImageLayer:
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

func resize_canvas(new_size : Vector2i, horizontal_alignment : HorizontalAlignment, vertical_alignment : VerticalAlignment):
	var offset : Vector2i
	var diff := new_size - size
	size = new_size

	if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		offset.x = int(diff.x*0.5)
	elif horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		offset.x = diff.x

	if vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		offset.y = int(diff.y*0.5)
	elif vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		offset.y = diff.y

	for layer in layers:
		layer.offset += offset

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

func _render_layers(framebuffer_pool : ImageProcessor.FramebufferPool, layer_list : Array) -> Layer.RenderOutput:
	var num_layers := len(layer_list)
	var last_output : Layer.RenderOutput = null
	for layer_index in range(num_layers-1, -1, -1):
		var entry = layer_list[layer_index]
		var layer = entry.layer

		var layer_output : Layer.RenderOutput = null
		if layer is GroupLayer:
			layer_output = entry.output
		else:
			layer_output = layer.render(framebuffer_pool)
		
		for effect : Effect in layer.effects:
			if effect.visible:
				var new_output := effect.render(framebuffer_pool, layer_output.texture)
				if new_output.texture != layer_output.texture:
					framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)
				layer_output.texture = new_output.texture
				layer_output.offset += new_output.offset

		if not last_output and layer.blend_mode == ImageProcessor.BlendMode.Normal:
			last_output = layer_output
		else:
			if not last_output:
				var temp_framebuffer := framebuffer_pool.get_framebuffer(Vector2i(32, 32))
				last_output = Layer.RenderOutput.new()
				last_output.texture = temp_framebuffer.texture

			var rect := Rect2i(Vector2i.ZERO, ImageProcessor.get_texture_size(last_output.texture))
			rect = rect.merge(Rect2i(layer_output.offset - last_output.offset, ImageProcessor.get_texture_size(layer_output.texture)))

			var framebuffer = framebuffer_pool.get_framebuffer(rect.size)
			ImageProcessor.blend_async(framebuffer, 
				layer_output.texture,
				layer_output.offset - last_output.offset - rect.position,
				last_output.texture,
				-rect.position,
				Color(1, 1, 1, layer.opacity), 
				Rect2i(Vector2i.ZERO, framebuffer.size), 
				layer.blend_mode)
			
			framebuffer_pool.release_framebuffer_by_texture(last_output.texture)
			framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)
			last_output.texture = framebuffer.texture
			last_output.offset += rect.position

	return last_output

func _render() -> void:
	_rendered_layers.clear()

	var framebuffer_pool := ImageProcessor.FramebufferPool.new()

	var canvas_framebuffer = framebuffer_pool.get_framebuffer(size)
	canvas_framebuffer["layer_id"] = 0

	var layer_stack := [{"group_id": 0, "group_layer": null, "layers": []}]
	for layer in layers:
		_rendered_layers.push_back(layer.clone())

		if layer is GroupLayer:
			var pass_through := layer.blend_mode == ImageProcessor.BlendMode.PassThrough and layer.effects.is_empty()
			var layer_list = layer_stack.back().layers if pass_through else []
			layer_stack.push_back({"group_id": layer.id, "group_layer": layer, "layers": layer_list})
		else:
			while layer_stack.back().group_id != layer.parent_id:
				var group_layer = layer_stack.back().group_layer
				if group_layer.blend_mode != ImageProcessor.BlendMode.PassThrough or not group_layer.effects.is_empty():
					var output := _render_layers(framebuffer_pool, layer_stack.back().layers)
					layer_stack.pop_back()
					if output:
						layer_stack.back().layers.push_back({"layer" : group_layer, "output": output})
				else:
					layer_stack.pop_back()
			layer_stack.back().layers.push_back({"layer": layer})

	var final_output : Layer.RenderOutput = null
	while not layer_stack.is_empty():
		var group_layer = layer_stack.back().group_layer
		if not group_layer or group_layer.blend_mode != ImageProcessor.BlendMode.PassThrough or not group_layer.effects.is_empty():
			var output := _render_layers(framebuffer_pool, layer_stack.back().layers)
			layer_stack.pop_back()
			if layer_stack.is_empty():
				final_output = output
			else:
				if output:
					layer_stack.back().layers.push_back({"layer" : group_layer, "output": output})
		else:
			layer_stack.pop_back()


	var bogus_texture := ImageProcessor.create_texture(Vector2i(16, 16))
	ImageProcessor.blend_async(canvas_framebuffer, final_output.texture, final_output.offset, bogus_texture, Vector2i.ZERO, Color.WHITE)
	framebuffer_pool.release_framebuffer_by_texture(final_output.texture)

	ImageProcessor.render_device.submit()
	ImageProcessor.render_device.sync()

	var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(canvas_framebuffer.texture, 0)
	output_image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, byte_data)
	output_image.generate_mipmaps()

	ImageProcessor.render_device.free_rid(bogus_texture)

	framebuffer_pool.release_framebuffer(canvas_framebuffer.framebuffer)
