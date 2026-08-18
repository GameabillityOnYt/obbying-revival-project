extends Control

@onready var current_scene = get_tree().current_scene
@onready var levelsContainer = $CenterContainer/VBoxContainer/OnlineLevelsList/VBoxContainer
@onready var statusLabel = $CenterContainer/VBoxContainer/Label
var request = 0
var level_button = preload("res://assets/prefabs/UI/mmv2/levelbutton.tscn")
var httpc = Httpc.new()

var downloading = false

func _setstate(state) -> void:
	statusLabel.text = state
	pass


func _playlevel(id: int) -> void:
	if downloading: return
	downloading = true
	var cache_dir = "user://customcache/"
	var path = cache_dir + "%d.onlinecache" % id
	
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)
	
	# 1. Use local cache if present
	if FileAccess.file_exists(path):
		print("Loading level %d from local cache..." % id)
		current_scene.loadAndGotoGame(path)
		return
	
	_setstate("Downloading level...")
	
	var result = await httpc.request(current_scene, "downloadlevel", false, [
		"id=" + str(id)
	])
	
	if not result or not result.success:
		_setstate("Failed to download level.")
		return
	
	var cachefile = FileAccess.open(path, FileAccess.WRITE)
	if cachefile:
		if result.data is PackedByteArray:
			cachefile.store_buffer(result.data)
		else:
			cachefile.store_string(str(result.data))
		cachefile.close()
		
		_setstate("Download complete!")
		current_scene.loadAndGotoGame(path)
	else:
		_setstate("Error writing cache file to disk.")
	downloading = false


func _launch_level_file(file_path: String) -> void:
	# Add your logic to parse the file and transition scenes here
	print("Launching level file from: ", file_path)


func _putresults(results) -> void:
	for level in results:
		var newLevelButton = level_button.instantiate()
		levelsContainer.add_child(newLevelButton)
		var diff_color = Color(current_scene.getColorOfDifficulty(str(int(level.difficulty))))
		newLevelButton.setup(level.title, level.author_name, str(int(level.difficulty)), diff_color, level.downloads, level.featured)
		newLevelButton.leftclick.connect(func():
			_playlevel(level.id)
		)
	pass


func _search(query="", page=1, featured="", order="id") -> void:
	_setstate("Loading...")
	for thing in levelsContainer.get_children():
		thing.queue_free()
	var result = await httpc.request(current_scene, "getlevelsv2", false, [
		"q=" + str(query),
		"f=" + str(featured),
		"o=" + str(order),
		"p=" + str(page)
	])
	
	if result.success:
		_setstate("%d results, page %d" % [len(result.data.data), page])
		_putresults(result.data.data)
	
	pass


func onSwitch() -> void:
	_search()
	pass


func _on_back_pressed() -> void:
	current_scene.switchToScreen("Online")
	pass # Replace with function body.
