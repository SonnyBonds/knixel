## KnixelResource is the base for all serializable parts of the document model.
##
## Apart from serialization it also has methods for comparing & cloning resources,
## which is used for UI and undo/redo updates.
##
## KnixelResource only extends Resource to be able to participate in typed arrays.
## No actual Resource functionality is used
class_name KnixelResource extends Resource

## Unique (within a document) ID of the resource
@export_storage var id : int

## Dictionary of all registered KnixelResource subtypes. Key:value is type_id:Script.
static var resource_types = {}

class Writer extends RefCounted:
	var zip_packer := ZIPPacker.new()
	var blob_names := {}

	func open(path : String):
		zip_packer.open(path)

	func close():
		zip_packer.close()

	func _notification(what):
		if what == NOTIFICATION_PREDELETE:
			zip_packer.close()

	func write_blob(name : String, data : PackedByteArray):
		zip_packer.start_file(name)
		zip_packer.write_file(data)
		zip_packer.close_file()

	func write_blob_reference(name : String, data : PackedByteArray) -> Dictionary:
		var dict := {}
		var original_name := name.get_basename()
		var ext := name.get_extension()
		if ext:
			ext = "." + ext
		var i := 2
		while name in blob_names:
			name = original_name + " " + str(i) + ext
			i += 1

		blob_names[name] = true

		dict["$type"] = "blob_reference"
		dict["path"] = name
		write_blob(name, data)

		return dict

class Reader extends RefCounted:
	var zip_reader := ZIPReader.new()
	var blob_names := {}

	func open(path : String) -> ErrorResult:
		var err := zip_reader.open(path)
		if err != Error.OK:
			return ErrorResult.new(error_string(err))

		return null

	func close():
		zip_reader.close()

	func read_blob(name : String) -> PackedByteArray:
		return zip_reader.read_file(name)

	func read_blob_reference(dict : Dictionary) -> Variant:
		if dict["$type"] != "blob_reference":
			return ErrorResult.new("Got object with type '%s' but expected 'blob_reference'.", dict["$type"])

		return read_blob(dict["path"])

# Ideally this should have been in _static_init, but initialization order
# seems to not be defined and this needs to happen after script classes have
# been loaded.
static func initialize():
	# Build a list of all KnixelResource derived types by iterating over all
	# registered types and checking if their parent is a KnixelResource derived type.
	# Instead of doing the search recursively, it's iterating multiple times leaving
	# types with unknown parents to subsequent iterations. When no progress has been
	# made (no new resource types added) only non-resource types remain in the list
	# and we're done.

	var unresolved := ProjectSettings.get_global_class_list()
	var resolved_resource_types := {}
	var resource_type_names = []
	while not unresolved.is_empty():
		var progress := false

		var scan := unresolved
		unresolved = []
		for cls in scan:
			if cls.base == &"KnixelResource" or resolved_resource_types.has(cls.base):
				var cls_name = cls["class"]
				resource_type_names.push_back(cls_name)
				resolved_resource_types[cls_name] = load(cls.path)
				progress = true
			elif ClassDB.is_class(cls.base):
				continue
			else:
				unresolved.push_back(cls)

		if not progress:
			break

	for cls_name in resolved_resource_types:
		var cls = resolved_resource_types[cls_name]

		# Generate a type ID from the class name
		var type_id = cls_name.to_snake_case()

		# Allow override of type name
		if &"type_id" in cls.get_script_constant_map():
			type_id = cls.get(&"type_id")

		# Check that the ID is not duplicate somehow
		assert(type_id not in resource_types)

		resource_types[type_id] = cls

		# Store the type_id in meta for later retrieval
		cls.set_meta(&"type_id", type_id)

		# Check (in debug) that we're not exporting stuff that KnixelResource can't handle (yet)
		if OS.is_debug_build():
			var category := ""
			for prop in cls.get_script_property_list():
				if prop.usage & PROPERTY_USAGE_CATEGORY:
						category = prop.name
				elif prop.usage & PROPERTY_USAGE_STORAGE:
					match prop.type:
						TYPE_STRING, TYPE_INT, TYPE_COLOR, TYPE_BOOL, TYPE_FLOAT, TYPE_VECTOR2I:
							pass
						TYPE_ARRAY:
							var split_array_type := (prop.hint_string as String).split(str(PROPERTY_HINT_RESOURCE_TYPE) + ":")
							assert(len(split_array_type) == 2, "Non-supported array type '%s' in property '%s' of '%s'." % [prop.hint_string, prop.name, category])
							var resource_type := split_array_type[1]
							assert(resource_type in resource_type_names, "Non-supported array type '%s' in property '%s' of '%s'." % [resource_type, prop.name, category])
						TYPE_OBJECT:
							match prop.hint_string:
								"Image":
									pass
								_:
									assert(false, "Non-supported export type '%s' in property '%s' of '%s'." % [prop.hint_string, prop.name, category])
						_:
							assert(false, "Non-supported export type '%s' in property '%s' of '%s'." % [type_string(prop.type), prop.name, category])

static var _next_id : int = 1

# TODO: The ID generation needs to be better
static func _get_next_id() -> int:
	var new_id = _next_id
	_next_id += 1
	return new_id

func _init():
	id = _get_next_id()

## Type id is unique for a resource type, and mostly used as a string name for serialization.
func get_type_id() -> String:
	return get_script().get_meta(&"type_id")

static func _to_json(value : Variant) -> Variant:
	match typeof(value):
		TYPE_INT, TYPE_STRING, TYPE_FLOAT, TYPE_BOOL:
			return value
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a }
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		_:
			return Error.ERR_BUG

static func _get_json_number(dict : Dictionary, field : String, type : String):
	var value = dict[field]
	if value == null:
		return ErrorResult.new("Expected field '%s' in %s object." % [field, type])
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return ErrorResult.new("Expected number field '%s' in %s object, but got %s." % [field, type, type_string(typeof(value))])
	return value

static func _from_json(value : Variant, expected_type : Variant) -> Variant:
	match expected_type:
		TYPE_INT, TYPE_FLOAT:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return ErrorResult.new("Got value of type %s but expected %s." % [type_string(typeof(value)), type_string(expected_type)])
			else:
				return convert(value, expected_type)
		TYPE_STRING, TYPE_BOOL:
			if typeof(value) != expected_type:
				return ErrorResult.new("Got value of type %s but expected %s." % [type_string(typeof(value)), type_string(expected_type)])
			else:
				return value
		TYPE_COLOR:
			if not value is Dictionary:
				return ErrorResult.new("Got value of type %s but expected color object." % [type_string(typeof(value))])

			var r = _get_json_number(value, "r", "color")
			if r is ErrorResult: return r
			var g = _get_json_number(value, "g", "color")
			if g is ErrorResult: return g
			var b = _get_json_number(value, "b", "color")
			if b is ErrorResult: return b
			var a = _get_json_number(value, "a", "color")
			if a is ErrorResult: return a
			
			return Color(r, g, b, a)            
		TYPE_VECTOR2I:
			if not value is Dictionary:
				return ErrorResult.new("Got value of type %s but expected 2D vector object." % [type_string(typeof(value))])

			var x = _get_json_number(value, "x", "2D vector")
			if x is ErrorResult: return x
			var y = _get_json_number(value, "y", "2D vector")
			if y is ErrorResult: return y

			return Vector2i(x, y)
		_:
			return ErrorResult.new("Internal error: Unsupported type %s" % [type_string(expected_type)])

## Load a resource from a Dictionary and a Reader.
## Returns either a new resource instance or an ErrorResult.
static func load(dict : Dictionary, reader : Reader, expected_type_id : String = "") -> Variant:
	var type_id = dict.get("$type", null)
	if not type_id:
		if expected_type_id:
			return ErrorResult.new("No resource type id found, but '%s' was expected." % [expected_type_id])
		else:
			return ErrorResult.new("No resource type id found.")

	if expected_type_id and type_id != expected_type_id:
		return ErrorResult.new("Found resource type id '%s', but '%s' was expected." % [type_id, expected_type_id])

	if not type_id in resource_types:
		return ErrorResult.new("Found unknown resource type id '%s'." % [type_id])

	var obj = resource_types[type_id].new() as KnixelResource

	for prop in obj.get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if prop.usage & PROPERTY_USAGE_STORAGE and dict.has(prop.name):
			if prop.type == TYPE_ARRAY:
				var json_arr = dict.get(prop.name)
				if not json_arr is Array:
					return ErrorResult.new("Expected array but got %s in property '%s' on '%s'." % [type_string(typeof(json_arr)), prop.name, type_id])
				var arr := [] #Array([], TYPE_OBJECT, &"Layer", Layer)
				for json_item in json_arr:
					var item = KnixelResource.load(json_item, reader)
					if item is ErrorResult:
						return item
					# TODO: Verify type
					arr.push_back(item)
				obj.get(prop.name).assign(arr)
			elif prop.type == TYPE_OBJECT:
				if prop.hint_string == "Image":
					var value_dict := dict.get(prop.name) as Dictionary
					var data = reader.read_blob_reference(value_dict)
					if data is ErrorResult:
						return data
					# TODO: Use another format to support HDR etc
					if (value_dict.path as String).get_extension() == "png":
						var image := Image.new()
						image.load_png_from_buffer(data)
						image.convert(Image.FORMAT_RGBAF)
						image = ImageProcessor.srgb_to_linear(image)
						obj.set(prop.name, image)
					else:
						return ErrorResult.new("Expected PNG blob for image in property '%s' on '%s'." % [prop.name, type_id])
				else:
					return ErrorResult.new("Internal error: Unexpected object type '%s' in property '%s' on '%s'." % [prop.hint_string, prop.name, type_id])
			else:
				var value : Variant = _from_json(dict.get(prop.name), prop.type)
				if value is ErrorResult:
					return value
				else:
					obj.set(prop.name, value)

	# TODO: The ID generation needs to be better, but right now
	# we'll try to make sure we don't get duplicate IDs by bumping the _next_id
	# value above any encountered ID
	if obj.id >= _next_id:
		_next_id = obj.id + 1

	return obj

## Serialize a resource to a dictionary, writing any blobs to the supplied Writer.
func save(writer : Writer) -> Dictionary:
	var dict := {}

	dict["$type"] = get_type_id()

	for prop in get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if prop.usage & PROPERTY_USAGE_STORAGE:
			if prop.type == TYPE_ARRAY:
				var arr := []
				for item in get(prop.name):
					arr.push_back(item.save(writer))
				dict[prop.name] = arr
			elif prop.type == TYPE_OBJECT:
				if prop.hint_string == "Image":
					# TODO: Use another format to support HDR etc
					var image := ImageProcessor.linear_to_srgb(get(prop.name) as Image)
					image.convert(Image.FORMAT_RGBA8)
					dict[prop.name] = writer.write_blob_reference(prop.name + ".png", image.save_png_to_buffer())
				else:
					# TODO: Error somehow
					pass
			else:
				dict[prop.name] = _to_json(get(prop.name))
	
	return dict

# This is unfortunate, but since KnixelResource is a Resource it also
# has some cruft that we're note using. In particular "duplicate" is
# easy to mix up with "clone" which is why we're having an extra guard here. 
@warning_ignore("native_method_override")
func duplicate(_subresources : bool = false) -> Resource:
	assert(false, "KnixelResource duplicate should not be used")
	return null

## Compare if this resource is equal to another, based on exported properties.
## Only properties with usage flag PROPERTY_USAGE_SCRIPT_VARIABLE are considered
## to filter out native (Resource) properties.
## Properties with PROPERTY_USAGE_NEVER_DUPLICATE are considered non-participating
## in equality test.
func compare(other : KnixelResource) -> bool:
	if get_script() != other.get_script():
		return false

	for prop in get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if prop.usage & PROPERTY_USAGE_NEVER_DUPLICATE:
			continue
		if (prop.usage & PROPERTY_USAGE_STORAGE) or (prop.usage & PROPERTY_USAGE_EDITOR):
			if prop.type == TYPE_ARRAY:
				var arr_a = get(prop.name)
				var arr_b = other.get(prop.name)
				if len(arr_a) != len(arr_b):
					return false
				else:
					for arr_i in len(arr_a):
						if !arr_a[arr_i].compare(arr_b[arr_i]):
							return false
			elif get(prop.name) != other.get(prop.name):
				return false

	return true

## Copy properties of another resource instance into this, based on exported properties.
## Only properties with usage flag PROPERTY_USAGE_SCRIPT_VARIABLE are considered
## to filter out native (Resource) properties.
## Properties with PROPERTY_USAGE_NEVER_DUPLICATE are not copied.
func copy_from(other : KnixelResource) -> void:
	assert(get_script() == other.get_script())

	for prop in get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		if prop.usage & PROPERTY_USAGE_NEVER_DUPLICATE:
			continue
		if prop.usage & PROPERTY_USAGE_STORAGE:
			if prop.type == TYPE_ARRAY:
				var arr := []
				for item in other.get(prop.name):
					arr.push_back(item.clone())
				get(prop.name).assign(arr)
			else:
				set(prop.name, other.get(prop.name))

## Create a new resource instance that is a copy of this, based on exported properties.
## Only properties with usage flag PROPERTY_USAGE_SCRIPT_VARIABLE are considered
## to filter out native (Resource) properties.
## Properties with PROPERTY_USAGE_NEVER_DUPLICATE are not copied.
func clone() -> KnixelResource:
	var copy = get_script().new()
	copy.copy_from(self)
	return copy
