extends Node3D

@onready var part_prefab = preload("res://assets/prefabs/building/Parts/Part.tscn")
@onready var cylinder_prefab = preload("res://assets/prefabs/building/Parts/cylinder.tscn")
@onready var wedge_prefab = preload("res://assets/prefabs/building/Parts/wedge.tscn")
@onready var cornerwedge_prefab = preload("res://assets/prefabs/building/Parts/cornerwedge.tscn")
@onready var ball_prefab = preload("res://assets/prefabs/building/Parts/ball.tscn")
@onready var truss_prefab = preload("res://assets/prefabs/building/Parts/Truss.tscn")
@onready var checkpoint_prefab = preload("res://assets/prefabs/models/checkpoint.tscn")

@onready var player = $Player

@onready var default_tile = preload("res://assets/images/textures/orp_brick_updated.png")
@onready var roblox_tile = preload("res://assets/images/textures/RobloxTile.png")

@onready var opaque_shader = preload("res://assets/resources/shaders/TextureRepeating.gdshader")
@onready var transparent_shader = preload("res://assets/resources/shaders/part_transparent.gdshader")

@onready var destinations: Dictionary = {} # Key: tp_id (String) -> Value: Node3D (Destination)

var checkpoints: Array = []
var spawn_point: Node3D = null
var alljump: bool = false

var _spawn_parent: Node3D = self
var _material_cache: Dictionary = {}

var roblox_studs: bool:
	get: return GameManager.RobloxStuds
var shiftlocked: bool:
	get: return GameManager.shiftlocked
var current_level: String:
	get: return GameManager.currentLevel
var game_manager_alljump: bool:
	get: return GameManager.alljump


func _ready() -> void:
	_spawn_parent = self
	alljump = game_manager_alljump
	
	WorkerThreadPool.add_task(func():
		_load_level_file_async(current_level)
	)

func _process(_delta: float) -> void:
	if alljump == true and game_manager_alljump == false:
		clear_all_checkpoints()
	alljump = game_manager_alljump

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("addCheckpoint"):
		add_checkpoint(player.position, player.rotation, player.velocity, player.cam.mode, player.cam.global_transform, shiftlocked)
	if Input.is_action_just_pressed("removeCheckpoint"):
		remove_checkpoints()


func _load_level_file_async(path: String) -> void:
	if not FileAccess.file_exists(path):
		print_debug("failed to open file: ", path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0:
		return
		
	var first_byte = file.get_8()
	file.seek(0)
	
	if first_byte == 123 or first_byte == 91: # '{' or '['
		print_debug("Detected format: JSON")
		var json_text = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			call_deferred("_level_from_json", json.data)
	else:
		print_debug("Detected format: binary buffer")
		var raw_bytes = file.get_buffer(file.get_length())
		call_deferred("_level_from_binary", raw_bytes)
	
	GameManager.call_deferred("set", "currentLoadedLevel", path)


func _level_from_json(data: Dictionary) -> void:
	_reset_loader_context()

	var main_folder = data.get("Data")
	if main_folder == null:
		push_error("Missing 'Data' key inside JSON!")
		return
		
	var parts_list = main_folder.get("Children", [])
	
	var container = Node3D.new()
	container.name = "LevelParts"
	_spawn_parent = container
	
	for child in parts_list:
		_spawn_node_json(child)

	add_child(container)
	_spawn_parent = self
	_finalize_spawn_and_reset()

func _spawn_node_json(node_data: Dictionary) -> void:
	var classname = node_data.get("ClassName", "")
	var p = node_data.get("Properties", {})
	
	var is_disabled = node_data.get("disabled", p.get("disabled", false))
	var transparency = clamp(float(node_data.get("Transparency", p.get("Transparency", 0.0))), 0.0, 1.0)
	
	var pos = _json_to_vector3(p.get("Position"))
	var rot = _json_to_vector3(p.get("Rotation"))
	var size = _json_to_vector3(p.get("Size"))
	var color = _json_to_color(p.get("Color"))

	if classname == "Part":
		var shape = node_data.get("Shape", "Block")
		_build_primitive_parts(shape, pos, rot, size, color, is_disabled, transparency)
	elif classname == "Spawn":
		add_part(pos, rot, size, "Spawn", color, is_disabled, transparency)
	elif classname == "Truss":
		add_truss(pos, rot, size, color, is_disabled, transparency)
	elif classname == "Teleporter" or classname == "Destination":
		var tp_id = node_data.get("tpID", "")
		add_part(pos, rot, size, classname, color, is_disabled, transparency, tp_id)
		
	var children = node_data.get("Children", [])
	for child in children:
		_spawn_node_json(child)


func _level_from_binary(raw_bytes: PackedByteArray) -> void:
	_reset_loader_context()
	
	var sp = StreamPeerBuffer.new()
	sp.data_array = raw_bytes
	
	var _obby_name = _read_binary_string(sp)
	var _obby_diff = _read_binary_string(sp)
	var _obby_creator = _read_binary_string(sp)
	
	print_debug("Binary buffer loading: ", _obby_name, " by ", _obby_creator)
	
	var _total_instances = sp.get_u32()
	
	var container = Node3D.new()
	container.name = "LevelParts"
	_spawn_parent = container
	
	var spawned_count = 0
	var MAX_SAFE_INSTANCES = 10000
	
	while sp.get_available_bytes() > 0:
		if spawned_count >= MAX_SAFE_INSTANCES:
			push_error("Reached maximum safe instance limit (", MAX_SAFE_INSTANCES, ")")
			break
			
		if sp.get_available_bytes() < 1:
			push_warning("Parser warning: truncated file stream reading flags")
			break
		# do not move around these unless you restructure the exporter (this follows the order of the exporter layout)
		var flags = sp.get_u8()
		var is_base_part = (flags & 1) != 0
		var is_not_collidable = (flags & 2) != 0
		var has_shape = (flags & 4) != 0
		var is_teleporter = (flags & 8) != 0
		
		var obj_name = _read_binary_string(sp)
		var classname = _read_binary_string(sp)
		var shape = _read_binary_string(sp) if has_shape else "Block"
		var tp_id = _read_binary_string(sp) if is_teleporter else ""
		
		var transparency: float = 0.0
		var pos = Vector3.ZERO
		var size = Vector3.ONE
		var rot = Vector3.ZERO
		var color = Color.WHITE
		
		if is_base_part:
			transparency = sp.get_u8() / 255.0
			pos = _read_binary_vector3(sp)
			size = _read_binary_vector3(sp)
			rot = _read_binary_vector3(sp)
			color = _read_binary_color(sp)
		
		if classname == "Part":
			_build_primitive_parts(shape, pos, rot, size, color, is_not_collidable, transparency)
			spawned_count += 1
		elif classname == "Spawn":
			add_part(pos, rot, size, "Spawn", color, is_not_collidable, transparency)
			spawned_count += 1
		elif classname == "Truss":
			add_truss(pos, rot, size, color, is_not_collidable, transparency)
			spawned_count += 1
		elif classname == "Teleporter" or classname == "Destination":
			add_part(pos, rot, size, classname, color, is_not_collidable, transparency, tp_id)
			spawned_count += 1

	add_child(container)
	_spawn_parent = self
	_finalize_spawn_and_reset()

func _build_primitive_parts(shape: String, pos: Vector3, rot: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	match shape:
		"Cylinder":
			add_cylinder(pos, rot, size, color, is_disabled, transparency)
		"Wedge":
			add_wedge(pos, rot, size, color, is_disabled, transparency)
		"CornerWedge":
			add_cornerwedge(pos, rot, size, color, is_disabled, transparency)
		"Ball":
			add_ball(pos, rot, size, color, is_disabled, transparency)
		_:
			add_part(pos, rot, size, "Part", color, is_disabled, transparency)

func add_part(pos: Vector3, rot_deg: Vector3, size: Vector3, classname: String, color: Color, is_disabled: bool, transparency: float, tp_id: String = "") -> void:
	if part_prefab == null: return
	var new_part = part_prefab.instantiate()
	_spawn_parent.add_child(new_part)
	
	var mesh = new_part.get_node_or_null("MeshInstance3D")
	var coll = new_part.get_node_or_null("CollisionShape3D")
	
	new_part.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	new_part.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	new_part.scale = size
	
	if coll: coll.disabled = is_disabled
	if mesh: texture(mesh, color, transparency)
		
	if classname == "Spawn":
		print("Spawn found at: ", pos)
		spawn_point = new_part
		new_part.name = "Spawn"
		
	elif classname == "Destination":
		new_part.name = "Destination_" + tp_id
		destinations[tp_id] = new_part
		if coll: coll.disabled = true # remove if you want dest collisions

	elif classname == "Teleporter":
		new_part.name = "Teleporter_" + tp_id
		_setup_teleporter_trigger(new_part, coll, tp_id)

func add_cylinder(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	if cylinder_prefab == null: return
	var new_cyl = cylinder_prefab.instantiate()
	_spawn_parent.add_child(new_cyl)
	
	var mesh = new_cyl.get_node_or_null("MeshInstance3D")
	var coll = new_cyl.get_node_or_null("CollisionShape3D")
	
	new_cyl.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	new_cyl.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	new_cyl.scale = Vector3.ONE
	
	var length = size.x
	var radius = min(size.z, size.y) / 2.0
	
	if mesh: mesh.scale = Vector3(radius * 2.0, length / 2.0, radius * 2.0)
		
	if coll and coll.shape is CylinderShape3D:
		var dup_shape = coll.shape.duplicate()
		dup_shape.radius = radius
		dup_shape.height = length
		coll.shape = dup_shape
		coll.disabled = is_disabled
		
	if mesh: texture(mesh, color, transparency)

func add_wedge(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	if wedge_prefab == null: return
	var new_wedge = wedge_prefab.instantiate()
	_spawn_parent.add_child(new_wedge)
	
	var mesh = new_wedge.get_node_or_null("MeshInstance3D")
	var coll = new_wedge.get_node_or_null("CollisionShape3D")
	
	new_wedge.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	var h = max(size.y, 0.001)
	var w = max(size.x, 0.001)
	var l = max(size.z, 0.001)
	
	var origin_vertices = PackedVector3Array([
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, -h/2, l/2), Vector3(w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, -h/2, -l/2), Vector3(-w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, h/2, l/2), Vector3(w/2, -h/2, l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(-w/2, h/2, l/2), Vector3(w/2, h/2, l/2),
		Vector3(-w/2, -h/2, -l/2), Vector3(w/2, h/2, l/2), Vector3(-w/2, h/2, l/2),
		Vector3(-w/2, -h/2, -l/2), Vector3(w/2, -h/2, -l/2), Vector3(w/2, h/2, l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(-w/2, -h/2, -l/2), Vector3(-w/2, h/2, l/2),
		Vector3(w/2, -h/2, l/2), Vector3(w/2, h/2, l/2), Vector3(w/2, -h/2, -l/2)
	])
	
	var final_vertices = PackedVector3Array()
	for v in origin_vertices:
		final_vertices.append(basis * v)
		
	if coll:
		var shape = ConvexPolygonShape3D.new()
		shape.points = final_vertices
		coll.shape = shape
		coll.disabled = is_disabled
		
	if mesh and mesh.mesh:
		var normals = PackedVector3Array()
		for i in range(0, final_vertices.size(), 3):
			var n = (final_vertices[i+2] - final_vertices[i]).cross(final_vertices[i+1] - final_vertices[i]).normalized()
			normals.append(n); normals.append(n); normals.append(n)
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = final_vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.mesh = arr_mesh
		texture(mesh, color, transparency)

func add_cornerwedge(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	if cornerwedge_prefab == null: return
	var new_corner = cornerwedge_prefab.instantiate()
	_spawn_parent.add_child(new_corner)
	
	var mesh = new_corner.get_node_or_null("MeshInstance3D")
	var coll = new_corner.get_node_or_null("CollisionShape3D")
	
	new_corner.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	var h = max(size.y, 0.001)
	var w = max(size.x, 0.001)
	var l = max(size.z, 0.001)
	
	var origin_vertices = PackedVector3Array([
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2, -h/2,  l/2), Vector3( w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2, -h/2, -l/2), Vector3(-w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2, -l/2), Vector3( w/2, -h/2, -l/2), Vector3( w/2,  h/2, -l/2),
		Vector3(-w/2, -h/2,  l/2), Vector3(-w/2, -h/2, -l/2), Vector3( w/2,  h/2, -l/2),
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2,  h/2, -l/2), Vector3( w/2, -h/2,  l/2),
		Vector3( w/2, -h/2,  l/2), Vector3( w/2,  h/2, -l/2), Vector3( w/2, -h/2, -l/2)
	])
	
	var final_vertices = PackedVector3Array()
	for v in origin_vertices:
		final_vertices.append(basis * v)
		
	if coll:
		var shape = ConvexPolygonShape3D.new()
		shape.points = final_vertices
		coll.shape = shape
		coll.disabled = is_disabled
		
	if mesh and mesh.mesh:
		var normals = PackedVector3Array()
		for i in range(0, final_vertices.size(), 3):
			var n = (final_vertices[i+2] - final_vertices[i]).cross(final_vertices[i+1] - final_vertices[i]).normalized()
			normals.append(n); normals.append(n); normals.append(n)
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = final_vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.mesh = arr_mesh
		texture(mesh, color, transparency)

func add_ball(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	if ball_prefab == null: return
	var new_ball = ball_prefab.instantiate()
	_spawn_parent.add_child(new_ball)
	
	var mesh = new_ball.get_node_or_null("MeshInstance3D")
	var coll = new_ball.get_node_or_null("CollisionShape3D")
	
	new_ball.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	new_ball.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	var radius = max(size.x, max(size.y, size.z)) / 2.0
	
	if coll and coll.shape is SphereShape3D:
		var dup_shape = coll.shape.duplicate()
		dup_shape.radius = radius
		coll.shape = dup_shape
		coll.disabled = is_disabled
		
	if mesh:
		var diameter = radius * 2.0
		mesh.scale = Vector3(diameter, diameter, diameter)
		texture(mesh, color, transparency)

func add_truss(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	if truss_prefab == null: return
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	var seg_h = 2.0
	var max_length = size.y
	var local_axis = Vector3.UP
	
	if size.x > size.y and size.x > size.z:
		max_length = size.x
		local_axis = Vector3.RIGHT
	elif size.z > size.y and size.z > size.x:
		max_length = size.z
		local_axis = Vector3.FORWARD
		
	var num_segments = max(1, int(floor(max_length / seg_h)))
	
	for i in range(num_segments):
		var new_truss = truss_prefab.instantiate()
		add_child(new_truss)
		
		var offset_scalar = -max_length / 2.0 + (i * seg_h) + (seg_h / 2.0)
		new_truss.position = pos + (basis * (local_axis * offset_scalar))
		new_truss.transform.basis = basis
		
		var coll = new_truss.get_node_or_null("CollisionShape3D")
		if coll and coll.shape is BoxShape3D:
			var dup_shape = coll.shape.duplicate()
			if local_axis == Vector3.UP: dup_shape.size = Vector3(size.x, seg_h, size.z)
			elif local_axis == Vector3.RIGHT: dup_shape.size = Vector3(seg_h, size.y, size.z)
			else: dup_shape.size = Vector3(size.x, size.y, seg_h)
			coll.shape = dup_shape
			coll.disabled = is_disabled
			
		var mesh_node = new_truss.get_node_or_null("Cube_016")
		if mesh_node and opaque_shader != null:
			texture(mesh_node,color,transparency)

	var physical_collider = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape_volume = BoxShape3D.new()
	box_shape_volume.size = size
	
	collision_shape.shape = box_shape_volume
	collision_shape.disabled = is_disabled
	
	physical_collider.add_child(collision_shape)
	physical_collider.add_to_group("climbable")
	_spawn_parent.add_child(physical_collider)
	
	physical_collider.position = pos
	physical_collider.transform.basis = basis

func texture(mesh_instance: MeshInstance3D, color: Color, transparency: float = 0.0) -> void:
	if mesh_instance == null: return
	
	var key = str(color) + "_" + str(roblox_studs) + "_" + str(transparency)
	if _material_cache.has(key):
		mesh_instance.material_override = _material_cache[key]
	else:
		var mat = ShaderMaterial.new()
		mat.shader = transparent_shader if transparency > 0.0 else opaque_shader
		
		var texture = roblox_tile if roblox_studs else default_tile
		var trans_value = 0.0 if roblox_studs else 0.75
		var overlay_mode = roblox_studs
		
		mat.set_shader_parameter("albedo_texture", texture)
		mat.set_shader_parameter("transparency", trans_value)
		mat.set_shader_parameter("use_overlay_mode", overlay_mode)
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("part_transparency", transparency)
		
		_material_cache[key] = mat
		mesh_instance.material_override = mat

# binary conversions
func _read_binary_string(sp: StreamPeerBuffer) -> String:
	if sp.get_available_bytes() < 1: # stops if stream empty
		push_warning("Parser warning : unexpected end of file reading string length.")
		return ""
		
	var length = sp.get_u8() # gets the first byte
	if length == 0: 
		return ""
	
	# max 300 character limit for names
	if length > 300:
		push_error("String length is too large")
		return ""
	
	if sp.get_available_bytes() < length:
		push_error("File ended before string could be fully read.")
		return ""
	
	var string_bytes = sp.get_data(length) # gets the string length in bytes
	if string_bytes[0] != OK:
		return ""
	
	return (string_bytes[1] as PackedByteArray).get_string_from_utf8() # converts the string bytes into letters

func _read_binary_vector3(sp: StreamPeerBuffer) -> Vector3:
	if sp.get_available_bytes() < 12:
		push_error("Not enough bytes left to parse Vector3.")
		return Vector3.ZERO
		
	var x = sp.get_float()
	var y = sp.get_float()
	var z = sp.get_float()
	return Vector3(x, y, z)

func _read_binary_color(sp: StreamPeerBuffer) -> Color:
	var r = sp.get_u8() / 255.0
	var g = sp.get_u8() / 255.0
	var b = sp.get_u8() / 255.0
	return Color(r, g, b)


# JSON conversions
func _json_to_vector3(d: Variant) -> Vector3:
	if typeof(d) == TYPE_ARRAY and d.size() >= 3:
		return Vector3(float(d[0]), float(d[1]), float(d[2]))
	elif typeof(d) == TYPE_DICTIONARY:
		var x = float(d.get("X", 0.0))
		var y = float(d.get("Y", 0.0))
		var z = float(d.get("Z", 0.0))
		return Vector3(x, y, z)
	return Vector3.ZERO

func _json_to_color(d: Variant) -> Color:
	if typeof(d) == TYPE_STRING:
		return Color.from_string(d, Color.WHITE)
	elif typeof(d) == TYPE_DICTIONARY:
		var r = float(d.get("R", 1.0))
		var g = float(d.get("G", 1.0))
		var b = float(d.get("B", 1.0))
		return Color(r, g, b)
	return Color.WHITE

func _setup_teleporter_trigger(part: Node3D, solid_collider: CollisionShape3D, tp_id: String) -> void:
	if solid_collider:
		solid_collider.disabled = true

	var area = Area3D.new()
	part.add_child(area)

	if solid_collider:
		var trigger_collider = solid_collider.duplicate()
		trigger_collider.disabled = false
		area.add_child(trigger_collider)

	area.body_entered.connect(func(body):
		if body == player or body.is_in_group("player") or body is CharacterBody3D:
			_teleport_player_to_id(body, tp_id)
	)

func _teleport_player_to_id(player_body: Node3D, tp_id: String) -> void:
	if destinations.has(tp_id):
		var dest_node = destinations[tp_id]
		if player_body.has_method("_handle_teleportation"):
			player_body.call("_handle_teleportation", dest_node.global_position, dest_node.global_rotation)
		else:
			player_body.global_position = dest_node.global_position
	else:
		push_warning("Teleporter with tpID '" + tp_id + "' entered but no matching Destination was found")

# --- CHECKPOINT HANDLING---
func _reset_loader_context() -> void:
	spawn_point = null
	_material_cache.clear()
	destinations.clear()

func _finalize_spawn_and_reset() -> void:
	print_debug("Level loaded. Spawn = ", spawn_point)
	if spawn_point != null:
		if player:
			player.set("spawn", spawn_point)
			if player.has_method("reset"):
				player.call("reset")
	else:
		push_warning("NO SPAWN FOUND IN LEVEL")

func add_checkpoint(pos: Vector3, rot: Vector3, vel: Vector3, cam_mode: int, cam_transform: Transform3D, shiftlock: bool) -> void:
	if game_manager_alljump:
		if checkpoint_prefab == null: return
		var new_cp = checkpoint_prefab.instantiate()
		new_cp.set_meta("saved_velocity", vel)
		new_cp.set_meta("camera_mode", cam_mode)
		new_cp.set_meta("camera_transform", cam_transform)
		new_cp.set_meta("shiftlocked", shiftlock)
		
		add_child(new_cp)
		new_cp.position = pos
		new_cp.rotation = rot
		checkpoints.append(new_cp)
		spawn_point = new_cp
		
		if player:
			player.set("spawn", new_cp)
		print_debug("Player spawn successfully updated to checkpoint!")

func remove_checkpoints() -> void:
	if checkpoints.size() > 0:
		var latest_checkpoint = checkpoints.pop_back()
		if is_instance_valid(latest_checkpoint):
			latest_checkpoint.queue_free()
			
	if checkpoints.size() > 0:
		var active_checkpoint = checkpoints.back()
		if is_instance_valid(active_checkpoint):
			spawn_point = active_checkpoint
			if player:
				player.set("spawn", active_checkpoint)
	else:
		var original_spawn = get_node_or_null("LevelParts/Spawn")
		if original_spawn != null:
			spawn_point = original_spawn
			if player:
				player.set("spawn", original_spawn)
func clear_all_checkpoints() -> void:
	while checkpoints.size() > 0:
		remove_checkpoints()
