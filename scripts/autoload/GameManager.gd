extends Node

@export var data:PlayerData = PlayerData.new()
signal DataLoaded
signal CharacterAdded(Player)

@export var Camera:Camera3D
@export var shiftlocked:bool = false

func _ready():
	get_window().mode = Window.MODE_WINDOWED
	if FileAccess.file_exists("user://data.tres"):
		data = ResourceLoader.load("user://data.tres")
	else:
		data = PlayerData.new()
		ResourceSaver.save(data,"user://data.tres")
	DataLoaded.emit()
	
	data.MaxFPSChanged.connect(func(new):
		Engine.max_fps = int(new)
		pass)
	Engine.max_fps = int(data.maxFPS)
	
	CharacterAdded.connect(func(new:Player):
		var rand = get_tree().get_nodes_in_group("SpawnLocation").pick_random()
		new.global_position = rand.global_position + Vector3(0,1,0)
		print("loaded character")
		pass)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ResourceSaver.save(data,"user://data.tres")
		get_tree().quit()
