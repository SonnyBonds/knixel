extends Control

class_name SpinText

signal edit_started
signal edit_ended

@onready var edit := $LineEdit as LineEdit
@onready var button := $Button as Control

@export var min_value : float = 0
@export var max_value : float = 100
@export var step : float = 1
@export var integer : bool = false
@export var display_rounded : bool = false
@export var value : float
@export var speed : float = 1.0
@export var unit : String
var _dragging := false
var _dragged_value : float = 0
var _pending_direction := Direction.NONE
var _last_drag_pos : Vector2

enum Direction { NONE, UP, DOWN }

func _ready():
	edit.focus_entered.connect(_on_focus_entered)
	edit.focus_exited.connect(_on_focus_exited)
	edit.text_submitted.connect(_on_text_submitted)
	button.gui_input.connect(_on_button_gui_input)

func _on_focus_entered():
	edit_started.emit()

func _on_focus_exited():
	edit_ended.emit()

func _commit_text():
	value = _fix_value(float(edit.text))

func _on_text_submitted(_new_text : String):
	_commit_text()
	edit_ended.emit()
	_update_text()
	edit.select_all()
	edit_started.emit()
	
func _input(event):
	if has_focus:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			_commit_text()
		
func _on_button_gui_input(event : InputEvent) -> void:
	var button_event := event as InputEventMouseButton
	if button_event and button_event.button_index == MOUSE_BUTTON_LEFT:
		if button_event.pressed:
			_last_drag_pos = button_event.global_position
			_dragged_value = value
			_dragging = true
			if button_event.position.y < button.size.y/2:
				_pending_direction = Direction.UP
			else:
				_pending_direction = Direction.DOWN
			edit_started.emit()
		elif not button_event.pressed:
			if _pending_direction == Direction.UP:
				value = _fix_value(value + step)
			elif _pending_direction == Direction.DOWN:
				value = _fix_value(value - step)

			if _dragging:
				edit_ended.emit()
				_dragging = false

	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_pending_direction = Direction.NONE

		# There's a bug in motion.relative in Popups so we'll have to roll our own for now.
		var delta := motion.global_position - _last_drag_pos
		_dragged_value -= delta.y * speed
		_last_drag_pos = motion.global_position
		value = _fix_value(_dragged_value)

func _fix_value(new_value : float) -> float:
	new_value = clamp(new_value, min_value, max_value)
	if integer:
		new_value = round(new_value)
	return new_value

func _process(_delta):
	if not edit.has_focus():
		_update_text()

func _update_text():
	if display_rounded:
		edit.text = str(round(value)) + unit
	else:
		edit.text = str(value) + unit

func is_editing():
	return edit.has_focus() or _dragging
