extends CheckButton

func _ready() -> void:
	self.button_pressed = GameManager.data.rpc_enabled

func _on_toggled(toggled_on: bool) -> void:
	GameManager.data.rpc_enabled = toggled_on
