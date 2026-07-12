extends Control
class_name CameraMinimap

@export var camera_path: NodePath
@export var scene_center := Vector3.ZERO
@export var top_map_world_radius := 6.0
@export var side_map_world_radius := 5.0
@export var map_size := 108.0
@export var map_gap := 8.0

const BACKGROUND := Color(0.025, 0.03, 0.04, 0.68)
const BORDER := Color(1.0, 1.0, 1.0, 0.32)
const GRID := Color(1.0, 1.0, 1.0, 0.11)
const FRUSTUM := Color(0.42, 0.82, 1.0, 0.95)
const FRUSTUM_FILL := Color(0.16, 0.55, 0.95, 0.16)
const CENTER_MARK := Color(1.0, 0.42, 0.36, 0.95)
const GROUND := Color(0.38, 1.0, 0.58, 0.85)
const TEXT := Color(1.0, 1.0, 1.0, 0.92)
const CAMERA_DOT := Color(1.0, 1.0, 1.0, 0.95)

var _camera: Camera3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_resolve_camera()
	set_process(true)


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_resolve_camera()

	queue_redraw()


func _draw() -> void:
	if _camera == null:
		return

	var top_rect := Rect2(Vector2.ZERO, Vector2(map_size, map_size))
	var side_rect := Rect2(Vector2(0.0, map_size + map_gap), Vector2(map_size, map_size))

	_draw_panel(top_rect)
	_draw_topdown(top_rect)
	_draw_top_label(top_rect)

	_draw_panel(side_rect)
	_draw_side(side_rect)
	_draw_side_label(side_rect)


func _get_minimum_size() -> Vector2:
	return Vector2(map_size, map_size * 2.0 + map_gap)


func _resolve_camera() -> void:
	if camera_path.is_empty():
		return

	_camera = get_node_or_null(camera_path) as Camera3D


func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, BACKGROUND, true)
	draw_rect(rect, BORDER, false, 1.0)

	var center := rect.get_center()
	draw_line(Vector2(rect.position.x, center.y), Vector2(rect.end.x, center.y), GRID, 1.0)
	draw_line(Vector2(center.x, rect.position.y), Vector2(center.x, rect.end.y), GRID, 1.0)


func _draw_topdown(rect: Rect2) -> void:
	var center := rect.get_center()
	var camera_pos := _camera.global_position
	var scl := (rect.size.x * 0.42) / maxf(top_map_world_radius, 0.001)
	var right := Vector2(_camera.global_basis.x.x, _camera.global_basis.x.z).normalized()
	var forward := Vector2(-_camera.global_basis.z.x, -_camera.global_basis.z.z).normalized()
	
	if right.is_zero_approx() or forward.is_zero_approx():
		right = Vector2.RIGHT
		forward = Vector2.UP
	
	var center_offset := Vector2(scene_center.x - camera_pos.x, scene_center.z - camera_pos.z)
	var scene_center_screen := center + Vector2(center_offset.dot(right), -center_offset.dot(forward)) * scl

	_draw_top_frustum(rect)
	_draw_cross(scene_center_screen, CENTER_MARK, 5.0)
	draw_circle(center, 3.0, CAMERA_DOT)


func _draw_top_frustum(rect: Rect2) -> void:
	var center := rect.get_center()
	var aspect := _get_camera_aspect()
	var half_fov := deg_to_rad(_camera.fov) * 0.5
	var half_horizontal_fov := atan(tan(half_fov) * aspect)
	var far := rect.size.x * 0.36
	var near := rect.size.x * 0.07
	var left_dir := Vector2(sin(-half_horizontal_fov), -cos(half_horizontal_fov))
	var right_dir := Vector2(sin(half_horizontal_fov), -cos(half_horizontal_fov))
	var near_left := center + left_dir * near
	var near_right := center + right_dir * near
	var far_left := center + left_dir * far
	var far_right := center + right_dir * far
	var points := PackedVector2Array([near_left, far_left, far_right, near_right])

	draw_colored_polygon(points, FRUSTUM_FILL)
	draw_polyline(PackedVector2Array([near_left, far_left, far_right, near_right, near_left]), FRUSTUM, 1.4, true)
	draw_line(center, center + Vector2.UP * far, FRUSTUM, 1.0, true)


func _draw_side(rect: Rect2) -> void:
	var center := rect.get_center()
	var scl := (rect.size.y * 0.42) / maxf(side_map_world_radius, 0.001)
	var camera_pos := _camera.global_position
	var ground_y := center.y + (camera_pos.y - scene_center.y) * scl

	if ground_y >= rect.position.y and ground_y <= rect.end.y:
		draw_line(Vector2(rect.position.x, ground_y), Vector2(rect.end.x, ground_y), GROUND, 1.3, true)

	_draw_side_frustum(rect)
	draw_circle(center, 3.0, CAMERA_DOT)


func _draw_side_frustum(rect: Rect2) -> void:
	var center := rect.get_center()
	var forward := -_camera.global_basis.z
	var pitch := asin(clampf(forward.y, -1.0, 1.0))
	var half_fov := deg_to_rad(_camera.fov) * 0.5
	var far := rect.size.x * 0.36
	var near := rect.size.x * 0.07
	var upper_dir := _side_direction(pitch + half_fov)
	var lower_dir := _side_direction(pitch - half_fov)
	var near_upper := center + upper_dir * near
	var near_lower := center + lower_dir * near
	var far_upper := center + upper_dir * far
	var far_lower := center + lower_dir * far
	var points := PackedVector2Array([near_upper, far_upper, far_lower, near_lower])

	draw_colored_polygon(points, FRUSTUM_FILL)
	draw_polyline(PackedVector2Array([near_upper, far_upper, far_lower, near_lower, near_upper]), FRUSTUM, 1.4, true)
	draw_line(center, center + _side_direction(pitch) * far, FRUSTUM, 1.0, true)


func _side_direction(angle: float) -> Vector2:
	return Vector2(cos(angle), -sin(angle)).normalized()


func _draw_top_label(rect: Rect2) -> void:
	var camera_pos := _camera.global_position
	var label := "X %.2f  Z %.2f" % [camera_pos.x, camera_pos.z]
	_draw_centered_label(label, Vector2(rect.get_center().x, rect.position.y + 15.0))


func _draw_side_label(rect: Rect2) -> void:
	var forward := -_camera.global_basis.z
	var pitch := rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))
	var label := "Y %.2f  %.1f°" % [_camera.global_position.y, pitch]
	_draw_centered_label(label, Vector2(rect.get_center().x, rect.end.y - 6.0), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)


func _draw_centered_label(
	label: String,
	pos: Vector2,
	alignment := HORIZONTAL_ALIGNMENT_CENTER,
	vertical_alignment := VERTICAL_ALIGNMENT_CENTER
) -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var text_size := font.get_string_size(label, alignment, -1.0, font_size)
	var text_position := pos

	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		text_position.x -= text_size.x * 0.5
	if vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		text_position.y += text_size.y * 0.35

	draw_string(font, text_position + Vector2(1.0, 1.0), label, alignment, -1.0, font_size, Color(0, 0, 0, 0.75))
	draw_string(font, text_position, label, alignment, -1.0, font_size, TEXT)


func _draw_cross(pos: Vector2, color: Color, radius: float) -> void:
	draw_line(pos + Vector2.LEFT * radius, pos + Vector2.RIGHT * radius, color, 1.5, true)
	draw_line(pos + Vector2.UP * radius, pos + Vector2.DOWN * radius, color, 1.5, true)
	draw_circle(pos, 2.0, color)


func _get_camera_aspect() -> float:
	var viewport := _camera.get_viewport()

	if viewport == null:
		return 1.0

	var viewport_size := viewport.get_visible_rect().size

	if viewport_size.y <= 0.0:
		return 1.0

	return viewport_size.x / viewport_size.y
