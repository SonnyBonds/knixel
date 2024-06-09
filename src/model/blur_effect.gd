class_name BlurEffect extends Effect

@export_range(0, 100) var radius : int = 50

func render(framebuffer_pool : ImageProcessor.FramebufferPool, input_texture : RID) -> Layer.RenderOutput:
	var input_size = ImageProcessor.get_texture_size(input_texture) + Vector2i(radius, radius)*2

	var extra_framebuffer := framebuffer_pool.get_framebuffer(input_size)
	var output_framebuffer := framebuffer_pool.get_framebuffer(input_size)
	ImageProcessor.blur_async(extra_framebuffer.framebuffer, input_texture, radius, Vector2(1, 0), Vector2i(radius, radius))
	ImageProcessor.blur_async(output_framebuffer.framebuffer, extra_framebuffer.texture, radius, Vector2(0, 1), Vector2i(0, 0))
	framebuffer_pool.release_framebuffer(extra_framebuffer.framebuffer)

	var result := Layer.RenderOutput.new()
	result.texture = output_framebuffer.texture
	result.offset = Vector2i(-radius, -radius)
	return result
