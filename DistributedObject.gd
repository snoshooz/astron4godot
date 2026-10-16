class_name DistributedObject
extends Node

var do_id: int = 0
var parent_id: int = 0
var zone_id: int = 0
var dclass: DCFile.DClass
var cr: AstronClientRepository

func generate() -> void: pass
func announce_generate() -> void: pass
func disable() -> void: pass
func delete() -> void: queue_free()

func handle_field_update(field_id: int, dg: Datagram) -> void:
	if not dclass.fields_by_id.has(field_id):
		push_warning("[DO %d] Field ID %d missing from %s" % [do_id, field_id, dclass.name])
		return
		
	var field: DCFile.DCField = dclass.fields_by_id[field_id]
	
	if field.is_molecular:
		for atom in field.atomic_fields:
			_unpack_and_call_atomic_field(atom, dg)
	else:
		_unpack_and_call_atomic_field(field, dg)

func _unpack_and_call_atomic_field(field: DCFile.DCField, dg: Datagram) -> void:
	var args: Array = []
	for param in field.parameters:
		args.append(_unpack_param(param, dg))
	
	var target_method = field.name
	if not has_method(target_method):
		var setter_name = "set" + field.name.capitalize().replace(" ", "")
		if has_method(setter_name):
			target_method = setter_name
		else:
			push_warning("[DO %d] Method '%s' not implemented on %s" % [do_id, field.name, name])
			return
			
	callv(target_method, args)

func _unpack_param(param: DCFile.DCParameter, dg: Datagram) -> Variant:
	var val: Variant
	match param.type_name:
		"uint8": val = dg.get_uint8()
		"uint16": val = dg.get_uint16()
		"uint32": val = dg.get_uint32()
		"uint64": val = dg.get_uint64()
		"int8":
			var raw = dg.get_uint8()
			val = raw - 256 if raw >= 128 else raw
		"int16":
			var raw = dg.get_uint16()
			val = raw - 65536 if raw >= 32768 else raw
		"int32":
			var raw = dg.get_uint32()
			val = raw - 4294967296 if raw >= 2147483648 else raw
		"float32": val = dg.get_float32()
		"string": val = dg.get_string()
		"blob":
			var length = dg.get_uint16()
			val = dg.get_raw(length)
		_:
			val = dg.get_string()
			
	if param.divisor != 1.0 and (val is int or val is float):
		val = float(val) / param.divisor
	return val

func send_update(field_name: String, args_fn: Callable = Callable()) -> void:
	if not dclass.fields_by_name.has(field_name):
		push_error("Field '%s' not found on '%s'" % [field_name, dclass.name])
		return
	var field: DCFile.DCField = dclass.fields_by_name[field_name]
	var dg = Datagram.new()
	dg.add_uint16(120)
	dg.add_uint32(do_id)
	dg.add_uint16(field.id)
	if args_fn.is_valid():
		args_fn.call(dg)
	cr.send_datagram(dg)
