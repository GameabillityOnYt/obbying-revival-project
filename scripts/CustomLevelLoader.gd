extends Node3D

@onready var part = preload("res://assets/prefabs/building/Parts/Part.tscn")
@onready var cylinder = preload("res://assets/prefabs/building/Parts/cylinder.tscn")
@onready var wedge = preload("res://assets/prefabs/building/Parts/wedge.tscn")
@onready var cornerwedge = preload("res://assets/prefabs/building/Parts/cornerwedge.tscn")
@onready var ball = preload("res://assets/prefabs/building/Parts/ball.tscn")
@onready var truss = preload("res://assets/prefabs/building/Parts/Truss.tscn")
@onready var player = $Player

@onready var default_tile = preload("res://assets/images/textures/orp_brick_updated.png")
@onready var roblox_tile = preload("res://assets/images/textures/RobloxTile.png")

@onready var opaque_shader = preload("res://assets/resources/shaders/TextureRepeating.gdshader")
@onready var transparent_shader = preload("res://assets/resources/shaders/part_transparent.gdshader")

# alljump
@onready var level = preload("res://custom.tscn")
@onready var checkpoint = preload("res://assets/prefabs/models/checkpoint.tscn")
var checkpoints = []
var spawn_point: Node3D = null
var alljump: bool = false

var _spawn_parent: Node3D = self
var _material_cache = {}

# ==========================================
# Core engine loops
# ==========================================
func _ready() -> void:
	alljump = GameManager.alljump
	
	WorkerThreadPool.add_task(func():
		var leveldata = load_level(GameManager.currentLevel)
		GameManager.currentLoadedLevel = GameManager.currentLevel
		if leveldata == null:
			return

		call_deferred("_finalize_loading", leveldata)
	)

func _process(_delta: float) -> void:
	if alljump == true and GameManager.alljump == false:
		remove_checkpoints()
		
	alljump = GameManager.alljump

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("addCheckpoint"):
		add_checkpoint(player.position, player.rotation, player.velocity, player.cam.mode, player.cam.global_transform, GameManager.shiftlocked)
	if Input.is_action_just_pressed("removeCheckpoint"):
		remove_last_checkpoint()

# ==========================================
# Checkpoint handling
# ==========================================

func add_checkpoint(pos: Vector3, rot: Vector3, vel: Vector3, cam_mode: int, cam_transform: Transform3D, shiftlock: bool):
	if GameManager.alljump:
		var newcheckpoint = checkpoint.instantiate()
		newcheckpoint.set_meta("saved_velocity", vel)
		
		newcheckpoint.set_meta("camera_mode", cam_mode)
		newcheckpoint.set_meta("camera_transform", cam_transform)
		newcheckpoint.set_meta("shiftlocked", shiftlock)
		
		add_child(newcheckpoint)
		newcheckpoint.position = pos
		newcheckpoint.rotation = rot
		checkpoints.append(newcheckpoint)
		spawn_point = newcheckpoint
		
		if player == null: await GameManager.CharacterAdded
		player.spawn = newcheckpoint
		print_debug("Player spawn successfully updated to checkpoint!")


func remove_checkpoints():
	for cp in checkpoints:
		if is_instance_valid(cp):
			cp.queue_free()
			
	checkpoints.clear()
	
	var original_spawn = get_node_or_null("LevelParts/Spawn") 
	if original_spawn:
		spawn_point = original_spawn
		player.spawn = original_spawn


func remove_last_checkpoint():
	if checkpoints.is_empty():
		return

	var last_checkpoint = checkpoints.pop_back() 

	if is_instance_valid(last_checkpoint):
		last_checkpoint.queue_free()

	if not checkpoints.is_empty():
		var previous_checkpoint = checkpoints[-1] 
		spawn_point = previous_checkpoint
		
		if player != null:
			player.spawn = previous_checkpoint
	else:
		var original_spawn = get_node_or_null("LevelParts/Spawn")
		spawn_point = original_spawn
		
		if player != null:
			player.spawn = original_spawn

# ==========================================
# Part specifications
# ==========================================

func stud_texture(mesh_instance: MeshInstance3D, color: Color, base_mat: Material, transparency: float = 0.0):
	if mesh_instance and base_mat:
		var key = str(color) + "_" + str(GameManager.RobloxStuds) + "_" + str(transparency)
		if _material_cache.has(key):
			mesh_instance.material_override = _material_cache[key]
		else:
			var mat = base_mat.duplicate() as ShaderMaterial
			if transparency > 0.0:
				mat.shader = transparent_shader
			else:
				mat.shader = opaque_shader
			
			var texture: Texture2D
			var trans: float
			var overlay: bool
			
			if GameManager.RobloxStuds:
				texture = roblox_tile
				trans = 0.0
				overlay = true
			else:
				texture = default_tile
				trans = 0.75
				overlay = false 
			
			mat.set_shader_parameter("albedo_texture", texture)
			mat.set_shader_parameter("transparency", trans)
			mat.set_shader_parameter("use_overlay_mode", overlay)
			mat.set_shader_parameter("base_color", color)
			mat.set_shader_parameter("part_transparency", transparency)
			
			_material_cache[key] = mat
			mesh_instance.material_override = mat


func add_part(pos, rot_deg, size, classname, color, is_disabled, transparency):
	var newpart = part.instantiate()
	_spawn_parent.add_child(newpart)
	
	var mesh = newpart.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newpart.get_node("CollisionShape3D")
	
	newpart.position = pos
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	newpart.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	# performance fix; scale instead of duplicating since we are using the same .tscn
	newpart.scale = size
	if coll:
		coll.disabled = is_disabled
	if mesh and mesh.mesh and mesh.mesh.material:
		stud_texture(mesh, color, mesh.mesh.material, transparency)

	if classname == "Spawn":
		print_debug("Spawn found at:", pos)
		spawn_point = newpart
		newpart.name = "Spawn"


func add_cylinder(pos, rot_deg, size, color, is_disabled, transparency):
	var newcyl = cylinder.instantiate()
	_spawn_parent.add_child(newcyl)
	var mesh = newcyl.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newcyl.get_node("CollisionShape3D") as CollisionShape3D
	
	newcyl.position = pos
	var rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	newcyl.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	newcyl.scale = Vector3.ONE
	
	var length = size.x
	var radius = min(size.z, size.y) / 2.0
	
	# scale only mesh to avoid jolt physics error 
	if mesh:
		mesh.scale = Vector3(radius * 2.0, length / 2.0, radius * 2.0)
	
	if coll and coll.shape:
		coll.shape = coll.shape.duplicate() # only duplicate coll shape
		coll.shape.radius = radius
		coll.shape.height = length
		coll.disabled = is_disabled
		
	if mesh and mesh.mesh and mesh.mesh.material:
		stud_texture(mesh, color, mesh.mesh.material, transparency)

func add_wedge(pos, rot_deg, size, color, is_disabled, transparency):
	var newwedge = wedge.instantiate()
	_spawn_parent.add_child(newwedge)
	var mesh = newwedge.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newwedge.get_node("CollisionShape3D")
	newwedge.position = pos
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	# transforming the vertices of the origin to the player's vertices
	var basis_ = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)

	var h = max(size.y, 0.001)
	var w = max(size.x, 0.001)
	var l = max(size.z, 0.001)
	# need this to map each of the vertices individually
	var origin_vertices = PackedVector3Array([
		# bottom face
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, -h/2, l/2), Vector3(w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, -h/2, -l/2), Vector3(-w/2, -h/2, -l/2),
		# back face
		Vector3(-w/2, -h/2, l/2), Vector3(w/2, h/2, l/2), Vector3(w/2, -h/2, l/2),
		Vector3(-w/2, -h/2, l/2), Vector3(-w/2, h/2, l/2), Vector3(w/2, h/2, l/2),
		# slope face
		Vector3(-w/2, -h/2, -l/2), Vector3(w/2, h/2, l/2), Vector3(-w/2, h/2, l/2),
		Vector3(-w/2, -h/2, -l/2), Vector3(w/2, -h/2, -l/2), Vector3(w/2, h/2, l/2),
		# left face
		Vector3(-w/2, -h/2, l/2), Vector3(-w/2, -h/2, -l/2), Vector3(-w/2, h/2, l/2),
		# right face
		Vector3(w/2, -h/2, l/2), Vector3(w/2, h/2, l/2), Vector3(w/2, -h/2, -l/2),
	])
	var final_vertices = PackedVector3Array()
	for vert in origin_vertices:
		final_vertices.append(basis_ * vert)
		
	if coll.shape:
		var shape = ConvexPolygonShape3D.new()
		shape.points = final_vertices
		coll.shape = shape
		coll.disabled = is_disabled
		
	var normals = PackedVector3Array()
	for i in range(0, final_vertices.size(), 3):
		var n = (final_vertices[i + 2] - final_vertices[i]).cross(
			final_vertices[i + 1] - final_vertices[i]).normalized()
		normals.append(n)
		normals.append(n)
		normals.append(n)
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	if mesh.mesh.material:
		var base_mat = mesh.mesh.material
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.mesh = arr_mesh
		stud_texture(mesh, color, base_mat, transparency)


func add_corner_wedge(pos, rot_deg, size, color, is_disabled, transparency):
	var newcornerwedge = cornerwedge.instantiate()
	_spawn_parent.add_child(newcornerwedge)
	var mesh = newcornerwedge.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newcornerwedge.get_node("CollisionShape3D")
	newcornerwedge.position = pos
	
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	# transforming the vertices of the origin to the player's vertices
	var basis_ = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	var h = max(size.y, 0.001)
	var w = max(size.x, 0.001)
	var l = max(size.z, 0.001)
	# need this to map each of the vertices individually
	var origin_vertices = PackedVector3Array([
		# bottom face
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2, -h/2,  l/2), Vector3( w/2, -h/2, -l/2),
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2, -h/2, -l/2), Vector3(-w/2, -h/2, -l/2),
		# back face
		Vector3(-w/2, -h/2, -l/2), Vector3( w/2, -h/2, -l/2), Vector3( w/2,  h/2, -l/2),
		# left face
		Vector3(-w/2, -h/2,  l/2), Vector3(-w/2, -h/2, -l/2), Vector3( w/2,  h/2, -l/2),
		# slope face
		Vector3(-w/2, -h/2,  l/2), Vector3( w/2,  h/2, -l/2), Vector3( w/2, -h/2,  l/2),
		# right face
		Vector3( w/2, -h/2,  l/2), Vector3( w/2,  h/2, -l/2), Vector3( w/2, -h/2, -l/2),
	])
	var final_vertices = PackedVector3Array()
	for vert in origin_vertices:
		final_vertices.append(basis_ * vert)
	
	if coll.shape:
		var shape = ConvexPolygonShape3D.new()
		shape.points = final_vertices
		coll.shape = shape
		coll.disabled = is_disabled
		
	var normals = PackedVector3Array()
	for i in range(0, final_vertices.size(), 3):
		var n = (final_vertices[i + 2] - final_vertices[i]).cross(
			final_vertices[i + 1] - final_vertices[i]).normalized()
		normals.append(n)
		normals.append(n)
		normals.append(n)
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	if mesh.mesh.material:
		var base_mat = mesh.mesh.material
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.mesh = arr_mesh
		stud_texture(mesh, color, base_mat, transparency)
	

func add_ball(pos, rot_deg, size, color, is_disabled, transparency):
	var newball = ball.instantiate()
	_spawn_parent.add_child(newball)
	var mesh = newball.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newball.get_node("CollisionShape3D")
	
	newball.position = pos
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	newball.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_XYZ)
	
	if coll and coll.shape:
		coll.shape = coll.shape.duplicate()
		var shape = coll.shape as SphereShape3D
		if shape:
			shape.radius = max(size.x, max(size.y, size.z)) / 2.0
		coll.disabled = is_disabled
	if mesh:
		var ball_radius = max(size.x, max(size.y, size.z)) / 2.0
		var ball_diameter = ball_radius * 2.0
		mesh.scale = Vector3(ball_diameter, ball_diameter, ball_diameter)
				
		if mesh.mesh and mesh.mesh.material:
			stud_texture(mesh, color, mesh.mesh.material, transparency)

func add_truss(pos: Vector3, rot_deg: Vector3, size: Vector3, color: Color, is_disabled: bool, transparency: float) -> void:
	var basis_ = Basis.from_euler(Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)), EULER_ORDER_XYZ)

	var seg_h: float = 2.0
	var max_length: float = size.y
	var local_axis: Vector3 = Vector3.UP

	if size.x > size.y && size.x > size.z:
		max_length = size.x
		local_axis = Vector3.RIGHT
	elif size.z > size.y && size.z > size.x:
		max_length = size.z
		local_axis = Vector3.FORWARD

	var num_segments: int = maxi(1, int(floor(max_length / seg_h)))

	# Make one single invisible collision parent for the entire truss
	var truss_root = StaticBody3D.new()
	truss_root.position = pos
	truss_root.transform.basis = basis_
	truss_root.add_to_group("climbable")
	_spawn_parent.add_child(truss_root)

	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.disabled = is_disabled
	truss_root.add_child(collision_shape)

	var dummy = truss.instantiate()
	var mesh_node = dummy.get_node_or_null("Cube_016") as MeshInstance3D
	if not mesh_node:
		dummy.queue_free()
		return
		
	var base_mesh = mesh_node.mesh
	var mesh_internal_transform = mesh_node.transform 
	var base_mat = mesh_node.material_override.duplicate() as ShaderMaterial
	
	if base_mat:
		if transparency > 0.0:
			base_mat.shader = transparent_shader
		else:
			base_mat.shader = opaque_shader
		base_mat.set_shader_parameter("base_color", color)
		base_mat.set_shader_parameter("part_transparency", transparency)
	
	dummy.queue_free()

	# Set up a MultiMesh instance so the computer can draw all segments in one single batch
	var multimesh_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = base_mesh
	mm.instance_count = num_segments
	
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = base_mat
	truss_root.add_child(multimesh_instance)

	for i in range(num_segments):
		var offset_scalar = -max_length / 2.0 + (i * seg_h) + (seg_h / 2.0)
		var local_pos = local_axis * offset_scalar
		
		var segment_transform = Transform3D(Basis.IDENTITY, local_pos) * mesh_internal_transform
		mm.set_instance_transform(i, segment_transform)

# ==========================================
# Loading handling
# ==========================================

func load_level(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print_debug("failed to open file:", path)
		return null

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print_debug("invalid json:", path)
		return null

	return json.data

func load_stuff(data):
	spawn_point = null

	print_debug("Loading level...")
	var main_folder = data.get("Data")
	if main_folder == null:
		push_error("Missing 'Data' key inside JSON!")
		return
	var parts_list = main_folder.get("Children", [])
	
	_material_cache.clear()
	var container = Node3D.new()
	container.name = "LevelParts"
	_spawn_parent = container
	
	for child in parts_list:
		spawn_node(child)

	add_child(container)
	_spawn_parent = self

	print_debug("Level loaded. Spawn =", spawn_point)
	
func _finalize_loading(leveldata):
	load_stuff(leveldata)

	if spawn_point != null:
		player.spawn = spawn_point
		player.reset()
	else:
		push_warning("NO SPAWN FOUND IN LEVEL")

# ==========================================
# Helper functions
# ==========================================

func to_vec3(d):
	if d == null:
		return Vector3.ZERO
	
	# New format
	if d is Array and d.size() >= 3:
		return Vector3(d[0], d[1], d[2])
		
	# Old format for compatibility
	if d is Dictionary:
		return Vector3(d.get("X", 0.0), d.get("Y", 0.0), d.get("Z", 0.0))
		
	return Vector3.ZERO

func to_color(d):
	if d == null:
		return Color.WHITE
		
	# New format (hex)
	if d is String:
		return Color.from_string(d, Color.WHITE)
		
	# Old format (dictionary lol holy unoptimized hooollyyyy)
	if d is Dictionary:
		return Color(d.get("R", 1.0), d.get("G", 1.0), d.get("B", 1.0))
		
	return Color.WHITE


func spawn_node(node_data):
	var classname : String = node_data.get("ClassName", "")
	var p : Dictionary = node_data.get("Properties", {})
	
	var is_disabled : bool = node_data.get("disabled", p.get("disabled", false))
	var transparency : float = clamp(node_data.get("Transparency", p.get("Transparency", 0.0)), 0.0, 1.0)
	
	var pos = to_vec3(p.get("Position"))
	var rot = to_vec3(p.get("Rotation"))
	var size = to_vec3(p.get("Size"))
	var color = to_color(p.get("Color"))
	
	if classname == "Part":
		var shape: String = node_data.get("Shape", "Block")
		if shape == "Block":
			add_part(pos, rot, size, "Part", color, is_disabled, transparency)
		elif shape == "Cylinder":
			add_cylinder(pos, rot, size, color, is_disabled, transparency)
		elif shape == "Wedge":
			add_wedge(pos, rot, size, color, is_disabled, transparency)
		elif shape == "CornerWedge":
			add_corner_wedge(pos, rot, size, color, is_disabled, transparency)
		elif shape == "Ball":
			add_ball(pos, rot, size, color, is_disabled, transparency)
		else:
			add_part(pos, rot, size, "Part", color, is_disabled, transparency)
			
	elif classname == "Spawn":
		add_part(pos, rot, size, "Spawn", color, is_disabled, transparency)
		
	elif classname == "Truss":
		add_truss(pos, rot, size, color, is_disabled, transparency)
			
	var children: Array = node_data.get("Children", [])
	if not children.is_empty():
		for child in children:
			if child is Dictionary:
				spawn_node(child)
