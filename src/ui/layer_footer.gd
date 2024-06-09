extends HBoxContainer

@onready var main := get_tree().current_scene as Main
@onready var _new_layer_button := %NewLayerButton as Button
@onready var _new_effect_layer_button := %NewEffectLayerButton as Button
@onready var _delete_layer_button := %DeleteLayerButton as Button
@onready var _effect_popup := %EffectPopupMenu as PopupMenu

func _ready():
	_new_layer_button.pressed.connect(_on_new_layer_pressed)
	_new_effect_layer_button.pressed.connect(_on_new_effect_pressed)
	_delete_layer_button.pressed.connect(_on_delete_layer_pressed)

	_effect_popup.add_item("Blur", 0)
	_effect_popup.add_item("Drop Shadow", 1)
	_effect_popup.id_pressed.connect(_on_effect_menu_pressed)

func _process(_delta : float) -> void:
	_new_layer_button.disabled = main.active_canvas == null
	_new_effect_layer_button.disabled = main.active_canvas == null
	_delete_layer_button.disabled = main.active_canvas == null or main.active_canvas.document.get_selected_layer() == null

func _on_new_layer_pressed() -> void:
	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	var layer := ImageLayer.new()
	layer.image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	layer.name = document.get_new_layer_name()
	document.layers.push_back(layer)
	document.selected_layer_id = layer.id
	document.selected_effect_id = 0
	document.selection = null

func _on_new_effect_pressed() -> void:
	if not main.active_canvas:
		return

	var layer := main.active_canvas.document.get_selected_layer()
	if not layer:
		return

	var content_scale : float = get_viewport().content_scale_factor 
	_effect_popup.popup_on_parent(Rect2i(Vector2i(_new_effect_layer_button.global_position * content_scale), _effect_popup.size))

func _on_delete_layer_pressed():
	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	var selected_layer = document.get_selected_layer()
	if selected_layer:
		if document.selected_effect_id == 0:
			var last_layer : Layer = null
			for layer in document.layers:
				if layer.id == document.selected_layer_id:
					break
				last_layer = layer
			document.layers.erase(selected_layer)
			if last_layer:
				document.selected_layer_id = last_layer.id
				document.selected_effect_id = 0
			else:
				_on_new_layer_pressed()
		else:
			var selected_effect_index : int = -1
			for effect_index in len(selected_layer.effects):
				if selected_layer.effects[effect_index].id == document.selected_effect_id:
					selected_effect_index = effect_index
					break
			if selected_effect_index != -1:
				selected_layer.effects.remove_at(selected_effect_index)
				var prev_index = max(0, selected_effect_index-1)
				if prev_index < len(selected_layer.effects):
					document.selected_effect_id = selected_layer.effects[prev_index].id
				else:
					document.selected_effect_id = 0

func _on_effect_menu_pressed(id : int) -> void:
	if not main.active_canvas:
		return

	var layer := main.active_canvas.document.get_selected_layer()
	if not layer:
		return

	# TODO: Don't hardcode
	if id == 0:
		var effect := BlurEffect.new()
		effect.name = "Blur"
		layer.effects.push_back(effect)
		main.active_canvas.document.selected_effect_id = effect.id
	elif id == 1:
		var effect := DropShadowEffect.new()
		effect.name = "Drop Shadow"
		layer.effects.push_back(effect)
		main.active_canvas.document.selected_effect_id = effect.id
