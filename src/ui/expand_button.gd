class_name ExpandButton extends Button

func _ready():
	toggled.connect(_on_toggled)

func _on_toggled(toggled_on : bool):
	if toggled_on:
		icon = preload("res://icons/expand_open.svg")
	else:
		icon = preload("res://icons/expand_closed.svg")
