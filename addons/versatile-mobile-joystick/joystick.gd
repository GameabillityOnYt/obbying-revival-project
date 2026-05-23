@tool
@icon("res://addons/versatile-mobile-joystick/JoystickNodeIcon.png")
extends Node2D

# Joystick modes
enum JoystickMode {
	FIXED,      # Joystick doesn't move
	DYNAMIC     # Joystick positioned where touch occurs
}

# Visibility modes
enum VisibilityMode {
	ALWAYS,
	WHEN_TOUCHED
}

# Exportable settings
## Texture of the stationary part of the joystick, typically larger than the tip.
## This defines the visual background of the joystick control.
## Recommended: Use a transparent PNG with a circular design for best results.
@export var base_texture: Texture2D:
	set(value):
		base_texture = value
		%Base.texture = base_texture
		if Engine.is_editor_hint():
			print("Base texture updated")

## Texture of the movable part of the joystick that follows the touch input.
## This represents the 'stick' part of the joystick that the player interacts with.
## Should be smaller than the base texture and visually distinct for clear user feedback.
@export var tip_texture: Texture2D:
	set(value):
		tip_texture = value
		%Tip.texture = tip_texture
		if Engine.is_editor_hint():
			print("Tip texture updated")

## Defines the central region where joystick input is ignored (dead zone).
## Helps prevent unintended input from small, accidental touches or imprecise controls.
## Adjust size to balance between preventing accidental input and maintaining responsiveness.
@export var deadzone_circle: CircleShape2D:
	set(value):
		deadzone_circle = value
		%DeadZone.shape = deadzone_circle
		if Engine.is_editor_hint():
			print("Deadzone updated")

## Sets the maximum range of motion for the joystick tip.
## Determines how far the joystick can move from its center position.
## Larger values allow for more precise control, smaller values for quicker full-strength input.
@export var tip_limit_circle: CircleShape2D:
	set(value):
		tip_limit_circle = value
		%TipLimit.shape = tip_limit_circle
		if Engine.is_editor_hint():
			print("Tip limit updated")

## Specifies the area where touch input is detected for joystick interaction.
## Can be larger than the visible joystick for easier touch detection.
## Useful for creating a larger interactive area without changing the joystick's visual size.
@export var touch_detection_region: RectangleShape2D:
	set(value):
		touch_detection_region = value
		%TouchDetector.shape = touch_detection_region
		if Engine.is_editor_hint():
			print("Touch detection region updated")

## Defines the response curve for joystick input strength.
@export var strength_curve: Curve

# Joystick configuration
## Determines if the joystick stays in a fixed position or appears at the touch location.
## FIXED: Joystick remains at its initial position.
## DYNAMIC: Joystick appears wherever the touch occurs within the detection region.
@export var joystick_mode: JoystickMode = JoystickMode.DYNAMIC

## Controls when the joystick is visible on the screen.
## ALWAYS: Joystick is always visible.
## WHEN_TOUCHED: Joystick only appears when the player touches the screen.
@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS

# Movement mappings
## Input action name for leftward movement.
## Links the joystick's left direction to this input action in the project settings.
@export var left_movement: String = "ui_left"

## Input action name for rightward movement.
## Links the joystick's right direction to this input action in the project settings.
@export var right_movement: String = "ui_right"

## Input action name for upward movement.
## Links the joystick's upward direction to this input action in the project settings.
@export var up_movement: String = "ui_up"

## Input action name for downward movement.
## Links the joystick's downward direction to this input action in the project settings.
@export var down_movement: String = "ui_down"

## Option to use the joystick only on mobile devices
@export var is_mobile_only: bool = false

## List of names of know mobile operating systems
var mobile_operating_systems = ["iOS", "Android"]

## Touch index to handle multitouch.
var joystick_touch_index: int = -1

# Touch state management
var being_touched: bool = false:
	set(value):
		if value == being_touched:
			return
		being_touched = value
		
		# Control visibility based on mode
		if being_touched:
			if visibility_mode == VisibilityMode.WHEN_TOUCHED:
				%Joystick.show()
		else:
			if visibility_mode == VisibilityMode.WHEN_TOUCHED:
				%Joystick.hide()

# Initial setup
func _ready() -> void:
	if not Engine.is_editor_hint():
		
		if OS.get_name() not in mobile_operating_systems and is_mobile_only:
			queue_free()
		if visibility_mode == VisibilityMode.WHEN_TOUCHED:
			%Joystick.hide()
		else:
			%Joystick.show()

func _update_tip_texture(texture : Texture2D) -> void:
	tip_texture = texture
	%Tip.texture = tip_texture
	if Engine.is_editor_hint():
		print("Tip texture updated")
# Configuration warnings in editor
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	# Check if all necessary settings are defined
	var required_values := {
		"Left Movement": left_movement,
		"Right Movement": right_movement,
		"Up Movement": up_movement,
		"Down Movement": down_movement,
		"Strength Curve": strength_curve,
		"Deadzone Circle": deadzone_circle,
		"Tip Limit Circle": tip_limit_circle,
		"Touch Detection Region": touch_detection_region,
		"Base Texture": base_texture,
		"Tip Texture": tip_texture
	}
	
	# Add warnings for undefined settings
	for key in required_values.keys():
		if not required_values[key]:
			warnings.append("Please define %s" % key)
	return warnings

# Check if point is inside touch detection region
func _is_inside_touch_detector(pos: Vector2) -> bool:
	var rect := touch_detection_region.get_rect()
	var relative_pos = pos - global_position
	return rect.has_point(abs(relative_pos))

# Touch input processing
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# Touch start
		if event.pressed and not being_touched:
			if _is_inside_touch_detector(event.position):
				joystick_touch_index = event.index
				being_touched = true
				%Touch.disabled = false
				if joystick_mode == JoystickMode.DYNAMIC:
					%Joystick.global_position = event.position
				_move_and_calculate(event)
		else:
			# Only release if it's the same finger that started the joystick
			if event.index == joystick_touch_index:
				being_touched = false
				%Touch.disabled = true
				%Tip.global_position = %Base.global_position
				_update_input_actions(Vector2.ZERO)
				joystick_touch_index = -1
	
	elif event is InputEventScreenDrag:
		# Touch drag
		if event.index == joystick_touch_index:
			if _is_inside_touch_detector(event.position):
				being_touched = true
				_move_and_calculate(event)
			else:
				being_touched = false
				%Tip.global_position = %Base.global_position
				_update_input_actions(Vector2.ZERO)

# Calculate joystick movement and strength
func _move_and_calculate(event: InputEvent) -> void:
	var t_init_pos: Vector2 = %Base.global_position
	var event_pos: Vector2 = event.position
	var direction: Vector2 = t_init_pos.direction_to(event_pos)
	var distance: float = t_init_pos.distance_to(event_pos)
	var max_distance: float = %TipLimit.shape.radius
	var deadzone_length: float = %DeadZone.shape.radius
	
	# Adjust distance considering deadzone
	var adjusted_distance: float = max(distance - deadzone_length, 0)
	var clamped_distance: float = clamp(adjusted_distance, 0, max_distance - deadzone_length)
	
	# Position the tip
	var final_tip_position: Vector2 = t_init_pos + direction * min(distance, max_distance)
	%Tip.global_position = final_tip_position
	
	# Normalize distance
	var normalized_distance: float = clamped_distance / (max_distance - deadzone_length)
	
	# Calculate output based on strength curve
	var output: Vector2 = Vector2.ZERO
	if normalized_distance > 0:
		output.x = direction.x * strength_curve.sample(normalized_distance)
		output.y = direction.y * strength_curve.sample(normalized_distance)
	_update_input_actions(output)

# Update input actions based on movement
func _update_input_actions(output: Vector2) -> void:
	var actions = [
		{"action": left_movement, "condition": output.x < 0, "strength": -output.x},
		{"action": right_movement, "condition": output.x > 0, "strength": output.x},
		{"action": up_movement, "condition": output.y < 0, "strength": -output.y},
		{"action": down_movement, "condition": output.y > 0, "strength": output.y}
	]
	
	# Trigger or release actions based on movement
	for action in actions:
		if action.condition:
			Input.action_press(action.action, action.strength)
		else:
			Input.action_release(action.action)
