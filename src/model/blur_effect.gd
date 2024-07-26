class_name BlurEffect extends Effect

@export_range(0, 100) var radius : int = 50

func render(framebuffer_pool : ImageProcessor.FramebufferPool, input_texture : RID, input_offset : Vector2i, document : Document) -> Layer.RenderOutput:
	var input_size := ImageProcessor.get_texture_size(input_texture)
	var output_size := input_size + Vector2i(radius, radius)*2
	var output_offset := input_offset - Vector2i(radius, radius)

	var wrap_rect : Rect2i
	if document.tiling == Document.Tiling.HORIZONTAL or document.tiling == Document.Tiling.BOTH:
		output_offset.x = 0
		output_size.x = document.size.x
		wrap_rect.size.x = output_size.x
	if document.tiling == Document.Tiling.VERTICAL or document.tiling == Document.Tiling.BOTH:
		output_offset.y = 0
		output_size.y = document.size.y
		wrap_rect.size.y = output_size.y

	var extra_framebuffer := framebuffer_pool.get_framebuffer(output_size)
	var output_framebuffer := framebuffer_pool.get_framebuffer(output_size)
	ImageProcessor.blur_async(extra_framebuffer.framebuffer, input_texture, radius, Vector2(1, 0), input_offset - output_offset, wrap_rect)
	ImageProcessor.blur_async(output_framebuffer.framebuffer, extra_framebuffer.texture, radius, Vector2(0, 1), Vector2i(0, 0), wrap_rect)
	framebuffer_pool.release_framebuffer(extra_framebuffer.framebuffer)

	var result := Layer.RenderOutput.new()
	result.texture = output_framebuffer.texture
	result.offset = output_offset
	return result
