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
		selection = Image.create(max(8, rect.size.x), max(8, rect.size.y), false, Image.FORMAT_RF)
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
	selection = Image.create(size.x+32, size.y+32, false, Image.FORMAT_RF)
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

func _render_compiled_layer_list(framebuffer_pool : ImageProcessor.FramebufferPool, layer_list : Array) -> Layer.RenderOutput:
	var num_layers := len(layer_list)
	var last_output : Layer.RenderOutput = null

	var pushed_groups := {}
	var held_outputs := []

	# Iterate over layers backwards because that's the order they're to be blended
	for layer_index in range(num_layers-1, -1, -1):
		var entry = layer_list[layer_index]
		var layer = entry.layer

		var layer_output : Layer.RenderOutput = null

		# Group layers are special
		if layer is GroupLayer:
			if entry.op == &"push":
				# If this is the beginning of a pass-through group we store the current compositing state
				# (if there is one)
				if last_output:
					var pushed_output := Layer.RenderOutput.new()
					pushed_output.texture = last_output.texture
					pushed_output.offset = last_output.offset
					pushed_groups[layer.id] = pushed_output
					held_outputs.push_back(pushed_output.texture)
				continue
			elif entry.op == &"pop":
				var held_output = pushed_groups.get(layer.id, null)

				# If it's the end of a pass-through group and the group actually did anything, 
				# we mix the original state back based on the opacity to partially "undo" 
				# whatever the group has done.
				if last_output != held_output:
					var held_texture = held_output.texture if held_output else ImageProcessor.dummy_texture
					var held_offset = held_output.offset if held_output else Vector2i.ZERO
					var last_output_size := ImageProcessor.get_texture_size(last_output.texture)
					var framebuffer = framebuffer_pool.get_framebuffer(last_output_size)
					ImageProcessor.blend_async(framebuffer, 
						last_output.texture,
						Vector2i.ZERO,
						held_texture,
						held_offset - last_output.offset,
						Color(1, 1, 1, layer.opacity), 
						Rect2i(Vector2i.ZERO, framebuffer.size),
						# If we're blending against a dummy we don't want the crossfade because it'll
						# blend in black
						ImageProcessor.BlendMode.InternalCrossFade if held_output else ImageProcessor.BlendMode.Normal)

					framebuffer_pool.release_framebuffer_by_texture(last_output.texture)
					last_output.texture = framebuffer.texture

					pushed_groups.erase(layer.id)

				if held_output:
					# With multiple nested pass-through groups the same output may be held
					# multiple times, we just erase one like a refcount
					held_outputs.erase(held_output.texture)
					# and release it if it's fully gone
					if held_outputs.find(held_output.texture) == -1:
						framebuffer_pool.release_framebuffer_by_texture(held_output.texture)

				continue
			else:
				# If it's a "normal" group, its layers have already been composited and
				# we're using the result as the output of this layer.
				assert(entry.op == &"blend")
				layer_output = entry.output
		else:
			layer_output = layer.render(framebuffer_pool)

		# Add any effects...	
		for effect : Effect in layer.effects:
			if effect.visible:
				var new_output := effect.render(framebuffer_pool, layer_output.texture)
				if new_output.texture != layer_output.texture:
					framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)
				layer_output.texture = new_output.texture
				layer_output.offset += new_output.offset

		# If it's the first layer with no blending, we're done and this is the output
		if not last_output and layer.opacity == 1 and layer.blend_mode == ImageProcessor.BlendMode.Normal:
			last_output = layer_output
		else:
			# If it's the first layer and it has blending, we blend on top of
			# a dummy texture just to keep things simple even if it's not optimal.
			if not last_output:
				last_output = Layer.RenderOutput.new()
				last_output.texture = ImageProcessor.dummy_texture

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

			# Again, only release output if it's not held
			if held_outputs.find(last_output.texture) == -1:
				framebuffer_pool.release_framebuffer_by_texture(last_output.texture)

			framebuffer_pool.release_framebuffer_by_texture(layer_output.texture)
			last_output.texture = framebuffer.texture
			last_output.offset += rect.position

	assert(held_outputs.is_empty())	

	return last_output

func _render_layers(framebuffer_pool : ImageProcessor.FramebufferPool, layers_to_render : Array[Layer]) -> Layer.RenderOutput:
	# Keep a stack of groups. First one may not be an actual group, but it makes it simpler
	# to always have an entry in the stack.
	var layer_stack := [{"group_id": layers_to_render.front().parent_id, "group_layer": null, "layers": [], "visible": true}]
	for layer in layers_to_render:
		if layer is GroupLayer:
			# Check if it's a pass through group. Groups with effects can't be pass-through
			var pass_through := layer.blend_mode == ImageProcessor.BlendMode.PassThrough and layer.effects.is_empty()
			# If it _is_ a pass through group, we use the parent group's layer list,
			# and composite it all in the same run
			var layer_list = layer_stack.back().layers if pass_through else []
			layer_stack.push_back({"group_id": layer.id, "group_layer": layer, "layers": layer_list, "visible": layer.visible and layer_stack.back().visible})
			if pass_through and layer.opacity != 1:
				# If we need to do opacity blending, we push a marker into the list that it needs handling. 
				# Since the renderer will render backwards (bottom up) this is the end of the group,
				# hence the "pop"
				layer_stack.back().layers.push_back({"layer": layer, "op": &"pop"})
		else:
			# When a layer is encountered that doesn't have the current group as parent
			# we're at the end of the current group and we start unraveling. 
			while layer_stack.back().group_id != layer.parent_id:
				var group_layer = layer_stack.back().group_layer
				# Non-pass through groups get rendered now
				if layer_stack.back().visible and (group_layer.blend_mode != ImageProcessor.BlendMode.PassThrough or not group_layer.effects.is_empty()):
					# Render the layers of the current group
					var output := _render_compiled_layer_list(framebuffer_pool, layer_stack.back().layers)
					# ...and pop it off the stack
					layer_stack.pop_back()
					if output:
						# If there actually was output (group wasn't empty) we add this to be composited
						# in the now current group.
						layer_stack.back().layers.push_back({"layer" : group_layer, "op": &"blend", "output": output})
				else:
					# For pass through groups that need blending we add a push-marker that the group starts here
					# (again, the renderer goes backwards)
					if group_layer.opacity != 1:
						layer_stack.back().layers.push_back({"layer": group_layer, "op": &"push"})
					layer_stack.pop_back()

			# All ending groups have been popped, add the layer to the current group's layer list
			if layer_stack.back().visible and layer.visible:
				layer_stack.back().layers.push_back({"layer": layer})

	# This is mostly the same as the popping loop above, popping any groups off the end
	# of the layer stack
	var final_output : Layer.RenderOutput = null
	while not layer_stack.is_empty():
		var group_layer = layer_stack.back().group_layer
		if layer_stack.back().visible and (not group_layer or group_layer.blend_mode != ImageProcessor.BlendMode.PassThrough or not group_layer.effects.is_empty()):
			var output := _render_compiled_layer_list(framebuffer_pool, layer_stack.back().layers)
			layer_stack.pop_back()
			if layer_stack.is_empty():
				final_output = output
			else:
				if output:
					layer_stack.back().layers.push_back({"layer" : group_layer, "op": &"blend", "output": output})
		else:
			if group_layer.opacity != 1:
				layer_stack.back().layers.push_back({"layer": group_layer, "op": &"push"})
			layer_stack.pop_back()

	return final_output

func _render() -> void:
	_rendered_layers.clear()

	var framebuffer_pool := ImageProcessor.FramebufferPool.new()

	var canvas_framebuffer = framebuffer_pool.get_framebuffer(size)
	canvas_framebuffer["layer_id"] = 0

	var final_output := _render_layers(framebuffer_pool, layers)

	# Copy the final result to the final texture
	# TODO: This creates a dummy input texture and blend_async, but it
	# should really just be a copy
	if final_output:
		ImageProcessor.blend_async(canvas_framebuffer, final_output.texture, final_output.offset, ImageProcessor.dummy_texture, Vector2i.ZERO, Color.WHITE)
		framebuffer_pool.release_framebuffer_by_texture(final_output.texture)

	ImageProcessor.render_device.submit()
	ImageProcessor.render_device.sync()

	var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(canvas_framebuffer.texture, 0)
	output_image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBAF, byte_data)

	framebuffer_pool.release_framebuffer(canvas_framebuffer.framebuffer)

	for layer in layers:
		# Keep a copy of last rendered layers to compare to for figuring out if we need to re-render 
		_rendered_layers.push_back(layer.clone())


func merge_down(layer_id : int) -> int:
	var start_index : int = -1
	for layer_index in len(layers):
		if layers[layer_index].id == layer_id:
			start_index = layer_index
			break

	if start_index == -1:
		return 0

	var new_name : String
	var end_index := start_index
	if layers[start_index] is GroupLayer:
		new_name = layers[start_index].name
		end_index = find_group_end(start_index)
	elif start_index+1 >= len(layers):
		return layers[start_index].id
	elif layers[start_index+1] is GroupLayer:
		new_name = layers[start_index+1].name
		end_index = find_group_end(start_index+1)
	else:
		if layers[start_index+1].parent_id != layers[start_index].parent_id:
			return layers[start_index].id
		new_name = layers[start_index+1].name
		end_index = start_index + 2
	
	var layers_to_merge : Array[Layer] = []
	for index in range(start_index, end_index):
		layers_to_merge.push_back(layers[index])

	if layers_to_merge.is_empty():
		assert(false)
		return layers[start_index].id

	var framebuffer_pool := ImageProcessor.FramebufferPool.new()
	var merged_output := _render_layers(framebuffer_pool, layers_to_merge)

	if not merged_output or not merged_output.texture:
		return layers[start_index].id
	
	ImageProcessor.render_device.submit()
	ImageProcessor.render_device.sync()

	var output_size := ImageProcessor.get_texture_size(merged_output.texture)
	var byte_data : PackedByteArray = ImageProcessor.render_device.texture_get_data(merged_output.texture, 0)
	var merged_image := Image.create_from_data(output_size.x, output_size.y, false, Image.FORMAT_RGBAF, byte_data)

	var layer := ImageLayer.new()
	layer.image = merged_image
	layer.parent_id = layers_to_merge.front().parent_id
	layer.offset = merged_output.offset
	layer.name = new_name

	for i in len(layers_to_merge):
		layers.remove_at(start_index)

	layers.insert(start_index, layer)

	framebuffer_pool.release_framebuffer_by_texture(merged_output.texture)
	
	return layer.id

func add_new_layer_at_selection() -> int:
	var layer := ImageLayer.new()
	layer.image = Image.create(8, 8, false, Image.FORMAT_RGBAF)
	layer.name = get_new_layer_name()
	
	var new_index = 0
	if selected_layer_id != 0:
		new_index = find_layer_index(selected_layer_id)
		if layers[new_index] is GroupLayer:
			layer.parent_id = layers[new_index].id
			new_index += 1
		else:
			layer.parent_id = layers[new_index].parent_id
	layers.insert(new_index, layer)
	
	return layer.id

func add_new_folder_at_selection() -> int:
	var layer := GroupLayer.new()
	layer.name = get_new_layer_name("Folder")
	
	var new_index = 0
	if selected_layer_id != 0:
		new_index = find_layer_index(selected_layer_id)
		if layers[new_index] is GroupLayer:
			layer.parent_id = layers[new_index].id
			new_index += 1
		else:
			layer.parent_id = layers[new_index].parent_id
	layers.insert(new_index, layer)
	
	return layer.id

func duplicate_selection() -> int:
	var selected_layer := get_selected_layer()
	if not selected_layer:
		return 0

	var new_layers : Array[Layer] = []
	var new_index = find_layer_index(selected_layer_id)
	if selected_layer is GroupLayer:
		var layer := selected_layer.clone()
		layer.id = Layer._get_next_id()
		new_layers.push_back(layer)

		var src_stack : Array[int] = []
		var new_stack : Array[int] = []
		var src_index = new_index + 1
		var last_src_id = selected_layer.id
		var last_new_id = layer.id
		while src_index < len(layers):
			if layers[src_index].parent_id == last_src_id:
				src_stack.push_back(last_src_id)
				new_stack.push_back(last_new_id)
			
			while not src_stack.is_empty() and layers[src_index].parent_id != src_stack.back():
				src_stack.pop_back()
				new_stack.pop_back()
			
			if src_stack.is_empty():
				break

			var new_layer := layers[src_index].clone()
			new_layer.id = Layer._get_next_id()
			new_layer.parent_id = new_stack.back()
			new_layers.push_back(new_layer)

			last_src_id = layers[src_index].id
			last_new_id = new_layer.id
			src_index += 1
	else:
		var layer := selected_layer.clone()
		layer.id = Layer._get_next_id()
		new_layers.push_back(layer)

	for layer in new_layers:
		layers.insert(new_index, layer)
		new_index += 1

	return new_layers.front().id
