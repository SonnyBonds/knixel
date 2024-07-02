class_name ResizeDialog extends Window

signal submitted(ResizeDialog)

var old_width : int = 100
var old_height : int = 100
var new_width : int = 100
var new_height : int = 100
var new_width_percent : float = 100
var new_height_percent : float = 100
var _linked := true

@onready var _width_edit := %WidthEdit as LineEdit
@onready var _width_percent_edit := %WidthEditPercent as LineEdit
@onready var _height_edit := %HeightEdit as LineEdit 
@onready var _height_percent_edit := %HeightEditPercent as LineEdit 
@onready var _link_button := %LinkButton as Button
@onready var _unit_drop_down := %UnitDropDown as DropDown

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
