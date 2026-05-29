extends Camera3D
class_name CamStuff

@export var target: CharacterBody3D
@export var distance := 10.0
@export var max_distance := 20.0
@export var zoom_speed := 2.0
@export var smooth_speed := 40

@export var freecam_speed := 40.0
@export var freecam_acceleration := 8.0
@export var freecam_rotation_smoothing := 15.0
var freecam_active := false
var freecam_pos := Vector3.ZERO
var target_yaw := 0.0
var target_pitch := 0.0

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

# whoever reads this please add camera shader caching it lags so hard on first zoom

func _input(event):
	if freecam_active:
		if event is InputEventMouseMotion:
			var aspect = get_viewport().size.x / get_viewport().size.y
			target_yaw -= event.screen_relative.x * aspect * GameManager.data.sensitivity / 200.0
			target_pitch -= event.screen_relative.y * GameManager.data.sensitivity / 200.0
			target_pitch = clamp(target_pitch, -1.5, 1.5)
		return
	
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

	if event is InputEventMouseMotion:
		if rotating or GameManager.shiftlocked:
			var aspect = get_viewport().size.x / get_viewport().size.y
			yaw -= event.screen_relative.x * aspect * GameManager.data.sensitivity / 200.0
			pitch -= event.screen_relative.y  * GameManager.data.sensitivity / 200.0
			pitch = clamp(pitch, -1.5, 1.5)

func _process(delta):
	if target == null:
		return

	if freecam_active:
		yaw = lerp_angle(yaw, target_yaw, freecam_rotation_smoothing * delta)
		pitch = lerp(pitch, target_pitch, freecam_rotation_smoothing * delta)
		global_transform.basis = Basis.from_euler(Vector3(pitch, yaw, 0))
		
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var forward = -global_transform.basis.z.normalized()
		var right = global_transform.basis.x.normalized()
		var target_move = (right * input_dir.x) + (forward * input_dir.y)
		
		if Input.is_action_pressed("ui_accept"): 
			target_move.y += 1.0
			
		freecam_pos = freecam_pos.lerp(freecam_pos + target_move, freecam_acceleration * delta)
		global_position += freecam_pos * freecam_speed * delta
		freecam_pos = freecam_pos.lerp(Vector3.ZERO, freecam_acceleration * delta)
		return

	if not snapping:
		yaw += Input.get_axis("look_left", "look_right") * delta
	else:
		snapping = false
	var look_basis = Basis.from_euler(Vector3(pitch, yaw, 0))
	global_transform.basis = look_basis
	var target_focus_pos = target.get_node("Focus").global_position
	if "step_visual_offset" in target:
		target_focus_pos.y += target.step_visual_offset
	
	var side_offset = Vector3.ZERO
	if GameManager.shiftlocked and mode == CameraMode.NORMAL:
		side_offset = look_basis.x * 1.75
		
	var shifted_focus = target_focus_pos + side_offset
	var max_desired_pos = shifted_focus + look_basis.z * target_distance
	
	ray.global_position = shifted_focus
	ray.target_position = ray.to_local(max_desired_pos)
	ray.force_raycast_update()
	
	var final_distance = target_distance
	if ray.is_colliding():
		var origin = ray.global_position
		var hit = ray.get_collision_point()
		final_distance = origin.distance_to(hit) - 0.2
	
	var calculated_target = min(target_distance, final_distance)
	if calculated_target < distance:
		distance = calculated_target
	else:
		distance = lerp(distance, calculated_target, smooth_speed * delta)

	if distance < 0.05:
		distance = 0.0
		
	global_position = shifted_focus + (look_basis.z * distance)
	auto_transparency()
		
func sync_angles(target_transform: Transform3D):
	var euler = target_transform.basis.get_euler()
	
	self.yaw = euler.y
	self.pitch = euler.x 
	if mode == CameraMode.FIRSTPERSON:
		self.target_distance = 0
		self.distance = 0
	
	global_transform = target_transform

# this function separate for auto transparencing player if part is blocking camera

func auto_transparency():
	if target == null:
		return
		
	var target_transparency := 0.0
	
	if distance < 2.0:
		target_transparency = remap(distance, 0.5, 2.0, 1.0, 0.0)
		target_transparency = clamp(target_transparency, 0.0, 1.0)
		
	if mode == CameraMode.FIRSTPERSON:
		target_transparency = 1.0

	for child in target.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			child.transparency = target_transparency
