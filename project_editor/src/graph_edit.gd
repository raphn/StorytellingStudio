extends GraphEdit
class_name DrawTable

@export var speed := 200.0
@export var floating_toolbar : FloatingToolbar
@export var zoom_slider : VSlider

var frame_selected :VectorGraphElementRuntime

var _touches: Dictionary[int, Vector2] = {}

var _previous_center := Vector2.ZERO
var _previous_distance := 0.0
var _pinching := false


# ======================================== || CALLBACKS ................. ||
func _ready() -> void:
	node_selected.connect(_node_selected)
	
	floating_toolbar.visible = false
	floating_toolbar.undo_request.connect(_transmit_undo_request)
	floating_toolbar.redo_request.connect(_transmit_redo_request)
	floating_toolbar.reset_request.connect(_transmit_reset_request)
	
	floating_toolbar.copy_requesy.connect(_copy_selected)
	floating_toolbar.accept_request.connect(_force_deselect)
	floating_toolbar.del_frame_request.connect(_delete_selected)
	
	zoom_slider.value_changed.connect(func(val): zoom = val)

func _process(delta: float) -> void:
	var move := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	if move:
		scroll_offset += move * (delta * speed / zoom)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)

	elif event is InputEventScreenDrag:
		_handle_drag(event)


# ======================================== || API ....................... ||
func recenter() -> void:
	zoom = 1.0
	scroll_offset = Vector2.ZERO
	zoom_slider.set_value_no_signal(zoom)


# ======================================== || NODE HANDLING ............. ||
func _node_selected(node:Node) -> void:
	if not node is VectorGraphElementRuntime:
		return
	
	frame_selected = node as VectorGraphElementRuntime
	frame_selected.position_offset_changed.connect(_reposition_floating_toolbar)
	frame_selected.node_deselected.connect(_selected_node_deselected.bind(node))
	
	floating_toolbar.visible = true
	floating_toolbar.reset_size()
	_reposition_floating_toolbar()

func _selected_node_deselected(node:Node) -> void:
	var frame := node as VectorGraphElementRuntime
	frame.node_deselected.disconnect(_selected_node_deselected)
	frame.position_offset_changed.disconnect(_reposition_floating_toolbar)
	
	if frame_selected != null and frame == frame_selected:
		floating_toolbar.visible = false
		frame_selected = null


func _force_deselect() -> void:
	frame_selected.set_selected(false)

func _copy_selected() -> void:
	var n_element := VectorGraphElementRuntime.new()
	add_child(n_element)
	
	n_element.position_offset = frame_selected.position_offset + Vector2(64.0, 64.0)
	n_element.size = frame_selected.size
	n_element.custom_minimum_size = frame_selected.custom_minimum_size
	n_element.resizable = frame_selected.resizable
	n_element.draggable = frame_selected.draggable
	n_element.selectable = frame_selected.selectable
	
	n_element.vertices = VectorPathGeometry.sanitize_vertices(frame_selected.vertices)
	n_element.runtime_editable = frame_selected.runtime_editable
	n_element.fill_color = frame_selected.fill_color
	n_element.outline_color = frame_selected.outline_color
	n_element.outline_width = frame_selected.outline_width
	n_element.curve_segments_per_edge = frame_selected.curve_segments_per_edge
	n_element.vertex_gizmo_modulate = frame_selected.vertex_gizmo_modulate
	n_element.in_handle_gizmo_modulate = frame_selected.in_handle_gizmo_modulate
	n_element.out_handle_gizmo_modulate = frame_selected.out_handle_gizmo_modulate
	n_element.handle_line_color = frame_selected.handle_line_color
	
	frame_selected.set_selected(false)
	n_element.set_selected(true)

func _delete_selected() -> void:
	if not frame_selected:
		return
	
	var to_del := frame_selected
	frame_selected.set_selected(false)
	
	remove_child(to_del)
	to_del.queue_free()


# ======================================== || NOTIFY EDITING FRAME ...... ||
func _transmit_undo_request() -> void:
	if frame_selected:
		frame_selected.undo()

func _transmit_redo_request() -> void:
	if frame_selected:
		frame_selected.redo()

func _transmit_reset_request() -> void:
	if frame_selected:
		frame_selected.reset_shape()


# ======================================== || INTERNAL .................. ||
func _reposition_floating_toolbar() -> void:
	floating_toolbar.position_offset = frame_selected.position_offset + (Vector2.UP * 64)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var local_position := _to_local_position(event.position)

	if event.pressed:
		# Only begin tracking touches that started inside the GraphEdit.
		if Rect2(Vector2.ZERO, size).has_point(local_position):
			_touches[event.index] = local_position
	else:
		_touches.erase(event.index)

	if _touches.size() == 2:
		_reset_pinch_reference()
		get_viewport().set_input_as_handled()
	else:
		_pinching = false
		_previous_distance = 0.0

func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return

	_touches[event.index] = _to_local_position(event.position)

	if _touches.size() != 2:
		return

	var points := _touches.values()
	var current_center: Vector2 = (points[0] + points[1]) * 0.5
	var current_distance: float = points[0].distance_to(points[1])

	if not _pinching or _previous_distance <= 0.0:
		_previous_center = current_center
		_previous_distance = current_distance
		_pinching = true
		return

	# Graph-space position previously located beneath the pinch center.
	var graph_anchor := scroll_offset + _previous_center / zoom

	var zoom_ratio := current_distance / _previous_distance
	var new_zoom := clampf(zoom * zoom_ratio, zoom_min, zoom_max)

	zoom = new_zoom
	zoom_slider.set_value_no_signal(zoom)

	# Keep the same graph position beneath the moving pinch center.
	# This also allows two-finger panning.
	scroll_offset = graph_anchor - current_center / zoom

	_previous_center = current_center
	_previous_distance = current_distance

	get_viewport().set_input_as_handled()

func _reset_pinch_reference() -> void:
	var points := _touches.values()

	_previous_center = (points[0] + points[1]) * 0.5
	_previous_distance = points[0].distance_to(points[1])
	_pinching = true


func _to_local_position(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position
