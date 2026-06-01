extends StaticBody3D

@export var damage:float = 10.0

func _ready():
	if not is_in_group("DamageDealer"):
		add_to_group("DamageDealer")
