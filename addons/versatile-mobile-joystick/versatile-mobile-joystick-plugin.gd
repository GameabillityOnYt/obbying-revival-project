@tool
extends EditorPlugin

func _enter_tree():
	if Engine.is_editor_hint():
		print("Versatile Mobile Joystick Loaded Succesfully")
