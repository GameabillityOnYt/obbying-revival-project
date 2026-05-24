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
@export var rendering:String = "vulkan"
# other types: vulkan, d3d12, metal

@export var body_colors: Dictionary = {
	"head": Color.WHITE,
	"torso": Color.WHITE,
	"left_arm": Color.WHITE,
	"right_arm": Color.WHITE,
	"left_leg": Color.WHITE,
	"right_leg": Color.WHITE
}
