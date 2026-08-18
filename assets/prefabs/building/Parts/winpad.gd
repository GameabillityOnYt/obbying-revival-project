extends RigidBody3D
@export var tpID := ""
@export var teleporterVariant := ""


func _on_area_3d_body_entered(body: Node3D) -> void:
	print(body.name)
	if body.name == "Player":
		# do ur shit here
			
		print("yes")
	pass # Replace with function body.
