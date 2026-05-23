extends Sprite2D

var direction : Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", 0)
	position += direction * 100 * delta
	%Line2D.set_point_position(1, direction * 100)
