extends Control

@onready var current_scene = get_tree().current_scene
var rendering_switched = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$RenderSwitchRestartDialog.confirmed.connect(confirm_restart)
	pass # Replace with function body.

func onSwitch() -> void:
	$CenterContainer/VBoxContainer/PanelContainer/ScrollContainer/VBoxContainer.reload()
	pass

func confirm_restart() -> void:
	ResourceSaver.save(GameManager.data, "user://data.tres")
	OS.create_instance(["--rendering-method", GameManager.data.renderer])
	get_tree().quit(0)

func _on_back_pressed() -> void:
	if rendering_switched:
		$RenderSwitchRestartDialog.popup_centered()
	rendering_switched = false
	GameManager.autosave()
	current_scene.switchToScreen("MainScreen")
	pass # Replace with function body.


func _on_v_box_container_changed_renderer() -> void:
	rendering_switched = true
	pass # Replace with function body.


func _on_render_switch_restart_dialog_confirmed() -> void:
	confirm_restart()
	pass # Replace with function body.


func _on_render_switch_restart_dialog_canceled() -> void:
	$RenderSwitchRestartDialog.hide()
	pass # Replace with function body.
