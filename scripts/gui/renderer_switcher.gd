extends OptionButton

const vals = ["forward_plus", "mobile", "gl_compatibility"]

func _ready() -> void:
	self.set_block_signals(true)
	
	var current_renderer = GameManager.data.renderer
	self.select(vals.find(current_renderer))
	
	self.set_block_signals(false)
	
	$ConfirmationDialog.confirmed.connect(confirm_restart)

func _on_item_selected(index: int) -> void:
	if RenderingServer.get_current_rendering_method() != vals[index]:
		GameManager.data.renderer = vals[index]
		$ConfirmationDialog.popup_centered()

func confirm_restart() -> void:
	ResourceSaver.save(GameManager.data, "user://data.tres")
	restart_game()

func restart_game() -> void:
	OS.create_instance(["--rendering-method", GameManager.data.renderer])
	get_tree().quit(0)
