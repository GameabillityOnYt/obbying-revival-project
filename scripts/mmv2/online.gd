extends Control

@onready var current_scene = get_tree().current_scene

func _on_back_pressed() -> void:
	current_scene.switchToScreen("MainScreen")
	pass # Replace with function body.


func _on_levels_pressed() -> void:
	current_scene.switchToScreen("OnlineLevels")
	pass # Replace with function body.
