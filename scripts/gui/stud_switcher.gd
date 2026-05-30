extends OptionButton

const vals = ["ORP Style", "Roblox Style"]

func _ready() -> void:
	clear()
	for item in vals: add_item(item)
	selected = 1 if GameManager.RobloxStuds else 0

func _on_item_selected(index: int) -> void:
	GameManager.RobloxStuds = (index == 1)
	ResourceSaver.save(GameManager.data, "user://data.tres")
