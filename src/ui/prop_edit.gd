extends Control

class_name PropEdit

var document : Document
var object : Object
var property_info : Dictionary

@onready var _label := %Label as Label
@onready var _value_edit := %ValueEdit as SpinText
@onready var _color_box := %ColorBox as ColorBox

func _ready():
	if property_info.type == TYPE_COLOR:
		_color_box.commit.connect(_on_color_commit)

		_color_box.visible = true
		_value_edit.visible = false
	else:
		_value_edit.edit_started.connect(_on_edit_started)
		_value_edit.edit_ended.connect(_on_edit_ended)
		
		_color_box.visible = false
		_value_edit.visible = true
		if property_info.hint == PROPERTY_HINT_RANGE:
			# TODO: Not very robust but oh well
			var values := (property_info.hint_string as String).split(",")
			_value_edit.min_value = float(values[0])
			_value_edit.max_value = float(values[1])
		if property_info.type == TYPE_INT:
			_value_edit.integer = true
	
	_label.text = property_info.name.capitalize()

	# TODO: This is needed to not have it glitch with the init color for one frame,
	# maybe should sort that out some other way.
	_process(0)
	_color_box._process(0)

func _on_edit_started():
	if document:
		document.start_undo_block()

func _on_edit_ended():
	if document:
		object.set(property_info.name, _value_edit.value)

		document.end_undo_block()

func _on_color_commit():
	object.set(property_info.name, _color_box.color)

func _process(_delta):
	if _value_edit.visible:
		if not _value_edit.is_editing():
			_value_edit.value = object.get(property_info.name)
		else:
			object.set(property_info.name, _value_edit.value)
	elif _color_box.visible:
		_color_box.color = object.get(property_info.name)
