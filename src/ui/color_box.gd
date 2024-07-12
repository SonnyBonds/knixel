extends Control

class_name ColorBox

signal commit

var color : Color = Color.WHITE

@onready var _popup := $Popup
@onready var _picker : KnixelColorPicker = %ColorPicker

func _ready():
	$Button.pressed.connect(_on_pressed)

	_picker.commit.connect(_on_picker_commit)

	# The viewport's scale isn't set properly until Main has been initialized
	await get_tree().process_frame

	_popup.content_scale_factor = get_viewport().content_scale_factor
	_popup.size *= _popup.content_scale_factor

	_process(0)

func _process(_delta):
	if _picker.is_visible_in_tree():
		color = _picker.color.srgb_to_linear()
	else:
		_picker.color = color.linear_to_srgb()

	$ColorRect.modulate = color.linear_to_srgb()

func _on_pressed():
	_picker.color = color
	_popup.popup_on_parent(Rect2i(Vector2i(64, 100), _popup.size))

func _on_picker_commit():
	_popup.hide()
	commit.emit()
