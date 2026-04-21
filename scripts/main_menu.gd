extends Node2D

@onready var Main:Node2D = $Main
@onready var Settings:Node2D = $Settings
@onready var cam:Camera2D = $Camera2D

func _ready():
	print("ready")
	pass

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")

func _on_settings_pressed() -> void:
	cam.global_position = Settings.global_position

func _on_return_to_main_pressed() -> void:
	cam.global_position = Main.global_position
