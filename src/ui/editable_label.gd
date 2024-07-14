class_name EditableLabel extends Label

signal commit

@onready var _line_edit := %LineEdit as LineEdit

func _ready():
	_line_edit.focus_exited.connect(_submit)
	_line_edit.text_submitted.connect(_on_edit_submitted)

func _gui_input(event):
	var button_event := event as InputEventMouseButton
	if button_event and button_event.double_click and button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
		_line_edit.text = text
		_line_edit.visible = true
		_line_edit.grab_focus()
		_line_edit.select_all()
		accept_event()
		return

func _on_edit_submitted(_text):
	_submit()

func _submit():
	if _line_edit.visible:
		text = _line_edit.text
		_line_edit.visible = false
		_line_edit.release_focus()
		commit.emit()

func _input(event: InputEvent):
	if _line_edit.visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not Rect2i(Vector2i(0,0), _line_edit.size).has_point(_line_edit.make_input_local(event).position):
				_submit()
