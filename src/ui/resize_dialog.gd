class_name ResizeDialog extends Window

signal submitted(ResizeDialog)

var old_width : int = 100
var old_height : int = 100
var new_width : int = 100
var new_height : int = 100
var _linked := true

@onready var _from_width_label := %FromWidthLabel as Label
@onready var _from_height_label := %FromHeightLabel as Label
@onready var _width_edit := %WidthEdit as LineEdit
@onready var _height_edit := %HeightEdit as LineEdit 
@onready var _link_button := %LinkButton as Button

func _ready() -> void:
	_from_width_label.text = str(old_width)
	_from_height_label.text = str(old_height)
	_width_edit.text = str(new_width)
	_height_edit.text = str(new_height)

	close_requested.connect(_close_requested)
	_width_edit.call_deferred("grab_focus")
	_width_edit.text_changed.connect(_on_width_text_changed)
	_width_edit.text_submitted.connect(_on_submit)
	_height_edit.text_changed.connect(_on_height_text_changed)
	_height_edit.text_submitted.connect(_on_submit)
	%CancelButton.pressed.connect(_close_requested)
	%OkButton.pressed.connect(_on_ok)
	_link_button.pressed.connect(_on_linked_clicked)

func _close_requested() -> void:
	queue_free()

func _on_width_text_changed(new_text : String) -> void:
	new_width = max(1, int(new_text))
	if _linked:
		@warning_ignore("integer_division")
		new_height = max(1, new_width * old_height / old_width)
		_height_edit.text = str(new_height)

func _on_height_text_changed(new_text : String) -> void:
	new_height = max(1, int(new_text))
	if _linked:
		@warning_ignore("integer_division")
		new_width = max(1, new_height * old_width / old_height)
		_width_edit.text = str(new_width)

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
	else:
		_link_button.icon = preload("res://icons/size_unlinked.svg")
