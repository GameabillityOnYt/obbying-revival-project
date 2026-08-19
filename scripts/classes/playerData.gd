extends Resource
class_name PlayerData

signal FOVChanged
signal MaxFPSChanged
signal VolumeChanged
@export var fov:float = 70.0 : 
	set(new):
		FOVChanged.emit(new)
		fov = new
@export var volume:float = 50.0 : 
	set(new):
		VolumeChanged.emit(new)
		volume = new
@export var sensitivity:float = 1.0
@export var maxFPS:int = 120 : 
	set(new):
		MaxFPSChanged.emit(new)
		maxFPS = new
@export var rpc_enabled = false
@export var renderer = "mobile"
@export var menuTransitions = true
@export var RToggle = false
@export var disableCursorWobble = false
@export var starsBg = false
@export var doNot = false

@export var onlineLoggedIn = false
@export var onlineUsername = ""
@export var onlineAuth = ""

@export var body_colors: Dictionary = {
	"head": Color.WHITE,
	"torso": Color.WHITE,
	"left_arm": Color.WHITE,
	"right_arm": Color.WHITE,
	"left_leg": Color.WHITE,
	"right_leg": Color.WHITE
}
