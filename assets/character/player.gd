extends CharacterBody3D

# walkspeed and jump height
var SPEED = 16
var JUMP_VELOCITY = 50

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

# Truss Variables
@export var sensitivity := 0.005
@export var climb_speed := 10.0
@export var stick_force := 2.0
@export var jump_off_force := 15.0 
@export var jump_up_force := 1.1
var knockback_timer := 0.0
var step_visual_offset := 0.0


var just_jumped_off := false
@export var shiftlockLogo: TextureRect

# -------  loading player components ---------

# truss flick rays

@onready var flickRay = $flickRay
@onready var flickRayBack = $flickRay2
@onready var flickRayRight = $flickRay3
@onready var flickRayLeft = $flickRay4

# camera 

@onready var cam: CamStuff = $Camera3D

# truss rays

@onready var ray = $TrussRay
@onready var topray = $GlideRay
@onready var glidetop = $GlideTop
@onready var glidebottom = $GlideBottom

# player and player animations

@onready var player = $Character
@onready var playerAnims = $Character/AnimationPlayer

# test variables to fix truss climbing
var climb_grace := 0.0
var last_truss_point := Vector3.ZERO

var noclip_speed := 60.0

# GUI

@export var timer: Control
@export var HealthBar: ProgressBar
@export var spawn: Node3D

var rotation_locked: bool : # checks if ur in firstperson or ur shiftlocked if so your rotation is locked
	get():
		return cam.mode == cam.CameraMode.FIRSTPERSON or GameManager.shiftlocked
@export var voidDepth := 300.0
var last_state = -1
var is_climbing := false
var climb_normal := Vector3.ZERO

func set_char_transparency(alpha: float): # for ghost mode etc
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
		
		if material:
			material.albedo_color.a = alpha
			if alpha >= 1.0:
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			else:
				material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		
			
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
		if not GameManager.practice:
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
		set_char_transparency(0.3)
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
	
	# truss logic
	if jump_lock <= 0.0:
		var touching_truss := false

		var active_ray = null

		if ray.is_colliding():
			active_ray = ray
		elif topray.is_colliding():
			active_ray = topray

		if active_ray:
			var collider = active_ray.get_collider()
			# this should be changed to work with parts later
			if collider and collider.is_in_group("climbable"):
				var normal = active_ray.get_collision_normal()
				
				var input_dir_check := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
				var cam_yaw_check = cam.yaw
				var forward_check = Vector3(-sin(cam_yaw_check), 0, -cos(cam_yaw_check)).normalized()
				var right_check = Vector3(cos(cam_yaw_check), 0, -sin(cam_yaw_check)).normalized()
				var move_dir_check = (right_check * input_dir_check.x + forward_check * input_dir_check.y).normalized()
				
				if is_on_floor() and move_dir_check.length() > 0.1 and move_dir_check.dot(normal) > 0.2:
					touching_truss = false
				else:
					touching_truss = true
					climb_normal = normal
					last_truss_point = active_ray.get_collision_point()
					climb_grace = 0.08
					truss_timer = 0.0
					truss_used = false

		if touching_truss:
			is_climbing = true
		else:
			climb_grace -= delta
			var dist = global_position.distance_to(last_truss_point)

			if climb_grace > 0.0 and dist < 0.45 and not (is_on_floor() and Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").length() > 0.1):
				is_climbing = true
			else:
				is_climbing = false
				climb_normal = Vector3.ZERO
				
	if step_visual_offset != 0.0:
		var old_offset = step_visual_offset
		step_visual_offset = move_toward(step_visual_offset, 0.0, delta * 20.0) 
		var diff = step_visual_offset - old_offset
		
		if player:
			player.position.y += diff

	# gravity
	if not is_on_floor() and not is_climbing and not $CollisionShape3D.disabled:
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
			
	if Input.is_action_just_pressed("Reset") and !GameManager.RToggle:
		reset()

	if Input.is_action_just_pressed("ResetAlt") and GameManager.RToggle:
		reset()
		
	if GameManager.practice:
		if Input.is_action_just_pressed("noclip"):
			$CollisionShape3D.disabled = not $CollisionShape3D.disabled
			if $CollisionShape3D.disabled:
				velocity = Vector3.ZERO 

		if Input.is_action_just_pressed("freecam"):
			cam.freecam_active = not cam.freecam_active
				
		if cam.freecam_active:
			State = states.Idle
			update_anim()
			return
	
	# noclip functionality
	# i made it rly close to roblox
	if GameManager.practice and $CollisionShape3D.disabled:
		State = states.Idle
		update_anim()
		
		rotation.y = cam.yaw + PI
		rotation.x = -cam.pitch 
		
		# i hate these action names so much someone make better names
		if Input.is_action_just_pressed("noclipspeedup"):
			noclip_speed = min(noclip_speed * 2.0, 500.0)
		if Input.is_action_just_pressed("noclipspeeddown"):
			noclip_speed = max(noclip_speed / 2.0, 3.75)
		
		var fly_dir := Vector3.ZERO
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var cam_basis = cam.global_transform.basis
		
		fly_dir = (cam_basis.x.normalized() * input_dir.x) + (-cam_basis.z.normalized() * input_dir.y)
		
		if Input.is_action_pressed("ui_accept"):
			fly_dir.y += 1.0
			
		global_position += fly_dir.normalized() * noclip_speed * delta
		
		is_climbing = false
		climb_normal = Vector3.ZERO
		just_jumped_off = false
		return
		
	if position.y <= -voidDepth:
		reset()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var cam_yaw = cam.yaw
	var forward = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)).normalized()
	var right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw)).normalized()

	var direction = (right * input_dir.x + forward * input_dir.y).normalized()

	if is_climbing:
		velocity -= climb_normal * 6.0 * delta # attaching player to truss
		
		var at_top := true
		if climb_normal != Vector3.ZERO:
			var hitting_truss: bool = glidetop.is_colliding() and glidetop.get_collider().is_in_group("climbable")
			if not hitting_truss:
				if glidebottom.is_colliding() and glidebottom.get_collider().is_in_group("climbable"):
					hitting_truss = true
			if hitting_truss:
				at_top = false
		# Allows gliding ONLY IF torso is above truss
		if at_top and input_dir.x != 0:
			velocity.x = right.x * input_dir.x * SPEED
			velocity.z = right.z * input_dir.x * SPEED
		else:
			velocity.x = 0
			velocity.z = 0
			
		# dynamic climbing based on camera
		var camf = -cam.global_transform.basis.z.normalized()
		var camr = cam.global_transform.basis.x.normalized()
		var charf = -global_transform.basis.z.normalized()

		var vf = camf.dot(charf)
		var vr = camr.dot(charf)

		var v_input = Input.get_axis("ui_down", "ui_up")
		var h_input = Input.get_axis("ui_left", "ui_right")

		var climb_input = (v_input * vf) - (h_input * vr)

		if abs(climb_input) > 0.01:
			climb_input = sign(climb_input)
		elif h_input != 0:
			climb_input = 1.0

		velocity.y = climb_input * climb_speed
		
		# leave truss when feet touch ground
		if is_on_floor() and climb_input <= 0:
			is_climbing = false
			climb_grace = 0.0
			climb_normal = Vector3.ZERO
		
		# bigger the number the stricter your camera needs to be straight to glide
		var looking_from_behind : float = abs(camf.dot(climb_normal))
		
		if at_top and input_dir.x != 0 and looking_from_behind > 0.7:
			velocity.x = right.x * input_dir.x * SPEED
			velocity.z = right.z * input_dir.x * SPEED
		else:
			# so technically this fixes gliding hopefully
			velocity.x = 0
			velocity.z = 0
		
		if Input.is_action_pressed("ui_accept") and knockback_timer <= 0:
			# truss bouncing
			var knockback_dir = -global_transform.basis.z.normalized()
			
			# Truss momentum logic
			
			# Quadratic formulas based off craws implementation
			velocity.x = knockback_dir.x * ((2.285 * pow(climb_input, 2)) - (2.825 * climb_input) + 38 )
			
			velocity.z = knockback_dir.z * ((2.285 * pow(climb_input, 2)) - (2.825 * climb_input) + 38)

			velocity.y = (-8.06 * pow(climb_input, 2)) + (8.06 * climb_input) + 45.3
			global_position += knockback_dir * 0.05
			
			is_climbing = false
			climb_normal = Vector3.ZERO
			just_jumped_off = true
			
			knockback_timer = 0.28
			jump_lock = 0.125
		
		set_climb_anim(
			climb_input == 0,
			"Up" if climb_input > 0 else "Down" if climb_input < 0 else "Idle"
		)
			
	else:
		if knockback_timer > 0.0:
			knockback_timer -= delta
			
			var current_h_vel = Vector3(velocity.x, 0.0, velocity.z)
			var target_h_vel = direction * SPEED
			
			if current_h_vel.length() > SPEED:
				current_h_vel = current_h_vel.move_toward(target_h_vel, 142.0 * delta)
			else:
				if direction != Vector3.ZERO:
					current_h_vel = target_h_vel
				else:
					current_h_vel = current_h_vel.move_toward(Vector3.ZERO, 140.0 * delta)
					
			velocity.x = current_h_vel.x
			velocity.z = current_h_vel.z
		else:
			if direction != Vector3.ZERO:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
			else:
				velocity.x = 0
				velocity.z = 0
	if not $CollisionShape3D.disabled:
		rotation.x = 0.0
		if rotation_locked:
			rotation.y = cam.yaw + PI
		elif direction.length() > 0.001 and not is_climbing:
			var target_angle = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle + PI, 10.0 * min(delta, 0.1))
			
			
	_step_climbing()
	move_and_slide()
	update_state()
	update_anim()
	just_jumped_off = false
	
func _step_climbing() -> void:
	if is_climbing or not is_on_floor():
		return

	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_vel.length() < 0.1:
		return

	var dt = get_physics_process_delta_time()
	var step_displacement = horizontal_vel * dt
	var hit_info = KinematicCollision3D.new()

	if test_move(global_transform, step_displacement, hit_info):
		var collision_normal = hit_info.get_normal()
		# checking if ther's no problem w floor at the top of us to hit us
		# previously you would just noclip in it
		
		# upd: no it's not
		if collision_normal.y > cos(floor_max_angle):
			return

		# it's more of automatic but number is still hard coded
		var step_height := 0.0
		var max_possible_step := 2.0
		var step_increment := 0.05
		var found_top := false
		var test_transform = global_transform

		while step_height < max_possible_step:
			step_height += step_increment
			var upward_transform = global_transform.translated(Vector3(0.0, step_height, 0.0))
			
			if not test_move(upward_transform, step_displacement):
				test_transform = upward_transform
				found_top = true
				break

		if found_top:
			var forward_tgt = test_transform.translated(step_displacement)
			var drop_sweep = Vector3(0.0, -step_height, 0.0)
			var ground_hit = KinematicCollision3D.new()
			
			if test_move(forward_tgt, drop_sweep, ground_hit):
				var drop_dist = ground_hit.get_travel().y
				var final_step_height = step_height + drop_dist
				
				if final_step_height > 0.01:
					global_position.y += final_step_height
					step_visual_offset -= final_step_height
					
					if player:
						player.position.y -= final_step_height
						
					force_update_transform()
	else:
		# step down handling
		var forward_tgt = global_transform.translated(step_displacement)
		var max_possible_step_down := 2.0
		var down_sweep = Vector3(0.0, -max_possible_step_down, 0.0)
		var ground_hit = KinematicCollision3D.new()
		
		if test_move(forward_tgt, down_sweep, ground_hit):
			var drop_dist = ground_hit.get_travel().y
			
			if drop_dist < -0.01:
				global_position.y += drop_dist
				step_visual_offset -= drop_dist
				
				if player:
					player.position.y -= drop_dist
					
				force_update_transform()

func _process(_delta: float) -> void:
	if Health <= 0:
		reset()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("kills"):
		remove_Health(kills)
	elif body.is_in_group("ouch"):
		remove_Health(ouch)
	elif body.is_in_group("instakills"):
		remove_Health(instakills)
