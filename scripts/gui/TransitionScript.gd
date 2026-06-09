extends Control

@onready var togg_360 = $DoA360

func _ready():
	togg_360.toggled.connect(on_toggle_360)
	
	GameManager.menu360 = togg_360.button_pressed

func on_toggle_360(state: bool):
	GameManager.menu360 = state
