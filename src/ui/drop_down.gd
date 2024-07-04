extends Button

class_name DropDown

signal commit

class Item extends RefCounted:
	var name : String
	var data : Variant
	var enabled := true
	
	func _init(_name : String, _data : Variant = null):
		name = _name
		data = _data
	
var items : Array[Item]
var current_item : Item

@onready var _popup_menu := %PopupMenu as PopupMenu

func _ready():
	pressed.connect(_on_pressed)

	_popup_menu.id_pressed.connect(_on_menu_pressed)

	# The viewport's scale isn't set properly until Main has been initialized
	await get_tree().process_frame

	_popup_menu.content_scale_factor = get_viewport().content_scale_factor
	_popup_menu.size *= _popup_menu.content_scale_factor

func _process(_delta):
	var item := current_item
	if item:
		text = item.name
	else:
		text = "-"

func _on_pressed():
	_popup_menu.clear()
	for index in len(items):
		_popup_menu.add_item(items[index].name, index)
		_popup_menu.set_item_disabled(index, !items[index].enabled)
	var content_scale : float = get_viewport().content_scale_factor 
	_popup_menu.popup_on_parent(Rect2i(Vector2i(global_position * content_scale), Vector2i(int(size.x*content_scale), 0)))

func _on_menu_pressed(id : int) -> void:
	current_item = items[id]
	commit.emit()
