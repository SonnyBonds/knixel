class_name LayerItem extends Control

var document : Document
var layer : Layer
var indent : int
var parent_visible : bool

@onready var _effect_list := %EffectList as EffectList
@onready var _visibility_button := %VisibilityButton as Button
@onready var _name_label := %NameLabel as EditableLabel
@onready var _preview := %Preview as TextureRect
@onready var _folder_icon := %FolderIcon as TextureRect
@onready var _folder_expand_button := %FolderExpandButton as ExpandButton
@onready var _effects_icon := %EffectsIcon as TextureRect
@onready var _effects_expand_button := %EffectsExpandButton as ExpandButton
#var _displayed_image : Image

func _ready():
	_visibility_button.pressed.connect(_on_visible_clicked)
	_name_label.commit.connect(_on_name_comitted)
	_folder_expand_button.pressed.connect(_on_folder_expand_clicked)
	_effects_expand_button.pressed.connect(_on_effects_expand_clicked)

	_refresh()

func _enter_tree():
	if is_node_ready():
		_refresh()

func _refresh():
	_process(0)
	%Indent.custom_minimum_size.x = indent * 8

	var is_group := layer is GroupLayer
	_folder_icon.visible = is_group
	_folder_expand_button.visible = is_group
	_preview.visible = not is_group

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
	_visibility_button.button_pressed = layer.visible
	_visibility_button.modulate.a = 1.0 if parent_visible else 0.5

	#if _displayed_image != layer.output:
	#	_displayed_image = layer.output
	#	if _displayed_image:
	#		%Preview.texture = ImageTexture.create_from_image(_displayed_image)
	#	else:
	#		%Preview.texture = null

	var has_effects := not layer.effects.is_empty()
	_effects_icon.visible = has_effects
	_effects_expand_button.visible = has_effects
	_effects_expand_button.button_pressed = layer.show_effects
	_effect_list.visible = layer.show_effects
	_effect_list.document = document
	_effect_list.layer = layer

	if layer is GroupLayer:
		_folder_expand_button.button_pressed = layer.expanded

func _on_visible_clicked():
	layer.visible = !layer.visible

func _on_name_comitted():
	layer.name = _name_label.text

func _on_folder_expand_clicked():
	layer.expanded = !layer.expanded

	if document.selected_layer_id != 0:
		var selected_layer := document.find_layer_by_id(document.selected_layer_id)
		if document.is_layer_descendent_of_other(selected_layer, layer):
			document.selected_layer_id = layer.id
			document.selected_effect_id = 0

func _on_effects_expand_clicked():
	layer.show_effects = !layer.show_effects

	if not layer.show_effects and document.selected_layer_id == layer.id:
		document.selected_effect_id = 0
