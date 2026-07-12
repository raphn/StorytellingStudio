extends RefCounted
class_name VectorPathGeometry

#const VectorGraphVertex := preload("res://project_editor/mesh_graph_element/src/vector_graph_vertex.gd")
const MIN_VERTEX_COUNT := 3
const POLYGON_POINT_EPSILON := 0.001


static func make_square_vertices(side := 160.0) -> Array[VectorGraphVertex]:
	return [
		create_vertex(Vector2(0, 0)),
		create_vertex(Vector2(side, 0)),
		create_vertex(Vector2(side, side)),
		create_vertex(Vector2(0, side)),
	]

static func create_vertex(vertex_position: Vector2, vertex_in_handle := Vector2.ZERO, vertex_out_handle := Vector2.ZERO) -> VectorGraphVertex:
	var vertex := VectorGraphVertex.new()
	vertex.position = vertex_position
	vertex.in_handle = vertex_in_handle
	vertex.out_handle = vertex_out_handle
	return vertex

static func sanitize_vertices(vertices: Array[VectorGraphVertex]) -> Array[VectorGraphVertex]:
	var clean_vertices: Array[VectorGraphVertex] = []
	for vertex in vertices:
		clean_vertices.append(vertex.copy())
	
	if clean_vertices.is_empty():
		return make_square_vertices()
	
	var fallback := make_square_vertices()
	while clean_vertices.size() < MIN_VERTEX_COUNT:
		clean_vertices.append(fallback[clean_vertices.size()].copy())
	
	return clean_vertices

static func shift_vertex_positions(vertices: Array[VectorGraphVertex], delta: Vector2) -> void:
	for vertex in vertices:
		vertex.position += delta

static func get_local_bounds(vertices: Array[VectorGraphVertex], curve_segments: int) -> Rect2:
	var sampled_points := sample_closed_path(vertices, curve_segments)
	for vertex in vertices:
		sampled_points.append(vertex.position)
		sampled_points.append(vertex.position + vertex.in_handle)
		sampled_points.append(vertex.position + vertex.out_handle)
	
	if sampled_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	
	var bounds := Rect2(sampled_points[0], Vector2.ZERO)
	for point in sampled_points:
		bounds = bounds.expand(point)
	return bounds

static func sample_closed_path(vertices: Array[VectorGraphVertex], curve_segments: int) -> PackedVector2Array:
	var path_points := PackedVector2Array()
	if vertices.size() < MIN_VERTEX_COUNT:
		return path_points
	
	var segment_count := maxi(curve_segments, 1)
	for index in vertices.size():
		var current := vertices[index]
		var next := vertices[(index + 1) % vertices.size()]
		
		if index == 0:
			path_points.append(current.position)
		
		for step in range(1, segment_count + 1):
			var t := float(step) / float(segment_count)
			path_points.append(_sample_cubic(
				current.position,
				current.position + current.out_handle,
				next.position + next.in_handle,
				next.position,
				t
			))
	
	return path_points

static func make_fill_polygon(vertices: Array[VectorGraphVertex], curve_segments: int) -> PackedVector2Array:
	return clean_polygon(sample_closed_path(vertices, curve_segments))

static func clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var clean_points := PackedVector2Array()
	var min_distance_squared := POLYGON_POINT_EPSILON * POLYGON_POINT_EPSILON
	for point in points:
		if clean_points.is_empty() or clean_points[clean_points.size() - 1].distance_squared_to(point) > min_distance_squared:
			clean_points.append(point)
	
	while clean_points.size() > 1 and clean_points[0].distance_squared_to(clean_points[clean_points.size() - 1]) <= min_distance_squared:
		clean_points.remove_at(clean_points.size() - 1)
	return clean_points

static func can_fill_polygon(points: PackedVector2Array) -> bool:
	return points.size() >= MIN_VERTEX_COUNT and not Geometry2D.triangulate_polygon(points).is_empty()

static func to_curve_2d(vertices: Array[VectorGraphVertex]) -> Curve2D:
	var curve := Curve2D.new()
	for vertex in vertices:
		curve.add_point(vertex.position, vertex.in_handle, vertex.out_handle)
	return curve

#static func _is_vertex(resource: Resource) -> bool:
	#return resource and resource.get_script() == VectorGraphVertex

static func _sample_cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (
		p0 * u * u * u
		+ p1 * 3.0 * u * u * t
		+ p2 * 3.0 * u * t * t
		+ p3 * t * t * t
	)
