class_name Layer extends KnixelResource

@export var name : String
@export var offset : Vector2i
@export var opacity : float = 1
@export var visible : bool = true
@export var blend_mode := ImageProcessor.BlendMode.Normal
@export var effects : Array[Effect] = []

class RenderOutput extends RefCounted:
	var texture : RID
	var offset : Vector2i

func _init():
	super()
	#blend_mode = preload("res://src/shaders/blend_modes/normal.gdshader")

func render(_framebuffer_pool : ImageProcessor.FramebufferPool) -> RenderOutput:
	assert(false)
	return Layer.RenderOutput.new()
