class_name ImageProcessor extends Node

enum BlendMode { Normal, Add, Darken, Difference, Lighten, Multiply, Screen, Subtract }

static var render_device := RenderingServer.create_local_rendering_device()
static var texture_view := RDTextureView.new()

class FramebufferPool extends RefCounted:
	var available_framebuffers : Array[Dictionary]
	var used_framebuffers : Array[Dictionary]

	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			for entry in available_framebuffers:
				ImageProcessor.render_device.free_rid(entry.framebuffer)
				ImageProcessor.render_device.free_rid(entry.texture)

			assert(used_framebuffers.is_empty())

			for entry in used_framebuffers:
				ImageProcessor.render_device.free_rid(entry.framebuffer)
				ImageProcessor.render_device.free_rid(entry.texture)

	func get_framebuffer(size : Vector2i) -> Dictionary:
		var entry : Dictionary
		for i in len(available_framebuffers):
			if available_framebuffers[i].size == size:
				entry = available_framebuffers.pop_at(i)
				break

		if not entry:
			var texture : RID = ImageProcessor.create_texture(size, RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)
			ImageProcessor.render_device.texture_clear(texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
			var framebuffer = ImageProcessor.render_device.framebuffer_create([texture])

			entry = { "texture": texture, "framebuffer": framebuffer, "size": size }

		used_framebuffers.push_back(entry)
		return entry

	func release_framebuffer(framebuffer : RID):
		for i in len(used_framebuffers):
			if used_framebuffers[i].framebuffer == framebuffer:
				available_framebuffers.push_back(used_framebuffers.pop_at(i))
				break

	func release_framebuffer_by_texture(texture : RID):
		for i in len(used_framebuffers):
			if used_framebuffers[i].texture == texture:
				available_framebuffers.push_back(used_framebuffers.pop_at(i))
				break

class ProcessingPipeline extends RefCounted:

	var render_device : RenderingDevice

	var rasterization_state := RDPipelineRasterizationState.new()
	var multisample_state := RDPipelineMultisampleState.new()
	var depth_stencil_state := RDPipelineDepthStencilState.new()
	var color_blend_state := RDPipelineColorBlendState.new()

	var shader : RID

	var pipelines : Dictionary

	func _init(rd : RenderingDevice):
		render_device = rd

	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			render_device.free_rid(shader)
			for pipeline in pipelines.values():
				render_device.free_rid(pipeline)

	func get_for_framebuffer(framebuffer : RID) -> RID:
		var framebuffer_format := render_device.framebuffer_get_format(framebuffer)

		if pipelines.has(framebuffer_format):
			return pipelines.get(framebuffer_format)

		var pipeline := render_device.render_pipeline_create(shader, 
			framebuffer_format, 
			RenderingDevice.INVALID_FORMAT_ID, 
			RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, 
			rasterization_state, 
			multisample_state, 
			depth_stencil_state, 
			color_blend_state)

		pipelines[framebuffer_format] = pipeline

		return pipeline

static func _create_fill_mask_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/output_colored_mask.glsl").get_spirv())

	return pipeline

static var _fill_mask_pipeline := _create_fill_mask_pipeline(render_device)

static func _create_splat_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/splat_texture.glsl").get_spirv())

	return pipeline

static var _splat_pipeline := _create_splat_pipeline(render_device)

static func _create_erase_mask_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_REVERSE_SUBTRACT
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/output_colored_mask.glsl").get_spirv())

	return pipeline

static var _erase_mask_pipeline := _create_erase_mask_pipeline(render_device)

static func _create_apply_mask_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/output_colored_mask.glsl").get_spirv())

	return pipeline

static var _apply_mask_pipeline := _create_apply_mask_pipeline(render_device)

static func _create_blend_pipeline(rd : RenderingDevice, blend_shader : RDShaderFile) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = false

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(blend_shader.get_spirv())

	return pipeline

static var _blend_pipelines := {}

static func _create_blur_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = false

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/blur.glsl").get_spirv())

	return pipeline

static var _blur_pipeline := _create_blur_pipeline(render_device)

static func _create_colorize_pipeline(rd : RenderingDevice) -> ProcessingPipeline:
	var pipeline := ProcessingPipeline.new(rd)

	var blend_attachment = RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	blend_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA

	pipeline.color_blend_state.attachments = [blend_attachment]
	
	pipeline.shader = rd.shader_create_from_spirv(preload("res://src/shaders/operations/output_solid_color.glsl").get_spirv())

	return pipeline

static var _colorize_pipeline := _create_colorize_pipeline(render_device)

static var _rect_index_buffer : RID
static var _rect_index_array : RID

static func _static_init():
	_blend_pipelines[BlendMode.Add] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/add.glsl"))
	_blend_pipelines[BlendMode.Darken] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/darken.glsl"))
	_blend_pipelines[BlendMode.Difference] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/difference.glsl"))
	_blend_pipelines[BlendMode.Lighten] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/lighten.glsl"))
	_blend_pipelines[BlendMode.Multiply] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/multiply.glsl"))
	_blend_pipelines[BlendMode.Normal] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/normal.glsl"))
	_blend_pipelines[BlendMode.Screen] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/screen.glsl"))
	_blend_pipelines[BlendMode.Subtract] = _create_blend_pipeline(render_device, preload("res://src/shaders/blend_modes/subtract.glsl"))

	var index_byte_array := PackedByteArray()
	index_byte_array.resize(12)
	index_byte_array.encode_u16(0, 0)
	index_byte_array.encode_u16(2, 1)
	index_byte_array.encode_u16(4, 2)
	index_byte_array.encode_u16(6, 1)
	index_byte_array.encode_u16(8, 2)
	index_byte_array.encode_u16(10, 3)
	_rect_index_buffer = render_device.index_buffer_create(6, RenderingDevice.INDEX_BUFFER_FORMAT_UINT16, index_byte_array)
	_rect_index_array = render_device.index_array_create(_rect_index_buffer, 0, 6)

static func shutdown():
	# TODO: Free everything properly
	render_device.free_rid(_rect_index_buffer)
	render_device.free_rid(_rect_index_array)

static func create_texture(size : Vector2i, usage_bits : int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) -> RID:
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = usage_bits

	return render_device.texture_create(format, texture_view, [])

static func create_texture_from_image(image : Image, usage_bits : int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT) -> RID:
	var format := RDTextureFormat.new()
	format.width = image.get_width()
	format.height = image.get_height()
	if image.get_format() == Image.FORMAT_RGBA8:
		format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	elif image.get_format() == Image.FORMAT_R8:
		format.format = RenderingDevice.DATA_FORMAT_R8_SRGB
	else:
		assert(false, "Unsupported image format: " + str(image.get_format()))
	format.usage_bits = usage_bits

	return render_device.texture_create(format, texture_view, [image.get_data()])

static func splat(framebuffer : RID, framebuffer_size : Vector2i, texture : RID, rect : Rect2i, color : Color):
	var rids : Array[RID] = []

	var constants := PackedByteArray()
	constants.resize(32)
	constants.encode_float(0, rect.position.x / float(framebuffer_size.x))
	constants.encode_float(4, rect.position.y / float(framebuffer_size.y))
	constants.encode_float(8, (rect.position.x + rect.size.x) / float(framebuffer_size.x))
	constants.encode_float(12, (rect.position.y + rect.size.y) / float(framebuffer_size.y))
	constants.encode_float(16, color.r)
	constants.encode_float(20, color.g)
	constants.encode_float(24, color.b)
	constants.encode_float(28, color.a)

	var sampler_state := RDSamplerState.new()
	var sampler = render_device.sampler_create(sampler_state)
	rids.push_back(sampler)

	var tex_uniform = RDUniform.new()
	tex_uniform.binding = 0
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	tex_uniform.add_id(sampler)
	tex_uniform.add_id(texture)

	var uniform_set := render_device.uniform_set_create([tex_uniform], _splat_pipeline.shader, 0)
	rids.push_back(uniform_set)

	var clear_colors = PackedColorArray([Color(0, 0, 0, 0)])
	var draw_list = render_device.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_KEEP, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	render_device.draw_list_bind_render_pipeline(draw_list, _splat_pipeline.get_for_framebuffer(framebuffer))
	render_device.draw_list_bind_index_array(draw_list, _rect_index_array)
	render_device.draw_list_set_push_constant(draw_list, constants, constants.size())
	render_device.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	render_device.draw_list_draw(draw_list, true, 1)
	render_device.draw_list_end()

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

static func _output_mask(image : Image, mask : Image, offset : Vector2i, color : Color, pipeline : ProcessingPipeline) -> Image:
	var rids : Array[RID] = []

	var output_texture := create_texture_from_image(image, RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	rids.push_back(output_texture)

	var framebuffer := render_device.framebuffer_create([output_texture])
	rids.push_back(framebuffer)

	var mask_texture := create_texture_from_image(mask)
	rids.push_back(mask_texture)

	var constants := PackedByteArray()
	constants.resize(32)
	constants.encode_s32(0, offset.x)
	constants.encode_s32(4, offset.y)
	constants.encode_float(16, color.r)
	constants.encode_float(20, color.g)
	constants.encode_float(24, color.b)
	constants.encode_float(28, color.a)

	var sampler_state := RDSamplerState.new()
	var sampler = render_device.sampler_create(sampler_state)
	rids.push_back(sampler)

	var tex_uniform = RDUniform.new()
	tex_uniform.binding = 0
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	tex_uniform.add_id(sampler)
	tex_uniform.add_id(mask_texture)
	
	var uniform_set := render_device.uniform_set_create([tex_uniform], pipeline.shader, 0)
	rids.push_back(uniform_set)

	var clear_colors = PackedColorArray([Color(0, 0, 0, 0)])
	var draw_list = render_device.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_KEEP, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	render_device.draw_list_bind_render_pipeline(draw_list, pipeline.get_for_framebuffer(framebuffer))
	render_device.draw_list_bind_index_array(draw_list, _rect_index_array)
	render_device.draw_list_set_push_constant(draw_list, constants, constants.size())
	render_device.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	render_device.draw_list_draw(draw_list, true, 1)
	render_device.draw_list_end()

	render_device.submit()
	render_device.sync()

	var byte_data : PackedByteArray = render_device.texture_get_data(output_texture, 0)
	var new_image := Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, byte_data)

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

	return new_image

static func fill_mask(image : Image, mask : Image, offset : Vector2i = Vector2i.ZERO, color : Color = Color.TRANSPARENT) -> Image:
	return _output_mask(image, mask, offset, color, _fill_mask_pipeline)

static func erase_mask(image : Image, mask : Image, offset : Vector2i = Vector2i.ZERO) -> Image:
	return _output_mask(image, mask, offset, Color.WHITE, _erase_mask_pipeline)

static func apply_mask(image : Image, mask : Image, offset : Vector2i = Vector2i.ZERO) -> Image:
	return _output_mask(image, mask, offset, Color.WHITE, _apply_mask_pipeline)

static func blur_async(framebuffer : RID, src_texture : RID, radius : float, direction : Vector2i, offset : Vector2i):
	var rids : Array[RID] = []

	var constants := PackedByteArray()
	constants.resize(32)
	constants.encode_float(0, radius)
	constants.encode_s32(8, direction.x)
	constants.encode_s32(12, direction.y)
	constants.encode_s32(16, offset.x)
	constants.encode_s32(20, offset.y)

	var sampler_state := RDSamplerState.new()
	var sampler = render_device.sampler_create(sampler_state)
	rids.push_back(sampler)

	var src_tex_uniform = RDUniform.new()
	src_tex_uniform.binding = 0
	src_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	src_tex_uniform.add_id(sampler)
	src_tex_uniform.add_id(src_texture)

	var uniform_set := render_device.uniform_set_create([src_tex_uniform], _blur_pipeline.shader, 0)
	rids.push_back(uniform_set)

	var clear_colors = PackedColorArray([Color(1, 1, 1, 1)])
	var draw_list = render_device.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_DISCARD, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	render_device.draw_list_bind_render_pipeline(draw_list, _blur_pipeline.get_for_framebuffer(framebuffer))
	render_device.draw_list_bind_index_array(draw_list, _rect_index_array)
	render_device.draw_list_set_push_constant(draw_list, constants, constants.size())
	render_device.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	render_device.draw_list_draw(draw_list, true, 1)
	render_device.draw_list_end()

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

static func colorize_async(framebuffer : RID, color : Color):
	var rids : Array[RID] = []

	var constants := PackedByteArray()
	constants.resize(16)
	constants.encode_float(0, color.r)
	constants.encode_float(4, color.g)
	constants.encode_float(8, color.b)
	constants.encode_float(12, color.a)

	var clear_colors = PackedColorArray([Color(1, 1, 1, 1)])
	var draw_list = render_device.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_KEEP, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	render_device.draw_list_bind_render_pipeline(draw_list, _colorize_pipeline.get_for_framebuffer(framebuffer))
	render_device.draw_list_bind_index_array(draw_list, _rect_index_array)
	render_device.draw_list_set_push_constant(draw_list, constants, constants.size())
	render_device.draw_list_draw(draw_list, true, 1)
	render_device.draw_list_end()

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

static func get_texture_size(texture : RID) -> Vector2i:
	var format := render_device.texture_get_format(texture)
	return Vector2i(format.width, format.height)
		
static func blend_async(framebuffer : Dictionary, src_texture : RID, src_offset : Vector2i, dst_texture : RID, dst_offset : Vector2i, color : Color, rect : Rect2i = Rect2i(Vector2i.ZERO, framebuffer.size), blend_mode : BlendMode = BlendMode.Normal):
	var rids : Array[RID] = []

	var constants := PackedByteArray()
	constants.resize(48)
	constants.encode_s32(0, src_offset.x)
	constants.encode_s32(4, src_offset.y)
	constants.encode_s32(8, dst_offset.x)
	constants.encode_s32(12, dst_offset.y)
	constants.encode_float(16, rect.position.x/float(framebuffer.size.x))
	constants.encode_float(20, rect.position.y/float(framebuffer.size.y))
	constants.encode_float(24, (rect.position.x + rect.size.x)/float(framebuffer.size.x))
	constants.encode_float(28, (rect.position.y + rect.size.y)/float(framebuffer.size.y))
	constants.encode_float(32, color.r)
	constants.encode_float(36, color.g)
	constants.encode_float(40, color.b)
	constants.encode_float(44, color.a)

	var sampler_state := RDSamplerState.new()
	var sampler = render_device.sampler_create(sampler_state)
	rids.push_back(sampler)

	var src_tex_uniform = RDUniform.new()
	src_tex_uniform.binding = 0
	src_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	src_tex_uniform.add_id(sampler)
	src_tex_uniform.add_id(src_texture)
	
	var dst_tex_uniform = RDUniform.new()
	dst_tex_uniform.binding = 1
	dst_tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	dst_tex_uniform.add_id(sampler)
	dst_tex_uniform.add_id(dst_texture)

	var uniform_set := render_device.uniform_set_create([src_tex_uniform, dst_tex_uniform], _blend_pipelines[blend_mode].shader, 0)
	rids.push_back(uniform_set)

	var clear_colors = PackedColorArray([Color(1, 1, 1, 1)])
	var draw_list = render_device.draw_list_begin(framebuffer.framebuffer, RenderingDevice.INITIAL_ACTION_DISCARD, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_DISCARD, clear_colors)
	render_device.draw_list_bind_render_pipeline(draw_list, _blend_pipelines[blend_mode].get_for_framebuffer(framebuffer.framebuffer))
	render_device.draw_list_bind_index_array(draw_list, _rect_index_array)
	render_device.draw_list_set_push_constant(draw_list, constants, constants.size())
	render_device.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	render_device.draw_list_draw(draw_list, true, 1)
	render_device.draw_list_end()

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

static func blend(src : Image, dst : Image, offset : Vector2i, color : Color) -> Image:
	var rids : Array[RID] = []

	var output_texture := create_texture_from_image(dst, RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	rids.push_back(output_texture)

	var framebuffer := render_device.framebuffer_create([output_texture])
	rids.push_back(framebuffer)

	var src_texture := create_texture_from_image(src)
	rids.push_back(src_texture)

	var dst_texture := create_texture_from_image(dst)
	rids.push_back(dst_texture)

	var framebuffer_dict := {"framebuffer": framebuffer, "texture": output_texture, "size" : dst.get_size()}

	blend_async(framebuffer_dict, src_texture, offset, output_texture, Vector2i.ZERO, color)

	render_device.submit()
	render_device.sync()

	var byte_data : PackedByteArray = render_device.texture_get_data(output_texture, 0)
	var new_image := Image.create_from_data(dst.get_width(), dst.get_height(), false, Image.FORMAT_RGBA8, byte_data)

	rids.reverse()
	for rid in rids:
		render_device.free_rid(rid)

	return new_image

static func crop_or_extend(image : Image, rect : Rect2i, src_offset : Vector2i = Vector2i.ZERO) -> Image:
	var result := Image.create(rect.size.x, rect.size.y, false, image.get_format())
	result.blit_rect(image, Rect2i(0, 0, image.get_width(), image.get_height()), src_offset-rect.position)
	return result
