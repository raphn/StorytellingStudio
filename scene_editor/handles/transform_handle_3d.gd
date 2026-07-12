extends Marker3D
class_name TransformHandle3D

signal transform_change_finished(old_transform: Transform3D, new_transform: Transform3D)

enum Operation {
	TRANSLATE,
	ROTATE,
	SCALE,
}

enum Axis {
	NONE = -1,
	X = 0,
	Y = 1,
	Z = 2,
	CENTER = 3,
}

enum CoordinateSpace {
	LOCAL,
	GLOBAL,
}

const AXIS_FLAG_X := 1
const AXIS_FLAG_Y := 2
const AXIS_FLAG_Z := 4
const POINTER_MOUSE := -1
const EPSILON := 0.0001
const HOVER_KEY_SEPARATOR := ":"

@export var input_enabled := true
@export var camera: Camera3D
@export var reference_space := CoordinateSpace.LOCAL:
	set(value):
		reference_space = value
		_refresh_visual_transform()

@export_group("Rendering")
@export_flags_3d_render var render_layers := 1:
	set(value):
		render_layers = value
		_apply_render_layers()

@export_group("Visible Handles")
@export var show_translate_handles := true:
	set(value):
		show_translate_handles = value
		_update_operation_visibility()
@export var show_rotate_handles := true:
	set(value):
		show_rotate_handles = value
		_update_operation_visibility()
@export var show_scale_handles := true:
	set(value):
		show_scale_handles = value
		_update_operation_visibility()

@export_group("Axis Locks")
@export_flags("X", "Y", "Z") var locked_position_axes := 0
@export_flags("X", "Y", "Z") var locked_rotation_axes := 0
@export_flags("X", "Y", "Z") var locked_scale_axes := 0

@export_group("Mobile Input")
@export var mouse_hit_radius_px := 18.0
@export var touch_hit_radius_px := 42.0
@export var respect_input_blocking_controls := true
@export var input_blocking_control_padding_px := 80.0
@export var input_blocking_min_effective_z_index := 1
@export var input_blocking_control_types := PackedStringArray(["VirtualJoystick"])
@export var input_blocking_control_names := PackedStringArray()
@export var input_blocking_control_groups := PackedStringArray(["handle_input_blocker", "input_blocker"])
@export var input_blocking_control_paths: Array[NodePath] = []

@export_group("Visual Size")
@export var screen_constant_size := true
@export var screen_size_px := 150.0
@export var handle_length := 1.2
@export var scale_handle_distance := 1.75
@export var scale_handle_gap := 0.28
@export var shaft_radius := 0.018
@export var head_radius := 0.07
@export var head_length := 0.2
@export var ring_radius := 0.85
@export var ring_tube_radius := 0.012
@export var scale_box_size := 0.12
@export var center_size := 0.12
@export var minimum_scale_factor := 0.05

var _visual_root: Node3D
var _translate_root: Node3D
var _rotate_root: Node3D
var _scale_root: Node3D
var _visual_scale := 1.0
var _control_materials: Dictionary = {}
var _hover_operation := -1
var _hover_axis := Axis.NONE

var _dragging := false
var _drag_pointer_id := POINTER_MOUSE
var _drag_operation := Operation.TRANSLATE
var _drag_axis := Axis.NONE
var _drag_changed := false
var _drag_start_global_transform := Transform3D.IDENTITY
var _drag_start_axis_param := 0.0
var _drag_start_plane_point := Vector3.ZERO
var _drag_start_rotation_vector := Vector3.ZERO


func _ready() -> void:
	_build_visuals()
	set_process(true)
	set_process_input(true)


func _process(_delta: float) -> void:
	_refresh_visual_transform()


func _exit_tree() -> void:
	if is_instance_valid(_visual_root):
		_visual_root.queue_free()


func _input(event: InputEvent) -> void:
	if not input_enabled or not is_inside_tree() or not is_visible_in_tree():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_pointer_blocked_by_control(event.position):
				_clear_hover()
				return
			_try_begin_drag(event.position, POINTER_MOUSE, false)
		elif _dragging and _drag_pointer_id == POINTER_MOUSE:
			_finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _dragging and _drag_pointer_id == POINTER_MOUSE:
			_update_drag(event.position)
			get_viewport().set_input_as_handled()
		else:
			if _is_pointer_blocked_by_control(event.position):
				_clear_hover()
			else:
				_update_hover(event.position, false)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_pointer_blocked_by_control(event.position):
				_clear_hover()
				return
			_try_begin_drag(event.position, event.index, true)
		elif _dragging and _drag_pointer_id == event.index:
			_finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _dragging and _drag_pointer_id == event.index:
		_update_drag(event.position)
		get_viewport().set_input_as_handled()


func set_axis_locked(operation: int, axis: int, locked: bool) -> void:
	if axis < Axis.X or axis > Axis.Z:
		return
	
	var flag := 1 << axis
	match operation:
		Operation.TRANSLATE:
			locked_position_axes = _set_lock_flag(locked_position_axes, flag, locked)
		Operation.ROTATE:
			locked_rotation_axes = _set_lock_flag(locked_rotation_axes, flag, locked)
		Operation.SCALE:
			locked_scale_axes = _set_lock_flag(locked_scale_axes, flag, locked)


func is_axis_locked(operation: int, axis: int) -> bool:
	if axis < Axis.X or axis > Axis.Z:
		return false
	
	var flag := 1 << axis
	match operation:
		Operation.TRANSLATE:
			return (locked_position_axes & flag) != 0
		Operation.ROTATE:
			return (locked_rotation_axes & flag) != 0
		Operation.SCALE:
			return (locked_scale_axes & flag) != 0
	return false


func use_local_coordinates() -> void:
	reference_space = CoordinateSpace.LOCAL


func use_global_coordinates() -> void:
	reference_space = CoordinateSpace.GLOBAL


func _set_lock_flag(mask: int, flag: int, locked: bool) -> int:
	if locked:
		return mask | flag
	return mask & ~flag


func _is_pointer_blocked_by_control(screen_position: Vector2) -> bool:
	if not respect_input_blocking_controls:
		return false
	
	return _has_blocking_control_at(get_viewport(), screen_position, 0)


func _has_blocking_control_at(node: Node, screen_position: Vector2, inherited_z_index: int) -> bool:
	var effective_z_index := inherited_z_index
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		if canvas_item.z_as_relative:
			effective_z_index += canvas_item.z_index
		else:
			effective_z_index = canvas_item.z_index
	
	for child in node.get_children():
		if _has_blocking_control_at(child, screen_position, effective_z_index):
			return true
	
	if not node is Control:
		return false
	
	var control := node as Control
	if not control.is_visible_in_tree():
		return false
	
	if not control.get_global_rect().grow(input_blocking_control_padding_px).has_point(screen_position):
		return false
	
	return _blocks_handle_input(control, effective_z_index)


func _blocks_handle_input(control: Control, effective_z_index: int) -> bool:
	if _is_explicit_input_blocking_control(control):
		return true
	
	for type_name in input_blocking_control_types:
		if type_name.is_empty():
			continue
		if control.name == type_name or control.is_class(type_name) or control.get_class() == type_name:
			return true
	
	for control_name in input_blocking_control_names:
		if not control_name.is_empty() and control.name == control_name:
			return true
	
	for group_name in input_blocking_control_groups:
		if not group_name.is_empty() and control.is_in_group(group_name):
			return true
	
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	
	return effective_z_index >= input_blocking_min_effective_z_index


func _is_explicit_input_blocking_control(control: Control) -> bool:
	for path in input_blocking_control_paths:
		if path == NodePath():
			continue
		var node := get_node_or_null(path)
		if node == null:
			continue
		if control == node or node.is_ancestor_of(control):
			return true
	return false


func _build_visuals() -> void:
	if is_instance_valid(_visual_root):
		_visual_root.queue_free()
	
	_control_materials.clear()
	_clear_hover()
	
	_visual_root = Node3D.new()
	_visual_root.name = "TransformHandleVisuals"
	_visual_root.top_level = true
	add_child(_visual_root)
	
	_translate_root = Node3D.new()
	_translate_root.name = "Translate"
	_visual_root.add_child(_translate_root)
	
	_rotate_root = Node3D.new()
	_rotate_root.name = "Rotate"
	_visual_root.add_child(_rotate_root)
	
	_scale_root = Node3D.new()
	_scale_root.name = "Scale"
	_visual_root.add_child(_scale_root)
	
	var axis_colors := [
		Color(1.0, 0.12, 0.1),
		Color(0.1, 0.85, 0.22),
		Color(0.16, 0.42, 1.0),
	]
	
	for axis in [Axis.X, Axis.Y, Axis.Z]:
		_add_translate_axis(axis, axis_colors[axis])
		_add_rotation_ring(axis, axis_colors[axis])
		_add_scale_axis(axis, axis_colors[axis])
	
	var center := MeshInstance3D.new()
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3.ONE * center_size
	center.mesh = center_mesh
	center.material_override = _make_material(Color(0.95, 0.95, 0.95, 0.9))
	_configure_visual_instance(center)
	_translate_root.add_child(center)
	_register_control_material(Operation.TRANSLATE, Axis.CENTER, center.material_override)
	
	_update_operation_visibility()
	_refresh_visual_transform()


func _add_translate_axis(axis: int, color: Color) -> void:
	var direction := _axis_vector(axis)
	var material := _make_material(color)
	_register_control_material(Operation.TRANSLATE, axis, material)
	
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.height = handle_length - head_length
	shaft_mesh.top_radius = shaft_radius
	shaft_mesh.bottom_radius = shaft_radius
	shaft_mesh.radial_segments = 12
	
	var shaft := MeshInstance3D.new()
	shaft.name = "%sTranslateShaft" % _axis_name(axis)
	shaft.mesh = shaft_mesh
	shaft.material_override = material
	_configure_visual_instance(shaft)
	shaft.transform = _axis_transform(direction, (handle_length - head_length) * 0.5)
	_translate_root.add_child(shaft)
	
	var head_mesh := CylinderMesh.new()
	head_mesh.height = head_length
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = head_radius
	head_mesh.radial_segments = 18
	
	var head := MeshInstance3D.new()
	head.name = "%sTranslateHead" % _axis_name(axis)
	head.mesh = head_mesh
	head.material_override = material
	_configure_visual_instance(head)
	head.transform = _axis_transform(direction, handle_length - head_length * 0.5)
	_translate_root.add_child(head)


func _add_scale_axis(axis: int, color: Color) -> void:
	var direction := _axis_vector(axis)
	var material := _make_material(color.lightened(0.12))
	_register_control_material(Operation.SCALE, axis, material)
	var shaft_start := handle_length + scale_handle_gap
	var shaft_end := maxf(scale_handle_distance - scale_box_size * 0.5, shaft_start)
	var shaft_height := maxf(shaft_end - shaft_start, 0.001)
	
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.height = shaft_height
	shaft_mesh.top_radius = shaft_radius * 0.75
	shaft_mesh.bottom_radius = shaft_radius * 0.75
	shaft_mesh.radial_segments = 10
	
	var shaft := MeshInstance3D.new()
	shaft.name = "%sScaleShaft" % _axis_name(axis)
	shaft.mesh = shaft_mesh
	shaft.material_override = material
	_configure_visual_instance(shaft)
	shaft.transform = _axis_transform(direction, (shaft_start + shaft_end) * 0.5)
	_scale_root.add_child(shaft)
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * scale_box_size
	
	var box := MeshInstance3D.new()
	box.name = "%sScaleBox" % _axis_name(axis)
	box.mesh = box_mesh
	box.material_override = material
	_configure_visual_instance(box)
	box.transform.origin = direction * scale_handle_distance
	_scale_root.add_child(box)


func _add_rotation_ring(axis: int, color: Color) -> void:
	var material := _make_material(Color(color.r, color.g, color.b, 0.82))
	_register_control_material(Operation.ROTATE, axis, material)
	
	var ring := MeshInstance3D.new()
	ring.name = "%sRotationRing" % _axis_name(axis)
	ring.mesh = _make_ring_mesh(axis, ring_radius, ring_tube_radius, 96, 8)
	ring.material_override = material
	_configure_visual_instance(ring)
	_rotate_root.add_child(ring)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.disable_receive_shadows = true
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _configure_visual_instance(instance: VisualInstance3D) -> void:
	instance.layers = render_layers
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_render_layers() -> void:
	if not is_instance_valid(_visual_root):
		return
	
	_apply_render_layers_to_tree(_visual_root)


func _apply_render_layers_to_tree(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = render_layers
	
	for child in node.get_children():
		_apply_render_layers_to_tree(child)


func _register_control_material(operation: int, axis: int, material: Material) -> void:
	if not material is StandardMaterial3D:
		return
	
	_control_materials[_control_key(operation, axis)] = {
		"material": material,
		"base_color": material.albedo_color,
	}


func _update_hover(screen_position: Vector2, touch_input: bool) -> void:
	if camera == null:
		_clear_hover()
		return
	
	var hit := _find_handle(screen_position, touch_input)
	if hit.is_empty():
		_clear_hover()
		return
	
	_set_hover(hit["operation"], hit["axis"])


func _set_hover(operation: int, axis: int) -> void:
	if _hover_operation == operation and _hover_axis == axis:
		return
	
	_hover_operation = operation
	_hover_axis = axis
	_refresh_control_materials()


func _clear_hover() -> void:
	if _hover_operation == -1 and _hover_axis == Axis.NONE:
		return
	
	_hover_operation = -1
	_hover_axis = Axis.NONE
	_refresh_control_materials()


func _refresh_control_materials() -> void:
	for key in _control_materials.keys():
		var entry: Dictionary = _control_materials[key]
		var material: StandardMaterial3D = entry["material"]
		var color: Color = entry["base_color"]
		if key == _control_key(_hover_operation, _hover_axis):
			material.albedo_color = color.lightened(0.45)
		else:
			material.albedo_color = color


func _control_key(operation: int, axis: int) -> String:
	return "%s%s%s" % [operation, HOVER_KEY_SEPARATOR, axis]


func _make_ring_mesh(axis: int, radius: float, tube_radius_value: float, segments: int, sides: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var axis_direction := _axis_vector(axis)
	var plane := _ring_plane_vectors(axis)
	var u: Vector3 = plane[0]
	var v: Vector3 = plane[1]
	
	for i in range(segments):
		var t := TAU * float(i) / float(segments)
		var radial := (cos(t) * u + sin(t) * v).normalized()
		var center := radial * radius
		for j in range(sides):
			var p := TAU * float(j) / float(sides)
			var tube_normal := (cos(p) * radial + sin(p) * axis_direction).normalized()
			vertices.append(center + tube_normal * tube_radius_value)
			normals.append(tube_normal)
	
	for i in range(segments):
		var next_i := (i + 1) % segments
		for j in range(sides):
			var next_j := (j + 1) % sides
			var a := i * sides + j
			var b := next_i * sides + j
			var c := next_i * sides + next_j
			var d := i * sides + next_j
			indices.append_array([a, b, c, a, c, d])
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _axis_transform(direction: Vector3, center_distance: float) -> Transform3D:
	var rotation := Basis(Quaternion(Vector3.UP, direction.normalized()))
	return Transform3D(rotation, direction * center_distance)


func _update_operation_visibility() -> void:
	if is_instance_valid(_translate_root):
		_translate_root.visible = show_translate_handles
	if is_instance_valid(_rotate_root):
		_rotate_root.visible = show_rotate_handles
	if is_instance_valid(_scale_root):
		_scale_root.visible = show_scale_handles


func _refresh_visual_transform() -> void:
	if not is_instance_valid(_visual_root) or not is_inside_tree():
		return
	
	if screen_constant_size and camera != null:
		_visual_scale = _calculate_screen_constant_scale(camera)
	else:
		_visual_scale = 1.0
	
	var visual_basis := _reference_basis().scaled(Vector3.ONE * _visual_scale)
	_visual_root.global_transform = Transform3D(visual_basis, global_position)


func _calculate_screen_constant_scale(view_camera: Camera3D) -> float:
	var viewport_height := maxf(float(get_viewport().get_visible_rect().size.y), 1.0)
	var depth := (global_position - view_camera.global_position).dot(-view_camera.global_transform.basis.z.normalized())
	depth = maxf(depth, 0.01)
	
	var pixels_per_meter := viewport_height
	if view_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		pixels_per_meter = viewport_height / maxf(view_camera.size, 0.01)
	else:
		var fov_radians := deg_to_rad(view_camera.fov)
		pixels_per_meter = viewport_height / (2.0 * depth * tan(fov_radians * 0.5))
	
	var world_size := screen_size_px / maxf(pixels_per_meter, 0.01)
	return maxf(world_size / maxf(handle_length, 0.01), 0.001)


func _try_begin_drag(screen_position: Vector2, pointer_id: int, touch_input: bool) -> void:
	if _dragging:
		return
	
	if camera == null:
		return
	
	_refresh_visual_transform()
	var hit := _find_handle(screen_position, touch_input)
	if hit.is_empty():
		return
	
	_drag_operation = hit["operation"]
	_drag_axis = hit["axis"]
	_set_hover(_drag_operation, _drag_axis)
	_drag_pointer_id = pointer_id
	_drag_start_global_transform = global_transform
	_drag_changed = false
	
	if not _initialize_drag(screen_position, camera):
		_clear_drag()
		return
	
	_dragging = true
	get_viewport().set_input_as_handled()


func _initialize_drag(screen_position: Vector2, view_camera: Camera3D) -> bool:
	var origin := _drag_start_global_transform.origin
	var axis_direction := _drag_axis_direction()
	
	match _drag_operation:
		Operation.TRANSLATE:
			if _drag_axis == Axis.CENTER:
				var plane_normal := -view_camera.global_transform.basis.z.normalized()
				var point = _ray_plane_intersection(view_camera, screen_position, origin, plane_normal)
				if point == null:
					return false
				_drag_start_plane_point = point
			else:
				_drag_start_axis_param = _axis_param_from_screen(view_camera, screen_position, origin, axis_direction)
		Operation.ROTATE:
			var point = _ray_plane_intersection(view_camera, screen_position, origin, axis_direction)
			if point == null:
				return false
			var rotation_vector: Vector3 = point - origin
			if rotation_vector.length_squared() <= EPSILON:
				return false
			_drag_start_rotation_vector = rotation_vector.normalized()
		Operation.SCALE:
			_drag_start_axis_param = _axis_param_from_screen(view_camera, screen_position, origin, axis_direction)
	
	return true


func _update_drag(screen_position: Vector2) -> void:
	if camera == null:
		return
	
	match _drag_operation:
		Operation.TRANSLATE:
			_update_translate_drag(camera, screen_position)
		Operation.ROTATE:
			_update_rotate_drag(camera, screen_position)
		Operation.SCALE:
			_update_scale_drag(camera, screen_position)
	
	_drag_changed = _drag_changed or _has_transform_changed(_drag_start_global_transform, global_transform)
	_refresh_visual_transform()


func _update_translate_drag(view_camera: Camera3D, screen_position: Vector2) -> void:
	var new_transform := _drag_start_global_transform
	if _drag_axis == Axis.CENTER:
		var plane_normal := -view_camera.global_transform.basis.z.normalized()
		var point = _ray_plane_intersection(view_camera, screen_position, _drag_start_global_transform.origin, plane_normal)
		if point == null:
			return
		new_transform.origin += _filter_position_delta(point - _drag_start_plane_point)
	else:
		var axis_direction := _drag_axis_direction()
		var next_param := _axis_param_from_screen(view_camera, screen_position, _drag_start_global_transform.origin, axis_direction)
		new_transform.origin += axis_direction * (next_param - _drag_start_axis_param)
	
	global_transform = new_transform


func _update_rotate_drag(view_camera: Camera3D, screen_position: Vector2) -> void:
	var origin := _drag_start_global_transform.origin
	var axis_direction := _drag_axis_direction()
	var point = _ray_plane_intersection(view_camera, screen_position, origin, axis_direction)
	if point == null:
		return
	
	var current_vector: Vector3 = point - origin
	if current_vector.length_squared() <= EPSILON:
		return
	
	var angle := _drag_start_rotation_vector.signed_angle_to(current_vector.normalized(), axis_direction)
	var rotation_basis := Basis(Quaternion(axis_direction, angle))
	global_transform = Transform3D(rotation_basis * _drag_start_global_transform.basis, origin)


func _update_scale_drag(view_camera: Camera3D, screen_position: Vector2) -> void:
	var axis_direction := _drag_axis_direction()
	var next_param := _axis_param_from_screen(view_camera, screen_position, _drag_start_global_transform.origin, axis_direction)
	var drag_units := maxf(scale_handle_distance * _visual_scale, 0.001)
	var factor := maxf(1.0 + (next_param - _drag_start_axis_param) / drag_units, minimum_scale_factor)
	var factors := Vector3.ONE
	if _drag_axis == Axis.CENTER:
		factors = Vector3.ONE * factor
	else:
		factors[_drag_axis] = factor
	
	var scale_basis := Basis.IDENTITY.scaled(factors)
	var new_basis := _drag_start_global_transform.basis
	if reference_space == CoordinateSpace.GLOBAL:
		new_basis = scale_basis * _drag_start_global_transform.basis
	else:
		new_basis = _drag_start_global_transform.basis * scale_basis
	
	global_transform = Transform3D(new_basis, _drag_start_global_transform.origin)


func _finish_drag() -> void:
	if _drag_changed and _has_transform_changed(_drag_start_global_transform, global_transform):
		transform_change_finished.emit(_drag_start_global_transform, global_transform)
	_clear_drag()


func _clear_drag() -> void:
	_dragging = false
	_drag_pointer_id = POINTER_MOUSE
	_drag_operation = Operation.TRANSLATE
	_drag_axis = Axis.NONE
	_drag_changed = false
	_clear_hover()


func _find_handle(screen_position: Vector2, touch_input: bool) -> Dictionary:
	if camera == null:
		return {}
	
	var hit_radius := touch_hit_radius_px if touch_input else mouse_hit_radius_px
	var best := {
		"operation": Operation.TRANSLATE,
		"axis": Axis.NONE,
		"distance": INF,
		"priority": -1,
	}
	
	if show_translate_handles:
		for axis in [Axis.X, Axis.Y, Axis.Z]:
			if is_axis_locked(Operation.TRANSLATE, axis):
				continue
			var distance := _screen_distance_to_axis_segment(camera, screen_position, axis, 0.0, handle_length)
			_consider_hit(best, Operation.TRANSLATE, axis, distance, 0)
		
		if locked_position_axes != (AXIS_FLAG_X | AXIS_FLAG_Y | AXIS_FLAG_Z):
			var center_distance := _screen_distance_to_world_point(camera, global_position, screen_position)
			_consider_hit(best, Operation.TRANSLATE, Axis.CENTER, center_distance, 2)
	
	if show_scale_handles:
		for axis in [Axis.X, Axis.Y, Axis.Z]:
			if is_axis_locked(Operation.SCALE, axis):
				continue
			var box_distance := _screen_distance_to_world_point(camera, _world_axis_point(axis, scale_handle_distance), screen_position)
			_consider_hit(best, Operation.SCALE, axis, box_distance, 3)
	
	if show_rotate_handles:
		for axis in [Axis.X, Axis.Y, Axis.Z]:
			if is_axis_locked(Operation.ROTATE, axis):
				continue
			var ring_distance := _screen_distance_to_ring(camera, screen_position, axis)
			_consider_hit(best, Operation.ROTATE, axis, ring_distance, 1)
	
	if best["distance"] <= hit_radius:
		return {
			"operation": best["operation"],
			"axis": best["axis"],
		}
	return {}


func _consider_hit(best: Dictionary, operation: int, axis: int, distance: float, priority: int) -> void:
	if distance < best["distance"] or (absf(distance - best["distance"]) <= 0.001 and priority > best["priority"]):
		best["operation"] = operation
		best["axis"] = axis
		best["distance"] = distance
		best["priority"] = priority


func _screen_distance_to_axis_segment(view_camera: Camera3D, screen_position: Vector2, axis: int, start_distance: float, end_distance: float) -> float:
	return _screen_distance_to_world_segment(
		view_camera,
		_world_axis_point(axis, start_distance),
		_world_axis_point(axis, end_distance),
		screen_position
	)


func _screen_distance_to_ring(view_camera: Camera3D, screen_position: Vector2, axis: int) -> float:
	var plane := _ring_plane_vectors(axis)
	var u: Vector3 = _reference_basis() * plane[0]
	var v: Vector3 = _reference_basis() * plane[1]
	var radius := ring_radius * _visual_scale
	var best := INF
	var previous_valid := false
	var previous_screen := Vector2.ZERO
	
	for i in range(73):
		var t := TAU * float(i) / 72.0
		var world_point := global_position + (cos(t) * u + sin(t) * v) * radius
		if view_camera.is_position_behind(world_point):
			previous_valid = false
			continue
		var projected := view_camera.unproject_position(world_point)
		if previous_valid:
			best = minf(best, _distance_to_screen_segment(screen_position, previous_screen, projected))
		previous_screen = projected
		previous_valid = true
	return best


func _screen_distance_to_world_segment(view_camera: Camera3D, start: Vector3, end: Vector3, screen_position: Vector2) -> float:
	if view_camera.is_position_behind(start) or view_camera.is_position_behind(end):
		return INF
	
	var start_screen := view_camera.unproject_position(start)
	var end_screen := view_camera.unproject_position(end)
	return _distance_to_screen_segment(screen_position, start_screen, end_screen)


func _screen_distance_to_world_point(view_camera: Camera3D, point: Vector3, screen_position: Vector2) -> float:
	if view_camera.is_position_behind(point):
		return INF
	return view_camera.unproject_position(point).distance_to(screen_position)


func _distance_to_screen_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= EPSILON:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _axis_param_from_screen(view_camera: Camera3D, screen_position: Vector2, axis_origin: Vector3, axis_direction: Vector3) -> float:
	var ray_origin := view_camera.project_ray_origin(screen_position)
	var ray_direction := view_camera.project_ray_normal(screen_position).normalized()
	var line_delta := axis_origin - ray_origin
	var a := axis_direction.dot(axis_direction)
	var b := axis_direction.dot(ray_direction)
	var c := ray_direction.dot(ray_direction)
	var d := axis_direction.dot(line_delta)
	var e := ray_direction.dot(line_delta)
	var denominator := a * c - b * b
	
	if absf(denominator) > EPSILON:
		return (b * e - c * d) / denominator
	
	var camera_forward := -view_camera.global_transform.basis.z.normalized()
	var plane_normal := axis_direction.cross(camera_forward)
	if plane_normal.length_squared() <= EPSILON:
		plane_normal = axis_direction.cross(view_camera.global_transform.basis.y.normalized())
	if plane_normal.length_squared() <= EPSILON:
		return 0.0
	
	var point = _ray_plane_intersection(view_camera, screen_position, axis_origin, plane_normal.normalized())
	if point == null:
		return 0.0
	return axis_direction.dot(point - axis_origin)


func _ray_plane_intersection(view_camera: Camera3D, screen_position: Vector2, plane_point: Vector3, plane_normal: Vector3):
	var ray_origin := view_camera.project_ray_origin(screen_position)
	var ray_direction := view_camera.project_ray_normal(screen_position).normalized()
	var denominator := plane_normal.dot(ray_direction)
	if absf(denominator) <= EPSILON:
		return null
	var distance := plane_normal.dot(plane_point - ray_origin) / denominator
	return ray_origin + ray_direction * distance


func _filter_position_delta(delta: Vector3) -> Vector3:
	if locked_position_axes == 0:
		return delta
	
	if reference_space == CoordinateSpace.GLOBAL:
		var filtered := delta
		if (locked_position_axes & AXIS_FLAG_X) != 0:
			filtered.x = 0.0
		if (locked_position_axes & AXIS_FLAG_Y) != 0:
			filtered.y = 0.0
		if (locked_position_axes & AXIS_FLAG_Z) != 0:
			filtered.z = 0.0
		return filtered
	
	var basis := _drag_start_global_transform.basis.orthonormalized()
	var local_delta := basis.inverse() * delta
	if (locked_position_axes & AXIS_FLAG_X) != 0:
		local_delta.x = 0.0
	if (locked_position_axes & AXIS_FLAG_Y) != 0:
		local_delta.y = 0.0
	if (locked_position_axes & AXIS_FLAG_Z) != 0:
		local_delta.z = 0.0
	return basis * local_delta


func _drag_axis_direction() -> Vector3:
	if _drag_axis == Axis.CENTER:
		return Vector3.ZERO
	
	var basis := Basis.IDENTITY
	if reference_space == CoordinateSpace.LOCAL:
		basis = _drag_start_global_transform.basis.orthonormalized()
	return (basis * _axis_vector(_drag_axis)).normalized()


func _reference_basis() -> Basis:
	if reference_space == CoordinateSpace.GLOBAL:
		return Basis.IDENTITY
	return global_transform.basis.orthonormalized()


func _world_axis_point(axis: int, distance: float) -> Vector3:
	var direction := (_reference_basis() * _axis_vector(axis)).normalized()
	return global_position + direction * distance * _visual_scale


func _ring_plane_vectors(axis: int) -> Array:
	match axis:
		Axis.X:
			return [Vector3.UP, Vector3.BACK]
		Axis.Y:
			return [Vector3.RIGHT, Vector3.BACK]
		Axis.Z:
			return [Vector3.RIGHT, Vector3.UP]
	return [Vector3.RIGHT, Vector3.UP]


func _axis_vector(axis: int) -> Vector3:
	match axis:
		Axis.X:
			return Vector3.RIGHT
		Axis.Y:
			return Vector3.UP
		Axis.Z:
			return Vector3.BACK
	return Vector3.ZERO


func _axis_name(axis: int) -> String:
	match axis:
		Axis.X:
			return "X"
		Axis.Y:
			return "Y"
		Axis.Z:
			return "Z"
	return "Center"


func _has_transform_changed(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_squared_to(b.origin) > EPSILON * EPSILON:
		return true
	if a.basis.x.distance_squared_to(b.basis.x) > EPSILON * EPSILON:
		return true
	if a.basis.y.distance_squared_to(b.basis.y) > EPSILON * EPSILON:
		return true
	if a.basis.z.distance_squared_to(b.basis.z) > EPSILON * EPSILON:
		return true
	return false
