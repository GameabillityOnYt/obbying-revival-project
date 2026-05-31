class_name SelectionManager
extends RefCounted

var camera: Camera3D
var transform_gizmo: Node3D
var selected_object: Node3D = null

func _init(p_camera: Camera3D, p_gizmo: Node3D) -> void:
	camera = p_camera
	transform_gizmo = p_gizmo

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera.moving_camera: 
			return
		
		if transform_gizmo and (transform_gizmo.hovering or transform_gizmo.editing):
			return
			
		perform_selection()

# handles raycast + gizmo
func perform_selection() -> void:
	var mouse_pos = camera.get_viewport().get_mouse_position()
	
	var ray_start = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_start + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_node = result.collider
		# until parent is "Instances"
		if is_part_of_instances(hit_node):
			var actual_part = hit_node
			while actual_part.get_parent() and actual_part.get_parent().name != "Instances":
				actual_part = actual_part.get_parent()
				
			selected_object = actual_part
			print("Selected: ", selected_object.name)
			
			# clear old and select new
			if transform_gizmo:
				transform_gizmo.clear_selection()
				transform_gizmo.select(selected_object)
			return 
				
	# check if there's a current gizmo when pressing void
	if transform_gizmo and (transform_gizmo.hovering or transform_gizmo.editing):
		return # keeps selection

	# deselect when no gizmo
	deselect_all()

func deselect_all() -> void:
	if transform_gizmo:
		transform_gizmo.clear_selection()
	selected_object = null

# helper function
func is_part_of_instances(node: Node) -> bool:
	var current = node
	while current != null:
		if current.name == "Instances":
			return true
		current = current.get_parent()
	return false
