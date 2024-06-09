class_name Tool extends RefCounted

var canvas : Canvas

func activate(new_canvas : Canvas):
    canvas = new_canvas

func deactivate():
    canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
    canvas = null

func get_options() -> Control:
    return null

func process():
    pass