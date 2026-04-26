extends RigidBody3D
class_name PlayerClass

const SPEED = 4
const JUMP_VELOCITY = 7.5

var follow_camera:bool :
	get():
		return cam.mode == cam.CameraMode.FIRSTPERSON or GameManager.shiftlocked
@onready var cam = $Camera3D

@export var HealthBar: ProgressBar

@onready var LegCasts = get_node("LegCasts").get_children()
var grounded = false
@export var ground_dist:float = 0

# health shit idk
@export var MaxHealth := 100.0
var Health := 100.0 : 
	set(new):
		Health = clamp(new,0,MaxHealth)
		update_health_bar()

func update_health_bar():
	if HealthBar:
		HealthBar.value = (Health / MaxHealth) * 100

func _ready():
	$Camera3D.top_level = true

func _ground_check():
	var shortest = INF
	var found_ground = false
	for legcast: RayCast3D in LegCasts:
		if legcast.is_colliding():
			found_ground = true
			shortest = min(shortest,legcast.get_collision_point().distance_to(legcast.global_position))
	grounded = found_ground
	ground_dist = shortest if shortest != INF else 0

func _physics_process(_delta: float) -> void:
	$HeadCollision.global_transform = $Character/ObbyAvatar/Skeleton3D/head/HeadCollision.global_transform
	$TorsoCollision.global_transform = $Character/ObbyAvatar/Skeleton3D/torso/TorsoCollision.global_transform
	_ground_check()
	
	if follow_camera:
		var target_y = cam.global_rotation.y + PI
		var rot_diff = wrapf(target_y - global_rotation.y, -PI, PI)
		var kP = 2000
		var kD = 10
		
		var torque_y = (rot_diff * kP) - (angular_velocity.y * kD)
		
		apply_torque(Vector3(0,torque_y * 20.0,0))
