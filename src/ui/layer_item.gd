extends Control

var document : Document
var layer : Layer

@onready var _effect_list := %EffectList as EffectList
var _displayed_image : Image

func _ready():
	%VisibilityButton.pressed.connect(_on_visible_clicked)

func _enter_tree():
	_process(0)

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
	%NameLabel.text = layer.name
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
