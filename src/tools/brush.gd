class_name BrushTool extends BrushToolBase

func activate(canvas : Canvas) -> void:
	_mode = Mode.BRUSH
	super(canvas)

func deactivate() -> void:
	super()
