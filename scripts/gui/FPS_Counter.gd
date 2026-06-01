extends Label
var counter = 0
func _process(_delta: float) -> void:
	counter += 1
	text = "FPS: %d // %d" % [Engine.get_frames_per_second(), counter]

func _ready():
	GameManager.CharacterAdded.connect(func(new):
		print("hello i was spawned")
		pass)
