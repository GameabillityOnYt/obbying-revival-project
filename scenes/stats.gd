extends Panel
func format_playtime(total_seconds: float) -> String:
	var seconds := int(total_seconds) % 60
	var minutes := int(total_seconds / 60) % 60
	var hours := int(total_seconds / 3600) % 24
	var days := int(total_seconds / 86400)
	
	var result = ""
	

	if days > 0:
		result += "%dd " % days
	if hours > 0 or days > 0:
		result += "%dh " % hours
	if minutes > 0 or hours > 0 or days > 0:
		result += "%dm " % minutes
		
	# Always show seconds at the end
	result += "%ds" % seconds
	
	return result
func updateTitle():
	var total_time = GameManager.leveldata.total_playtime
	var total_attempts = GameManager.leveldata.total_attempts
	var formatted_time = format_playtime(total_time)
	
	$Label2.text = "Level Playtime: %s\nLevel Attempts: %d" % [
		formatted_time,
		total_attempts
	]
func _ready():
	var updateTimer = Timer.new()
	add_child(updateTimer)
	
	updateTimer.one_shot = false
	updateTimer.wait_time = 1.0
	
	# FIXED: Removed the () from updateTitle
	updateTimer.timeout.connect(updateTitle) 
	
	updateTimer.start()
	
	# Optional: Call it once at the start so the label doesn't look blank for the first second
	updateTitle()
