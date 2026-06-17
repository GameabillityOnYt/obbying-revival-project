extends CheckButton

func _ready() -> void:
	self.button_pressed = GameManager.RToggle

func _on_toggled(toggled_on: bool) -> void:
	GameManager.RToggle = toggled_on
