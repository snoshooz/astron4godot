class_name DCTokens
extends RefCounted

enum SubatomicType {
	ST_INT8 = 0,
	ST_INT16 = 1,
	ST_INT32 = 2,
	ST_INT64 = 3,
	ST_UINT8 = 4,
	ST_UINT16 = 5,
	ST_UINT32 = 6,
	ST_UINT64 = 7,
	ST_FLOAT64 = 8,
	ST_STRING = 9,
	ST_BLOB = 10,
	ST_CHAR = 11,
	ST_INVALID = 12
}

static func get_type_id(type_name: String) -> int:
	match type_name.to_lower():
		"int8": return SubatomicType.ST_INT8
		"int16": return SubatomicType.ST_INT16
		"int32": return SubatomicType.ST_INT32
		"int64": return SubatomicType.ST_INT64
		"uint8": return SubatomicType.ST_UINT8
		"uint16": return SubatomicType.ST_UINT16
		"uint32": return SubatomicType.ST_UINT32
		"uint64": return SubatomicType.ST_UINT64
		"float", "float32", "float64", "double": return SubatomicType.ST_FLOAT64
		"string": return SubatomicType.ST_STRING
		"blob": return SubatomicType.ST_BLOB
		"char": return SubatomicType.ST_CHAR
		_: return SubatomicType.ST_INVALID
