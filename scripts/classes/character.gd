extends Node3D
class_name CharacterAvatarMesh

# These relative paths point exactly to its own local bone attachment children
@onready var head_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/head/Head
@onready var torso_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/torso/Torso
@onready var left_arm_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/leftarm/LeftArm
@onready var right_arm_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/rightarm/RightArm
@onready var left_leg_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/leftleg/LeftLeg
@onready var right_leg_mesh: MeshInstance3D = $ObbyAvatar/Skeleton3D/rightleg/RightLeg

func _ready() -> void:
	apply_saved_colors()

func apply_saved_colors() -> void:
	if GameManager and GameManager.data and GameManager.data.body_colors:
		update_part_color("head", GameManager.data.body_colors.get("head", Color.WHITE))
		update_part_color("torso", GameManager.data.body_colors.get("torso", Color.WHITE))
		update_part_color("left_arm", GameManager.data.body_colors.get("left_arm", Color.WHITE))
		update_part_color("right_arm", GameManager.data.body_colors.get("right_arm", Color.WHITE))
		update_part_color("left_leg", GameManager.data.body_colors.get("left_leg", Color.WHITE))
		update_part_color("right_leg", GameManager.data.body_colors.get("right_leg", Color.WHITE))

func update_part_color(part_name: String, new_color: Color) -> void:
	var target_mesh: MeshInstance3D = null
	
	match part_name.to_lower():
		"head": target_mesh = head_mesh
		"torso": target_mesh = torso_mesh
		"left_arm": target_mesh = left_arm_mesh
		"right_arm": target_mesh = right_arm_mesh
		"left_leg": target_mesh = left_leg_mesh
		"right_leg": target_mesh = right_leg_mesh
		
	if not target_mesh: return
	
	# Override to setup new colors
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.7
	mat.albedo_color = new_color
	
	target_mesh.material_override = mat
