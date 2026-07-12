extends Resource
class_name VectorGraphData

@export var name					: String
@export var position_offset			: Vector2
@export var size					: Vector2
@export var custom_minimum_size		: Vector2

@export var resizable			: bool
@export var draggable			: bool
@export var selectable			: bool
@export var runtime_editable	: bool

@export var vertices	: Array[VectorGraphVertex]
@export var curve_segments_per_edge	 : int

@export var fill_color					: Color
@export var outline_color				: Color
@export var outline_width				: float
@export var vertex_gizmo_modulate		: Color
@export var in_handle_gizmo_modulate	: Color
@export var out_handle_gizmo_modulate	: Color
@export var handle_line_color			: Color


static func from(vec_graph:VectorGraphElementRuntime) -> VectorGraphData:
	var n_dt := VectorGraphData.new()
	
	n_dt.position_offset = vec_graph.position_offset
	n_dt.size = vec_graph.size
	n_dt.custom_minimum_size = vec_graph.custom_minimum_size
	n_dt.resizable = vec_graph.resizable
	n_dt.draggable = vec_graph.draggable
	n_dt.selectable = vec_graph.selectable
	n_dt.vertices = VectorPathGeometry.sanitize_vertices(vec_graph.vertices)
	n_dt.runtime_editable = vec_graph.runtime_editable
	n_dt.fill_color = vec_graph.fill_color
	n_dt.outline_color = vec_graph.outline_color
	n_dt.outline_width = vec_graph.outline_width
	n_dt.curve_segments_per_edge = vec_graph.curve_segments_per_edge
	n_dt.vertex_gizmo_modulate = vec_graph.vertex_gizmo_modulate
	n_dt.in_handle_gizmo_modulate = vec_graph.in_handle_gizmo_modulate
	n_dt.out_handle_gizmo_modulate = vec_graph.out_handle_gizmo_modulate
	n_dt.handle_line_color = vec_graph.handle_line_color
	
	return n_dt
