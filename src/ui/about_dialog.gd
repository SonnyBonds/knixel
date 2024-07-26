class_name AboutDialog extends Window

func _ready() -> void:
	close_requested.connect(_close_requested)
	%OkButton.pressed.connect(_on_ok)
	%KnixelVersionLabel.text = "v" + ProjectSettings.get_setting("application/config/version")
	%GodotVersionLabel.text = "v" + Engine.get_version_info().string

func _close_requested() -> void:
	queue_free()

func _on_ok() -> void:
	queue_free()
