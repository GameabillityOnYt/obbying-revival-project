extends RigidBody3D
class_name PlayerClass

var rotation_locked:bool :
	get():
		return cam.mode == cam.CameraMode.FIRSTPERSON or GameManager.shiftlocked
		
@onready var cam:CamStuff = $Camera3D
@onready var LegCasts = get_node("LegCasts").get_children()

@export var HealthBar: ProgressBar

var grounded = false
var ground_dist:float = 0
var ground_pos

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

func _physics_process(_delta: float) -> void:
	_ground_check()
	
