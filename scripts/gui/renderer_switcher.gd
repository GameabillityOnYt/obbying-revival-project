extends OptionButton

const vals = ["forward_plus", "mobile", "gl_compatibility"]
var is_ready = false

func _ready() -> void:
	var current_renderer = GameManager.data.renderer
	var target_index = vals.find(current_renderer)
	
	if target_index != -1:
		self.select(target_index)
	
	$ConfirmationDialog.confirmed.connect(confirm_restart)
	is_ready = true

func _on_item_selected(index: int) -> void:
	if !is_ready:
		return
		
	if RenderingServer.get_current_rendering_method() != vals[index]:
		GameManager.data.renderer = vals[index]
		$ConfirmationDialog.popup_centered()

func confirm_restart() -> void:
	ResourceSaver.save(GameManager.data, "user://data.tres")
	restart_game()

func restart_game() -> void:
	OS.create_instance(["--rendering-method", GameManager.data.renderer])
	get_tree().quit(0)
