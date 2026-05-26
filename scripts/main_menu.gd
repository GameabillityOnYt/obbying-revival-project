extends Node2D

@onready var Main:Node2D = $Main
@onready var Settings:Node2D = $Settings
@onready var AvatarCustom:Node2D = $AvatarCustom
@onready var cam:Camera2D = $Camera2D
var button = preload("res://assets/prefabs/UI/LevelCard.tscn")
@onready var title = $Main/Desc/Label
@onready var desc = $Main/Desc/Label2
@onready var list = $Main/Panel/ScrollContainer/VBoxContainer
@onready var file_dialog = $FileDialog

@export var menu_avatar: CharacterAvatarMesh
@export var body_parts: Dictionary[ColorPickerButton, String]

@export var menu_avatar: CharacterAvatarMesh
@export var body_parts: Dictionary[ColorPickerButton, String]

func _ready():
	OS.request_permissions()
	var perms = OS.get_granted_permissions()
	if not (perms.has("android.permission.READ_EXTERNAL_STORAGE") or perms.has("android.permission.MANAGE_EXTERNAL_STORAGE")):
		$Main/warn.show()
	
	#var levels = load_all_levels()
	#for i in levels:
		#var level = load_level(i)
		#
		#if not level or typeof(level) != TYPE_DICTIONARY:
			#push_warning("Level data at index " + str(i) + " is invalid.")
			#continue
#
		#var obby_name = level.get("ObbyName", "Undefined Level")
		#var difficulty = level.get("Difficulty", "Unknown")
		#var creator = level.get("Creator", "Unknown Creator")
#
		#var buttonthing = button.instantiate()
		#buttonthing.text = obby_name
		#list.add_child(buttonthing)
		#
		#buttonthing.pressed.connect(func():
			#GameManager.currentLevel = i
			#descLabel.text = "Selected: %s\nTier: %s\nBy: %s" % [obby_name, difficulty, creator]
		#)
	get_window().files_dropped.connect(_file_dragged)
	load_all_levels()
	
	for picker in body_parts:
		var part_name: String = body_parts[picker]
		picker.color_changed.connect(func(c): _send_color_to_player(part_name, c))
		picker.color = GameManager.data.body_colors.get(part_name, Color.WHITE)
	
# 
func _send_color_to_player(part: String, color: Color):
	GameManager.data.body_colors[part] = color
	
	if menu_avatar:
		menu_avatar.update_part_color(part, color)

func _file_dragged(files:PackedStringArray):
	for x in files:
		if x.ends_with(".json"):
			print("level lowk dragged")
			var file_name = x.get_file()
			print(file_name)
			var dest = "user://levels/"+file_name
			
			if FileAccess.file_exists(dest):
				push_warning("Level already exists! Ignoring.")
				return
			
			DirAccess.copy_absolute(x,dest)
			load_all_levels()
		else:
			print("file not json durr")
	pass


	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://custom.tscn")
	
	if DiscordRPCManager != null:
		DiscordRPCManager.playing(GameManager.currentLevel)



func _on_settings_pressed() -> void:
	cam.global_position = Settings.global_position
	
	if DiscordRPCManager != null:
		DiscordRPCManager.settings()



func _on_return_to_main_pressed() -> void:
	cam.global_position = Main.global_position
	
	if DiscordRPCManager != null:
		DiscordRPCManager.menu()

func _on_return_to_settings_pressed() -> void:
	cam.global_position = Settings.global_position

func _on_avatar_pressed() -> void:
	cam.global_position = AvatarCustom.global_position

func load_level(path):
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		print("failed to open file " + path)
		return
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) != OK:
		print("invalid json ", path)
		return
	var data = json.data
	return data


func load_all_levels(dir_path = "user://levels"):
	for x in list.get_children():
		x.call_deferred("queue_free")
	var levels = fetch_levels(dir_path)

	for i in levels:
		var level = load_level(i)
		
		if not level or typeof(level) != TYPE_DICTIONARY:
			push_warning("Level data at index " + str(i) + " is invalid.")
			continue

		var obby_name = level.get("ObbyName", "Undefined Level")
		var difficulty = level.get("Difficulty", "Unknown")
		var creator = level.get("Creator", "Unknown Creator")

		var buttonthing = button.instantiate()
		buttonthing.text = obby_name
		list.add_child(buttonthing)
		
		buttonthing.pressed.connect(func():
			GameManager.currentLevel = i
			title.text = "Selected: %s" % [obby_name]
			desc.text = "Tier: %s\nBy: %s" % [difficulty, creator]
		)

func fetch_levels(dir_path = "user://levels"):
	var levels = []
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		print("no levels folder gng")
		return levels
	
	dir.list_dir_begin()
	var file = dir.get_next()
	print(file)
	while file != "":
		if file.ends_with(".json"):
			levels.append(dir_path + "/" + file)
		file = dir.get_next()
	
	dir.list_dir_end()
	return levels


func _on_load_folder_pressed() -> void:
	file_dialog.show()


func _on_file_dialog_dir_selected(dir: String) -> void:
	load_all_levels(dir)
