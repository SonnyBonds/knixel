class_name ImageLayer extends Layer

@export var image : Image
var _texture_image : Image
var _texture_rid : RID

func extract_masked_image(mask : Image, mask_offset : Vector2i = Vector2i.ZERO) -> Image:
    var new_image := ImageProcessor.apply_mask(image, mask, mask_offset-offset)
    var rect : Rect2i = new_image.get_used_rect()
    if rect.position != Vector2i(0, 0) or rect.size != new_image.get_size():
        new_image.blit_rect(new_image, rect, Vector2i(0, 0))
        new_image.crop(rect.size.x, rect.size.y)

    return new_image

func get_texture() -> RID:
    if image == _texture_image and _texture_rid:
        return _texture_rid
    
    if _texture_rid:
        ImageProcessor.render_device.free_rid(_texture_rid)

    _texture_rid = ImageProcessor.create_texture_from_image(image)
    _texture_image = image

    return _texture_rid

func render(_framebuffer_pool : ImageProcessor.FramebufferPool) -> Layer.RenderOutput:
    var result := RenderOutput.new()
    result.texture = get_texture()
    result.offset = offset
    return result
