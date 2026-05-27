extends OptionButton

const vals = [
	"forward_plus",
	"mobile",
	"gl_compatibility"
]

func _ready() -> void:
	self.select(vals.find(GameManager.data.renderer))

func _on_item_selected(index: int) -> void:
	GameManager.data.renderer = vals[index]
	if RenderingServer.get_current_rendering_method() != vals[index]:
		$AcceptDialog.popup()
