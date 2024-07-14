class_name LayerItem extends Control

var document : Document
var layer : Layer
var indent : int

@onready var _effect_list := %EffectList as EffectList
@onready var _name_label := %NameLabel as EditableLabel
#var _displayed_image : Image

func _ready():
	%VisibilityButton.pressed.connect(_on_visible_clicked)
	_name_label.commit.connect(_on_name_comitted)

	_refresh_indent()

func _enter_tree():
	if is_node_ready():
		_refresh_indent()

func _refresh_indent():
	_process(0)
	%Indent.custom_minimum_size.x = indent * 8

func _gui_input(event):
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		document.selected_layer_id = layer.id
		document.selected_effect_id = 0
				
func _process(_delta):
	var selected = document.selected_layer_id == layer.id
	if selected:
		theme_type_variation = "LayerPanelSelected"
		%HeaderPanel.theme_type_variation = "LayerHeaderPanelSelected"
	else:
		theme_type_variation = "LayerPanel"
		%HeaderPanel.theme_type_variation = "LayerHeaderPanel"
	_name_label.text = layer.name
	%VisibilityButton.button_pressed = layer.visible

	#if _displayed_image != layer.output:
	#	_displayed_image = layer.output
	#	if _displayed_image:
	#		%Icon.texture = ImageTexture.create_from_image(_displayed_image)
	#	else:
	#		%Icon.texture = null

	if _effect_list:
		_effect_list.document = document
		_effect_list.layer = layer

func _on_visible_clicked():
	layer.visible = !layer.visible

func _on_name_comitted():
	layer.name = _name_label.text
