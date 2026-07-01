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
@onready var search = $Main/SearchBar
@onready var orig: Array
@onready var sorted: Array
var searchTerm = ""
var current_page: String = "main"
@onready var pin_button = $Main/SearchBar/PinToggle
var can_search_pinned = false


@export var menu_avatar: CharacterAvatarMesh
@export var body_parts: Dictionary[ColorPickerButton, String]

@onready var context_menu: PopupMenu = $ContextMenu
var pinned_levels: Array = []
var context_level_path: String = ""
var current_focus

func _ready():
	# -- Level Handlers -- #
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	get_window().files_dropped.connect(_file_dragged)
	_load_pinned_levels_from_file()
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	load_all_levels()
	
	# -- Customization -- #
	print(body_parts)
	for picker in body_parts:
		var part_name: String = body_parts[picker]
		picker.color_changed.connect(func(c): _send_color_to_player(part_name, c))
		picker.color = GameManager.data.body_colors.get(part_name, Color.WHITE)
	
	# -- Pin toggle stuff -- #
	pin_button.add_theme_stylebox_override("pressed", pin_button.get_theme_stylebox("hover"))
	# -- Grab input for search -- #
	if search != null:
		search.draw_control_chars = false
		search.grab_focus()
	else:
		push_warning("SearchBar node not found at $SearchBar! Check your scene tree hierarchy.")

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

func format_playtime(total_seconds: float) -> String:
	var seconds := int(total_seconds) % 60
	var minutes := int(total_seconds / 60) % 60
	var hours := int(total_seconds / 3600) % 24
	var days := int(total_seconds / 86400)
	
	var result = ""
	

	if days > 0:
		result += "%dd " % days
	if hours > 0 or days > 0:
		result += "%dh " % hours
	if minutes > 0 or hours > 0 or days > 0:
		result += "%dm " % minutes
		
	# Always show seconds at the end
	result += "%ds" % seconds
	
	return result

func select_level(path: String, obby_name, difficulty, creator):
	GameManager.currentLevel = path
	# lvl info
	
	var lvl_name = obby_name 
	var lvl_time = GameManager.leveldata.level_playtime.get(GameManager.currentLevel, 0.0)
	var lvl_attempts = GameManager.leveldata.level_attempts.get(GameManager.currentLevel, 0)
	var formatted_time = format_playtime(lvl_time)
	
	title.text = "Selected: %s" % [lvl_name]
	desc.text = "Tier: %s\nBy: %s\n\nLevel Playtime: %s\nLevel Attempts: %d\n\nHit enter to play" % [
		difficulty, 
		creator, 
		formatted_time,
		lvl_attempts
	]
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

		var buttonthing: Button = button.instantiate()
		var is_pinned = i in pinned_levels
		buttonthing.text = ("📌 " if is_pinned else "") + obby_name
		buttonthing.set_meta("pinned", is_pinned)
		buttonthing.set_meta("level_path", i)
		
		list.add_child(buttonthing)

		buttonthing.pressed.connect(func():
			select_level(i, obby_name, difficulty, creator)
		)

		buttonthing.gui_input.connect(func(event):
			_on_level_card_gui_input(event, i)
		)
		
	orig = list.get_children()
	sorted = orig.duplicate()
	sort_levels()

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

func _clear_search():
	clear_selected_level()
	if search != null:
		search.text = ""
	searchTerm = ""
	sort_levels()
	if search != null:
		search.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and current_page == "main":
		if search != null and !event.is_action_pressed("Escape"):
			search.grab_focus()
		
		if event.is_action_pressed("Pin Search"):
			pin_button.button_pressed = !can_search_pinned

		if event.is_action_pressed("Escape"):
			_clear_search()
			
		if event.is_action_pressed("Enter"):
			if current_page != "main":
				return
			if GameManager.currentLevel == "":
				var level_files = fetch_levels()
				var button: Button = list.get_child(0)
				print(list.get_child(0).text)
				button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
				var selected_level_path = _get_path_for_button(button)
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
				var path_a = _get_path_for_button(a)
				var path_b = _get_path_for_button(b)
				var pin_a = path_a in pinned_levels
				var pin_b = path_b in pinned_levels
				if can_search_pinned:
					if pin_a != pin_b:
						return pin_a
					
					if pin_a and pin_b:
						return a.text.substr(1).to_lower().similarity(searchTerm.to_lower()) > b.text.substr(1).to_lower().similarity(searchTerm.to_lower())
						# return pinned_levels.find(path_a) < pinned_levels.find(path_b)
				
				var is_a = searchTerm.to_lower() in a.text.to_lower()
				var is_b = searchTerm.to_lower() in b.text.to_lower()
				
				if is_a != is_b:
					return is_a
				
				return a.text.to_lower().similarity(searchTerm.to_lower()) > b.text.to_lower().similarity(searchTerm.to_lower())
		)
		
		orig.sort_custom(
			func(a: Button, b: Button):
				var path_a = _get_path_for_button(a)
				var path_b = _get_path_for_button(b)
				var pin_a = path_a in pinned_levels
				var pin_b = path_b in pinned_levels

				if pin_a != pin_b:
					return pin_a
				
				if pin_a and pin_b:
					return pinned_levels.find(path_a) < pinned_levels.find(path_b)

				return a.text.to_lower() < b.text.to_lower()
		)
		
		for item: Button in orig:
			list.move_child(item, sorted.find(item))

	else:
		
		orig.sort_custom(
			func(a: Button, b: Button):
				var path_a = _get_path_for_button(a)
				var path_b = _get_path_for_button(b)
				var pin_a = path_a in pinned_levels
				var pin_b = path_b in pinned_levels
				

				if pin_a != pin_b:
					return pin_a
				
				if pin_a and pin_b:
					return pinned_levels.find(path_a) < pinned_levels.find(path_b)

				return orig.find(a) < orig.find(b)
		)
		
		for item: Button in orig:
			list.move_child(item, orig.find(item))

func _get_path_for_button(btn: Button) -> String:
	if btn.has_meta("level_path"):
		return btn.get_meta("level_path")
	return ""

func _on_level_card_gui_input(event: InputEvent, path: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and context_menu:
		context_level_path = path
		context_menu.clear()
		# i'm doing everything here because idk how to add on context menu
		# also it should be dynamic so yeah
		var is_pinned = path in pinned_levels
		context_menu.add_item("Unpin Level" if is_pinned else "Pin Level", 0)
		if is_pinned:
			context_menu.add_item("Move Up", 1)
			context_menu.add_item("Move Down", 2)
		context_menu.add_item("Delete Level",3)
		context_menu.position = get_viewport().get_mouse_position()
		context_menu.show()

func _on_context_menu_id_pressed(id: int):
	if context_level_path == "":
		return
	
	match id:
		0:
			_toggle_pin_level(context_level_path)
		1:
			var idx = pinned_levels.find(context_level_path)
			if idx > 0:
				var temp = pinned_levels[idx]
				pinned_levels[idx] = pinned_levels[idx - 1]
				pinned_levels[idx - 1] = temp
				_save_pinned_levels_to_file()
				load_all_levels()
		2:
			var idx = pinned_levels.find(context_level_path)
			if idx != -1 and idx < pinned_levels.size() - 1:
				var temp = pinned_levels[idx]
				pinned_levels[idx] = pinned_levels[idx + 1]
				pinned_levels[idx + 1] = temp
				_save_pinned_levels_to_file()
				load_all_levels()
		3:
			print("deleted level: " + context_level_path)
			DirAccess.remove_absolute(context_level_path)
			load_all_levels()


func _toggle_pin_level(path: String):
	if path in pinned_levels:
		pinned_levels.erase(path)
	else:
		pinned_levels.append(path)
	
	_save_pinned_levels_to_file()
	load_all_levels()

func _load_pinned_levels_from_file():
	if GameManager.data != null and "pinned_levels" in GameManager.data:
		pinned_levels = GameManager.data.pinned_levels
		return
		
	if FileAccess.file_exists("user://pinned_levels.json"):
		var file = FileAccess.open("user://pinned_levels.json", FileAccess.READ)
		if file != null:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK:
				if typeof(json.data) == TYPE_ARRAY:
					pinned_levels = json.data
					return
	pinned_levels = []

func _save_pinned_levels_to_file():
	if GameManager.data != null and "pinned_levels" in GameManager.data:
		GameManager.data.pinned_levels = pinned_levels
		ResourceSaver.save(GameManager.data, "user://data.tres")
		return
		
	var file = FileAccess.open("user://pinned_levels.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(pinned_levels))

# -- Switching between "pages" -- #

func _on_settings_pressed() -> void: # when you press settings it makes your camera go to the settings area
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	current_page = "settings"
	cam.global_position = Settings.global_position
	
	if DiscordRPCManager != null:
		DiscordRPCManager.settings() # discordrpc settings thingy

func _on_return_to_main_pressed() -> void:
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	current_page = "main"
	cam.global_position = Main.global_position
	
	if search != null:
		search.grab_focus()
	
	if DiscordRPCManager != null:
		DiscordRPCManager.menu()

func _on_return_to_settings_pressed() -> void:
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	current_page = "settings"
	cam.global_position = Settings.global_position

func _on_avatar_pressed() -> void:
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	current_page = "avatar"
	cam.global_position = AvatarCustom.global_position

func _on_help_pressed() -> void:
	$Camera2D.position_smoothing_enabled = GameManager.data.menuTransitions
	current_page = "help"
	cam.global_position = Help.global_position


func _on_search_bar_text_changed(text) -> void:
	if search != null:
		searchTerm = search.text
	else:
		searchTerm = text
	sort_levels()

func _on_pin_toggle_toggled(toggled_on: bool) -> void:
	can_search_pinned = not can_search_pinned
	_clear_search()
