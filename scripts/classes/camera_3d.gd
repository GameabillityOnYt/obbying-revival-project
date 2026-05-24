extends Camera3D
class_name CamStuff

@export var target: CharacterBody3D
@export var distance := 10.0
@export var max_distance := 20.0
@export var zoom_speed := 2.0
@export var smooth_speed := 10

var snapping := false
const step := PI / 4.0
var yaw := 0.0
var pitch := 0.0
var rotating := false

enum CameraMode {NORMAL, FIRSTPERSON, GHOST_MODE}
@export var mode: CameraMode = CameraMode.NORMAL
@onready var ray: RayCast3D = target.get_node("Focus/ray")
@export var offset: Vector3 = Vector3.ZERO

var target_distance := 10.0 :
	set(new):
		target_distance = clamp(new, 0.0, max_distance)
		
		if target_distance <= 0.0:
			mode = CameraMode.FIRSTPERSON
		elif target_distance < 2.0:
			mode = CameraMode.GHOST_MODE
		else:
			mode = CameraMode.NORMAL

func _ready():
	GameManager.Camera = self
	target_distance = distance
	fov = GameManager.data.fov
	ray.add_exception(target)
	GameManager.data.FOVChanged.connect(func(new):
		fov = new
	)

func _unhandled_input(event):
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
	if Input.is_action_pressed("zoom_in"):
		target_distance -= zoom_speed
	elif Input.is_action_pressed("zoom_out"):
		target_distance += zoom_speed
	if not GameManager.shiftlocked and mode == CameraMode.NORMAL:
		rotating = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	else:
		rotating = true
	
	target.visible = (mode != CameraMode.FIRSTPERSON)
	target.rotation_locked = GameManager.shiftlocked or mode == CameraMode.FIRSTPERSON

	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if rotating or GameManager.shiftlocked or event is InputEventScreenDrag:
			yaw -= event.relative.x * GameManager.data.sensitivity / 200.0
			pitch -= event.relative.y * GameManager.data.sensitivity / 200.0
			pitch = clamp(pitch, -1.5, 1.5)

func _process(delta):
	if target == null:
		return
	if not snapping:
		yaw += Input.get_axis("look_left", "look_right") * delta
	else:
		snapping = false
	var look_basis = Basis.from_euler(Vector3(pitch, yaw, 0))
	global_transform.basis = look_basis
	var target_focus_pos = target.get_node("Focus").global_position
	var max_desired_pos = target_focus_pos + look_basis.z * target_distance
	
	ray.target_position = ray.to_local(max_desired_pos)
	ray.force_raycast_update()
	
	var final_distance = target_distance
	if ray.is_colliding():
		var origin = ray.global_position
		var hit = ray.get_collision_point()
		final_distance = origin.distance_to(hit) - 0.1
	
	distance = min(lerp(distance, target_distance, smooth_speed * delta), final_distance)
	
	var side_offset = Vector3.ZERO
	
	if GameManager.shiftlocked and mode == CameraMode.NORMAL:
		side_offset = look_basis.x * 1.75
		
	global_position = target_focus_pos + (look_basis.z * distance) + side_offset
	
func sync_angles(target_transform: Transform3D):
	var euler = target_transform.basis.get_euler()
	
	self.yaw = euler.y
	self.pitch = euler.x 
	if mode == CameraMode.FIRSTPERSON:
		self.target_distance = 0
		self.distance = 0
	
	global_transform = target_transform
