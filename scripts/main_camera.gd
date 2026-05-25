extends Camera3D
@export var Speed := 5.0
@export var accel := 50.0
@export var mouse_speed := 500

var velocity := Vector3.ZERO
var lookAngles = Vector2.ZERO
var movingCamera := false
var just_captured := false

func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if !movingCamera:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			movingCamera = true
			just_captured = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		movingCamera = false

	lookAngles.y = clamp(lookAngles.y, PI/-2, PI/2)

	if movingCamera:
		set_rotation(Vector3(lookAngles.y, lookAngles.x, 0))

	var direction = updateDirection()
	if direction.length_squared() > 0:
		velocity += direction * accel * delta
	if velocity.length() > Speed:
		velocity = velocity.normalized() * Speed

	translate(velocity * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if just_captured:
			just_captured = false
			return

		if movingCamera:
			lookAngles -= event.relative / mouse_speed
func updateDirection():
	var dir = Vector3()
	if Input.is_action_pressed("move_forward"):
		dir += Vector3.FORWARD
	if Input.is_action_pressed("move_backwards"):
		dir += Vector3.BACK
	if Input.is_action_pressed("move_left"):
		dir += Vector3.LEFT
	if Input.is_action_pressed("move_right"):
		dir += Vector3.RIGHT
	if Input.is_action_pressed("move_down"):
		dir += Vector3.DOWN
	if Input.is_action_pressed("move_up"):
		dir += Vector3.UP
	if dir == Vector3.ZERO:
		velocity = Vector3.ZERO
	return dir.normalized()
