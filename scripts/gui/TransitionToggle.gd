extends Button

func _pressed():
	var frame = get_parent().get_node("TransitionFrame")
	frame.visible = !frame.visible
