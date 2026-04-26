extends AnimatedSprite2D

enum ICON {NORMAL, CLICK, SHIFTLOCK}

func _process(_delta: float) -> void:
	var is_first_person = false
	if GameManager.Camera:
		is_first_person = (GameManager.Camera.mode == GameManager.Camera.CameraMode.FIRSTPERSON)

	if is_first_person or GameManager.shiftlocked:
		global_position = get_viewport_rect().size / 2
	else:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			global_position = get_global_mouse_position()

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
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.is_echo():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_inverted(event.is_pressed())
