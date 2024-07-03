extends Control

class_name Canvas

var selecting : bool = false
var document : Document
var tool : Tool

var _last_size : Vector2
var _displayed_image : Image
var _displayed_selection : Image

func pos_to_image(pos : Vector2) -> Vector2:
	return (%Image as Control).get_transform().affine_inverse() * pos

func pos_from_image(pos : Vector2) -> Vector2:
	return (%Image as Control).get_transform() * pos

func pos_to_selection(pos : Vector2) -> Vector2:
	return pos_to_image(pos) - Vector2(document.selection_offset)

func pos_from_selection(pos : Vector2) -> Vector2:
	return pos_from_image(pos + Vector2(document.selection_offset))

func _ready():
	_last_size = size
	resized.connect(_on_resized)

func reset_view():
	# TODO: Figure out DPI
	%Image.scale = Vector2(0.5, 0.5)
	%Image.position = (Vector2i(size) - document.size/2) / 2

func _on_resized():
	%Image.position += (size-_last_size) * 0.5
	_last_size = size

func _gui_input(event : InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		var image_control := %Image as Control
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor = 1.1																													
			if button.device == -1:
				factor = 1/factor
			var diff = image_control.global_position - button.global_position
			var pre_scale = image_control.scale
			if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				image_control.scale = clamp(image_control.scale / factor, Vector2.ONE*0.05, Vector2.ONE*20)
			elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
				image_control.scale = clamp(image_control.scale * factor, Vector2.ONE*0.05, Vector2.ONE*20)
			var scale_diff = image_control.scale / pre_scale
			image_control.global_position = button.global_position + diff * scale_diff
	
	var motion := event as InputEventMouseMotion
	if motion:
		var image_control := %Image as Control
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			image_control.position += motion.relative

func activate_tool(new_tool : Tool) -> void:
	if tool:
		tool.deactivate()
	
	tool = new_tool

	if tool:
		tool.activate(self)

func _process(_delta):
	if tool:
		tool.process()

	var image_control := %Image as Control

	if _displayed_image != document.output_image:
		_displayed_image = document.output_image
		image_control.texture = ImageTexture.create_from_image(_displayed_image)
		image_control.size = _displayed_image.get_size()

	$Background.position = image_control.position
	$Background.size = image_control.size * image_control.scale

	if document.selection != _displayed_selection:
		_displayed_selection = document.selection
		if _displayed_selection:
			%Selection.texture = ImageTexture.create_from_image(_displayed_selection)
		else:
			%Selection.texture = null
	%Selection.position = document.selection_offset
