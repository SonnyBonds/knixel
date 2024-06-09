extends Window

class_name NewDialog

signal submitted(NewDialog)

var document_name := "Untitled"
var width : int = 100
var height : int = 100

func _ready() -> void:
	%NameEdit.text = document_name
	%WidthEdit.text = str(width)
	%HeightEdit.text = str(height)

	close_requested.connect(_close_requested)
	%WidthEdit.call_deferred("grab_focus")
	%NameEdit.text_submitted.connect(_on_submit)
	%WidthEdit.text_submitted.connect(_on_submit)
	%HeightEdit.text_submitted.connect(_on_submit)
	%CancelButton.pressed.connect(_close_requested)
	%OkButton.pressed.connect(_on_ok)

func _close_requested() -> void:
	queue_free()

func _on_submit(_text : String) -> void:
	submitted.emit(self)
	queue_free()

func _on_ok() -> void:
	submitted.emit(self)
	queue_free()

func _process(_delta) -> void:
	name = %NameEdit.text
	width = int(%WidthEdit.text)
	height = int(%HeightEdit.text)
