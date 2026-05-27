extends Node

const VERSIONLINK = "https://raw.githubusercontent.com/GameabillityOnYt/obbying-revival-project/refs/heads/main/version.txt"
const TARGETRATIO = 16.0/9.0

@onready var window = get_window()
@export var data:PlayerData = PlayerData.new()
@export var currentLevel:String
@export var Camera:CamStuff
@export var shiftlocked:bool = false
@export var alljump:bool = false
@export var RToggle:bool = false

signal DataLoaded
signal CharacterAdded(Player)
signal VersionLoaded

var version_latest:String   #  This is the latest version from github - danki
var version:String          #  The current version - danki

func _init() -> void:
	# Loading playerdata
	if FileAccess.file_exists("user://data.tres"):
		data = ResourceLoader.load("user://data.tres")
	else:
		data = PlayerData.new()
		ResourceSaver.save(data,"user://data.tres")
	DataLoaded.emit() # Telling game its done loading
	
	if RenderingServer.get_current_rendering_method() != data.renderer:
		OS.create_instance(["--rendering-method",data.renderer])
		OS.kill(OS.get_process_id())
	
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			toggle_fullscreen()

func toggle_fullscreen():
	if window.mode == Window.MODE_WINDOWED:
		window.mode = Window.MODE_FULLSCREEN # take a wild guess on what this does
	else:
		window.mode = Window.MODE_WINDOWED

# fullscreen (not) copyrighted by Tob Odin Odin and (not) only allowed in ORP usage.

func copy_default_levels():
	var source_dir = DirAccess.open("res://mainlevels")
	if source_dir == null:
		print("Failed to open res://mainlevels")
		return

	source_dir.list_dir_begin()

	while true:
		var file_name = source_dir.get_next()

		if file_name == "":
			break

		if source_dir.current_is_dir():
			continue

		var source_path = "res://mainlevels/" + file_name
		var target_path = "user://levels/" + file_name

		if FileAccess.file_exists(target_path):
			continue

		var source_file = FileAccess.open(source_path, FileAccess.READ)
		if source_file == null:
			continue

		var lvl_data = source_file.get_buffer(source_file.get_length())

		var target_file = FileAccess.open(target_path, FileAccess.WRITE)
		if target_file == null:
			continue

		target_file.store_buffer(lvl_data)

		print("Copied level:", file_name)

	source_dir.list_dir_end()

func ensure_levels_folder(): # makes sure that levels exists lol
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("levels"):
		dir.make_dir("levels")

func _ready():
	print(RenderingServer.get_current_rendering_method())
	var open = FileAccess.open("res://version.txt",FileAccess.READ)
	version = open.get_as_text()
	open.close()
	var request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		if result == OK:
			version_latest = body.get_string_from_utf8()
			VersionLoaded.emit()
		pass)
		
	request.request(VERSIONLINK,[],HTTPClient.METHOD_GET)
	
	# Window + Mouse Setup
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	get_window().mode = Window.MODE_WINDOWED
	ensure_levels_folder()
	copy_default_levels()
	
	# Fps handling thing
	data.MaxFPSChanged.connect(func(new):
		Engine.max_fps = int(new)
		pass)
	Engine.max_fps = int(data.maxFPS)
	
	# Yep
	CharacterAdded.connect(func(new):
		var rand = get_tree().get_nodes_in_group("SpawnLocation").pick_random()
		new.global_position = rand.global_position + Vector3(0,1,0)
		pass)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if !OS.is_restart_on_exit_set():
			ResourceSaver.save(data,"user://data.tres")
		get_tree().quit()
