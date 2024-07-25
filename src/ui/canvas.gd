extends Control

class_name Canvas

var selecting : bool = false
var document : Document
var tool : Tool

@onready var image_control := %Image as Control
@onready var selection_control := %Selection as Control
@onready var _overlay := %Overlay as Control
@onready var _image_outline := %ImageOutline as Control
@onready var _background := %Background as Control
@onready var _tiled_image_control := %TiledImage as Control
@onready var _tiled_background := %TiledBackground as Control

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
	# Show 1:1 pixels by default
	var ui_scale = get_viewport().content_scale_factor
	%Image.scale = Vector2(1 / ui_scale, 1 / ui_scale)
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

	var view_bounds_min := Vector2(20, 20) - image_control.size * image_control.scale
	var view_bounds_max := size - Vector2(20, 20)
	image_control.position = image_control.position.clamp(view_bounds_min, view_bounds_max)

	if _displayed_image != document.output_image:
		_displayed_image = document.output_image
		image_control.texture = ImageTexture.create_from_image(_displayed_image)
		image_control.size = _displayed_image.get_size()
		_tiled_image_control.texture = image_control.texture

	var tile_image_pos := image_control.position
	var scaled_size := image_control.size * image_control.scale
	tile_image_pos.x = fmod(round(image_control.position.x), scaled_size.x)
	if tile_image_pos.x > 0:
		tile_image_pos.x -= scaled_size.x
	tile_image_pos.y = fmod(round(image_control.position.y), scaled_size.y)
	if tile_image_pos.y > 0:
		tile_image_pos.y -= scaled_size.y

	_tiled_image_control.position = tile_image_pos
	_tiled_image_control.scale = image_control.scale
	_tiled_image_control.size = (size - _tiled_image_control.position) / image_control.scale
	_tiled_image_control.visible = document.view_tiled
	_tiled_background.visible = document.view_tiled

	var ui_scale = get_viewport().content_scale_factor
	if image_control.scale.x > 1/ui_scale:
		image_control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		image_control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_tiled_background.position = _tiled_image_control.position
	_tiled_background.size = _tiled_image_control.size * _tiled_image_control.scale
	_background.position = image_control.position
	_background.size = image_control.size * image_control.scale
	_overlay.size = image_control.size

	_image_outline.position = image_control.position
	_image_outline.size = image_control.size * image_control.scale
	_image_outline.visible = document.view_tiled

	if document.selection != _displayed_selection:
		_displayed_selection = document.selection
		if _displayed_selection:
			selection_control.texture = ImageTexture.create_from_image(_displayed_selection)
		else:
			selection_control.texture = null
	selection_control.position = document.selection_offset
