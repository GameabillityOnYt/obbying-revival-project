class_name SelectionManager
extends RefCounted

var camera: Camera3D
var transform_gizmo: Node3D
# to make shift selecting multiple objects via array tracking
var selected_objects: Array[Node3D] = []

func _init(p_camera: Camera3D, p_gizmo: Node3D) -> void:
	camera = p_camera
	transform_gizmo = p_gizmo

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera.moving_camera: 
			return
		
		if transform_gizmo and (transform_gizmo.hovering or transform_gizmo.editing):
			return
			
		var is_shifting = Input.is_physical_key_pressed(KEY_SHIFT)
		perform_selection(is_shifting)
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_BACKSPACE:
			if not selected_objects.is_empty():
				print("Deleting %d selected instances" % selected_objects.size())
				for obj in selected_objects:
					if is_instance_valid(obj):
						obj.queue_free()
				deselect_all()

# handles raycast + gizmo
func perform_selection(keep_existing: bool) -> void:
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
			while actual_part.get_parent().name != "Instances":
				actual_part = actual_part.get_parent()
			
			if not keep_existing:
				deselect_all()
			
			if not selected_objects.has(actual_part):
				selected_objects.append(actual_part)
				print("Added to selection: ", actual_part.name)
				
				if transform_gizmo:
					if transform_gizmo.has_method("select_targets"):
						transform_gizmo.select_targets(selected_objects)
					else:
						transform_gizmo.select(actual_part)
			return
				
	# check if there's a current gizmo when pressing void
	if transform_gizmo and (transform_gizmo.hovering or transform_gizmo.editing):
		return # keeps selection

	# deselect when no gizmo
	deselect_all()

func deselect_all() -> void:
	if transform_gizmo:
		transform_gizmo.clear_selection()
	selected_objects.clear()

# helper function
func is_part_of_instances(node: Node) -> bool:
	var current = node
	while current != null:
		if current.name == "Instances":
			return true
		current = current.get_parent()
	return false
