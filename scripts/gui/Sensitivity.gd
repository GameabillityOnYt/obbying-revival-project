extends HSlider

@export var Player: CharacterBody3D


func _on_value_changed(value: float) -> void:
	Player.sensitivity = value / 1000
	print(Player.sensitivity)
