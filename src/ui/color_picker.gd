extends Panel

class_name KnixelColorPicker

signal commit

var color : Color = Color.WHITE

var _last_saturation : float = 1
var _last_hue : float = 0
var _displayed_h : float
var _displayed_s : float
var _displayed_v : float

@onready var _red_edit := %RedEdit as SpinText
@onready var _green_edit := %GreenEdit as SpinText
@onready var _blue_edit := %BlueEdit as SpinText
@onready var _hue_edit := %HueEdit as SpinText
@onready var _saturation_edit := %SaturationEdit as SpinText
@onready var _value_edit := %ValueEdit as SpinText
@onready var _hex_edit := %HexEdit as LineEdit
@onready var _color_circle := %ColorCircle as Control
@onready var _hue_line := %HueLine as Control

# Called when the node enters the scene tree for the first time.
func _ready():
	var hue_image := Image.create(16, 256, false, Image.FORMAT_RGB8)

	# TODO: Generate on GPU
	for h in 256:
		for x in hue_image.get_width():
			hue_image.set_pixel(x, h, Color.from_hsv(h/256.0, 1, 1))

	%HueBox.texture = ImageTexture.create_from_image(hue_image)

	%ColorBox.gui_input.connect(_color_gui_input)
	%HueBox.gui_input.connect(_hue_gui_input)

	%OkButton.pressed.connect(_on_ok_pressed)

	_red_edit.edit_ended.connect(_commit_rgb)
	_green_edit.edit_ended.connect(_commit_rgb)
	_blue_edit.edit_ended.connect(_commit_rgb)
	_hue_edit.edit_ended.connect(_commit_hsv)
	_saturation_edit.edit_ended.connect(_commit_hsv)
	_value_edit.edit_ended.connect(_commit_hsv)
	
	_hex_edit.text_submitted.connect(_on_hex_submitted)
	_hex_edit.gui_input.connect(_on_hex_input)
	
	_update_color_box()

func _commit_rgb():
	color.r = _red_edit.value / 255.0
	color.g = _green_edit.value / 255.0
	color.b = _blue_edit.value / 255.0

func _commit_hsv():
	_last_hue = _hue_edit.value / 255.0
	_last_saturation = _saturation_edit.value / 255.0
	color = Color.from_hsv(_last_hue, _last_saturation, _value_edit.value / 255.0)

func _process(_delta):
	if _red_edit.is_editing() or _green_edit.is_editing() or _blue_edit.is_editing():
		_commit_rgb()
	else:
		_red_edit.value = floor(min(255, color.r * 256))
		_green_edit.value = floor(min(255, color.g * 256))
		_blue_edit.value = floor(min(255, color.b * 256))

	if color.v > 0:
		_last_saturation = color.s
	if color.s > 0:
		_last_hue = color.h

	if _hue_edit.is_editing() or _saturation_edit.is_editing() or _value_edit.is_editing():
		_commit_hsv()
	else:
		_hue_edit.value = floor(min(255, _last_hue * 256))
		_saturation_edit.value = floor(min(255, _last_saturation * 256))
		_value_edit.value = floor(min(255, color.v * 256))

	_color_circle.position.x = min(_last_saturation*256, 255) - _color_circle.size.x*0.5
	_color_circle.position.y = 255-min(color.v*256, 255) - _color_circle.size.y*0.5
	_color_circle.self_modulate = color

	_hue_line.position.y = floor(min(_last_hue*256, 255))

	if not _hex_edit.has_focus():
		_hex_edit.text = color.to_html(false)

	_update_color_box()
	
func _update_color_box():
	var color_image := Image.create(256, 256, false, Image.FORMAT_RGB8)

	if _displayed_h == _last_hue and _displayed_s == _last_saturation and _displayed_v == color.v:
		return
		
	_displayed_h = _last_hue
	_displayed_s = _last_saturation
	_displayed_v = color.v
	var h := _last_hue

	# TODO: Generate on GPU
	for s in 256:
		for v in 256:
			color_image.set_pixel(s, v, Color.from_hsv(h, s/256.0, (255-v)/256.0))

	if %ColorBox.texture is ImageTexture:
		%ColorBox.texture.update(color_image)
	else:
		%ColorBox.texture = ImageTexture.create_from_image(color_image)	

func _color_gui_input(event : InputEvent) -> void:
	var mouse_event := event as InputEventMouse
	if mouse_event and mouse_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var s := float(clamp(mouse_event.position.x/255.0, 0, 1))
		var v := float(clamp(1 - (mouse_event.position.y/255.0), 0, 1))
		_last_saturation = s
		color = Color.from_hsv(_last_hue, s, v)

func _hue_gui_input(event : InputEvent) -> void:
	var mouse_event := event as InputEventMouse
	if mouse_event and mouse_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var h := float(clamp(mouse_event.position.y/255.0, 0, 255.0/256.0)) # Clamp below 1 to avoid wrap
		_last_hue = h
		color = Color.from_hsv(h, _last_saturation, color.v)

func _on_hex_submitted(_hex_text : String) -> void:
	_commit_hex()
	
func _commit_hex():
	color = Color.from_string(_hex_edit.text, color)
	_hex_edit.text = color.to_html(false)
	_hex_edit.select_all()

func _on_hex_input(event : InputEvent) -> void:
	if has_focus:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			_commit_hex()

func _on_ok_pressed():
	commit.emit()
