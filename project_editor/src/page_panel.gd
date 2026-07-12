extends PanelContainer
class_name PagePanel

@export var controller: ProjectEditor
@export var graph: GraphEdit
@export var page_num_display: Label

@export_category("Debugging")
@export var debug: MobileDebug


## Display the page number at the bottom of the page.
var page_number := "":
	set(value):
		page_number = value

		if page_num_display:
			page_num_display.text = "Page %s" % value


var _drawing := false
var _press_lock := false


func _process(_delta: float) -> void:
	_drawing = Input.is_action_pressed("draw")


func _gui_input(event: InputEvent) -> void:
	if debug:
		debug.push(str(event))

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

	# Intentionally ignore InputEventMouseMotion.
	# Stylus hovering generates motion events without actual contact.


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		_press_lock = false
		return

	if not event.pressed:
		_press_lock = false
		return

	_try_create_frame(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Stylus tip contact is normally represented as the left mouse button.
	# Ignore right-click, stylus side buttons, wheel events, etc.
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		_press_lock = false
		return

	_try_create_frame(event.position)


func _try_create_frame(event_position: Vector2) -> void:
	if _press_lock:
		return

	if not _drawing:
		return

	# Lock before creating because Android may report the same physical contact
	# as both ScreenTouch and an emulated MouseButton event.
	_press_lock = true
	_create_frame_at(event_position)


func _create_frame_at(panel_local_position: Vector2) -> void:
	# _gui_input() positions are local to this PagePanel. Convert the position
	# into the GraphEdit's local coordinate system first.
	var viewport_position := (
		get_global_transform_with_canvas()
		* panel_local_position
	)

	var graph_local_position := (
		graph.get_global_transform_with_canvas().affine_inverse()
		* viewport_position
	)

	# scroll_offset is already expressed in graph-space units.
	var graph_position := (
		graph.scroll_offset
		+ graph_local_position / graph.zoom
	)

	var new_frame := VectorGraphElementRuntime.new()
	graph.add_child(new_frame)
	new_frame.position_offset = graph_position

	controller.set_dirty()

	new_frame.something_changed.connect(
		func() -> void:
			controller.set_dirty()
	)
