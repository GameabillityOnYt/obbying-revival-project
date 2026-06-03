# variables

extends Node2D

@onready var Main:Node2D = $Main
@onready var Settings:Node2D = $Settings
@onready var AvatarCustom:Node2D = $AvatarCustom
@onready var Help:Node2D = $Help
@onready var cam:Camera2D = $Camera2D
var button = preload("res://assets/prefabs/UI/LevelCard.tscn")
@onready var title = $Main/Desc/Label
@onready var desc = $Main/Desc/Label2
@onready var list = $Main/Panel/ScrollContainer/VBoxContainer
@onready var version = $Main/Version
@onready var search = $SearchBar
@onready var orig: Array
@onready var sorted: Array
var searchTerm = ""
var current_page: String = "main"

@export var menu_avatar: CharacterAvatarMesh
@export var body_parts: Dictionary[ColorPickerButton, String]

func _ready():

	# -- Level Handlers -- #
	get_window().files_dropped.connect(_file_dragged)
	load_all_levels()
	
	# -- Customization -- #
	print(body_parts)
	for picker in body_parts:
		var part_name: String = body_parts[picker]
		picker.color_changed.connect(func(c): _send_color_to_player(part_name, c))
		picker.color = GameManager.data.body_colors.get(part_name, Color.WHITE)
	
	# -- Grab input for search -- #
	search.draw_control_chars = false
	search.grab_focus(true)

func _send_color_to_player(part: String, color: Color):
	GameManager.data.body_colors[part] = color
	print(GameManager.data.body_colors)
	if menu_avatar:
		menu_avatar.update_part_color(part, color)

	if DiscordRPCManager != null:
		DiscordRPCManager.menu()

func _file_dragged(files:PackedStringArray):
	for x in files:
		if x.ends_with(".json"):
			var file_name = x.get_file()
			print(file_name + " has been dragged into the game!")
			var dest = "user://levels/"+file_name
			
			if FileAccess.file_exists(dest):
				push_warning("Level already exists! Ignoring.")
				return
			
			DirAccess.copy_absolute(x,dest)
			load_all_levels()
		else:
			push_warning("File isn't json! Ignoring.")
	pass

func _on_play_pressed() -> void: # when you press play
	if GameManager.currentLevel != "":
		get_tree().change_scene_to_file("res://custom.tscn")
		
		if DiscordRPCManager != null:
			DiscordRPCManager.playing(GameManager.currentLevel)


func load_level(path): # loads level data and returns it
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
	
func clear_selected_level():
	GameManager.currentLevel = ""
	title.text = "Select a level"
	desc.text = ""

func select_level(path: String, obby_name, difficulty, creator):
	GameManager.currentLevel = path
	title.text = "Selected: %s" % [obby_name]
	desc.text = "Tier: %s\nBy: %s\n\nHit enter to play" % [difficulty, creator]

## Loads all levels in the folder and then adds it to the level list
func load_all_levels():
	
	orig.clear()
	sorted.clear()
	for x in list.get_children():
		x.call_deferred("queue_free")

	var levels = fetch_levels()

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
			select_level(i, obby_name, difficulty, creator)
		)
	orig = list.get_children()
	sorted = orig.duplicate()



## Gets a list of ur levels
func fetch_levels():
	var levels = []
	var dir = DirAccess.open("user://levels")
	
	if dir == null:
		print("no levels folder gng")
		return levels
	
	dir.list_dir_begin()
	var file = dir.get_next()
	
	while file != "":
		if file.ends_with(".json"):
			levels.append("user://levels/" + file)
		file = dir.get_next()
	
	dir.list_dir_end()
	return levels

func search_for_string_that_contains(str: String, arr: Array, orig: String = str):
	if str.length() > 4:
		for item: String in arr:
			if item.contains(str):
				return item
		return search_for_string_that_contains(str.substr(0, str.length()/2), arr, orig)
	else:
		print("Couldn't be found")
		return arr[0]



func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if !event.is_action_pressed("Escape"):
			search.grab_focus(true)
		
		if event.is_action_pressed("Escape"):
			clear_selected_level()
			search.text = ""
			searchTerm = ""
			sort_levels()
			search.release_focus()
			
		if event.is_action_pressed("Enter"):
			if GameManager.currentLevel == "":
				var level_files = fetch_levels()
				var button: Button = list.get_child(0)
				print(list.get_child(0).text)
				var selected_level_path = search_for_string_that_contains(button.text, level_files)
				print(selected_level_path)
				var loaded_level = load_level(selected_level_path)
				
				select_level(
					selected_level_path,
					loaded_level.get("ObbyName", "Undefined Level"),
					loaded_level.get("Difficulty", "Unknown"),
					loaded_level.get("Creator", "Unknown Creator")
				)
			else:
				_on_play_pressed()




# Searching
func sort_levels():	
	if searchTerm != "":
		orig = list.get_children()
		sorted = orig.duplicate()
		
		sorted.sort_custom(
			func(a: Button, b: Button): 
				var is_a = searchTerm.to_lower() in a.text.to_lower()
				var is_b = searchTerm.to_lower() in b.text.to_lower()
				
				if is_a != is_b:
					return is_a
				
				return a.text.to_lower().similarity(searchTerm.to_lower()) > b.text.to_lower().similarity(searchTerm.to_lower())
		)
		
		orig.sort_custom(
			func(a: Button, b: Button):
				return a.text.to_lower() < b.text.to_lower()
		)
		
		for item: Button in orig:
			list.move_child(item, sorted.find(item))

	else:
		
		
		for item: Button in orig:
			list.move_child(item, orig.find(item))

# -- Switching between "pages" -- #

func _on_settings_pressed() -> void: # when you press settings it makes your camera go to the settings area
	current_page = "settings"
	GameManager.set_sliders_enabled(true)
	cam.global_position = Settings.global_position
	
	if DiscordRPCManager != null:
		DiscordRPCManager.settings() # discordrpc settings thingy

func _on_return_to_main_pressed() -> void:
	current_page = "main"
	GameManager.set_sliders_enabled(false)
	cam.global_position = Main.global_position
	
	if DiscordRPCManager != null:
		DiscordRPCManager.menu()

func _on_return_to_settings_pressed() -> void:
	current_page = "settings"
	GameManager.set_sliders_enabled(true)
	cam.global_position = Settings.global_position

func _on_avatar_pressed() -> void:
	current_page = "avatar"
	GameManager.set_sliders_enabled(false)
	cam.global_position = AvatarCustom.global_position

func _on_help_pressed() -> void:
	current_page = "help"
	GameManager.set_sliders_enabled(false)
	cam.global_position = Help.global_position


func _on_search_bar_text_changed(text) -> void:
	searchTerm = search.text
	sort_levels()
