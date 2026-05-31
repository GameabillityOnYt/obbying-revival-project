extends CheckButton

func _on_toggled(toggled_on: bool) -> void:
	GameManager.alljump = toggled_on
	print(GameManager.alljump)
