extends Resource
class_name PlayerData

signal FOVChanged
signal MaxFPSChanged

@export var fov:float = 70.0 : 
	set(new):
		FOVChanged.emit(new)
		fov = new
@export var sensitivity:float = 1.0
@export var maxFPS:int = 120 : 
	set(new):
		MaxFPSChanged.emit(new)
		maxFPS = new
@export var rendering:String = "opengl3"
# other types: vulkan, d3d12
