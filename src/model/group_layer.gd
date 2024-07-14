class_name GroupLayer extends Layer

@export var expanded : bool = true

func _init():
    super()
    blend_mode = ImageProcessor.BlendMode.PassThrough

func rescale(_scale : Vector2) -> void:
    pass

func render(_framebuffer_pool : ImageProcessor.FramebufferPool) -> Layer.RenderOutput:
    return Layer.RenderOutput.new()
