extends Panel

var milliseconds := 0
var seconds := 0
var minutes := 0

@onready var label = $Label

func resetTime():
	milliseconds = 0
	seconds = 0
	minutes = 0

func _physics_process(delta: float) -> void:
	milliseconds += int(delta * 1000)

	if milliseconds >= 1000:
		seconds += milliseconds / 1000.0
		milliseconds = milliseconds % 1000

	if seconds >= 60:
		minutes += seconds / 60.0
		seconds = seconds % 60
	label.text = "%02d:%02d:%03d" % [minutes, seconds, milliseconds]
	
	if GameManager.practice:
		$Indicator.visible = true
	else:
		$Indicator.visible = false
