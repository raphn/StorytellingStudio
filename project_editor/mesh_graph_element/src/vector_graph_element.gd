extends GraphElement
class_name VectorGraphElementRuntime

const POINT_GIZMO_TEXTURE := preload("res://project_editor/mesh_graph_element/graphs/point.png")
const POINT_GIZMO_SELECTED_TEXTURE := preload("res://project_editor/mesh_graph_element/graphs/point_selected.png")

const MIN_GRAPH_ELEMENT_SIZE := Vector2(8, 8)
const GEOMETRY_EPSILON := 0.001

signal something_changed
signal vertices_changed(vertices: Array[Resource])

var vertices: Array[VectorGraphVertex]:
	set(value):
		_set_vertices(value, true)
	get:
		return _vertices
var runtime_editable := true:
	set(value):
		runtime_editable = value
		_sync_gizmos()
var fill_color := Color.WHITE: # Nice blue -> Color(0.16, 0.56, 0.92, 0.18):
	set(value):
		fill_color = value
		queue_redraw()
var outline_color := Color.BLACK: # Nice blue -> Color(0.08, 0.28, 0.46, 0.86):
	set(value):
		outline_color = value
		queue_redraw()
var outline_width := 2.0:
	set(value):
		outline_width = value
		queue_redraw()
var curve_segments_per_edge := 12:
	set(value):
		curve_segments_per_edge = value
		_refresh_geometry(false)
var vertex_gizmo_modulate := Color.WEB_GRAY:
	set(value):
		vertex_gizmo_modulate = value
		_sync_gizmos()
var in_handle_gizmo_modulate := Color(0.35, 0.75, 1.0):
	set(value):
		in_handle_gizmo_modulate = value
		_sync_gizmos()
var out_handle_gizmo_modulate := Color(1.0, 0.62, 0.25):
	set(value):
		out_handle_gizmo_modulate = value
		_sync_gizmos()
var handle_line_color := Color(0.501, 0.501, 0.501, 0.42):
	set(value):
		handle_line_color = value
		queue_redraw()
var gizmo_size := Vector2(24, 24):
	set(value):
		gizmo_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		queue_redraw()

# Number of the page this frame belongs to
var origin_page := -1

var long_press_seconds := 0.45
var long_press_move_tolerance := 8.0
var edge_hit_distance := 14.0
var debug_gizmo_render := true
var undo_limit := 64

var _vertices: Array[VectorGraphVertex] = VectorPathGeometry.make_square_vertices()
var _is_refreshing_vertices := false
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _active_history_label := ""
var _active_history_snapshot: Dictionary = {}
var _dragged_gizmo_vertex_index := -1
var _dragged_gizmo_role := -1
var _hovered_gizmo_vertex_index := -1
var _hovered_gizmo_role := -1
var _vertices_with_visible_handles: Dictionary = {}
var _long_press_vertex_index := -1
var _long_press_start_position := Vector2.ZERO
var _long_press_elapsed := 0.0
var _long_press_active := false
var _fill_triangulation_failed := false
var _hovered_segment_start_index := -1
var _hovered_segment_end_index := -1
var _skew_segment_start_index := -1
var _skew_segment_end_index := -1
var _skew_drag_start_mouse := Vector2.ZERO
var _skew_drag_start_a := Vector2.ZERO
var _skew_drag_start_b := Vector2.ZERO
var _skew_drag_direction := Vector2.ZERO
var _skew_cursor_active := false
var _is_resizing_rect := false
var _resize_drag_direction := Vector2.ZERO
var _resize_drag_delta := Vector2.ZERO
var _resize_drag_start_size := Vector2.ZERO
var _resize_drag_start_position_offset := Vector2.ZERO
var _resize_drag_start_bounds := Rect2()
var _resize_drag_start_vertices: Array[VectorGraphVertex] = []


# ============================================================================== CALLBACKS

func _ready() -> void:
	clip_contents = false
	resizable = true
	add_theme_icon_override(&"resizer", VecGraphIcons.get_resize_diagonal_left())
	_configure_graph_element_signals()
	_set_vertices(vertices, false)
	
	var panel := TextureRect.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_gizmos()
	elif what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_EXIT_TREE:
		_clear_segment_hover()

func _process(delta: float) -> void:
	if not _long_press_active:
		set_process(false)
		return
	
	if not _should_show_gizmos() or not _has_vertex(_long_press_vertex_index):
		_cancel_long_press()
		_debug_gizmo("long press canceled")
		return
	
	_long_press_elapsed += delta
	if _long_press_elapsed >= long_press_seconds:
		_cancel_history_edit()
		_toggle_vertex_handles(_long_press_vertex_index)
		_stop_dragging_gizmo()
		_cancel_long_press()

func _input(event: InputEvent) -> void:
	if not _should_show_resize_handles():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var direction := _find_resize_handle_direction(_event_to_local_position(event))
			if direction != Vector2.ZERO:
				_start_resize_handle_drag(direction)
				get_viewport().set_input_as_handled()
		elif _is_resize_handle_dragging():
			_stop_resize_handle_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_resize_handle_dragging():
		_move_resize_handle_drag(_screen_delta_to_local(event.relative))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			var direction := _find_resize_handle_direction(_event_to_local_position(event))
			if direction != Vector2.ZERO:
				_start_resize_handle_drag(direction)
				get_viewport().set_input_as_handled()
		elif _is_resize_handle_dragging():
			_stop_resize_handle_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _is_resize_handle_dragging():
		_move_resize_handle_drag(_screen_delta_to_local(event.relative))
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not _should_show_gizmos():
		_clear_segment_hover()
		return
	
	if _is_resize_handle_dragging():
		accept_event()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_on_resize_handle(event.position):
				_clear_segment_hover()
				accept_event()
			elif _try_begin_gizmo_drag(event.position):
				accept_event()
			elif _try_use_segment_press(event.position):
				accept_event()
		else:
			_cancel_long_press()
			if _is_dragging_gizmo():
				_stop_dragging_gizmo()
				accept_event()
			elif _is_skew_dragging():
				_stop_skew_drag()
				accept_event()
	elif event is InputEventMouseMotion:
		if _is_dragging_gizmo():
			if _is_waiting_for_long_press(event.position):
				accept_event()
				return
			_move_gizmo_target(_dragged_gizmo_vertex_index, _dragged_gizmo_role, event.position)
			accept_event()
		elif _is_skew_dragging():
			_move_skew_segment(event.position)
			accept_event()
		elif _is_on_resize_handle(event.position):
			_clear_segment_hover()
			accept_event()
		else:
			_update_hover(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_on_resize_handle(event.position):
				_clear_segment_hover()
				accept_event()
			elif _try_begin_gizmo_drag(event.position):
				accept_event()
			elif _try_use_segment_press(event.position):
				accept_event()
		else:
			_cancel_long_press()
			if _is_dragging_gizmo():
				_stop_dragging_gizmo()
				accept_event()
			elif _is_skew_dragging():
				_stop_skew_drag()
				accept_event()
	elif event is InputEventScreenDrag:
		if _is_dragging_gizmo():
			if _is_waiting_for_long_press(event.position):
				accept_event()
				return
			_move_gizmo_target(_dragged_gizmo_vertex_index, _dragged_gizmo_role, event.position)
			accept_event()
		elif _is_skew_dragging():
			_move_skew_segment(event.position)
			accept_event()

func _draw() -> void:
	var closed_path := VectorPathGeometry.sample_closed_path(_vertices, curve_segments_per_edge)
	var fill_path := VectorPathGeometry.clean_polygon(closed_path)
	
	if VectorPathGeometry.can_fill_polygon(fill_path):
		_fill_triangulation_failed = false
		draw_colored_polygon(fill_path, fill_color)
	elif debug_gizmo_render and not _fill_triangulation_failed:
		_fill_triangulation_failed = true
		_debug_gizmo("fill skipped: polygon triangulation failed")
	
	if outline_width > 0.0 and fill_path.size() >= 2:
		var outline_points := PackedVector2Array(fill_path)
		outline_points.append(fill_path[0])
		draw_polyline(outline_points, outline_color, outline_width, true)
	
	if _should_show_gizmos():
		_draw_hovered_segment()
		_draw_handle_guides()
		_draw_gizmos()
		_draw_resize_handles()


# ============================================================================== SAVE LOAD

func get_data() -> VectorGraphData:
	return VectorGraphData.from(self)

static func create_from(data:VectorGraphData, with_parent:GraphEdit, controller:ProjectEditor) -> void:
	var n_vec := VectorGraphElementRuntime.new()
	with_parent.add_child(n_vec)
	
	n_vec.position_offset = data.position_offset
	n_vec.size = data.size
	n_vec.custom_minimum_size = data.custom_minimum_size
	n_vec.resizable = data.resizable
	n_vec.draggable = data.draggable
	n_vec.selectable = data.selectable
	n_vec.vertices = VectorPathGeometry.sanitize_vertices(data.vertices)
	n_vec.runtime_editable = data.runtime_editable
	n_vec.fill_color = data.fill_color
	n_vec.outline_color = data.outline_color
	n_vec.outline_width = data.outline_width
	n_vec.curve_segments_per_edge = data.curve_segments_per_edge
	n_vec.vertex_gizmo_modulate = data.vertex_gizmo_modulate
	n_vec.in_handle_gizmo_modulate = data.in_handle_gizmo_modulate
	n_vec.out_handle_gizmo_modulate = data.out_handle_gizmo_modulate
	n_vec.handle_line_color = data.handle_line_color
	
	n_vec.something_changed.connect(func(): controller.set_dirty())


# ============================================================================== CLASS BODY

func reset_shape(side := 160.0) -> void:
	var before := _make_history_snapshot()
	_set_vertices(VectorPathGeometry.make_square_vertices(side), false)
	_push_undo_snapshot(before, "Reset Shape")

func get_curve_2d() -> Curve2D:
	return VectorPathGeometry.to_curve_2d(_vertices)

func set_vertex_position(vertex_index: int, local_position: Vector2) -> void:
	if not _has_vertex(vertex_index):
		return
	
	var before := _make_history_snapshot()
	_set_vertex_position(vertex_index, local_position)
	_push_undo_snapshot(before, "Move Vertex")

func set_vertex_in_handle(vertex_index: int, local_position: Vector2) -> void:
	if not _has_vertex(vertex_index):
		return
	
	var before := _make_history_snapshot()
	_set_vertex_in_handle(vertex_index, local_position)
	_push_undo_snapshot(before, "Move In Handle")

func set_vertex_out_handle(vertex_index: int, local_position: Vector2) -> void:
	if not _has_vertex(vertex_index):
		return
	
	var before := _make_history_snapshot()
	_set_vertex_out_handle(vertex_index, local_position)
	_push_undo_snapshot(before, "Move Out Handle")


func undo() -> bool:
	return undo_geometry_edit()

func redo() -> bool:
	return redo_geometry_edit()

func undo_geometry_edit() -> bool:
	if _undo_stack.is_empty():
		return false
	
	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append({
		"label": entry.label,
		"snapshot": _make_history_snapshot(),
	})
	_apply_history_snapshot(entry.snapshot)
	_debug_gizmo("undo %s" % entry.label)
	return true

func redo_geometry_edit() -> bool:
	if _redo_stack.is_empty():
		return false
	
	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append({
		"label": entry.label,
		"snapshot": _make_history_snapshot(),
	})
	_apply_history_snapshot(entry.snapshot)
	_debug_gizmo("redo %s" % entry.label)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not selected:
		return
	
	if _is_action_pressed_if_exists(event, &"ui_undo") or _is_action_pressed_if_exists(event, &"undo"):
		if undo_geometry_edit():
			get_viewport().set_input_as_handled()
	elif _is_action_pressed_if_exists(event, &"ui_redo") or _is_action_pressed_if_exists(event, &"redo"):
		if redo_geometry_edit():
			get_viewport().set_input_as_handled()

func _set_vertex_position(vertex_index: int, local_position: Vector2) -> void:
	var next_vertices := _copy_vertices()
	next_vertices[vertex_index].position = local_position
	_set_vertices(next_vertices, true)

func _set_vertex_in_handle(vertex_index: int, local_position: Vector2) -> void:
	var next_vertices := _copy_vertices()
	next_vertices[vertex_index].in_handle = local_position - next_vertices[vertex_index].position
	_set_vertices(next_vertices, true)

func _set_vertex_out_handle(vertex_index: int, local_position: Vector2) -> void:
	var next_vertices := _copy_vertices()
	next_vertices[vertex_index].out_handle = local_position - next_vertices[vertex_index].position
	_set_vertices(next_vertices, true)

func _configure_graph_element_signals() -> void:
	if not node_selected.is_connected(_on_node_selected):
		node_selected.connect(_on_node_selected)
	if not node_deselected.is_connected(_on_node_deselected):
		node_deselected.connect(_on_node_deselected)
	if not resize_request.is_connected(_on_resize_request):
		resize_request.connect(_on_resize_request)
	if not resize_end.is_connected(_on_resize_end):
		resize_end.connect(_on_resize_end)

func _on_node_selected() -> void:
	_sync_gizmos()
	queue_redraw()

func _on_node_deselected() -> void:
	_stop_resize_handle_drag()
	_stop_dragging_gizmo()
	_stop_skew_drag()
	_hovered_gizmo_vertex_index = -1
	_hovered_gizmo_role = -1
	_clear_segment_hover()
	_cancel_long_press()
	_sync_gizmos()
	queue_redraw()

func _set_vertices(value: Array[VectorGraphVertex], preserve_graph_position: bool) -> void:
	if _is_refreshing_vertices:
		_vertices = value
		return
	
	_is_refreshing_vertices = true
	_vertices = VectorPathGeometry.sanitize_vertices(value)
	_trim_visible_handle_state()
	_refresh_geometry(preserve_graph_position)
	_is_refreshing_vertices = false

func _refresh_geometry(preserve_graph_position: bool) -> void:
	var graph_position_shift := _normalize_to_local_space()
	if preserve_graph_position and graph_position_shift != Vector2.ZERO:
		position_offset += graph_position_shift
	_fit_rect_to_geometry()
	_sync_gizmos()
	queue_redraw()
	vertices_changed.emit(_vertices)

func _normalize_to_local_space() -> Vector2:
	var bounds := VectorPathGeometry.get_local_bounds(_vertices, curve_segments_per_edge)
	var shift := bounds.position
	if shift == Vector2.ZERO:
		return Vector2.ZERO
	
	VectorPathGeometry.shift_vertex_positions(_vertices, -shift)
	return shift

func _fit_rect_to_geometry() -> void:
	var bounds := VectorPathGeometry.get_local_bounds(_vertices, curve_segments_per_edge)
	var required_size := Vector2(
		maxf(bounds.size.x, MIN_GRAPH_ELEMENT_SIZE.x),
		maxf(bounds.size.y, MIN_GRAPH_ELEMENT_SIZE.y)
	)
	custom_minimum_size = MIN_GRAPH_ELEMENT_SIZE
	size = required_size

func _on_resize_request(new_size: Vector2) -> void:
	if not resizable:
		return
	if _is_resize_handle_dragging():
		return
	
	if not _is_resizing_rect:
		_begin_history_edit("Resize Shape")
		_is_resizing_rect = true
	
	_resize_geometry_to_size(new_size)

func _on_resize_end(_new_size: Vector2) -> void:
	if _is_resize_handle_dragging():
		return
	if not _is_resizing_rect:
		return
	
	_is_resizing_rect = false
	_commit_history_edit()

func _resize_geometry_to_size(new_size: Vector2) -> void:
	var target_size := Vector2(
		maxf(new_size.x, MIN_GRAPH_ELEMENT_SIZE.x),
		maxf(new_size.y, MIN_GRAPH_ELEMENT_SIZE.y)
	)
	var bounds := VectorPathGeometry.get_local_bounds(_vertices, curve_segments_per_edge)
	_apply_resized_geometry(_vertices, bounds, target_size, position_offset)

func _apply_resized_geometry(source_vertices: Array[VectorGraphVertex], source_bounds: Rect2, target_size: Vector2, target_position_offset: Vector2) -> void:
	var scl := Vector2.ONE
	if source_bounds.size.x > GEOMETRY_EPSILON:
		scl.x = target_size.x / source_bounds.size.x
	if source_bounds.size.y > GEOMETRY_EPSILON:
		scl.y = target_size.y / source_bounds.size.y
	
	var next_vertices := _copy_vertices_from(source_vertices)
	for vertex in next_vertices:
		vertex.position = (vertex.position - source_bounds.position) * scl
		vertex.in_handle *= scl
		vertex.out_handle *= scl
	
	position_offset = target_position_offset
	_set_vertices(next_vertices, true)

func _draw_resize_handles() -> void:
	if not _should_show_resize_handles():
		return
	
	for handle in _get_resize_handle_infos():
		_draw_resize_handle(handle.texture, handle.rect.position)

func _draw_resize_handle(texture: Texture2D, handle_position: Vector2) -> void:
	draw_texture(texture, handle_position)

func _should_show_resize_handles() -> bool:
	return resizable and selected


func _is_on_resize_handle(local_position: Vector2) -> bool:
	return _find_resize_handle_direction(local_position) != Vector2.ZERO

func _find_resize_handle_direction(local_position: Vector2) -> Vector2:
	if not _should_show_resize_handles():
		return Vector2.ZERO
	
	for handle in _get_resize_handle_infos():
		var rect: Rect2 = handle.rect
		if rect.has_point(local_position):
			return handle.direction
	return Vector2.ZERO

func _get_resize_handle_infos() -> Array[Dictionary]:
	var diag_left := VecGraphIcons.get_resize_diagonal_left()
	var diag_right := VecGraphIcons.get_resize_diagonal_right()
	var horiz_tex := VecGraphIcons.get_resize_horizontal()
	var vert_tex := VecGraphIcons.get_resize_vertical()
	
	var diagonal_left_size := diag_left.get_size()
	var diagonal_right_size := diag_right.get_size()
	var horizontal_size := horiz_tex.get_size()
	var vertical_size := vert_tex.get_size()
	
	return [
		{
			"texture": diag_left,
			"rect": Rect2(-diagonal_left_size, diagonal_left_size),
			"direction": Vector2(-1, -1),
		},
		{
			"texture": diag_right,
			"rect": Rect2(Vector2(size.x, -diagonal_right_size.y), diagonal_right_size),
			"direction": Vector2(1, -1),
		},
		{
			"texture": diag_right,
			"rect": Rect2(Vector2(-diagonal_right_size.x, size.y), diagonal_right_size),
			"direction": Vector2(-1, 1),
		},
		{
			"texture": diag_left,
			"rect": Rect2(size, diagonal_left_size),
			"direction": Vector2(1, 1),
		},
		{
			"texture": horiz_tex,
			"rect": Rect2(Vector2(-horizontal_size.x, (size.y - horizontal_size.y) * 0.5), horizontal_size),
			"direction": Vector2(-1, 0),
		},
		{
			"texture": horiz_tex,
			"rect": Rect2(Vector2(size.x, (size.y - horizontal_size.y) * 0.5), horizontal_size),
			"direction": Vector2(1, 0),
		},
		{
			"texture": vert_tex,
			"rect": Rect2(Vector2((size.x - vertical_size.x) * 0.5, -vertical_size.y), vertical_size),
			"direction": Vector2(0, -1),
		},
		{
			"texture": vert_tex,
			"rect": Rect2(Vector2((size.x - vertical_size.x) * 0.5, size.y), vertical_size),
			"direction": Vector2(0, 1),
		},
	]

func _start_resize_handle_drag(direction: Vector2) -> void:
	_cancel_long_press()
	_stop_dragging_gizmo()
	_stop_skew_drag()
	_clear_segment_hover()
	_begin_history_edit("Resize Shape")
	_is_resizing_rect = true
	_resize_drag_direction = direction
	_resize_drag_delta = Vector2.ZERO
	_resize_drag_start_size = size
	_resize_drag_start_position_offset = position_offset
	_resize_drag_start_bounds = VectorPathGeometry.get_local_bounds(_vertices, curve_segments_per_edge)
	_resize_drag_start_vertices = _copy_vertices()

func _move_resize_handle_drag(local_delta: Vector2) -> void:
	if not _is_resize_handle_dragging():
		return
	
	_resize_drag_delta += local_delta
	var target_size := _resize_drag_start_size
	if _resize_drag_direction.x != 0.0:
		target_size.x = maxf(MIN_GRAPH_ELEMENT_SIZE.x, _resize_drag_start_size.x + (_resize_drag_delta.x * _resize_drag_direction.x))
	if _resize_drag_direction.y != 0.0:
		target_size.y = maxf(MIN_GRAPH_ELEMENT_SIZE.y, _resize_drag_start_size.y + (_resize_drag_delta.y * _resize_drag_direction.y))
	
	var target_position_offset := _resize_drag_start_position_offset
	if _resize_drag_direction.x < 0.0:
		target_position_offset.x += _resize_drag_start_size.x - target_size.x
	if _resize_drag_direction.y < 0.0:
		target_position_offset.y += _resize_drag_start_size.y - target_size.y
	
	_apply_resized_geometry(_resize_drag_start_vertices, _resize_drag_start_bounds, target_size, target_position_offset)
	queue_redraw()

func _stop_resize_handle_drag() -> void:
	if not _is_resize_handle_dragging():
		return
	
	_resize_drag_direction = Vector2.ZERO
	_resize_drag_delta = Vector2.ZERO
	_resize_drag_start_vertices.clear()
	_is_resizing_rect = false
	_commit_history_edit()

func _is_resize_handle_dragging() -> bool:
	return _resize_drag_direction != Vector2.ZERO

func _event_to_local_position(event: InputEvent) -> Vector2:
	var local_event := make_input_local(event)
	return local_event.position

func _screen_delta_to_local(screen_delta: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse().basis_xform(screen_delta)


func _sync_gizmos() -> void:
	if not _should_show_gizmos():
		_stop_resize_handle_drag()
		_stop_dragging_gizmo()
		_stop_skew_drag()
		_hovered_gizmo_vertex_index = -1
		_hovered_gizmo_role = -1
		_clear_segment_hover()
		_cancel_long_press()
	queue_redraw()

func _move_gizmo_target(vertex_index: int, role: int, local_position: Vector2) -> void:
	match role:
		VectorPointGizmo.Role.IN_HANDLE:
			_set_vertex_in_handle(vertex_index, local_position)
		VectorPointGizmo.Role.OUT_HANDLE:
			_set_vertex_out_handle(vertex_index, local_position)
		_:
			_set_vertex_position(vertex_index, local_position)

func _draw_handle_guides() -> void:
	for vertex_index in _vertices.size():
		if not _are_vertex_handles_visible(vertex_index):
			continue
		
		var vertex := _vertices[vertex_index]
		draw_line(vertex.position, vertex.position + vertex.in_handle, handle_line_color, 1.0, true)
		draw_line(vertex.position, vertex.position + vertex.out_handle, handle_line_color, 1.0, true)

func _draw_hovered_segment() -> void:
	if not _has_vertex(_hovered_segment_start_index) or not _has_vertex(_hovered_segment_end_index):
		return
	
	var a: Vector2 = _vertices[_hovered_segment_start_index].position
	var b: Vector2 = _vertices[_hovered_segment_end_index].position
	draw_line(a, b, Color(1.0, 0.85, 0.15, 0.75), maxf(outline_width + 2.0, 3.0), true)

func _draw_gizmos() -> void:
	for vertex_index in _vertices.size():
		_draw_gizmo(vertex_index, VectorPointGizmo.Role.VERTEX)
	
	for vertex_index in _vertices.size():
		if _are_vertex_handles_visible(vertex_index):
			_draw_gizmo(vertex_index, VectorPointGizmo.Role.IN_HANDLE)
			_draw_gizmo(vertex_index, VectorPointGizmo.Role.OUT_HANDLE)

func _draw_gizmo(vertex_index: int, role: int) -> void:
	var center := _get_gizmo_center(vertex_index, role)
	var rect := Rect2(center - (gizmo_size * 0.5), gizmo_size)
	var texture := POINT_GIZMO_TEXTURE
	
	if _is_active_gizmo(vertex_index, role):
		texture = POINT_GIZMO_SELECTED_TEXTURE
	
	draw_texture_rect(texture, rect, false, _get_gizmo_modulate(role))
	if debug_gizmo_render:
		draw_rect(rect, _get_gizmo_modulate(role), false, 2.0)
		draw_line(rect.position, rect.end, _get_gizmo_modulate(role), 1.0, true)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), _get_gizmo_modulate(role), 1.0, true)

func _should_show_gizmos() -> bool:
	return selected # runtime_editable and selected and _selected_for_editing


func _try_begin_gizmo_drag(local_position: Vector2) -> bool:
	var hit: Dictionary = _find_gizmo_at(local_position)
	if not hit.has("vertex_index"):
		return false
	
	_clear_segment_hover()
	_dragged_gizmo_vertex_index = hit.vertex_index
	_dragged_gizmo_role = hit.role
	_begin_history_edit(_get_gizmo_history_label(hit.role))
	_start_long_press(hit.vertex_index, local_position)
	return true

func _try_use_segment_press(local_position: Vector2) -> bool:
	var hit: Dictionary = _find_segment_near(local_position)
	if not hit.has("start_index"):
		return false
	
	if _is_vert_draw_pressed():
		_insert_vertex_on_segment(hit)
	else:
		_start_skew_drag(hit, local_position)
	return true

func _find_gizmo_at(local_position: Vector2) -> Dictionary:
	for vertex_index in range(_vertices.size() - 1, -1, -1):
		var roles := [VectorPointGizmo.Role.VERTEX]
		if _are_vertex_handles_visible(vertex_index):
			roles = [
				VectorPointGizmo.Role.OUT_HANDLE,
				VectorPointGizmo.Role.IN_HANDLE,
				VectorPointGizmo.Role.VERTEX,
			]
		
		for role in roles:
			var rect := Rect2(_get_gizmo_center(vertex_index, role) - (gizmo_size * 0.5), gizmo_size)
			if rect.has_point(local_position):
				return {
					"vertex_index": vertex_index,
					"role": role,
				}
	
	return {}

func _update_hover(local_position: Vector2) -> void:
	var gizmo_hit: Dictionary = _find_gizmo_at(local_position)
	var next_hover_vertex_index := int(gizmo_hit.get("vertex_index", -1))
	var next_hover_role := int(gizmo_hit.get("role", -1))
	var hover_changed := next_hover_vertex_index != _hovered_gizmo_vertex_index or next_hover_role != _hovered_gizmo_role
	_hovered_gizmo_vertex_index = next_hover_vertex_index
	_hovered_gizmo_role = next_hover_role
	
	if gizmo_hit.has("vertex_index"):
		_clear_segment_hover()
	elif _update_segment_hover(local_position):
		hover_changed = true
	
	if hover_changed:
		queue_redraw()

func _update_segment_hover(local_position: Vector2) -> bool:
	var hit: Dictionary = _find_segment_near(local_position)
	var next_start := int(hit.get("start_index", -1))
	var next_end := int(hit.get("end_index", -1))
	var changed := next_start != _hovered_segment_start_index or next_end != _hovered_segment_end_index
	_hovered_segment_start_index = next_start
	_hovered_segment_end_index = next_end
	
	if hit.has("direction"):
		_apply_skew_cursor(hit.direction)
	else:
		_clear_skew_cursor()
	
	return changed


func _find_segment_near(local_position: Vector2) -> Dictionary:
	var best_hit: Dictionary = {}
	var best_distance := INF
	for start_index in _vertices.size():
		var end_index := (start_index + 1) % _vertices.size()
		var a: Vector2 = _vertices[start_index].position
		var b: Vector2 = _vertices[end_index].position
		var segment: Vector2 = b - a
		var length_squared: float = segment.length_squared()
		if length_squared <= 0.0001:
			continue
		
		var projection: Vector2 = _project_point_to_segment(local_position, a, b)
		var distance: float = local_position.distance_to(projection)
		if distance <= edge_hit_distance and distance < best_distance:
			best_distance = distance
			best_hit = {
				"start_index": start_index,
				"end_index": end_index,
				"point": projection,
				"direction": segment.normalized(),
				"distance": distance,
			}
	
	return best_hit

func _project_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return a
	
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return a + (segment * t)

func _insert_vertex_on_segment(hit: Dictionary) -> void:
	var before := _make_history_snapshot()
	var next_vertices := _copy_vertices()
	var insert_index := int(hit.start_index) + 1
	if insert_index > next_vertices.size():
		insert_index = next_vertices.size()
	next_vertices.insert(insert_index, VectorPathGeometry.create_vertex(hit.point))
	_vertices_with_visible_handles.clear()
	_set_vertices(next_vertices, true)
	_push_undo_snapshot(before, "Add Vertex")
	_debug_gizmo("vertex inserted on segment %d -> %d at %s" % [hit.start_index, hit.end_index, hit.point])


func _start_skew_drag(hit: Dictionary, local_position: Vector2) -> void:
	_cancel_long_press()
	_begin_history_edit("Skew Segment")
	_skew_segment_start_index = hit.start_index
	_skew_segment_end_index = hit.end_index
	_skew_drag_start_mouse = local_position
	_skew_drag_direction = hit.direction
	_skew_drag_start_a = _vertices[_skew_segment_start_index].position
	_skew_drag_start_b = _vertices[_skew_segment_end_index].position
	_debug_gizmo("skew start segment %d -> %d" % [_skew_segment_start_index, _skew_segment_end_index])

func _move_skew_segment(local_position: Vector2) -> void:
	if not _is_skew_dragging():
		return
	
	var delta := local_position - _skew_drag_start_mouse
	var projected_delta := _skew_drag_direction * delta.dot(_skew_drag_direction)
	var next_vertices := _copy_vertices()
	next_vertices[_skew_segment_start_index].position = _skew_drag_start_a + projected_delta
	next_vertices[_skew_segment_end_index].position = _skew_drag_start_b + projected_delta
	_set_vertices(next_vertices, true)

func _is_skew_dragging() -> bool:
	return _has_vertex(_skew_segment_start_index) and _has_vertex(_skew_segment_end_index)

func _stop_skew_drag() -> void:
	if _is_skew_dragging():
		_debug_gizmo("skew stop")
	_skew_segment_start_index = -1
	_skew_segment_end_index = -1
	_skew_drag_direction = Vector2.ZERO
	_commit_history_edit()

func _is_vert_draw_pressed() -> bool:
	return InputMap.has_action(&"vert_draw") and Input.is_action_pressed(&"vert_draw")

func _apply_skew_cursor(direction: Vector2) -> void:
	var texture := VecGraphIcons.get_cursor_skew_horizontal()
	if absf(direction.y) > absf(direction.x):
		texture = VecGraphIcons.get_cursor_skew_vertical()
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, texture.get_size() * 0.5)
	_skew_cursor_active = true


func _clear_segment_hover() -> void:
	if _hovered_segment_start_index == -1 and _hovered_segment_end_index == -1:
		_clear_skew_cursor()
		return
	_hovered_segment_start_index = -1
	_hovered_segment_end_index = -1
	_clear_skew_cursor()
	queue_redraw()

func _clear_skew_cursor() -> void:
	if not _skew_cursor_active:
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_skew_cursor_active = false

func _get_gizmo_center(vertex_index: int, role: int) -> Vector2:
	var vertex := _vertices[vertex_index]
	match role:
		VectorPointGizmo.Role.IN_HANDLE:
			return vertex.position + vertex.in_handle
		VectorPointGizmo.Role.OUT_HANDLE:
			return vertex.position + vertex.out_handle
		_:
			return vertex.position

func _is_active_gizmo(vertex_index: int, role: int) -> bool:
	return (
		(_dragged_gizmo_vertex_index == vertex_index and _dragged_gizmo_role == role)
		or (_hovered_gizmo_vertex_index == vertex_index and _hovered_gizmo_role == role)
	)

func _is_dragging_gizmo() -> bool:
	return _dragged_gizmo_vertex_index >= 0 and _dragged_gizmo_role >= 0


func _start_long_press(vertex_index: int, local_position: Vector2) -> void:
	_debug_gizmo("long press start vertex=%d position=%s" % [vertex_index, local_position])
	_long_press_vertex_index = vertex_index
	_long_press_start_position = local_position
	_long_press_elapsed = 0.0
	_long_press_active = true
	set_process(true)

func _cancel_long_press_if_moved(local_position: Vector2) -> void:
	if not _long_press_active:
		return
	
	if _long_press_start_position.distance_to(local_position) > long_press_move_tolerance:
		_cancel_long_press()

func _is_waiting_for_long_press(local_position: Vector2) -> bool:
	if not _long_press_active:
		return false
	
	if _long_press_start_position.distance_to(local_position) <= long_press_move_tolerance:
		return true
	
	_cancel_long_press()
	return false

func _cancel_long_press() -> void:
	_long_press_vertex_index = -1
	_long_press_elapsed = 0.0
	_long_press_active = false
	set_process(false)

func _stop_dragging_gizmo() -> void:
	_dragged_gizmo_vertex_index = -1
	_dragged_gizmo_role = -1
	_commit_history_edit()


func _toggle_vertex_handles(vertex_index: int) -> void:
	if not _has_vertex(vertex_index):
		return
	
	if _are_vertex_handles_visible(vertex_index):
		_vertices_with_visible_handles.erase(vertex_index)
		_debug_gizmo("handles hidden vertex=%d" % vertex_index)
	else:
		_vertices_with_visible_handles[vertex_index] = true
		_debug_gizmo("handles visible vertex=%d in=%s out=%s" % [
			vertex_index,
			_get_gizmo_center(vertex_index, VectorPointGizmo.Role.IN_HANDLE),
			_get_gizmo_center(vertex_index, VectorPointGizmo.Role.OUT_HANDLE),
		])
	
	_hovered_gizmo_vertex_index = vertex_index
	_hovered_gizmo_role = VectorPointGizmo.Role.VERTEX
	queue_redraw()

func _are_vertex_handles_visible(vertex_index: int) -> bool:
	return _vertices_with_visible_handles.has(vertex_index)

func _trim_visible_handle_state() -> void:
	for key in _vertices_with_visible_handles.keys():
		if int(key) < 0 or int(key) >= _vertices.size():
			_vertices_with_visible_handles.erase(key)

func _begin_history_edit(label: String) -> void:
	if not _active_history_snapshot.is_empty():
		return
	_active_history_label = label
	_active_history_snapshot = _make_history_snapshot()

func _commit_history_edit() -> void:
	if _active_history_snapshot.is_empty():
		return
	_push_undo_snapshot(_active_history_snapshot, _active_history_label)
	_active_history_label = ""
	_active_history_snapshot = {}

func _cancel_history_edit() -> void:
	_active_history_label = ""
	_active_history_snapshot = {}

func _push_undo_snapshot(before: Dictionary, label: String) -> void:
	if before.is_empty() or _snapshots_match(before, _make_history_snapshot()):
		return
	_undo_stack.append({
		"label": label,
		"snapshot": before,
	})
	while _undo_stack.size() > undo_limit:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_debug_gizmo("undo step %s" % label)
	something_changed.emit()

func _make_history_snapshot() -> Dictionary:
	return {
		"vertices": _copy_vertices(),
		"position_offset": position_offset,
		"visible_handles": _copy_visible_handle_indices(),
	}

func _apply_history_snapshot(snapshot: Dictionary) -> void:
	_cancel_history_edit()
	_stop_dragging_gizmo()
	_stop_skew_drag()
	_cancel_long_press()
	position_offset = snapshot.position_offset
	_vertices = _copy_vertices_from(snapshot.vertices)
	_vertices_with_visible_handles = _visible_handle_dictionary_from(snapshot.visible_handles)
	_trim_visible_handle_state()
	_fit_rect_to_geometry()
	_sync_gizmos()
	queue_redraw()
	vertices_changed.emit(_vertices)
	something_changed.emit()

func _copy_visible_handle_indices() -> Array[int]:
	var visible_handles: Array[int] = []
	for key in _vertices_with_visible_handles.keys():
		visible_handles.append(int(key))
	return visible_handles

func _visible_handle_dictionary_from(indices: Array) -> Dictionary:
	var visible_handles := {}
	for index in indices:
		visible_handles[int(index)] = true
	return visible_handles

func _copy_vertices_from(source_vertices: Array) -> Array[VectorGraphVertex]:
	var copied_vertices: Array[VectorGraphVertex] = []
	for vertex in source_vertices:
		if vertex:
			copied_vertices.append(vertex.copy())
	return copied_vertices

func _snapshots_match(a: Dictionary, b: Dictionary) -> bool:
	if a.position_offset != b.position_offset:
		return false
	var a_vertices: Array = a.vertices
	var b_vertices: Array = b.vertices
	if a_vertices.size() != b_vertices.size():
		return false
	for index in a_vertices.size():
		if not _vertices_match(a_vertices[index], b_vertices[index]):
			return false
	return _visible_handle_dictionary_from(a.visible_handles) == _visible_handle_dictionary_from(b.visible_handles)

func _vertices_match(a: Resource, b: Resource) -> bool:
	return a.position == b.position and a.in_handle == b.in_handle and a.out_handle == b.out_handle

func _get_gizmo_history_label(role: int) -> String:
	match role:
		VectorPointGizmo.Role.IN_HANDLE:
			return "Move In Handle"
		VectorPointGizmo.Role.OUT_HANDLE:
			return "Move Out Handle"
		_:
			return "Move Vertex"

func _is_action_pressed_if_exists(event: InputEvent, action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and event.is_action_pressed(action_name)

func _get_gizmo_modulate(role: int) -> Color:
	match role:
		VectorPointGizmo.Role.IN_HANDLE:
			return in_handle_gizmo_modulate
		VectorPointGizmo.Role.OUT_HANDLE:
			return out_handle_gizmo_modulate
		_:
			return vertex_gizmo_modulate

func _has_vertex(vertex_index: int) -> bool:
	return vertex_index >= 0 and vertex_index < _vertices.size()

func _copy_vertices() -> Array[VectorGraphVertex]:
	var next_vertices: Array[VectorGraphVertex] = []
	for vertex in _vertices:
		next_vertices.append(vertex.copy())
	return next_vertices

func _debug_gizmo(message: String) -> void:
	if debug_gizmo_render:
		print_debug("[VectorGraphElementRuntime] ", message)
