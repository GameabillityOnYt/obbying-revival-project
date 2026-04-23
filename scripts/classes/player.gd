extends CharacterBody3D
class_name Player

const SPEED = 4
const JUMP_VELOCITY = 7.5

#coyote time shi
@export var coyote_time := 0.125
var coyote_timer := 0.0

var truss_timer := 999.0
var truss_used := false

enum states {Climbing, Idle, Walking, Falling, Jumping}

@export var State: states :
	set(new):
		if is_node_ready():
			State = new
			update_anim()

var jump_lock := 0.0

# health shit idk
@export var MaxHealth := 100.0
var Health := 100.0 : 
	set(new):
		if new < Health: # Checking if u took damage
			if new > 0: # checking if ur alive
				regen_timer = 0.0
				took_damage = true
		
		update_health_bar()
		Health = clamp(new,0,MaxHealth)

@export var regen_rate := 1.0  # HP per second
@export var regen_delay := 2.0  # seconds after taking damage
var regen_timer := 0.0
var took_damage := false

# camera and trusses etc
@export var climb_speed := 3.0
@export var stick_force := 2.0
@export var jump_off_force := 40
@export var jump_up_force := 3.0
var just_jumped_off := false
@export var shiftlockLogo: TextureRect
@onready var flickRay = $flickRay
@onready var flickRayBack = $flickRay2
@onready var flickRayRight = $flickRay3
@onready var flickRayLeft = $flickRay4
@onready var cam = $Camera3D
@onready var ray = $RayCast3D
@onready var brickCollision = $Area3D
@onready var player = $Character
@onready var playerAnims = $Character/AnimationPlayer
@export var HealthBar: ProgressBar

@export var voidDepth := 50.0
@export var follow_camera := false 
var last_state = -1
var is_climbing := false
var climb_normal := Vector3.ZERO

func set_climb_anim(pause: bool, dir: String):
	if pause:
		playerAnims.speed_scale = 0.0
	else:
		if dir == "Up":
			playerAnims.speed_scale = 1.0
		elif dir == "Down":
			playerAnims.speed_scale = -1.0
		else:
			playerAnims.speed_scale = 0.0

func update_anim():
	if State == last_state:
		return

	match State:
		states.Idle:
			playerAnims.play("idle", 0.1)
			playerAnims.speed_scale = 1.0

		states.Walking:
			playerAnims.play("walk", 0.1)
			playerAnims.speed_scale = 1.0

		states.Climbing:
			playerAnims.play("climb", 0.2)

		states.Jumping:
			playerAnims.play("jump", 0.1)
			playerAnims.speed_scale = 1.0

		states.Falling:
			playerAnims.play("fall", 0.1)
			playerAnims.speed_scale = 1.0

	last_state = State
func update_state():
	if is_climbing:
		State = states.Climbing
	elif not is_on_floor():
		if velocity.y > 0:
			State = states.Jumping
		else:
			State = states.Falling
	elif Vector3(velocity.x, 0, velocity.z).length() > 0.1:
		State = states.Walking
	else:
		State = states.Idle
		
func _ready() -> void:
	reset()


func is_leg_near_ground() -> bool:
	return (flickRay.is_colliding() or flickRayBack.is_colliding() or flickRayRight.is_colliding() or flickRayLeft.is_colliding())


func update_health_bar():
	if HealthBar:
		HealthBar.value = (Health / MaxHealth) * 100

func reset():
	await get_tree().process_frame
	Health = MaxHealth
	GameManager.CharacterAdded.emit(self)

func _physics_process(delta: float) -> void:
	# timers
	truss_timer += delta
	jump_lock = max(jump_lock - delta, 0.0)

	# regen
	if Health < MaxHealth:
		if took_damage:
			regen_timer += delta
			if regen_timer >= regen_delay:
				took_damage = false
		else:
			Health += regen_rate * delta
			Health = min(Health, MaxHealth)

	# climbing
	if ray.is_colliding() and not is_on_floor():
		var collider = ray.get_collider()

		if collider.is_in_group("climbable"):
			is_climbing = true
			climb_normal = ray.get_collision_normal()
			ray.target_position.y = -0.2

			truss_timer = 0.0
			truss_used = false

		else:
			is_climbing = false
			climb_normal = Vector3.ZERO
			ray.target_position.y = -0.1
	else:
		is_climbing = false
		climb_normal = Vector3.ZERO

	# gravity
	if not is_on_floor() and not is_climbing:
		velocity += get_gravity() * delta

	# truss coyote logic
	if truss_timer < 0.1 and not truss_used:
		if is_leg_near_ground():
			truss_used = true
			coyote_timer = coyote_time
		else:
			coyote_timer = 0

	# ground coyote
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)


	if Input.is_action_pressed("ui_accept"):
		print(coyote_timer)
		if coyote_timer > 0 and not is_climbing and jump_lock <= 0.0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0


	if Input.is_action_just_pressed("ui_accept"):
		if is_climbing:
			velocity += climb_normal * jump_off_force + Vector3.UP * jump_up_force
			is_climbing = false
			just_jumped_off = true

			jump_lock = 0.1

	if position.y <= -voidDepth:
		reset()

	# movement
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var cam_basis = cam.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x

	forward.y = 0
	right.y = 0

	forward = forward.normalized()
	right = right.normalized()

	var direction = (right * input_dir.x + forward * input_dir.y).normalized()

	if is_climbing:
		velocity.x = 0
		velocity.z = 0

		if Input.is_action_pressed("ui_up"):
			velocity.y = -climb_speed
			set_climb_anim(false, "Up")
		elif Input.is_action_pressed("ui_down"):
			velocity.y = climb_speed
			set_climb_anim(false, "Down")
		else:
			velocity.y = 0
			set_climb_anim(true, "Idle")

	elif not just_jumped_off:
		if direction != Vector3.ZERO:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = 0
			velocity.z = 0

# rotation
	if is_climbing:
		if follow_camera:
			var cam_forward = -cam.global_transform.basis.z
			cam_forward.y = 0
			cam_forward = cam_forward.normalized()

			if cam_forward.length() > 0.001:
				rotation.y = atan2(cam_forward.x, cam_forward.z)
		else:
			pass 

	else:
		if follow_camera:
			var cam_forward = -cam.global_transform.basis.z
			cam_forward.y = 0
			cam_forward = cam_forward.normalized()

			if cam_forward.length() > 0.001:
				rotation.y = atan2(cam_forward.x, cam_forward.z)

		else:
			if direction.length() > 0.001:
				var target_angle = atan2(direction.x, direction.z)
				rotation.y = lerp_angle(rotation.y, target_angle, 10 * delta)

	move_and_slide()
	update_state()
	update_anim()
	just_jumped_off = false


func _process(_delta: float) -> void:
	if Health <= 0:
		reset()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("DamageDealer"):
		self.Health -= body.damage
