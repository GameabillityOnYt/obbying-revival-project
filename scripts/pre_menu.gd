extends Control

func _ready() -> void:
	$Label.text = "Loading data"
	if !GameManager.data: await GameManager.DataLoaded
	get_tree().call_deferred("change_scene_to_file","res://scenes/MainMenu.tscn")
	
