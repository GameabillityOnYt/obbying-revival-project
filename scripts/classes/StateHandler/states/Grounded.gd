extends State
class_name GroundedState

@export var kP:float = 10
@export var kD:float = 2

const MaxForce = 741.6
const Gain = 150

func physics_update(_dt:float):
	var curr = player.linear_velocity
	var diff = player.ground_dist
	var apply = -kP * (diff-2.48) - kD * curr.y + player.get_gravity().y*8
	
	# // ADD TO WALKING STATE!!! ALSO INCLUDE THE WALK DIRECTION 
	#AND MAKE IT ACTUALLY RELATIVE OK!!!
	
	#var target = player.global_basis.z*16
	#var correctionVector = target - Vector3(curr.x, 0, curr.z)
	#correctionVector = correctionVector.normalized() * min(MaxForce,Gain*correctionVector.length())
	#var correctionForce = correctionVector*player.mass 
	
	#player.apply_central_force(correctionForce)
	
	player.apply_force(Vector3(0,apply,0))
