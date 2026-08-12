extends Control

@onready var current_scene = get_tree().current_scene
@onready var levelsContainer = $CenterContainer/VBoxContainer/LocalLevelsList/VBoxContainer
var level_button = preload("res://assets/prefabs/UI/mmv2/levelbutton.tscn")
var regex = RegEx.new()

var _level_entries: Array[Dictionary] = []

const FUZZY_THRESHOLD: float = 0.45

func reloadLevels() -> void:
	_level_entries.clear()
	for child in levelsContainer.get_children():
		child.queue_free()
	
	var localLevels = current_scene.fetchLevelsDirectory()
	for localLevelPath in localLevels:
		var level = current_scene.fetchLevelMetadata(localLevelPath)
		if not level:
			continue
		
		var newLevelButton = level_button.instantiate()
		newLevelButton.name = level.ObbyName
		newLevelButton.set_meta("path", localLevelPath)
		levelsContainer.add_child(newLevelButton)
		var diff_color = Color(current_scene.getColorOfDifficulty(level.Difficulty))
		newLevelButton.setup(level.ObbyName, level.Creator, level.Difficulty, diff_color)
		
		_level_entries.append({
			"node": newLevelButton,
			"name": str(level.ObbyName).to_lower(),
			"creator": str(level.Creator).to_lower(),
			"difficulty": str(level.Difficulty).to_lower()
		})

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reloadLevels()

func _process(_delta: float) -> void:
	pass

func _on_back_pressed() -> void:
	current_scene.switchToScreen("MainScreen")
	$CenterContainer/VBoxContainer/HBoxContainer/LineEdit.text = ""
	_execute_search("")

func _execute_search(new_text: String) -> void:
	var query = new_text.strip_edges().to_lower()
	
	if query.is_empty():
		for entry in _level_entries:
			if is_instance_valid(entry.node):
				entry.node.visible = true
		return

	for entry in _level_entries:
		if not is_instance_valid(entry.node):
			continue
			
		# 1. Exact / Substring match check (highest priority)
		var is_direct_match = entry.name.contains(query) or entry.creator.contains(query)
		
		if is_direct_match:
			entry.node.visible = true
			continue
			
		# 2. Fuzzy match fallback for typos
		var score_name = _get_fuzzy_score(query, entry.name)
		var score_creator = _get_fuzzy_score(query, entry.creator)
		var max_score = maxf(score_name, score_creator)
		
		entry.node.visible = max_score >= FUZZY_THRESHOLD

# Calculates string similarity from 0.0 (completely different) to 1.0 (identical)
func _get_fuzzy_score(str1: String, str2: String) -> float:
	var distance = _levenshtein_distance(str1, str2)
	var max_len = float(maxi(str1.length(), str2.length()))
	if max_len == 0.0:
		return 1.0
	return 1.0 - (float(distance) / max_len)

# Standard Levenshtein Distance Algorithm
func _levenshtein_distance(s1: String, s2: String) -> int:
	var len1 = s1.length()
	var len2 = s2.length()
	
	if len1 == 0: return len2
	if len2 == 0: return len1
	
	var dp = []
	for i in range(len1 + 1):
		var row = []
		row.resize(len2 + 1)
		dp.append(row)
		
	for i in range(len1 + 1):
		dp[i][0] = i
	for j in range(len2 + 1):
		dp[0][j] = j
		
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			dp[i][j] = mini(
				mini(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
				dp[i - 1][j - 1] + cost
			)
			
	return dp[len1][len2]


func _on_line_edit_text_submitted(new_text: String) -> void:
	_execute_search(new_text)
	pass # Replace with function body.


func _on_line_edit_text_changed(new_text: String) -> void:
	# TODO: should add a settings module to toggle this one event
	_execute_search(new_text)
	pass # Replace with function body.


func _on_refresh_pressed() -> void:
	$CenterContainer/VBoxContainer/HBoxContainer/LineEdit.text = ""
	reloadLevels()
	_execute_search("")
	pass # Replace with function body.

func _on_clear_query_pressed() -> void:
	$CenterContainer/VBoxContainer/HBoxContainer/LineEdit.text = ""
	_execute_search("")
	pass # Replace with function body.
