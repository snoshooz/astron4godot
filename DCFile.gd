class_name DCFile
extends RefCounted

class DCParameter:
	var type_name: String = ""
	var type_id: int = 11
	var divisor: float = 1.0
	var modulus: int = 0

class DCField:
	var id: int = 0
	var name: String = ""
	var flags: Array[String] = []
	var keyword_mask: int = 0
	var sorted_keyword_ids: Array[int] = []
	var parameters: Array[DCParameter] = []
	var is_molecular: bool = false
	var atomic_fields: Array[DCField] = []

class DClass:
	var id: int = 0
	var name: String = ""
	var parent_names: Array[String] = []
	var python_path: String = ""
	var client_script_path: String = ""
	var fields: Array[DCField] = []
	var fields_by_id: Dictionary = {}
	var fields_by_name: Dictionary = {}

var classes: Array[DClass] = []
var classes_by_id: Dictionary = {}
var classes_by_name: Dictionary = {}
var current_dclass_id: int = 1
var current_field_id: int = 1