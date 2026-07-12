extends TextureButton
class_name VectorPointGizmo

signal drag_started(vertex_index: int, role: int)
signal dragged(vertex_index: int, role: int, local_position: Vector2)
signal drag_ended(vertex_index: int, role: int)

enum Role {
	VERTEX,
	IN_HANDLE,
	OUT_HANDLE,
}

@export var gizmo_size := Vector2(24, 24)

var vertex_index := -1
var role := Role.VERTEX
var _dragging := false


func _ready() -> void:
	custom_minimum_size = gizmo_size
	size = gizmo_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_update_tooltip()


func setup(next_vertex_index: int, next_role: int) -> void:
	vertex_index = next_vertex_index
	role = next_role as Role
	name = _make_name()
	_update_tooltip()

func set_center_position(local_position: Vector2) -> void:
	size = gizmo_size
	position = local_position - (size * 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			drag_started.emit(vertex_index, role)
		else:
			drag_ended.emit(vertex_index, role)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var parent_control := get_parent() as Control
		if parent_control:
			dragged.emit(vertex_index, role, parent_control.get_local_mouse_position())
		accept_event()


func _make_name() -> String:
	match role:
		Role.IN_HANDLE:
			return "Vertex%dInHandle" % vertex_index
		Role.OUT_HANDLE:
			return "Vertex%dOutHandle" % vertex_index
		_:
			return "Vertex%dPoint" % vertex_index

func _update_tooltip() -> void:
	match role:
		Role.IN_HANDLE:
			tooltip_text = "Move vertex %d incoming handle" % vertex_index
		Role.OUT_HANDLE:
			tooltip_text = "Move vertex %d outgoing handle" % vertex_index
		_:
			tooltip_text = "Move vertex %d" % vertex_index
