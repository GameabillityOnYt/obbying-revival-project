extends CheckButton

func _on_toggled(toggled_on: bool) -> void:
	GameManager.nfToggle = toggled_on
	print(GameManager.nfToggle)
