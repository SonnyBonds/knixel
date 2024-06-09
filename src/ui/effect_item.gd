extends Control

var document : Document
var layer : Layer
var effect : Effect
var _prop_edits : Array

func _ready():
	%VisibilityButton.pressed.connect(_on_visible_clicked)
	for prop in effect.get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if prop.usage & PROPERTY_USAGE_EDITOR and not prop.name == "script":
			var prop_edit := preload("res://src/ui/prop_edit.tscn").instantiate()
			prop_edit.document = document
			prop_edit.object = effect
			prop_edit.property_info = prop
			_prop_edits.push_back(prop_edit)
			%PropertyList.add_child(prop_edit)
	_process(0)

func _gui_input(event):
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		document.selected_layer_id = layer.id
		document.selected_effect_id = effect.id

func _process(_delta):
	for prop_edit in _prop_edits:
		prop_edit.object = effect

	var selected = document.selected_layer_id == layer.id and document.selected_effect_id == effect.id
	if selected:
		theme_type_variation = "EffectPanelSelected"
	else:
		theme_type_variation = "EffectPanel"

	%NameLabel.text = effect.name
	%VisibilityButton.button_pressed = effect.visible

func _on_visible_clicked():
	effect.visible = !effect.visible
