class_name Datagram
extends RefCounted

var buffer: PackedByteArray = PackedByteArray()
var offset: int = 0

func _init(initial: PackedByteArray = PackedByteArray()) -> void:
	buffer = initial
	offset = 0


func add_uint8(val: int) -> void:
	buffer.append(val & 0xFF)
	
func add_uint16(val: int) -> void:
	var idx = buffer.size()
	buffer.resize(idx + 2)
	buffer.encode_u16(idx, val)

func add_uint32(val: int) -> void:
	var idx = buffer.size()
	buffer.resize(idx + 4)
	buffer.encode_u32(idx, val)

func add_uint64(val: int) -> void:
	var idx = buffer.size()
	buffer.resize(idx + 8)
	buffer.encode_u64(idx, val)

func add_float32(val: float) -> void:
	var idx = buffer.size()
	buffer.resize(idx + 4)
	buffer.encode_float(idx, val)

func add_string(val: String) -> void:
	var raw = val.to_utf8_buffer()
	add_uint16(raw.size())
	buffer.append_array(raw)

func add_raw(raw: PackedByteArray) -> void:
	buffer.append_array(raw)


func get_uint8() -> int:
	var v = buffer.decode_u8(offset); offset += 1; return v

func get_uint16() -> int:
	var v = buffer.decode_u16(offset); offset += 2; return v

func get_uint32() -> int:
	var v = buffer.decode_u32(offset); offset += 4; return v

func get_uint64() -> int:
	var v = buffer.decode_u64(offset); offset += 8; return v

func get_float32() -> float:
	var v = buffer.decode_float(offset); offset += 4; return v

func get_string() -> String:
	var length = get_uint16()
	var raw = buffer.slice(offset, offset + length)
	offset += length
	return raw.get_string_from_utf8()

func get_remaining() -> int:
	return buffer.size() - offset
