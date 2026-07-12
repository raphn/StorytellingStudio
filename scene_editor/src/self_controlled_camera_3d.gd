extends Camera3D
class_name SelfControlledCamera3D

@export_category("Input")
@export var move_action_name := "cam_move"
@export var look_action_name := "cam_look"

@export_category("Movement")
@export var move_speed := 5.0

@export_category("Camera Look")
@export var look_speed := 90.0
@export_range(1.0, 89.9, 0.1) var max_pitch_degrees := 89.0

var move_actions: Array[StringName]
var look_actions: Array[StringName]

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	move_actions = _create_directional_actions(move_action_name)
	look_actions = _create_directional_actions(look_action_name)

	# YXZ applies yaw before pitch and prevents unwanted camera roll.
	rotation_order = EULER_ORDER_YXZ

	_yaw = rotation.y
	_pitch = rotation.x


func _process(delta: float) -> void:
	_process_movement(delta)
	_process_look(delta)


func _process_movement(delta: float) -> void:
	var input := _get_directional_input(move_actions)

	if input.is_zero_approx():
		return

	# Camera-local movement:
	# X = right/left
	# Y = up/down
	# Z = forward/backward
	var direction := (
		global_basis.x * input.x
		+ global_basis.y * input.y
		- global_basis.z * input.z
	).normalized()

	global_position += direction * move_speed * delta


func _process_look(delta: float) -> void:
	var input := _get_directional_input(look_actions)

	if input.is_zero_approx():
		return

	var look_radians := deg_to_rad(look_speed) * delta

	_yaw -= input.x * look_radians
	_pitch += input.y * look_radians

	var max_pitch := deg_to_rad(max_pitch_degrees)
	_pitch = clampf(_pitch, -max_pitch, max_pitch)

	# Keeping yaw and pitch separate avoids accumulating Euler rotations
	# and prevents the camera from rolling.
	rotation = Vector3(_pitch, _yaw, 0.0)


func _get_directional_input(actions: Array[StringName]) -> Vector3:
	return Vector3(
		Input.get_action_strength(actions[3])
			- Input.get_action_strength(actions[2]),
		Input.get_action_strength(actions[0])
			- Input.get_action_strength(actions[1]),
		Input.get_action_strength(actions[0])
			- Input.get_action_strength(actions[1])
	)


func _create_directional_actions(base_name: String) -> Array[StringName]:
	return [
		StringName(base_name + "_up"),
		StringName(base_name + "_down"),
		StringName(base_name + "_left"),
		StringName(base_name + "_right"),
	]
