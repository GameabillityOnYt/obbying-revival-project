extends Control

@onready var current_scene = get_tree().current_scene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.





func _on_local_levels_pressed() -> void:
	current_scene.switchToScreen("LocalLevels")
	pass # Replace with function body.
