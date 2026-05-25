extends CharacterBody3D

# walkspeed and jump height
const SPEED = 14
const JUMP_VELOCITY = 45

# coyote time shi
@export var coyote_time := 0.125
var coyote_timer := 0.0

var truss_timer := 999.0
var truss_used := false

enum states {Climbing, Idle, Walking, Falling, Jumping}

@export var State: states

var jump_lock := 0.0

# health shit idk
@export var MaxHealth := 100.0
var Health := 100.0
var kills := 5
var ouch := 20
var instakills := MaxHealth
@export var regen_rate := 1.0  # HP per second
@export var regen_delay := 2.0  # seconds after taking damage
var regen_timer := 0.0
var took_damage := false

# camera and trusses etc
@export var sensitivity := 0.005
@export var climb_speed := 10.0
@export var stick_force := 2.0

@export var jump_off_force := 15.0 
@export var jump_up_force := 1.1
var knockback_timer := 0.0


var just_jumped_off := false
@export var shiftlockLogo: TextureRect
@onready var flickRay = $flickRay
@onready var flickRayBack = $flickRay2
@onready var flickRayRight = $flickRay3
@onready var flickRayLeft = $flickRay4
@onready var cam: CamStuff = $Camera3D
@onready var ray = $RayCast3D
@onready var brickCollision = $Area3D
@onready var player = $Character
@onready var playerAnims = $Character/AnimationPlayer

@export var timer: Control
@export var HealthBar: ProgressBar
@export var spawn: Node3D

var rotation_locked: bool :
	get():
		return cam.mode == cam.CameraMode.FIRSTPERSON or GameManager.shiftlocked
@export var voidDepth := 300.0
var last_state = -1
var is_climbing := false
var climb_normal := Vector3.ZERO

func set_char_transparency(alpha: float):
	var charNode = $Character
	if not charNode:
		print("char not found :(")
		return
		
	_apply_transparency_recursive(charNode, alpha)

func _apply_transparency_recursive(node: Node, alpha: float):
	if node is MeshInstance3D:
		var material = node.material_override
		if not material or not (material is StandardMaterial3D):
			if node.get_active_material(0) is StandardMaterial3D:
				material = node.get_active_material(0).duplicate()
			else:
				material = StandardMaterial3D.new()
			
			node.material_override = material
		
		if alpha >= 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		else:
			material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		
		material.albedo_color.a = alpha
	
	for child in node.get_children():
		_apply_transparency_recursive(child, alpha)

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

func remove_Health(amount: float):
	if Health > 0:
		Health = max(0, Health - amount)
		update_health_bar()
		regen_timer = 0.0
		took_damage = true

func add_Health(amount: float):
	if Health < MaxHealth:
		Health = min(MaxHealth, Health + amount)
		update_health_bar()

func reset():
	if spawn != null:
		global_position = spawn.global_position
		global_rotation = spawn.global_rotation
		
		if spawn.has_meta("saved_velocity"):
			velocity = spawn.get_meta("saved_velocity")
			if velocity.length() > 0.1:
				knockback_timer = 0.1 
		else:
			velocity = Vector3.ZERO
		if spawn.has_meta("camera_mode"):
			cam.mode = spawn.get_meta("camera_mode")
			GameManager.shiftlocked = spawn.get_meta("shiftlocked")
			cam.global_transform = spawn.get_meta("camera_transform")
			
			cam.sync_angles(cam.global_transform)
		if not GameManager.alljump:
			timer.get_node("Panel").resetTime()
		

	Health = MaxHealth
	update_health_bar()
	is_climbing = false
	climb_normal = Vector3.ZERO
	knockback_timer = 0.0

func _physics_process(delta: float) -> void:
	# timers
	truss_timer += delta
	jump_lock = max(jump_lock - delta, 0.0)
	if cam.target_distance < 5:
		set_char_transparency(0.5)
	else:
		set_char_transparency(1.0)
		
	# health regen
	if Health < MaxHealth:
		if took_damage:
			regen_timer += delta
			if regen_timer >= regen_delay:
				took_damage = false
		else:
			Health += regen_rate * delta
			Health = min(Health, MaxHealth)
			update_health_bar()

	if ray.is_colliding() and jump_lock <= 0.0:
		var collider = ray.get_collider()

		if collider.is_in_group("climbable"):
			if not is_climbing:
				is_climbing = true
				climb_normal = ray.get_collision_normal()
			
			ray.target_position.y = -1.0
			truss_timer = 0.0
			truss_used = false
		else:
			is_climbing = false
			climb_normal = Vector3.ZERO
			ray.target_position.y = -0.5
	else:
		is_climbing = false
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
		if coyote_timer > 0 and not is_climbing and jump_lock <= 0.0:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0
			
	if Input.is_action_pressed("Reset"):
		reset()
		
	if Input.is_action_just_pressed("ui_accept"):
		if is_climbing:
			var backward_dir = global_transform.basis.z
			var knockback_dir = Vector3(-backward_dir.x, 0, -backward_dir.z).normalized()
			
			velocity.x = knockback_dir.x * jump_off_force * 2.0
			velocity.z = knockback_dir.z * jump_off_force * 2.0
			velocity.y = JUMP_VELOCITY * jump_up_force
			
			is_climbing = false
			climb_normal = Vector3.ZERO
			just_jumped_off = true
			
			knockback_timer = 0.2
			jump_lock = 0.125

	if position.y <= -voidDepth:
		reset()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var cam_yaw = cam.yaw
	var forward = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)).normalized()
	var right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw)).normalized()

	var direction = (right * input_dir.x + forward * input_dir.y).normalized()

	if is_climbing:
		var at_top := true
		if climb_normal != Vector3.ZERO:
			var space_state = get_world_3d().direct_space_state
			
			# Starts at chest height (0.5 best value)
			var ray_start = global_position + Vector3(0, 0.5, 0) 
			var ray_end = ray_start - climb_normal * 1.2 
			
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			
			var result = space_state.intersect_ray(query)
			
			if result and result.collider.is_in_group("climbable"):
				at_top = false
		# Allows gliding ONLY IF torso is above truss
		if at_top and input_dir.x != 0:
			velocity.x = right.x * input_dir.x * SPEED
			velocity.z = right.z * input_dir.x * SPEED
		else:
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
	else:
		if knockback_timer > 0.0:
			knockback_timer -= delta
			
			if direction != Vector3.ZERO:
				velocity.x = lerp(velocity.x, direction.x * SPEED, 3.0 * delta)
				velocity.z = lerp(velocity.z, direction.z * SPEED, 3.0 * delta)
			else:
				velocity.x = lerp(velocity.x, 0.0, 2.0 * delta)
				velocity.z = lerp(velocity.z, 0.0, 2.0 * delta)
		else:
			if direction != Vector3.ZERO:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.x = 0
				velocity.z = 0
	if rotation_locked:
		rotation.y = cam.yaw + PI
	else:
		if direction.length() > 0.001 and not is_climbing:
			var target_angle = atan2(-direction.x, -direction.z)
			var stable_delta = min(delta, 0.1)
			rotation.y = lerp_angle(rotation.y, target_angle + PI, 10.0 * stable_delta)
			
	move_and_slide()
	update_state()
	update_anim()
	just_jumped_off = false

func _process(delta: float) -> void:
	if Health <= 0:
		reset()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("kills"):
		remove_Health(kills)
	elif body.is_in_group("ouch"):
		remove_Health(ouch)
	elif body.is_in_group("instakills"):
		remove_Health(instakills)
