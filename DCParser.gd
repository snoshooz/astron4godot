class_name DCParser
extends RefCounted

static func parse_files(file_paths: Array[String]) -> DCFile:
	var dc_file = DCFile.new()
	dc_file.current_dclass_id = 1
	dc_file.current_field_id = 1
	
	var combined_source = ""
	for path in file_paths:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			combined_source += "\n" + file.get_as_text()
			file.close()
		else:
			push_error("Failed to read DC file at: %s" % path)

	var clean = _strip_comments(combined_source)
	_parse_all_classes(clean, dc_file)
	
	return dc_file

static func _parse_all_classes(source: String, dc_file: DCFile) -> void:
	var dclass_regex = RegEx.new()
	dclass_regex.compile("dclass\\s+([A-Za-z0-9_]+)(?:\\s*:\\s*([A-Za-z0-9_,\\s]+))?\\s*(?:\"([^\"]+)\")?\\s*\\{([^\\}]*)\\};?")
	
	for match in dclass_regex.search_all(source):
		var dclass = DCFile.DClass.new()
		dclass.id = dc_file.current_dclass_id
		dc_file.current_dclass_id += 1
		
		dclass.name = match.get_string(1).strip_edges()
		
		var parents_str = match.get_string(2).strip_edges()
		if not parents_str.is_empty():
			for p in parents_str.split(","):
				var parent_name = p.strip_edges()
				if not parent_name.is_empty():
					dclass.parent_names.append(parent_name)
		
		var raw_path = match.get_string(3).strip_edges()
		if not raw_path.is_empty():
			dclass.python_path = raw_path
			dclass.client_script_path = _resolve_script_path(raw_path)
		else:
			dclass.client_script_path = "res://astron4godot/%s.gd" % dclass.name
		
		dc_file.classes.append(dclass)
		dc_file.classes_by_id[dclass.id] = dclass
		dc_file.classes_by_name[dclass.name] = dclass

		var body = match.get_string(4)
		_parse_fields(body, dclass, dc_file)

static func _parse_fields(body: String, dclass: DCFile.DClass, dc_file: DCFile) -> void:
	var statements = body.split(";", false)
	for stmt in statements:
		var line = stmt.strip_edges()
		if line.is_empty():
			continue
		
		if ":" in line and not "(" in line:
			var parts = line.split(":")
			var mol_name = parts[0].strip_edges()
			var atom_names = parts[1].split(",")

			var mol_field = DCFile.DCField.new()
			mol_field.id = dc_file.current_field_id
			dc_file.current_field_id += 1
			mol_field.name = mol_name
			mol_field.is_molecular = true

			for atom_name in atom_names:
				var a_clean = atom_name.strip_edges()
				var atom = _find_field_in_hierarchy(a_clean, dclass, dc_file)
				if atom:
					mol_field.atomic_fields.append(atom)
				else:
					push_error("Molecular field '%s' references unknown atomic field '%s'" % [mol_name, a_clean])

			dclass.fields.append(mol_field)
			dclass.fields_by_id[mol_field.id] = mol_field
			dclass.fields_by_name[mol_field.name] = mol_field
			continue
		
		var paren_start = line.find("(")
		var paren_end = line.rfind(")")
		if paren_start == -1 or paren_end == -1:
			continue

		var field_name = line.substr(0, paren_start).strip_edges()
		var params_str = line.substr(paren_start + 1, paren_end - paren_start - 1).strip_edges()
		var trailing_flags = line.substr(paren_end + 1).strip_edges().split(" ", false)

		var field = DCFile.DCField.new()
		field.id = dc_file.current_field_id
		dc_file.current_field_id += 1
		field.name = field_name
		field.is_molecular = false

		for flag in trailing_flags:
			field.flags.append(flag.strip_edges())
		
		if not params_str.is_empty():
			for token in params_str.split(","):
				var trimmed_tok = token.strip_edges()
				if not trimmed_tok.is_empty():
					field.parameters.append(_parse_param(trimmed_tok))

		dclass.fields.append(field)
		dclass.fields_by_id[field.id] = field
		dclass.fields_by_name[field.name] = field

static func _find_field_in_hierarchy(field_name: String, dclass: DCFile.DClass, dc_file: DCFile) -> DCFile.DCField:
	if dclass.fields_by_name.has(field_name):
		return dclass.fields_by_name[field_name]
	for p_name in dclass.parent_names:
		if dc_file.classes_by_name.has(p_name):
			var res = _find_field_in_hierarchy(field_name, dc_file.classes_by_name[p_name], dc_file)
			if res:
				return res
	return null

static func _parse_param(token: String) -> DCFile.DCParameter:
	var param = DCFile.DCParameter.new()
	param.divisor = 1.0
	param.modulus = 0

	var parts = token.split(" ", false)
	var type_token = parts[0]
	
	if "%" in type_token and "/" in type_token:
		var slash_split = type_token.split("/")
		param.divisor = slash_split[1].to_float()
		var mod_split = slash_split[0].split("%")
		param.modulus = mod_split[1].to_int()
		type_token = mod_split[0]
	elif "%" in type_token:
		var mod_split = type_token.split("%")
		param.modulus = mod_split[1].to_int()
		type_token = mod_split[0]
	elif "/" in type_token:
		var slash_split = type_token.split("/")
		param.divisor = slash_split[1].to_float()
		type_token = slash_split[0]

	param.type_name = type_token
	param.type_id = DCTokens.get_type_id(type_token)
	return param

static func _resolve_script_path(python_path: String) -> String:
	var client_module = python_path.split("/")[0].strip_edges()
	if client_module.begins_with("direct.distributed."):
		var target_name = client_module.trim_prefix("direct.distributed.")
		return "res://astron4godot/%s.gd" % target_name
	var godot_path = client_module.replace(".", "/")
	return "res://%s.gd" % godot_path

static func _strip_comments(source: String) -> String:
	var block_comment = RegEx.new()
	block_comment.compile("/\\*[\\s\\S]*?\\*/")
	var stripped = block_comment.sub(source, "", true)
	var line_comment = RegEx.new()
	line_comment.compile("//.*$")
	return line_comment.sub(stripped, "", true)
