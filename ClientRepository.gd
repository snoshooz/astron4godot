class_name AstronClientRepository
extends Node

signal connected_to_server
signal disconnected_from_server
signal hello_accepted
signal object_generated(do_id: int, obj: DistributedObject)

enum MsgType {
	CLIENT_HELLO = 1,
	CLIENT_HELLO_RESP = 2,
	CLIENT_DISCONNECT = 3,
	CLIENT_EJECT = 4,
	CLIENT_HEARTBEAT = 5,
	CLIENT_OBJECT_SET_FIELD = 120,
	CLIENT_OBJECT_LEAVING = 132,
	CLIENT_ENTER_OBJECT_REQUIRED = 142,
	CLIENT_ENTER_OBJECT_REQUIRED_OTHER = 143,
	CLIENT_ADD_INTEREST = 200,
	CLIENT_REMOVE_INTEREST = 203
}

@export var dc_files: Array[String] = [
	"res://astron4godot/basic.dc"
]
@export var server_version: String = "dev"
@export var dc_hash: int = 0
@export var heartbeat_interval: float = 10.0

var tcp: StreamPeerTCP = StreamPeerTCP.new()
var is_connected: bool = false
var receive_buffer: PackedByteArray = PackedByteArray()
var heartbeat_timer: float = 0.0

var dc_file: DCFile
var do_id2do: Dictionary = {}

func _ready() -> void:
	_load_dc_files()

func _load_dc_files() -> void:
	dc_file = DCParser.parse_files(dc_files)

func _process(delta: float) -> void:
	tcp.poll()
	var status = tcp.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not is_connected:
			is_connected = true
			connected_to_server.emit()
			_send_hello()
			
		_read_network_stream()
		_handle_heartbeat(delta)
	elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		if is_connected:
			is_connected = false
			disconnected_from_server.emit()
			_cleanup_objects()

func connect_to_astron(host: String, port: int) -> Error:
	receive_buffer.clear()
	return tcp.connect_to_host(host, port)

func send_datagram(dg: Datagram) -> void:
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var frame = Datagram.new()
	frame.add_uint16(dg.buffer.size())
	frame.add_raw(dg.buffer)
	tcp.put_data(frame.buffer)

func add_interest(interest_id: int, parent_id: int, zone_id: int, context: int = 0) -> void:
	var dg = Datagram.new()
	dg.add_uint16(MsgType.CLIENT_ADD_INTEREST)
	dg.add_uint32(context)
	dg.add_uint16(interest_id)
	dg.add_uint32(parent_id)
	dg.add_uint32(zone_id)
	send_datagram(dg)

func _send_hello() -> void:
	var dg = Datagram.new()
	dg.add_uint16(MsgType.CLIENT_HELLO)
	dg.add_uint32(dc_hash)
	dg.add_string(server_version)
	send_datagram(dg)

func _handle_heartbeat(delta: float) -> void:
	heartbeat_timer += delta
	if heartbeat_timer >= heartbeat_interval:
		heartbeat_timer = 0.0
		var dg = Datagram.new()
		dg.add_uint16(MsgType.CLIENT_HEARTBEAT)
		send_datagram(dg)

func _read_network_stream() -> void:
	var avail = tcp.get_available_bytes()
	if avail <= 0: return
	var chunk = tcp.get_data(avail)
	if chunk[0] == OK:
		receive_buffer.append_array(chunk[1])
		
	while receive_buffer.size() >= 2:
		var frame_len = receive_buffer.decode_u16(0)
		var total_len = 2 + frame_len
		if receive_buffer.size() < total_len:
			break
			
		var data = receive_buffer.slice(2, total_len)
		receive_buffer = receive_buffer.slice(total_len)
		_dispatch_datagram(Datagram.new(data))

func _dispatch_datagram(dg: Datagram) -> void:
	var msg_type = dg.get_uint16()
	match msg_type:
		MsgType.CLIENT_HELLO_RESP:
			hello_accepted.emit()
		MsgType.CLIENT_EJECT:
			var code = dg.get_uint32()
			var reason = dg.get_string()
			push_error("[Astron] Ejected: %d - %s" % [code, reason])
		MsgType.CLIENT_ENTER_OBJECT_REQUIRED, MsgType.CLIENT_ENTER_OBJECT_REQUIRED_OTHER:
			_handle_generate(dg, msg_type == MsgType.CLIENT_ENTER_OBJECT_REQUIRED_OTHER)
		MsgType.CLIENT_OBJECT_LEAVING:
			_handle_delete(dg.get_uint32())
		MsgType.CLIENT_OBJECT_SET_FIELD:
			var do_id = dg.get_uint32()
			var field_id = dg.get_uint16()
			if do_id2do.has(do_id):
				do_id2do[do_id].handle_field_update(field_id, dg)

func _handle_generate(dg: Datagram, has_other: bool) -> void:
	var do_id = dg.get_uint32()
	var parent_id = dg.get_uint32()
	var zone_id = dg.get_uint32()
	var dclass_id = dg.get_uint16()
	
	if not dc_file.classes_by_id.has(dclass_id):
		push_error("DClass ID %d not registered" % dclass_id)
		return
		
	var dclass: DCFile.DClass = dc_file.classes_by_id[dclass_id]
	if not ResourceLoader.exists(dclass.client_script_path):
		push_error("Could not find script at %s" % dclass.client_script_path)
		return
		
	var script: GDScript = load(dclass.client_script_path)
	var obj: DistributedObject = script.new()
	obj.name = "%s_%d" % [dclass.name, do_id]
	obj.do_id = do_id
	obj.parent_id = parent_id
	obj.zone_id = zone_id
	obj.dclass = dclass
	obj.cr = self
	
	do_id2do[do_id] = obj
	add_child(obj)
	obj.generate()
	
	for field in dclass.fields:
		if field.flags.has("required"):
			obj.handle_field_update(field.id, dg)
			
	if has_other:
		var count = dg.get_uint16()
		for i in range(count):
			var field_id = dg.get_uint16()
			obj.handle_field_update(field_id, dg)
			
	obj.announce_generate()
	object_generated.emit(do_id, obj)

func _handle_delete(do_id: int) -> void:
	if do_id2do.has(do_id):
		var obj = do_id2do[do_id]
		do_id2do.erase(do_id)
		obj.disable()
		obj.delete()

func _cleanup_objects() -> void:
	for do_id in do_id2do.keys():
		_handle_delete(do_id)
