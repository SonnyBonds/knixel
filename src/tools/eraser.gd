class_name EraserTool extends BrushToolBase

func activate(canvas : Canvas) -> void:
	_mode = Mode.ERASER
	super(canvas)

func deactivate() -> void:
	super()
