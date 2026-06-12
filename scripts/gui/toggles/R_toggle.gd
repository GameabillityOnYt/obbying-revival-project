extends CheckButton

func _ready() -> void:
	self.button_pressed = GameManager.data.RToggle

func _on_toggled(toggled_on: bool) -> void:
	GameManager.data.RToggle = toggled_on
