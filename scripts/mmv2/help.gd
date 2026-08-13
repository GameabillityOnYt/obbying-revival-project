extends Control

@onready var current_scene = get_tree().current_scene
@onready var tabBar = $CenterContainer/VBoxContainer/VBoxContainer/TabBar
@onready var contentContainer = $CenterContainer/VBoxContainer/VBoxContainer/ContentContainer
var content = []
var loaded = false
var weGotHelp = false
var oldtab = 1

const helpEndpoint = "https://static.obbyrevivalproject.org/helpfiles/v1.txt"
const TransitionTime = 0.35
const OutScreenX = 50
const InScreenX = 200

# Called when the node enters the scene tree for the first time. ok whatever you say godot
func _gethelp() -> void:
	if weGotHelp: return
	weGotHelp = true
	contentContainer.get_node("Content").text = "Loading..."
	var request = HTTPRequest.new()
	self.add_child(request)
	request.request_completed.connect(func(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		var raw = body.get_string_from_utf8()
		var rawsplit = raw.split("[-seperator-boundary<>]", false)
		for thing in rawsplit:
			thing = thing.strip_edges()
			content.append(thing)
		_load_content()
		request.queue_free()
	)
	var error = request.request(helpEndpoint)
	if error != OK:
		push_warning("Error: ", error)
	pass

func _load_content() -> void:
	loaded = true
	_switch_tab(0)
	pass

func _switch_tab(tab: int) -> void:
	if not loaded:
		return
	if oldtab == tab:
		return
	tabBar.current_tab = tab
	var newContent:RichTextLabel = contentContainer.get_node("Content")
	newContent.modulate = Color.TRANSPARENT
	newContent.text = content.get(tab)
	contentContainer.add_child(newContent)
	var tween = create_tween().bind_node(self).set_ease(Tween.EASE_OUT).set_parallel(true)
	if tab > oldtab:
		newContent.offset_transform_position = Vector2(InScreenX, 0)
		tween.tween_property(newContent, "modulate", Color.WHITE, TransitionTime).set_trans(Tween.TRANS_SINE)
		tween.tween_property(newContent, "offset_transform_position", Vector2.ZERO, TransitionTime).set_trans(Tween.TRANS_QUAD)
	else:
		newContent.offset_transform_position = Vector2(-InScreenX, 0)
		tween.tween_property(newContent, "modulate", Color.WHITE, TransitionTime).set_trans(Tween.TRANS_SINE)
		tween.tween_property(newContent, "offset_transform_position", Vector2.ZERO, TransitionTime).set_trans(Tween.TRANS_QUAD)
	oldtab = tab
	pass

func _on_back_pressed() -> void:
	_switch_tab(0)
	current_scene.switchToScreen("MainScreen")
	pass # Replace with function body.


func _on_tab_bar_tab_clicked(tab: int) -> void:
	_switch_tab(tab)
	pass # Replace with function body.


func _on_content_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
	pass # Replace with function body.

func onSwitch() -> void:
	_gethelp()
	pass
