extends Control

class_name Main

var active_canvas : Canvas

var _clipboard : Image

enum { FILE_NEW, FILE_OPEN, FILE_CLOSE, FILE_SAVE, FILE_SAVE_AS, FILE_EXPORT, FILE_EXPORT_AGAIN, FILE_QUIT,
	   EDIT_UNDO, EDIT_REDO, EDIT_CUT, EDIT_COPY, EDIT_COPY_MERGED, EDIT_PASTE, EDIT_SELECT_ALL, EDIT_FILL_FOREGROUND, EDIT_FILL_BACKGROUND, EDIT_CLEAR_SELECTION, EDIT_DELETE,
	   IMAGE_RESIZE_IMAGE, IMAGE_RESIZE_CANVAS }

@onready var canvas_container := %CanvasContainer as TabContainer
@onready var _swap_colors_button := %SwapColorsButton as Button
@onready var _reset_colors_button := %ResetColorsButton as Button

func _init():
	KnixelResource.initialize()
	
func _shortcut(key : Key):
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = key

		var shortcut := Shortcut.new()
		shortcut.events = [ event ]
		return shortcut

func _ready():
	get_window().gui_embed_subwindows = false
	var dpi_scale = 2 if DisplayServer.screen_get_dpi() >= 192 and DisplayServer.screen_get_size().x >= 2048 else 1
	get_viewport().content_scale_factor = dpi_scale

	%ForegroundColorBox.commit.connect(_on_foreground_commit)
	%BackgroundColorBox.commit.connect(_on_background_commit)	
	
	%FileMenu.get_popup().id_pressed.connect(_on_menu_pressed)
	%FileMenu.get_popup().add_item("New...", FILE_NEW, KEY_MASK_CTRL | KEY_N)
	%FileMenu.get_popup().add_item("Open...", FILE_OPEN, KEY_MASK_CTRL | KEY_O)
	%FileMenu.get_popup().add_item("Close", FILE_CLOSE, KEY_MASK_CTRL | KEY_W)
	%FileMenu.get_popup().add_separator()
	%FileMenu.get_popup().add_item("Save", FILE_SAVE, KEY_MASK_CTRL | KEY_S)
	%FileMenu.get_popup().add_item("Save As...", FILE_SAVE_AS, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
	%FileMenu.get_popup().add_separator()
	%FileMenu.get_popup().add_item("Export...", FILE_EXPORT, KEY_MASK_CTRL | KEY_MASK_ALT | KEY_MASK_SHIFT | KEY_S)
	%FileMenu.get_popup().add_item("Export Again", FILE_EXPORT_AGAIN, KEY_MASK_CTRL | KEY_MASK_ALT | KEY_S)
	%FileMenu.get_popup().add_separator()
	%FileMenu.get_popup().add_item("Quit", FILE_QUIT, KEY_MASK_CTRL | KEY_Q)

	%EditMenu.get_popup().id_pressed.connect(_on_menu_pressed)
	%EditMenu.get_popup().add_item("Undo", EDIT_UNDO, KEY_MASK_CTRL | KEY_Z)
	%EditMenu.get_popup().add_item("Redo", EDIT_REDO, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_Z)
	%EditMenu.get_popup().add_separator()
	%EditMenu.get_popup().add_item("Cut", EDIT_CUT, KEY_MASK_CTRL | KEY_X)
	%EditMenu.get_popup().add_item("Copy", EDIT_COPY, KEY_MASK_CTRL | KEY_C)
	%EditMenu.get_popup().add_item("Copy Merged", EDIT_COPY_MERGED, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_C)
	%EditMenu.get_popup().add_item("Paste", EDIT_PASTE, KEY_MASK_CTRL | KEY_V)
	%EditMenu.get_popup().add_separator()
	%EditMenu.get_popup().add_item("Select All", EDIT_SELECT_ALL, KEY_MASK_CTRL | KEY_A)
	%EditMenu.get_popup().add_item("Clear Selection", EDIT_CLEAR_SELECTION, KEY_MASK_CTRL | KEY_D)
	%EditMenu.get_popup().add_separator()
	%EditMenu.get_popup().add_item("Fill With Foreground", EDIT_FILL_FOREGROUND, KEY_MASK_ALT | KEY_DELETE)
	%EditMenu.get_popup().add_item("Fill With Background", EDIT_FILL_BACKGROUND, KEY_MASK_CTRL | KEY_DELETE)
	%EditMenu.get_popup().add_separator()
	%EditMenu.get_popup().add_item("Delete", EDIT_DELETE, KEY_DELETE)

	%ImageMenu.get_popup().id_pressed.connect(_on_menu_pressed)
	%ImageMenu.get_popup().add_item("Resize Image...", IMAGE_RESIZE_IMAGE, KEY_MASK_CTRL | KEY_MASK_ALT | KEY_I)
	%ImageMenu.get_popup().add_item("Resize Canvas...", IMAGE_RESIZE_CANVAS, KEY_MASK_CTRL | KEY_MASK_ALT | KEY_C)

	$FileOpenDialog.file_selected.connect(_on_file_open_selected)
	$FileOpenDialog.filters = [
		"*.knx, *.png,*.jpg,*.jpeg,*.bmp,*.tga,*.webp ; Image files",
		]

	$FileSaveDialog.filters = ["*.knx ; Knixel files"]
	$FileSaveDialog.file_selected.connect(_on_file_save_selected)

	$FileExportDialog.filters = ["*.png,*.jpg,*.jpeg,*.bmp,*.tga,*.webp ; Image files"]
	$FileExportDialog.file_selected.connect(_on_file_export_selected)

	for child in %ToolBar.get_children():
		if child is ToolButton:
			child.pressed.connect(func(): active_canvas.activate_tool(child.tool_type.new()))

	# TODO: Add the tools in code instead of in the UI scene
	%ToolBar/Move.shortcut = _shortcut(KEY_V)
	%ToolBar/BoxSelect.shortcut = _shortcut(KEY_M)
	%ToolBar/Brush.shortcut = _shortcut(KEY_B)
	%ToolBar/Eraser.shortcut = _shortcut(KEY_E)
	%ToolBar/EyeDropper.shortcut = _shortcut(KEY_I)

	_swap_colors_button.shortcut = _shortcut(KEY_X)
	_reset_colors_button.shortcut = _shortcut(KEY_D)
	_swap_colors_button.pressed.connect(swap_colors)
	_reset_colors_button.pressed.connect(reset_colors)

	for arg in OS.get_cmdline_args():
		# TODO: Figure out why the editor passes a scene as argument
		# to the application
		if arg.ends_with(".tscn"):
			continue
		load_from_file(arg)

func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE:
		ImageProcessor.shutdown()

func swap_colors():
	if active_canvas:
		active_canvas.document.swap_colors()

func reset_colors():
	if active_canvas:
		active_canvas.document.reset_colors()

func _on_foreground_commit():
	if active_canvas:
		active_canvas.document.foreground_color = %ForegroundColorBox.color

func _on_background_commit():
	if active_canvas:
		active_canvas.document.background_color = %BackgroundColorBox.color

func open_new_dialog() -> void:
	var dialog = preload("res://src/ui/new_dialog.tscn").instantiate()

	var image := _get_clipboard_image()
	if image:
		dialog.width = image.get_width()
		dialog.height = image.get_height()

	dialog.content_scale_factor = get_viewport().content_scale_factor
	dialog.size *= dialog.content_scale_factor

	dialog.position = get_window().position + (get_window().size - dialog.size) / 2

	dialog.submitted.connect(_on_new_dialog_submitted)

	add_child(dialog)

func open_resize_image_dialog() -> void:
	var dialog = preload("res://src/ui/resize_image_dialog.tscn").instantiate()

	if not active_canvas:
		return

	dialog.old_width = active_canvas.document.size.x
	dialog.old_height = active_canvas.document.size.y
	dialog.new_width = active_canvas.document.size.x
	dialog.new_height = active_canvas.document.size.y

	dialog.content_scale_factor = get_viewport().content_scale_factor
	dialog.size *= dialog.content_scale_factor

	dialog.position = get_window().position + (get_window().size - dialog.size) / 2

	dialog.submitted.connect(_on_resize_image_dialog_submitted)

	add_child(dialog)

func open_resize_canvas_dialog() -> void:
	var dialog = preload("res://src/ui/resize_canvas_dialog.tscn").instantiate()

	if not active_canvas:
		return

	dialog.old_width = active_canvas.document.size.x
	dialog.old_height = active_canvas.document.size.y
	dialog.new_width = active_canvas.document.size.x
	dialog.new_height = active_canvas.document.size.y

	dialog.content_scale_factor = get_viewport().content_scale_factor
	dialog.size *= dialog.content_scale_factor

	dialog.position = get_window().position + (get_window().size - dialog.size) / 2

	dialog.submitted.connect(_on_resize_canvas_dialog_submitted)

	add_child(dialog)

func _on_new_dialog_submitted(dialog : NewDialog) -> void:
	if dialog.width < 1 or dialog.width > 4096 or dialog.height < 1 or dialog.height > 4096:
		return

	var image := Image.create(dialog.width, dialog.height, false, Image.FORMAT_RGBA8)
	if not image:
		return

	_create_document_from_image(image, dialog.name)

func _on_resize_image_dialog_submitted(dialog : ResizeImageDialog) -> void:
	if dialog.new_width < 1 or dialog.new_width > 4096 or dialog.new_height < 1 or dialog.new_height > 4096:
		return

	if not active_canvas:
		return

	active_canvas.document.resize_image(Vector2i(dialog.new_width, dialog.new_height))

func _on_resize_canvas_dialog_submitted(dialog : ResizeCanvasDialog) -> void:
	if dialog.new_width < 1 or dialog.new_width > 4096 or dialog.new_height < 1 or dialog.new_height > 4096:
		return

	if not active_canvas:
		return

	active_canvas.document.resize_canvas(Vector2i(dialog.new_width, dialog.new_height), dialog.horizontal_alignment, dialog.vertical_alignment)

func _on_menu_pressed(id : int) -> void:
	match id:
		FILE_NEW:
			open_new_dialog()
		FILE_OPEN:
			$FileOpenDialog.popup()
		FILE_SAVE:
			save()
		FILE_SAVE_AS:
			save_as()
		FILE_EXPORT:
			$FileExportDialog.popup()
		FILE_EXPORT_AGAIN:
			export_again()
		FILE_CLOSE:
			if active_canvas:
				active_canvas.queue_free()
				active_canvas = null
		FILE_QUIT:
			get_tree().quit()
		EDIT_UNDO:
			if active_canvas:
				active_canvas.document.undo()
		EDIT_REDO:
			if active_canvas:
				active_canvas.document.redo()
		EDIT_CUT:
			cut()
		EDIT_COPY:
			copy()
		EDIT_COPY_MERGED:
			copy_merged()
		EDIT_PASTE:
			paste()
		EDIT_DELETE:
			active_canvas.document.delete_selection()
		EDIT_SELECT_ALL:
			active_canvas.document.select_all() 
		EDIT_CLEAR_SELECTION:
			active_canvas.document.selection = null
		EDIT_FILL_FOREGROUND:
			active_canvas.document.fill(active_canvas.document.foreground_color)
		EDIT_FILL_BACKGROUND:
			active_canvas.document.fill(active_canvas.document.background_color)
		IMAGE_RESIZE_IMAGE:
			open_resize_image_dialog()
		IMAGE_RESIZE_CANVAS:
			open_resize_canvas_dialog()

func _on_file_open_selected(file : String) -> void:
	load_from_file(file)

func _on_file_save_selected(file : String) -> void:
	if active_canvas:
		active_canvas.document.path = file
		active_canvas.document.save_to_file()

func _on_file_export_selected(file : String) -> void:
	if active_canvas:
		match file.get_extension():
			"png":
				active_canvas.document.output_image.save_png(file)
			"jpg", "jpeg":
				active_canvas.document.output_image.save_jpg(file)
			"webp":
				active_canvas.document.output_image.save_webp(file)
			_:
				# TODO: Error report
				return
		active_canvas.document.last_export_path = file		

func _create_canvas_with_document(document : Document, title : String) -> Canvas:
	var canvas := preload("res://src/ui/canvas.tscn").instantiate()
	canvas.document = document
	canvas_container.add_child(canvas)
	canvas_container.set_tab_title(canvas_container.get_tab_count()-1, title)
	canvas.reset_view()

	canvas.activate_tool(%ToolBar/BoxSelect.tool_type.new())
	canvas_container.current_tab = canvas_container.get_tab_count()-1
	active_canvas = canvas

	return canvas

func _create_document_from_image(image : Image, title : String) -> Document:
	var layer := ImageLayer.new()
	layer.image = image
	layer.name = "Layer 1"

	var document := Document.new()
	document.layers = [layer]
	document.selected_layer_id = layer.id
	document.selected_effect_id = 0
	document.size = Vector2i(image.get_width(), image.get_height())

	_create_canvas_with_document(document, title)

	return document

func _process(_delta):
	active_canvas = canvas_container.get_current_tab_control() as Canvas

	if active_canvas:
		_swap_colors_button.disabled = false
		_reset_colors_button.disabled = false

		for child in %ToolBar.get_children():
			child.disabled = false

		active_canvas.document.check()

		%ForegroundColorBox.color = active_canvas.document.foreground_color
		%BackgroundColorBox.color = active_canvas.document.background_color

		for child in %ToolBar.get_children():
			child.set_pressed_no_signal(active_canvas.tool and child is ToolButton and child.tool_type == active_canvas.tool.get_script())
	else:
		_swap_colors_button.disabled = true
		_reset_colors_button.disabled = true

		for child in %ToolBar.get_children():
			child.disabled = true

func load_from_file(path : String) -> void:
	if not FileAccess.file_exists(path):
		ErrorResult.new("Failed to open '%s'. The file does not exist." % path)

	var image = Image.new()
	if image.load(path) == Error.OK:
		image.convert(Image.FORMAT_RGBA8)
		_create_document_from_image(image, path.get_file())
		return

	var document = Document.load_from_file(path)
	if document is ErrorResult:
		show_error(ErrorResult.new("Failed to load file.", document))
	else:
		_create_canvas_with_document(document, path.get_file())

func save() -> void:
	if not active_canvas:
		return

	if not active_canvas.document.path:
		save_as()
	else:
		active_canvas.document.save_to_file()

func save_as() -> void:
	if not active_canvas:
		return

	if active_canvas.document.path:
		$FileSaveDialog.current_file = active_canvas.document.path
	else:
		$FileSaveDialog.current_file = "new file.knx"
	$FileSaveDialog.popup()

func export_again():
	if not active_canvas:
		return

	if active_canvas.document.last_export_path:
		_on_file_export_selected(active_canvas.document.last_export_path)
	else:
		$FileExportDialog.popup()


func cut() -> void:
	if not active_canvas:
		return

	copy()
	active_canvas.document.delete_selection()

func copy() -> void:
	if not active_canvas:
		return

	var layer := active_canvas.document.get_selected_layer() as ImageLayer
	if not layer:
		return

	var image := layer.extract_masked_image(active_canvas.document.selection, active_canvas.document.selection_offset)

	# TODO: System clipboard
	DisplayServer.clipboard_set("")
	_clipboard = image

func copy_merged() -> void:
	if not active_canvas:
		return

	var document := active_canvas.document

	var image := active_canvas.document.output_image.duplicate()
	image.clear_mipmaps()
	image = ImageProcessor.apply_mask(active_canvas.document.output_image, document.selection, document.selection_offset)

	var rect : Rect2i = image.get_used_rect()
	if rect.position != Vector2i(0, 0) or rect.size != image.get_size():
		image.blit_rect(image, rect, Vector2i(0, 0))
		image.crop(rect.size.x, rect.size.y)

	# TODO: System clipboard
	DisplayServer.clipboard_set("")
	_clipboard = image

func paste() -> void:
	var image := _get_clipboard_image()
	
	if image:
		if active_canvas:
			var layer := ImageLayer.new()
			layer.image = image
			layer.name = active_canvas.document.get_new_layer_name()
			active_canvas.document.layers.push_front(layer)
			active_canvas.document.selected_layer_id = layer.id
			active_canvas.document.selected_effect_id = 0
			active_canvas.document.selection = null
		else:
			_create_document_from_image(image, "Untitled")

func _get_clipboard_image() -> Image:
	var image : Image
	if DisplayServer.clipboard_has_image():
		image = DisplayServer.clipboard_get_image()
		image.convert(Image.FORMAT_RGBA8)
	else:
		image = _clipboard as Image

	return image

func show_error(error : ErrorResult) -> void:
	var error_dialog := preload("res://src/ui/error_dialog.tscn").instantiate()

	error_dialog.message = error.to_string()
	error_dialog.content_scale_factor = get_viewport().content_scale_factor
	error_dialog.size *= error_dialog.content_scale_factor

	error_dialog.position = get_window().position + (get_window().size - error_dialog.size) / 2
	print(error_dialog.message)

	add_child(error_dialog)
