extends HBoxContainer

@onready var main := get_tree().current_scene as Main
@onready var opacity_edit := %OpacityEdit as SpinText
@onready var blend_mode_drop_down := %BlendModeDropDown as DropDown

func _ready():
	opacity_edit.edit_started.connect(_on_edit_started)
	opacity_edit.edit_ended.connect(_on_edit_ended)
	
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Normal", ImageProcessor.BlendMode.Normal))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Add", ImageProcessor.BlendMode.Add))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Subtract", ImageProcessor.BlendMode.Subtract))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Multiply", ImageProcessor.BlendMode.Multiply))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Lighten", ImageProcessor.BlendMode.Lighten))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Darken", ImageProcessor.BlendMode.Darken))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Screen", ImageProcessor.BlendMode.Screen))
	blend_mode_drop_down.items.push_back(DropDown.Item.new("Difference", ImageProcessor.BlendMode.Difference))
	blend_mode_drop_down.commit.connect(_on_blend_mode_commit)

func _on_edit_started():
	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	if document:
		document.start_undo_block()

func _on_edit_ended():
	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	if document:
		var layer = document.get_selected_layer()
		if layer:
			layer.opacity = opacity_edit.value * 0.01

		document.end_undo_block()

func _process(_delta):
	if not main.active_canvas:
		return
		
	var document = main.active_canvas.document
	if not document:
		return
		
	var layer = document.get_selected_layer()
	if not layer:
		return

	if opacity_edit.is_editing():
		layer.opacity = opacity_edit.value * 0.01
	else:
		opacity_edit.value = layer.opacity * 100

	var blend_item : DropDown.Item
	for item in blend_mode_drop_down.items:
		if item.data == layer.blend_mode:
			blend_item = item
	blend_mode_drop_down.current_item = blend_item

func _on_blend_mode_commit():
	if not main.active_canvas:
		return

	var document = main.active_canvas.document
	if not document:
		return
		
	var layer = document.get_selected_layer()
	if layer:
		layer.blend_mode = blend_mode_drop_down.current_item.data
