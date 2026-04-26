extends Camera3D
class_name CamStuff

@export var target: PlayerClass
@export var distance := 10.0
@export var max_distance := 20.0
@export var zoom_speed := 1
@export var smooth_speed := 10

var snapping := false
const step := PI / 4.0
var yaw := 0.0
var pitch := 0.0
var rotating := false

enum CameraMode {NORMAL, FIRSTPERSON}
@export var mode: CameraMode = CameraMode.NORMAL
@onready var ray: RayCast3D = target.get_node("Focus/ray")
@export var offset:Vector3 = Vector3.ZERO

var target_distance := 10.0 :
	set(new):
		if new <= 0:
			mode = CameraMode.FIRSTPERSON
		target_distance = new

func _ready():
	GameManager.Camera = self
	target_distance = distance
	fov = GameManager.data.fov
	ray.add_exception(target)
	GameManager.data.FOVChanged.connect(func(new):
		fov = new
		pass)

func _input(event):
	if Input.is_action_just_pressed("left_align"):
		var step_index = round(yaw / step)
		step_index += 1
		yaw = wrapf(step_index * step, -PI, PI)
		snapping = true
	if Input.is_action_just_pressed("right_align"):
		var step_index = round(yaw / step)
		step_index -= 1
		yaw = wrapf(step_index * step, -PI, PI)
		snapping = true
	if Input.is_action_just_pressed("shift_lock"):
		GameManager.shiftlocked = !GameManager.shiftlocked

	if Input.is_action_pressed("zoom_in"):
		target_distance -= zoom_speed
	elif Input.is_action_pressed("zoom_out"):
		target_distance += zoom_speed

	target_distance = clamp(target_distance, 0, max_distance)
	mode = CameraMode.NORMAL if target_distance > 0 else CameraMode.FIRSTPERSON
	
	if not GameManager.shiftlocked and mode == CameraMode.NORMAL:
		rotating = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		target_distance = clamp(target_distance, 0, max_distance)
	else:
		rotating = true
	
	target.visible = mode == CameraMode.NORMAL
	target.follow_camera = GameManager.shiftlocked or mode == CameraMode.FIRSTPERSON

	if event is InputEventMouseMotion:
		if rotating or GameManager.shiftlocked:
			yaw -= event.relative.x * GameManager.data.sensitivity/200
			pitch -= event.relative.y * GameManager.data.sensitivity/200
			pitch = clamp(pitch, -1.5, 1.5)

func _process(delta):
	offset = Vector3(.35,0,0) if GameManager.shiftlocked else Vector3.ZERO
	if target == null:
		return
	if not snapping:
		yaw += Input.get_axis("look_left","look_right") * delta
	else:
		snapping = false
	var max_desired_pos = target.get_node("Focus").global_position + global_basis.z*target_distance
	
	ray.target_position = ray.to_local(max_desired_pos)
	ray.force_raycast_update()
	
	var final_distance = target_distance
	if ray.is_colliding():
		var origin = ray.global_position
		var hit = ray.get_collision_point()
		final_distance = origin.distance_to(hit)-.1
	
	distance = min(lerp(distance, target_distance, smooth_speed * delta),final_distance)
	rotation = Vector3(pitch,yaw,0)
	
	global_position = target.get_node("Focus").global_position + global_basis.z * distance + global_transform.basis*offset
