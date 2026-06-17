extends CheckButton

func _ready() -> void:
	self.button_pressed = GameManager.data.menuTransitions

func _on_toggled(toggled_on: bool) -> void:
	GameManager.data.menuTransitions = toggled_on
