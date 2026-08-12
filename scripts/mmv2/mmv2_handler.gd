extends Node3D

const difficultyColors: Dictionary = {
	"25" = "#333333",
	"24" = "#6B9330",
	"23" = "#6C367F",
	"22" = "#732D2D",
	"21" = "#607D6F",
	"20" = "#A17726",
	"19" = "#3E5273",
	"18" = "#56873C",
	"17" = "#999999",
	"16" = "#D75A7F",
	"15" = "#74ACDE",
	"14" = "#597095",
	"13" = "#BCB0B8",
	"12" = "#E9A141",
	"11" = "#C6C8D3",
	"10" = "#BFCDDA",
	"9" = "#B7D1E1",
	"8" = "#AFDAE9",
	"7" = "#A6E3F2",
	"6" = "#9DECF9",
	"5" = "#A4EDAE",
	"4" = "#ADE8B4",
	"3" = "#B7E3BD",
	"2" = "#C0ECC7",
	"1" = "#C6F6D5",
	"0" = "#FFFFFF"
}

@onready var camera = $Camera3D
@onready var screensContainer = $MainMenuControlContainer/Control
@onready var screens: Dictionary[String, Control] = {
	MainScreen = screensContainer.get_node("MainScreen"),
	LocalLevels = screensContainer.get_node("LocalLevels")
}
@onready var tree = get_tree()
@export var TransitionTime = 0.4
@export var OffScreenPosition = Vector2(900, 0)
var panorama_rotation = 0
var currentScreen = "MainScreen"

func switchToScreen(screenName: String) -> void:
	var oldScreen = screens[currentScreen]
	oldScreen.process_mode = Node.PROCESS_MODE_DISABLED
	currentScreen = screenName
	
	var newScreen = screens[screenName]
	newScreen.show()
	newScreen.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tweenout = tree.create_tween().bind_node(self).set_ease(Tween.EASE_OUT).set_parallel(true)
	tweenout.tween_property(oldScreen, "modulate", Color.TRANSPARENT, TransitionTime).set_trans(Tween.TRANS_SINE)
	tweenout.tween_property(oldScreen, "position", OffScreenPosition, TransitionTime).set_trans(Tween.TRANS_QUAD)
	tweenout.tween_property(newScreen, "modulate", Color.WHITE, TransitionTime).set_trans(Tween.TRANS_SINE)
	tweenout.tween_property(newScreen, "position", Vector2.ZERO, TransitionTime).set_trans(Tween.TRANS_QUAD)
	tweenout.chain().tween_callback(func():
		oldScreen.hide()
	)

func fetchLevelsDirectory() -> Array: # (inherit)
	var levels = []
	var dir = DirAccess.open("user://levels")
	
	if dir == null:
		print_debug("no levels folder gng")
		return levels
	
	dir.list_dir_begin()
	var file = dir.get_next()
	
	while file != "":
		if file.ends_with(".json") or file.ends_with(".bin"):
			levels.append("user://levels/" + file)
		file = dir.get_next()
	
	dir.list_dir_end()
	return levels
	
func readBinaryString(sp: StreamPeerBuffer) -> String: # (inherit)
	if sp.get_available_bytes() < 1: 
		return ""
	var length = sp.get_u8()
	if length == 0: 
		return ""
	
	# 300 character limit on names
	if length > 300:
		push_error("String length is too large")
		return ""
		
	if sp.get_available_bytes() < length:
		push_error("File ended before string could be fully read.")
		return ""
		
	var string_bytes = sp.get_data(length)
	if string_bytes[0] != OK:
		return ""
	return (string_bytes[1] as PackedByteArray).get_string_from_utf8()

func fetchLevelMetadata(path): # loads level data and returns it (inherit)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0:
		print_debug("failed to open file " + path)
		return
	
	# checks if it's JSON or Binary
	var first_byte = file.get_8()
	file.seek(0)
	
	if first_byte == 123 or first_byte == 91: # '{' or '['
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) != OK:
			print_debug("invalid json ", path)
			return
		
		return {
			"ObbyName": json.data.ObbyName,
			"Difficulty": json.data.Difficulty,
			"Creator": json.data.Creator
		}
	else: 
		var sp = StreamPeerBuffer.new()
		sp.data_array = file.get_buffer(file.get_length())
		
		var obby_name = readBinaryString(sp)
		var obby_diff = readBinaryString(sp)
		var obby_creator = readBinaryString(sp)
		
		return {
			"ObbyName": obby_name,
			"Difficulty": obby_diff,
			"Creator": obby_creator
		}

func getColorOfDifficulty(difficulty) -> String:
	var diffColor = difficultyColors.get(difficulty, "#FFFFFF")
	return diffColor

func loadAndGotoGame(path):
	GameManager.currentLevel = path
	tree.change_scene_to_file("res://custom.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for key in screens:
		var screen: Control = screens[key]
		screen.modulate = Color.TRANSPARENT
		screen.position = OffScreenPosition
		screen.hide()
	
	screens[currentScreen].modulate = Color.WHITE
	screens[currentScreen].position = Vector2.ZERO
	screens[currentScreen].show()
	screens[currentScreen].process_mode = Node.PROCESS_MODE_INHERIT
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	panorama_rotation = fmod(panorama_rotation + delta * 0.03, 360.0) 
	var panorama_normal = panorama_rotation - 180.0
	camera.rotation = Vector3(0, panorama_rotation, 0)
	pass
