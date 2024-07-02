class_name ResizeCanvasDialog extends Window

signal submitted(ResizeCanvasDialog)

var old_width : int = 100
var old_height : int = 100
var new_width : int = 100
var new_height : int = 100
var new_width_percent : float = 100
var new_height_percent : float = 100
var horizontal_alignment := HORIZONTAL_ALIGNMENT_LEFT
var vertical_alignment := VERTICAL_ALIGNMENT_TOP
var _linked := true

@onready var _width_edit := %WidthEdit as LineEdit
@onready var _width_percent_edit := %WidthEditPercent as LineEdit
@onready var _height_edit := %HeightEdit as LineEdit 
@onready var _height_percent_edit := %HeightEditPercent as LineEdit 
@onready var _link_button := %LinkButton as Button

@onready var _align_button_tl := %AlignTL as Button
@onready var _align_button_t := %AlignT as Button
@onready var _align_button_tr := %AlignTR as Button
@onready var _align_button_l := %AlignL as Button
@onready var _align_button_c := %AlignC as Button
@onready var _align_button_r := %AlignR as Button
@onready var _align_button_bl := %AlignBL as Button
@onready var _align_button_b := %AlignB as Button
@onready var _align_button_br := %AlignBR as Button

func _ready() -> void:
	_width_edit.text = str(new_width)
	_height_edit.text = str(new_height)

	close_requested.connect(_close_requested)

	_width_edit.call_deferred("grab_focus")
	_width_edit.text_changed.connect(_on_width_text_changed)
	_width_percent_edit.text_changed.connect(_on_width_percent_text_changed)
	_width_edit.text_submitted.connect(_on_submit)
	_width_percent_edit.text_submitted.connect(_on_submit)

	_height_edit.text_changed.connect(_on_height_text_changed)
	_height_percent_edit.text_changed.connect(_on_height_percent_text_changed)
	_height_edit.text_submitted.connect(_on_submit)
	_height_percent_edit.text_submitted.connect(_on_submit)

	_align_button_tl.pressed.connect(_on_alignment_clicked)
	_align_button_t.pressed.connect(_on_alignment_clicked)
	_align_button_tr.pressed.connect(_on_alignment_clicked)
	_align_button_l.pressed.connect(_on_alignment_clicked)
	_align_button_c.pressed.connect(_on_alignment_clicked)
	_align_button_r.pressed.connect(_on_alignment_clicked)
	_align_button_bl.pressed.connect(_on_alignment_clicked)
	_align_button_b.pressed.connect(_on_alignment_clicked)
	_align_button_br.pressed.connect(_on_alignment_clicked)

	%CancelButton.pressed.connect(_close_requested)
	%OkButton.pressed.connect(_on_ok)
	_link_button.pressed.connect(_on_linked_clicked)

func _close_requested() -> void:
	queue_free()

func _on_width_text_changed(new_text : String) -> void:
	new_width = max(1, int(new_text))
	new_width_percent = 100 * new_width / float(old_width)
	_width_percent_edit.text = str(new_width_percent)
	if _linked:
		_update_linked_height()

func _on_width_percent_text_changed(new_text : String) -> void:
	new_width_percent = float(new_text)
	new_width = max(1, int(round(old_width*new_width_percent * 0.01)))
	_width_edit.text = str(new_width)
	if _linked:
		_update_linked_height()

func _on_height_text_changed(new_text : String) -> void:
	new_height = max(1, int(new_text))
	new_height_percent = 100 * new_height / float(old_height)
	_height_percent_edit.text = str(new_height_percent)
	if _linked:
		_update_linked_width()

func _on_height_percent_text_changed(new_text : String) -> void:
	new_height_percent = float(new_text)
	new_height = max(1, int(round(old_height*new_height_percent * 0.01)))
	_height_edit.text = str(new_height)
	if _linked:
		_update_linked_width()

func _update_linked_width():
	new_width_percent = new_height_percent
	new_width = max(1, int(round(old_width * new_width_percent * 0.01)))
	_width_edit.text = str(new_width)
	_width_percent_edit.text = str(new_width_percent)

func _update_linked_height():
	new_height_percent = new_width_percent
	new_height = max(1, int(round(old_height * new_height_percent * 0.01)))
	_height_edit.text = str(new_height)
	_height_percent_edit.text = str(new_height_percent)

func _on_submit(_text : String) -> void:
	submitted.emit(self)
	queue_free()

func _on_ok() -> void:
	submitted.emit(self)
	queue_free()

func _on_linked_clicked():
	_linked = !_linked
	if _linked:
		_link_button.icon = preload("res://icons/size_linked.svg")
		_update_linked_height()
	else:
		_link_button.icon = preload("res://icons/size_unlinked.svg")

func _on_alignment_clicked() -> void:
	# Not fantastic but it works
	if _align_button_tl.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
	elif _align_button_t.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
	elif _align_button_tr.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
	elif _align_button_l.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif _align_button_c.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif _align_button_r.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif _align_button_bl.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	elif _align_button_b.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	elif _align_button_br.button_pressed:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

