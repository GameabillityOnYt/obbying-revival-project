extends Camera3D

@export var Speed := 5.0
@export var accel := 50.0

var velocity := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var moving_camera := false
var rotating := false

# --- variables for manipulating objects ---
var selected_object: Node3D = null
var is_moving_object := false
var placement_distance := 5.0 
@onready var transform_gizmo: Node3D = $"../Gizmo3D"
var selection_manager: SelectionManager

func _ready() -> void:
	selection_manager = SelectionManager.new(self, transform_gizmo)

func _process(delta: float) -> void:
	moving_camera = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	GameManager.editor_rotating = moving_camera
	if moving_camera:
		pitch = clamp(pitch, -1.5, 1.5)
		set_rotation(Vector3(pitch, yaw, 0))

	var direction = updateDirection()
	if direction.length_squared() > 0:
		velocity += direction * accel * delta
	if velocity.length() > Speed:
		velocity = velocity.normalized() * Speed

	translate(velocity * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and moving_camera:
		var aspect = get_viewport().size.x / get_viewport().size.y
		yaw -= event.screen_relative.x * aspect * GameManager.data.sensitivity / 200.0
		pitch -= event.screen_relative.y * GameManager.data.sensitivity / 200.0

	if selection_manager:
		selection_manager.handle_input(event)

func updateDirection() -> Vector3:
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): dir += Vector3.FORWARD
	if Input.is_action_pressed("move_backwards"): dir += Vector3.BACK
	if Input.is_action_pressed("move_left"): dir += Vector3.LEFT
	if Input.is_action_pressed("move_right"): dir += Vector3.RIGHT
		
	if dir == Vector3.ZERO:
		velocity = Vector3.ZERO
		
	return dir.normalized()
