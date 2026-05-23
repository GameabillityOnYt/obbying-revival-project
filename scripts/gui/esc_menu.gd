extends Control

func toggle_paused():
	get_tree().paused = !get_tree().paused
	var paused = get_tree().paused
	var intween = create_tween()
	intween.set_ease(Tween.EASE_IN_OUT)
	intween.set_trans(Tween.TRANS_CUBIC)
	intween.bind_node(self)
	intween.tween_property(self,"position",Vector2.ZERO if paused else Vector2(0,-720),.5)
	if !get_tree().paused: get_viewport().gui_release_focus()
	@warning_ignore("incompatible_ternary")

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and !event.is_echo() and event.is_pressed():
			toggle_paused()
			
func _ready():
	$Back.pressed.connect(toggle_paused)
	$Menu.pressed.connect(func():
		get_tree().call_deferred("change_scene_to_file","res://scenes/MainMenu.tscn")
		get_tree().paused = false
		GameManager.alljump = false
		pass)
	$Quit.pressed.connect(func():
		GameManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
		pass)
