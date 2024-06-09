extends Window

var message : String:
	get:
		return %MessageLabel.text
	set(value):
		%MessageLabel.text = value

func _ready():
	close_requested.connect(_close_requested)
	%OkButton.pressed.connect(_on_ok)
	%OkButton.grab_focus()

func _close_requested() -> void:
	queue_free()

func _on_ok() -> void:
	queue_free()
