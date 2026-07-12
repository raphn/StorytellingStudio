@tool
extends GraphElement
class_name VectorGraphElementPlaceholder

@export var vertices: Array[VectorGraphVertex] = VectorPathGeometry.make_square_vertices():
	set(value):
		vertices = VectorPathGeometry.sanitize_vertices(value)
		_refresh_blueprint_preview()

@export var runtime_editable := true

@export var fill_color := Color.WHITE: # Nice blue -> Color(0.16, 0.56, 0.92, 0.18):
	set(value):
		fill_color = value
		queue_redraw()
@export var outline_color := Color.BLACK: # Nice blue -> Color(0.08, 0.28, 0.46, 0.86):
	set(value):
		outline_color = value
		queue_redraw()
@export_range(0.0, 16.0, 0.25, "or_greater") var outline_width := 2.0:
	set(value):
		outline_width = value
		queue_redraw()
@export_range(1, 64, 1, "or_greater") var curve_segments_per_edge := 12:
	set(value):
		curve_segments_per_edge = value
		_refresh_blueprint_preview()

@export var vertex_gizmo_modulate := Color.WEB_GRAY
@export var in_handle_gizmo_modulate := Color(0.35, 0.75, 1.0)
@export var out_handle_gizmo_modulate := Color(1.0, 0.62, 0.25)

@export var handle_line_color := Color(0.517, 0.517, 0.517, 0.26):
	set(value):
		handle_line_color = value
		queue_redraw()


func _ready() -> void:
	clip_contents = true
	vertices = VectorPathGeometry.sanitize_vertices(vertices)
	_refresh_blueprint_preview()
	
	if not Engine.is_editor_hint():
		call_deferred("_replace_with_runtime_element")

func _draw() -> void:
	var closed_path := VectorPathGeometry.sample_closed_path(vertices, curve_segments_per_edge)
	if closed_path.size() < VectorPathGeometry.MIN_VERTEX_COUNT:
		return
	
	draw_colored_polygon(closed_path, fill_color)
	
	if outline_width > 0.0:
		var outline_points := PackedVector2Array(closed_path)
		outline_points.append(closed_path[0])
		draw_polyline(outline_points, outline_color, outline_width, true)
	
	_draw_blueprint_handles()


func _refresh_blueprint_preview() -> void:
	if not is_inside_tree():
		queue_redraw()
		return
	
	var bounds := VectorPathGeometry.get_local_bounds(vertices, curve_segments_per_edge)
	var required_size := Vector2(maxf(bounds.end.x, 1.0), maxf(bounds.end.y, 1.0))
	custom_minimum_size = required_size
	if size.x < required_size.x or size.y < required_size.y:
		size = Vector2(maxf(size.x, required_size.x), maxf(size.y, required_size.y))
	queue_redraw()

func _replace_with_runtime_element() -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	
	var runtime_element: GraphElement = VectorGraphElementRuntime.new()
	_copy_blueprint_to_runtime(runtime_element)
	_move_children_to_runtime(runtime_element)
	
	var child_index := get_index()
	parent_node.remove_child(self)
	parent_node.add_child(runtime_element)
	parent_node.move_child(runtime_element, child_index)
	queue_free()

func _copy_blueprint_to_runtime(runtime_element: GraphElement) -> void:
	runtime_element.name = name
	runtime_element.position_offset = position_offset
	runtime_element.size = size
	runtime_element.custom_minimum_size = custom_minimum_size
	runtime_element.resizable = resizable
	runtime_element.draggable = draggable
	runtime_element.selectable = selectable
	runtime_element.selected = selected
	
	runtime_element.vertices = VectorPathGeometry.sanitize_vertices(vertices)
	runtime_element.runtime_editable = runtime_editable
	runtime_element.fill_color = fill_color
	runtime_element.outline_color = outline_color
	runtime_element.outline_width = outline_width
	runtime_element.curve_segments_per_edge = curve_segments_per_edge
	runtime_element.vertex_gizmo_modulate = vertex_gizmo_modulate
	runtime_element.in_handle_gizmo_modulate = in_handle_gizmo_modulate
	runtime_element.out_handle_gizmo_modulate = out_handle_gizmo_modulate
	runtime_element.handle_line_color = handle_line_color

func _move_children_to_runtime(runtime_element: GraphElement) -> void:
	for child in get_children():
		remove_child(child)
		runtime_element.add_child(child)

func _draw_blueprint_handles() -> void:
	for vertex in vertices:
		draw_line(vertex.position, vertex.position + vertex.in_handle, handle_line_color, 1.0, true)
		draw_line(vertex.position, vertex.position + vertex.out_handle, handle_line_color, 1.0, true)
		draw_circle(vertex.position, 4.0, outline_color)
		draw_circle(vertex.position + vertex.in_handle, 3.0, in_handle_gizmo_modulate)
		draw_circle(vertex.position + vertex.out_handle, 3.0, out_handle_gizmo_modulate)
