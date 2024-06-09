extends PanelContainer

@onready var main := get_tree().current_scene as Main

var _current_tool : Tool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	custom_minimum_size.y = 80
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var tool : Tool = null

	if main.active_canvas:
		tool = main.active_canvas.tool

	if tool == _current_tool:
		return

	_current_tool = tool

	for child in get_children():
		child.queue_free()

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 5)
	margin_container.add_theme_constant_override("margin_right", 5)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	add_child(margin_container)

	var list_container := VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 2)
	margin_container.add_child(list_container)

	var empty := true
	if tool:
		for prop in tool.get_property_list():
			if prop.usage & PROPERTY_USAGE_EDITOR and not prop.name == "script":
				var prop_edit := preload("res://src/ui/prop_edit.tscn").instantiate()
				prop_edit.object = tool
				prop_edit.property_info = prop
				list_container.add_child(prop_edit)
				empty = false

	if empty:
		var label := Label.new()
		label.text = "No tool options."
		label.add_theme_font_size_override("font_size", 10)
		list_container.add_child(label)