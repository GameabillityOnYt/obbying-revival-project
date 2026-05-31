extends Control

func toggle_paused():
	get_tree().paused = !get_tree().paused
	
	var paused = get_tree().paused
	
	$ControlText.text = "WASD - Walking\nSpace - Jump"

	if GameManager.alljump and GameManager.nfToggle:
		$ControlText.text += """\n
	Checkpoints:
	F - Place Checkpoint
	V - Remove Checkpoint
	R/Ctrl + R - TP to Checkpoint

	Shift + P - Toggle on/off freecam
	1 - Toggle on/off noclip"""

	elif GameManager.alljump:
		$ControlText.text += """\n
	Checkpoints:
	F - Place Checkpoint
	V - Remove Checkpoint
	R/Ctrl + R - TP to Checkpoint"""

	elif GameManager.nfToggle:
		$ControlText.text += """
	R/Ctrl + R - Reset to Spawn

	Shift + P - Toggle on/off freecam
	1 - Toggle on/off noclip
	Q/E - Change speed of Noclip"""

	else:
		$ControlText.text += "\nR/Ctrl + R - Reset to Spawn"
	
	var intween = create_tween()
	intween.set_ease(Tween.EASE_IN_OUT)
	intween.set_trans(Tween.TRANS_CUBIC)
	intween.bind_node(self)
	intween.tween_property(self,"position",Vector2.ZERO if paused else Vector2(0,-720),.5)
	
	if !get_tree().paused:
		get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void: # lets u like press esc l enter to leave
	if event is InputEventKey:
		if !event.is_echo() and event.is_pressed():
			if event.keycode == KEY_ESCAPE :
				toggle_paused()
			if get_tree().paused:
				if event.keycode == KEY_L:
					$Menu.grab_focus()
				if event.keycode == KEY_Q:
					$Quit.grab_focus()
			
func _ready():
	$Back.pressed.connect(toggle_paused) # runs the toggle_paused function when u press the back to game button
	
	$Menu.pressed.connect(func():
		get_tree().call_deferred("change_scene_to_file","res://scenes/MainMenu.tscn") # changes scene to menu
		get_tree().paused = false # turns off paused
		GameManager.alljump = false # turns off alljump when u go out of the game
		GameManager.currentLevel = ""
		pass)
	
	$Quit.pressed.connect(func():
		GameManager._notification(NOTIFICATION_WM_CLOSE_REQUEST) # closes window
		pass)
