extends CheckButton

func _on_toggled(toggled_on: bool) -> void:
	GameManager.practice = toggled_on
	print(GameManager.practice)
