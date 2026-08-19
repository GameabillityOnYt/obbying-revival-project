extends Control

@onready var current_scene = get_tree().current_scene
@onready var splashNode = $CenterContainer/VBoxContainer/LogoContainer/Splash

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var splashes = FileAccess.get_file_as_string("res://assets/prefabs/UI/mmv2/splashes.txt").split("\n", false)
	var splash = Array(splashes).pick_random()
	splashNode.text = splash
	var tween = create_tween().bind_node(self).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.set_loops()
	tween.tween_property(splashNode, "offset_transform_scale", Vector2(1.1, 1.1), 0.4)
	tween.tween_property(splashNode, "offset_transform_scale", Vector2(1, 1), 0.4)
	pass # Replace with function body.

func quitgame() -> void:
	get_tree().quit(0)
	pass

func _on_local_levels_pressed() -> void:
	current_scene.switchToScreen("LocalLevels")
	pass # Replace with function body.


func _on_help_pressed() -> void:
	current_scene.switchToScreen("Help")
	pass # Replace with function body.


func _on_settings_pressed() -> void:
	current_scene.switchToScreen("Settings")
	pass # Replace with function body.


func _on_quit_game_pressed() -> void:
	$ConfirmationDialog.popup_centered()
	pass # Replace with function body.


func _on_confirmation_dialog_confirmed() -> void:
	quitgame()
	pass # Replace with function body.


func _on_confirmation_dialog_canceled() -> void:
	$ConfirmationDialog.hide()
	pass # Replace with function body.


func _on_online_pressed() -> void:
	current_scene.switchToScreen("Online")
	pass # Replace with function body.
