extends Node3D

@onready var part = preload("res://assets/prefabs/building/Old/Part.tscn")
@onready var truss = preload("res://assets/prefabs/building/Old/Truss.tscn")
@onready var player = $Player


# alljump
@onready var level = preload("res://custom.tscn")
@onready var checkpoint = preload("res://assets/prefabs/models/checkpoint.tscn")
var checkpoints = []
var spawn_point: Node3D = null

func load_level(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("failed to open file:", path)
		return null

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("invalid json:", path)
		return null

	return json.data



func addCheckpoint(pos: Vector3, rot: Vector3, vel: Vector3, cam_mode: int, cam_transform: Transform3D, shiftlock: bool):
	if GameManager.alljump:
		var newcheckpoint = checkpoint.instantiate()
		newcheckpoint.set_meta("saved_velocity", vel)
		
		newcheckpoint.set_meta("camera_mode", cam_mode)
		newcheckpoint.set_meta("camera_transform", cam_transform)
		newcheckpoint.set_meta("shiftlocked", shiftlock)
		
		add_child(newcheckpoint)
		newcheckpoint.position = pos + Vector3(0,1,0)
		newcheckpoint.rotation = rot
		checkpoints.append(newcheckpoint)
		spawn_point = newcheckpoint
		
		if player == null: await GameManager.CharacterAdded
		player.spawn = newcheckpoint
		print("Player spawn successfully updated to checkpoint!")

func removeCheckpoints():
	for cp in checkpoints:
		if is_instance_valid(cp):
			cp.queue_free()
			
	checkpoints.clear()
	
	var original_spawn = get_node_or_null("Spawn") 
	if original_spawn:
		spawn_point = original_spawn
		player.spawn = original_spawn

func removeLastCheckpoint():
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
		var original_spawn = get_node_or_null("Spawn")
		spawn_point = original_spawn
		
		if player != null:
			player.spawn = original_spawn

func to_vec3(d):
	if d == null:
		return Vector3.ZERO
	return Vector3(d.get("X", 0), d.get("Y", 0), d.get("Z", 0))


func to_color(d):
	if d == null:
		return Color.WHITE
	return Color(d.get("R", 1), d.get("G", 1), d.get("B", 1))


func addPart(pos, rot_deg, size, classname, color):
	var newpart = part.instantiate()
	add_child(newpart)
	var mesh = newpart.get_node("MeshInstance3D") as MeshInstance3D
	var coll = newpart.get_node("CollisionShape3D")
	newpart.position = pos
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	newpart.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_ZXY)
	if coll.shape:
		coll.shape = coll.shape.duplicate() 
		var shape = coll.shape as BoxShape3D
		if shape:
			shape.size = size
	if mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()
		var box_mesh = mesh.mesh as BoxMesh
		if box_mesh:
			box_mesh.size = size
			
		if mesh.mesh.material:
			mesh.mesh.material = mesh.mesh.material.duplicate()
			mesh.mesh.material.set_shader_parameter("base_color", color)

	if classname == "Spawn":
		print("Spawn found at:", pos)
		spawn_point = newpart
		newpart.name = "Spawn"


func addTruss(pos, rot_deg, size, _classname):
	var newtruss = truss.instantiate()
	add_child(newtruss)

	var _mesh = newtruss.get_node("Truss/trusss")
	var coll = newtruss.get_node("Truss/CollisionShape3D")
	newtruss.position = pos
	var rot_rad = Vector3(
		deg_to_rad(rot_deg.x),
		deg_to_rad(rot_deg.y),
		deg_to_rad(rot_deg.z)
	)
	newtruss.transform.basis = Basis.from_euler(rot_rad, EULER_ORDER_ZXY)
	if coll.shape:
		coll.shape = coll.shape.duplicate()
		var shape = coll.shape as BoxShape3D
		if shape:
			shape.size = size

func spawn_node(node_data):
	var classname = node_data.get("ClassName", "")

	if classname == "Part":
		var p = node_data.get("Properties", {})
		addPart(
			to_vec3(p.get("Position")),
			to_vec3(p.get("Rotation")),
			to_vec3(p.get("Size")),
			"Part",
			to_color(p.get("Color"))
		)

	elif classname == "Spawn":
		var p = node_data.get("Properties", {})
		addPart(
			to_vec3(p.get("Position")),
			to_vec3(p.get("Rotation")),
			to_vec3(p.get("Size")),
			"Spawn",
			to_color(p.get("Color"))
		)
	elif classname == "Truss":
		var p = node_data.get("Properties", {})
		addTruss(
			to_vec3(p.get("Position")),
			to_vec3(p.get("Rotation")),
			to_vec3(p.get("Size")),
			"Truss"
		)

	for child in node_data.get("Children", []):
		spawn_node(child)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("addCheckpoint"):
		addCheckpoint(player.position, player.rotation, player.velocity, player.cam.mode, player.cam.global_transform, GameManager.shiftlocked)
	if Input.is_action_just_pressed("removeCheckpoint"):
		removeLastCheckpoint()


func loadstuff(data):
	spawn_point = null

	print("Loading level...")
	var main_folder = data.get("Data")
	if main_folder == null:
		push_error("Missing 'Data' key inside JSON!")
		return
	var parts_list = main_folder.get("Children", [])
	for child in parts_list:
		spawn_node(child)

	print("Level loaded. Spawn =", spawn_point)



func _ready() -> void:
	var leveldata = load_level(GameManager.currentLevel)

	if leveldata == null:
		return

	loadstuff(leveldata)


	if spawn_point != null:
		player.spawn = spawn_point
		player.reset()
	else:
		push_warning("NO SPAWN FOUND IN LEVEL")
