class_name Effect extends KnixelResource

@export_storage var name : String
@export_storage var visible : bool = true
@export_storage var mix : float = 1

func render(_framebuffer_pool : ImageProcessor.FramebufferPool, _input_texture : RID, _input_offset : Vector2i, _document : Document) -> Layer.RenderOutput:
	assert(false)
	return Layer.RenderOutput.new()
