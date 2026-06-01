extends RigidBody3D
class_name PlayerClass

var rotation_locked:bool :
	get():
		return cam.mode == cam.CameraMode.FIRSTPERSON or GameManager.shiftlocked
		
@onready var cam:CamStuff = $Camera3D
@onready var LegCasts = get_node("LegCasts").get_children()

@export var HealthBar: ProgressBar

@export var max_step_height: float = 2.0
@export var step_check_distance: float = 0.5
@export var step_up_boost: float = 150.0

var grounded = false
var ground_dist:float = 0
var ground_pos
var step_raycast: RayCast3D
var can_step_up: bool = false
var step_up_timer: float = 0.0

@onready var anim_tree = $Character/AnimationTree["parameters/playback"]

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
	GameManager.CharacterAdded.emit(self)
	$Camera3D.top_level = true
	step_raycast = RayCast3D.new()
	step_raycast.enabled = true
	add_child(step_raycast)
	step_raycast.position = Vector3(0, 0.5, 0)
	step_raycast.target_position = Vector3.FORWARD * step_check_distance

func _ground_check():
	var shortest = INF
	var found_ground = false
	var closest_pos = null
	
	#var ray_length = 1.5 if grounded else 1.1
	#ray_length += abs(linear_velocity.y) / 100.0 if abs(linear_velocity.y) > 100 else 0
	#ray_length = ray_length * 2 + 1
	
	var legcast:RayCast3D = $LegCasts/Center
	#legcast.target_position = Vector3.UP*-ray_length
	
	if legcast.is_colliding() and legcast.get_collision_normal().dot(Vector3.UP)>cos(89):
		found_ground=true
		var dist = legcast.get_collision_point().distance_to(legcast.global_position)
		shortest = min(shortest,dist)
		if dist <= shortest:
			closest_pos = legcast.get_collision_point()
	
	if !found_ground:
		for lg: RayCast3D in LegCasts:
			#lg.target_position = Vector3.UP*-ray_length
			if lg.is_colliding() and lg.get_collision_normal().dot(Vector3.UP)>cos(89):
				found_ground=true
				var dist = lg.get_collision_point().distance_to(lg.global_position)
				shortest = min(shortest,dist)
				if dist <= shortest:
					closest_pos = lg.get_collision_point()
	
	grounded = found_ground
	ground_dist = shortest if shortest != INF else 9999
	ground_pos = closest_pos

func _check_for_step_up() -> bool:
	# casting forward for obstacle detection
	step_raycast.target_position = global_transform.basis.z * -step_check_distance

	if step_raycast.is_colliding():
		var collision_point = step_raycast.get_collision_point()
		var obstacle_height = collision_point.y - global_position.y

		if 0 < obstacle_height and obstacle_height <= max_step_height:
			return true

	return false

func _apply_step_up():
	# give upwards velocity when u step up.
	linear_velocity.y = step_up_boost
	can_step_up = false

func _physics_process(_delta: float) -> void:
	_ground_check()

	if grounded and linear_velocity.length() > 0.5:
		if _check_for_step_up():
			_apply_step_up()
	
