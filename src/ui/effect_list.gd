extends Control

class_name EffectList

@onready var effect_container := %EffectContainer as Control
@onready var drop_hint := %DropHint as Control
var _hint_drop_effect : Effect
var document : Document
var layer : Layer

func _ready():
	mouse_exited.connect(_on_mouse_exited)

func _process(_delta):
	var dirty = false
	
	var num_effects = 0
	if layer:
		num_effects = len(layer.effects)

	if num_effects != effect_container.get_child_count():
		dirty = true
	else:
		var index = 0
		for item in effect_container.get_children():
			if item.effect != layer.effects[index]:
				dirty = true
				break
			index += 1

	custom_minimum_size = effect_container.size
	if dirty:
		update()
		
func update():
	var existing_items := effect_container.get_children()
	for child in existing_items:
		effect_container.remove_child(child)

	if layer:
		for effect in layer.effects:
			var found_existing := false
			for item_index in len(existing_items):
				var existing_item := existing_items[item_index]
				if existing_item.layer.id == layer.id and existing_item.effect.id == effect.id:
					# Relink to new actual instance
					existing_item.layer = layer
					existing_item.effect = effect

					effect_container.add_child(existing_item)
					existing_items.remove_at(item_index)
					found_existing = true
					break

			if found_existing:
				continue

			var item = preload("res://src/ui/effect_item.tscn").instantiate()
			item.document = document
			item.layer = layer
			item.effect = effect
			effect_container.add_child(item)
			item.set_drag_forwarding(\
				func(from_position): return _effect_get_drag_data(effect, from_position),\
				func(at_position, data): return _effect_can_drop_data(effect, at_position, data),\
				func(at_position, data): _effect_drop_data(effect, at_position, data))

	for item in existing_items:
		item.queue_free()

func _calc_effect_drop_location(at_effect : Effect, above : bool):
	if not layer:
		return {}

	var last_effect : Effect = null
	var index : int = 0
	for effect in layer.effects:
		if (above and effect == at_effect) or (not above and last_effect == at_effect):
			return {"after": last_effect, "before": effect, "index": index}
		last_effect = effect
		index += 1
	
	return {"after": layer.effects.back(), "before": null, "index": len(layer.effects)}
	
func _effect_get_drag_data(target_effect : Effect, _from_position : Vector2) -> Variant:
	var preview := PanelContainer.new()
	var label := Label.new()
	label.text = target_effect.name
	preview.add_child(label)
	set_drag_preview(preview)
	_hint_drop_effect = target_effect
	return target_effect

func _find_effect_control(effect : Effect) -> Control:
	for child in effect_container.get_children():
		if child.effect == effect:
			return child

	return null

func _effect_can_drop_data(target_effect : Effect, at_position : Vector2, data : Variant) -> bool:
	var can_drop := false

	# Need extra "is effect" test because it might not even be an object (e.g. Dictionary)
	var dragged_effect := data as Effect if data is Effect else null
	if dragged_effect:
		var control := _find_effect_control(target_effect)
		if control:
			var above := at_position.y < control.size.y/2
			var drop_location = _calc_effect_drop_location(target_effect, above)
			if drop_location.after != dragged_effect and drop_location.before != dragged_effect:
				var offset := 0.0 if above else control.size.y
				drop_hint.position.y = control.global_position.y - global_position.y + offset
				drop_hint.visible = true
				can_drop = true
		
		if not can_drop:
			drop_hint.position.y = 0
			drop_hint.visible = false

		return true
	else:
		return false

func _effect_drop_data(target_effect : Effect, at_position : Vector2, data : Variant) -> void:
	drop_hint.visible = false

	# Need extra "is effect" test because it might not even be an object (e.g. Dictionary)
	var dragged_effect := data as Effect if data is Effect else null
	if not dragged_effect:
		return

	if not layer:
		return

	var control := _find_effect_control(target_effect)
	if not control:
		return

	var above := at_position.y < control.size.y/2
	var drop_location = _calc_effect_drop_location(target_effect, above)
	if drop_location.after == dragged_effect or drop_location.before == dragged_effect:
		return

	var current_index = layer.effects.find(dragged_effect)
	if current_index == -1:
		return

	var new_index = drop_location.index
	if new_index > current_index:
		new_index -= 1
	layer.effects.remove_at(current_index)
	layer.effects.insert(new_index, dragged_effect)

func _can_drop_data(_at_position : Vector2, data : Variant) -> bool:
	# Need extra "is effect" test because it might not even be an object (e.g. Dictionary)
	var dragged_effect := data as Effect if data is Effect else null
	if not dragged_effect:
		return false

	var control := effect_container.get_children().back() as Control
	if control.effect != dragged_effect:
		drop_hint.position.y = control.global_position.y - global_position.y + control.size.y
		drop_hint.visible = true
	else:
		drop_hint.position.y = 0
		drop_hint.visible = false

	return true

func _drop_data(_at_position : Vector2, data:Variant) -> void:
	drop_hint.visible = false

	var effect := data as Effect if data is Effect else null
	if not effect:
		return

	if not layer:
		return
	layer.effects.erase(effect)
	layer.effects.push_back(effect)

func _on_mouse_exited():
	drop_hint.visible = false
