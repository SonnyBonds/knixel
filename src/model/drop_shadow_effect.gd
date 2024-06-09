class_name DropShadowEffect extends Effect

@export_range(-180, 180) var angle : int = 135
@export_range(0, 100) var distance : int = 10
@export_range(0, 100) var radius : int = 5
@export var color : Color = Color.BLACK

func render(framebuffer_pool : ImageProcessor.FramebufferPool, input_texture : RID) -> Layer.RenderOutput:
	var a := -angle * PI / 180.0
	var drop_offset := Vector2i(int(round(cos(a) * distance)), int(round(sin(a) * distance)))

	var input_size = ImageProcessor.get_texture_size(input_texture)
	var input_rect := Rect2i(0, 0, input_size.x, input_size.y)
	var shadow_rect := input_rect.grow(radius)
	shadow_rect.position -= drop_offset

	var rect := input_rect.merge(shadow_rect)

	var framebuffer_a := framebuffer_pool.get_framebuffer(rect.size)
	var framebuffer_b := framebuffer_pool.get_framebuffer(rect.size)
	ImageProcessor.blur_async(framebuffer_a.framebuffer, input_texture, radius, Vector2(1, 0), -drop_offset-rect.position)
	ImageProcessor.blur_async(framebuffer_b.framebuffer, framebuffer_a.texture, radius, Vector2(0, 1), Vector2i(0, 0))
	ImageProcessor.colorize_async(framebuffer_b.framebuffer, color)
	ImageProcessor.blend_async(framebuffer_a, input_texture, -rect.position, framebuffer_b.texture, Vector2i.ZERO, Color.WHITE)

	framebuffer_pool.release_framebuffer(framebuffer_b.framebuffer)

	var result := Layer.RenderOutput.new()
	result.texture = framebuffer_a.texture
	result.offset = Vector2i(rect.position.x, rect.position.y)
	return result
