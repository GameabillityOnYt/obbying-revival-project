extends PanelContainer
@onready var name_label: Label = $HBoxContainer/MainMetaContainer/Name
@onready var creator_label: Label = $HBoxContainer/MainMetaContainer/Creator
@onready var difficulty_label: Label = $HBoxContainer/DifficultyContainer/Difficulty
@onready var difficulty_container: PanelContainer = $HBoxContainer/DifficultyContainer

signal rightclick
signal leftclick

func setup(obby_name: String, creator: String, difficulty: String, diff_color: Color, downloads=null, featured=null) -> void:
	if not is_node_ready():
		await is_node_ready()
	name_label.text = obby_name
	creator_label.text = "by " + creator
	if downloads != null:
		creator_label.text = "by " + creator + (", %d dl." % downloads)
	difficulty_label.text = difficulty
	
	# Handle StyleBox internally
	var stylebox = difficulty_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if stylebox:
		stylebox.border_color = diff_color
		difficulty_container.add_theme_stylebox_override("panel", stylebox)
	if featured == 1.0:
		var sb2 = StyleBoxFlat.new()
		var sb3 = StyleBoxFlat.new()
		var sb4 = StyleBoxFlat.new()
		sb2.bg_color = Color(0.44, 0.41, 0.00, 0.60)
		sb3.bg_color = Color(0.697, 0.651, 0.0, 0.6)
		sb4.bg_color = Color(0.271, 0.252, 0.0, 0.6)
		sb2.corner_detail = 5
		sb3.corner_detail = 5
		sb4.corner_detail = 5
		$Button.add_theme_stylebox_override("normal", sb2)
		$Button.add_theme_stylebox_override("hover", sb3)
		$Button.add_theme_stylebox_override("pressed", sb4)
	print(obby_name, featured)

func _on_button_pressed() -> void:
	leftclick.emit()
	pass # Replace with function body.


func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		rightclick.emit()
	pass # Replace with function body.
