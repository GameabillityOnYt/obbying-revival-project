extends VBoxContainer

@onready var stuff = {
	rendering_mode = $RenderingMode/RenderingMode,
	max_fps = $MaxFPS/MaxFPS,
	
	sensitivity_slider = $Sensitivity/SensitivitySlider,
	sensitivity_number = $Sensitivity/SensitivityNumber,
	
	ctrl_r_to_restart = $CtrlRToRestart,
	
	fov_slider = $FOV/FOVSlider,
	fov_number = $FOV/FOVNumber,
	
	use_alt_stud = $UseAltStud,
	disable_wobbly = $DisableWobbly,
	discord_rpc = $DiscordRPC,
	do_not = $DoNot,
	volume_slider = $Music/Volume,
	volume_number = $Music/Volume2
}

signal changed_renderer
signal bg_option

func reload() -> void:
	var render_method = RenderingServer.get_current_rendering_method()
	var reverse_index_render_method = {"forward_plus":0,"mobile":1,"gl_compatibility":2}
	stuff.rendering_mode.selected = reverse_index_render_method[render_method]
	stuff.max_fps.value = GameManager.data.maxFPS
	stuff.sensitivity_slider.value = GameManager.data.sensitivity
	stuff.sensitivity_number.value = GameManager.data.sensitivity
	stuff.ctrl_r_to_restart.button_pressed = not GameManager.data.RToggle
	stuff.fov_slider.value = GameManager.data.fov
	stuff.fov_number.value = GameManager.data.fov
	stuff.use_alt_stud.button_pressed = GameManager.RobloxStuds
	stuff.disable_wobbly.button_pressed = GameManager.data.disableCursorWobble
	stuff.discord_rpc.button_pressed = GameManager.data.rpc_enabled
	stuff.do_not.button_pressed = GameManager.data.doNot
	stuff.volume_slider.value = GameManager.data.volume
	stuff.volume_number.value = GameManager.data.volume
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reload()
	pass # Replace with function body.


func _on_rendering_mode_item_selected(index: int) -> void:
	const vals = ["forward_plus", "mobile", "gl_compatibility"]
	
	if RenderingServer.get_current_rendering_method() != vals[index]:
		GameManager.data.renderer = vals[index]
		changed_renderer.emit()
	pass # Replace with function body.


func _on_max_fps_value_changed(value: float) -> void:
	@warning_ignore("narrowing_conversion") # no.
	GameManager.data.maxFPS = value
	pass # Replace with function body.


func _on_sensitivity_slider_value_changed(value: float) -> void:
	stuff.sensitivity_number.value = value
	GameManager.data.sensitivity = value
	pass # Replace with function body.


func _on_sensitivity_number_value_changed(value: float) -> void:
	stuff.sensitivity_slider.value = value
	GameManager.data.sensitivity = value
	pass # Replace with function body.


func _on_fov_slider_value_changed(value: float) -> void:
	stuff.fov_number.value = value
	GameManager.data.fov = value
	pass # Replace with function body.


func _on_fov_number_value_changed(value: float) -> void:
	stuff.fov_slider.value = value
	GameManager.data.fov = value
	pass # Replace with function body.


func _on_use_alt_stud_toggled(toggled_on: bool) -> void:
	GameManager.RobloxStuds = toggled_on
	pass # Replace with function body.


func _on_disable_wobbly_toggled(toggled_on: bool) -> void:
	GameManager.data.disableCursorWobble = toggled_on
	pass # Replace with function body.


func _on_discord_rpc_toggled(toggled_on: bool) -> void:
	GameManager.data.rpc_enabled = toggled_on
	pass # Replace with function body.


func _on_do_not_toggled(toggled_on: bool) -> void:
	GameManager.data.doNot = toggled_on
	pass # Replace with function body.


func _on_ctrl_r_to_restart_toggled(toggled_on: bool) -> void:
	GameManager.data.RToggle = not toggled_on
	pass # Replace with function body.


func _on_use_old_stars_toggled(toggled_on: bool) -> void:
	GameManager.data.starsBg = toggled_on
	bg_option.emit(toggled_on)
	pass # Replace with function body.


func _on_volume_2_value_changed(value: float) -> void:
	stuff.volume_slider.value = value
	GameManager.data.volume = value
	GameManager.apply_volume()


func _on_volume_value_changed(value: float) -> void:
	stuff.volume_number.value = value
	GameManager.data.volume = value
	GameManager.apply_volume()
