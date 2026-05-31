extends Control

@onready var Part = preload("res://assets/prefabs/building/Parts/Part.tscn")
@onready var Cylinder = preload("res://assets/prefabs/building/Parts/cylinder.tscn")
@onready var Truss = preload("res://assets/prefabs/building/Parts/Truss.tscn")
@onready var Sphere = preload("res://assets/prefabs/building/Parts/ball.tscn")
@onready var Wedge = preload("res://assets/prefabs/building/Parts/wedge.tscn")
@onready var CornerWedge = preload("res://assets/prefabs/building/Parts/cornerwedge.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# ------ handles object spawning -------

func spawn_object(prefab: PackedScene) -> void:
	var camera = get_viewport().get_camera_3d()
	var forward_direction = -camera.global_transform.basis.z.normalized()
	var spawn_position = camera.global_position + (forward_direction * 5.0)
	var instances_node = get_tree().current_scene.find_child("Instances", true, false)
	var instance = prefab.instantiate() as Node3D
	if instance:
		instance.global_position = spawn_position
		instances_node.add_child(instance)
	
func _on_part_pressed() -> void:
	spawn_object(Part)


func _on_cylinder_pressed() -> void:
	spawn_object(Cylinder)


func _on_truss_pressed() -> void:
	spawn_object(Truss)


func _on_sphere_pressed() -> void:
	spawn_object(Sphere)


func _on_wedge_pressed() -> void:
	spawn_object(Wedge)


func _on_cornerwedge_pressed() -> void:
	spawn_object(CornerWedge)
