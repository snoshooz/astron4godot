class_name DistributedNode
extends DistributedObject

var parent_str: PackedByteArray = PackedByteArray()
var node_parent_id: int = 0

var p3d_position: Vector3 = Vector3.ZERO
var p3d_hpr: Vector3 = Vector3.ZERO

var target_godot_pos: Vector3 = Vector3.ZERO
var target_godot_rot: Vector3 = Vector3.ZERO

static func p3d_pos_to_godot(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y)

static func godot_pos_to_p3d(g: Vector3) -> Vector3:
	return Vector3(g.x, -g.z, g.y)

static func p3d_hpr_to_godot_euler(hpr: Vector3) -> Vector3:
	return Vector3(deg_to_rad(hpr.y), deg_to_rad(-hpr.x), deg_to_rad(-hpr.z))

static func godot_euler_to_p3d_hpr(euler: Vector3) -> Vector3:
	return Vector3(fposmod(-rad_to_deg(euler.y), 360.0), rad_to_deg(euler.x), -rad_to_deg(euler.z))

func setParentStr(data: PackedByteArray) -> void:
	parent_str = data

func setParent(pid: int) -> void:
	node_parent_id = pid

func setX(x: float) -> void:
	p3d_position.x = x
	_sync_transform()

func setY(y: float) -> void:
	p3d_position.y = y
	_sync_transform()

func setZ(z: float) -> void:
	p3d_position.z = z
	_sync_transform()

func setH(h: float) -> void:
	p3d_hpr.x = h
	_sync_transform()

func setP(p: float) -> void:
	p3d_hpr.y = p
	_sync_transform()

func setR(r: float) -> void:
	p3d_hpr.z = r
	_sync_transform()

func _sync_transform() -> void:
	target_godot_pos = p3d_pos_to_godot(p3d_position)
	target_godot_rot = p3d_hpr_to_godot_euler(p3d_hpr)

func b_set_xyz_h(godot_pos: Vector3, godot_rot: Vector3) -> void:
	var p3d_pos = godot_pos_to_p3d(godot_pos)
	var hpr = godot_euler_to_p3d_hpr(godot_rot)
	
	p3d_position = p3d_pos
	p3d_hpr.x = hpr.x
	_sync_transform()
	
	send_update("setXYZH", func(dg: Datagram):
		_pack_fixed(dg, p3d_pos.x)
		_pack_fixed(dg, p3d_pos.y)
		_pack_fixed(dg, p3d_pos.z)
		_pack_fixed(dg, hpr.x)
	)

func _pack_fixed(dg: Datagram, val: float, divisor: float = 10.0) -> void:
	var scaled = clampi(int(round(val * divisor)), -32768, 32767)
	dg.add_uint16(scaled & 0xFFFF)
