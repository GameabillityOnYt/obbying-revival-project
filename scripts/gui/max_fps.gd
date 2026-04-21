extends SpinBox

func _ready():
	value = GameManager.data.maxFPS

func _on_value_changed(new: int) -> void:
	GameManager.data.maxFPS = new
