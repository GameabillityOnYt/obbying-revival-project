extends PanelContainer
@onready var name_label: Label = $HBoxContainer/MainMetaContainer/Name
@onready var creator_label: Label = $HBoxContainer/MainMetaContainer/Creator
@onready var difficulty_label: Label = $HBoxContainer/DifficultyContainer/Difficulty
@onready var difficulty_container: PanelContainer = $HBoxContainer/DifficultyContainer

func setup(obby_name: String, creator: String, difficulty: String, diff_color: Color) -> void:
	name_label.text = obby_name
	creator_label.text = "by " + creator
	difficulty_label.text = difficulty
	
	# Handle StyleBox internally
	var stylebox = difficulty_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if stylebox:
		stylebox.border_color = diff_color
		difficulty_container.add_theme_stylebox_override("panel", stylebox)

func _on_button_pressed() -> void:
	get_tree().current_scene.loadAndGotoGame(self.get_meta("path"))
	pass # Replace with function body.
