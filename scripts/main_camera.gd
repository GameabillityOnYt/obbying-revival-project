extends Camera3D

@export_group("Flycam Controls")
@export var Speed := 5.0
@export var accel := 50.0
@export var mouse_speed := 500.0

@export_group("Cubemap Capture")
# Key used to trigger the 6-image capture sequence
@export var trigger_key: Key = KEY_F9
# Directory where captured faces will be saved
@export var output_directory: String = "res://cubemap_faces/"

var velocity := Vector3.ZERO
var lookAngles := Vector2.ZERO
var movingCamera := false
var just_captured := false
var is_capturing := false

# Cardinal directions in radians for 6 cubemap faces
const FACES = {
	"front":  Vector3(0, 0, 0),                 # Forward (-Z)
	"right":  Vector3(0, deg_to_rad(-90), 0),   # Right (+X)
	"back":   Vector3(0, deg_to_rad(180), 0),   # Back (+Z)
	"left":   Vector3(0, deg_to_rad(90), 0),    # Left (-X)
	"up":     Vector3(deg_to_rad(-90), 0, 0),   # Up (+Y)
	"down":   Vector3(deg_to_rad(90), 0, 0)     # Down (-Y)
}

func _process(delta: float) -> void:
	# Freeze flycam input during screenshot process
	if is_capturing:
		return

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
	if is_capturing:
		return

	# Shortcut key check for cubemap capture
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == trigger_key:
			capture_cubemap()
			return

	# Flycam mouse look
	if event is InputEventMouseMotion:
		if just_captured:
			just_captured = false
			return

		if movingCamera:
			lookAngles -= event.relative / mouse_speed

func updateDirection() -> Vector3:
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

func capture_cubemap() -> void:
	is_capturing = true
	movingCamera = false
	velocity = Vector3.ZERO
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	print("Starting 6-face cubemap capture from current camera position...")

	# 1. Save current camera FOV
	var original_fov = fov
	
	# 2. Enforce 1024x1024 window & 90° FOV (required for seamless seams)
	DisplayServer.window_set_size(Vector2i(1024, 1024))
	fov = 90.0

	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_absolute(output_directory)

	# 3. Rotate camera face by face and save screenshots
	for face_name in FACES:
		global_rotation = FACES[face_name]
		
		# Allow the renderer 2 frames to flush the GPU buffer
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var img = get_viewport().get_texture().get_image()
		var file_path = output_directory + face_name + ".png"
		var err = img.save_png(file_path)

		if err == OK:
			print("Saved: ", file_path)
		else:
			push_error("Failed to save: " + file_path)

	# 4. Restore original camera state and rotation
	fov = original_fov
	set_rotation(Vector3(lookAngles.y, lookAngles.x, 0))
	is_capturing = false
	print("Capture complete! PNGs saved to: ", output_directory)
