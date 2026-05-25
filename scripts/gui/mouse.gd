extends AnimatedSprite2D

enum ICON {NORMAL, CLICK, SHIFTLOCK}

var last_pos:Vector2
var last_rotating = false
var wobbly = false # >:3
var wobbly_speed = 0
@onready var canvas:CanvasLayer = get_parent()

func _process(delta: float) -> void:
	if wobbly:
		var mouse_speed = (get_global_mouse_position().x-global_position.x)/get_window().size.x
		var force = (0 - skew) * 200.0 - wobbly_speed * 4.0
		wobbly_speed += force * delta
		wobbly_speed += mouse_speed * 75
		skew += wobbly_speed * delta
		rotation += wobbly_speed * delta
		wobbly_speed *= .98
	
	if Input.is_action_just_pressed("WOBBLE"):
		wobbly = not wobbly
	
	if get_tree().paused:
		if not Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		global_position = get_global_mouse_position()
		return
	
	var is_first_person = false
	var rotating = false
	var v_size = Vector2(get_viewport().size.x,get_viewport().size.y)
	var mouse_pos = get_viewport().get_mouse_position()/v_size
	
	if GameManager.Camera:
		is_first_person = (GameManager.Camera.mode == GameManager.Camera.CameraMode.FIRSTPERSON)
		rotating = GameManager.Camera.rotating
		
		if Input.is_action_just_pressed("shift_lock"):
			GameManager.shiftlocked = !GameManager.shiftlocked
	else:
		GameManager.shiftlocked = false
	
	if rotating and !last_rotating:
		last_pos = mouse_pos
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if GameManager.shiftlocked or is_first_person:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			last_pos = mouse_pos # this fixes mouse bugging out after unshiftlock

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		global_position = get_viewport_rect().size / 2
	elif !rotating:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			get_viewport().warp_mouse(last_pos*v_size)
	
	if !Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if !last_rotating and !(get_global_mouse_position().distance_to(get_viewport_rect().size/2)<5):
			global_position = get_global_mouse_position()
		else:
			global_position = last_pos*v_size
	
	last_rotating = rotating
	
	if GameManager.shiftlocked:
		set_icon(ICON.SHIFTLOCK)
	elif get_viewport().gui_get_hovered_control():
		set_icon(ICON.CLICK)
	else:
		set_icon(ICON.NORMAL)

func set_inverted(val:bool):
	var mat = material as ShaderMaterial
	mat.set_shader_parameter("Inverted",val)

func set_icon(icon:ICON):
	frame = icon
	if frame == 2:
		offset = Vector2.ZERO
		scale = Vector2.ONE
	else:
		offset = Vector2.ONE*16
		scale = Vector2.ONE*1.5
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.is_echo():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_inverted(event.is_pressed())
