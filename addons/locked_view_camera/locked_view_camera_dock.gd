@tool
extends VBoxContainer

const META_KEY := "locked_view_camera_path"

var editor_interface: EditorInterface

var scene_root: Node
var locked_camera: Camera3D

var camera_selector := OptionButton.new()
var assign_selected_button := Button.new()
var clear_button := Button.new()
var status_label := Label.new()

var preview := SubViewport.new()
var preview_camera := Camera3D.new()
var preview_rect := TextureRect.new()

func _ready() -> void:
	set_process(true)

	camera_selector.item_selected.connect(_on_camera_selected)
	camera_selector.fit_to_longest_item = false
	camera_selector.clip_text = true
	camera_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	assign_selected_button.text = "Assign Selected Camera3D"
	assign_selected_button.pressed.connect(_assign_selected_camera)
	assign_selected_button.clip_text = true
	assign_selected_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	clear_button.text = "Clear"
	clear_button.pressed.connect(_clear_locked_camera)
	clear_button.clip_text = true
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_child(camera_selector)
	row.add_child(assign_selected_button)
	row.add_child(clear_button)

	add_child(row)
	add_child(status_label)

	preview.size = Vector2i(360, 220)
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.disable_3d = false
	preview_camera.current = true
	preview.add_child(preview_camera)

	preview_rect.custom_minimum_size = Vector2(360, 220)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.texture = preview.get_texture()

	add_child(preview)
	add_child(preview_rect)

	_refresh_scene_context()

func _process(_delta: float) -> void:
	var current_root := editor_interface.get_edited_scene_root()
	if current_root != scene_root:
		_refresh_scene_context()

	_resolve_locked_camera()
	_update_visibility()
	_update_preview_camera()

func _refresh_scene_context() -> void:
	scene_root = editor_interface.get_edited_scene_root()
	locked_camera = null
	_rebuild_camera_selector()
	_resolve_locked_camera()

func _rebuild_camera_selector() -> void:
	camera_selector.clear()

	if scene_root == null:
		camera_selector.add_item("No active scene")
		return

	camera_selector.add_item("No Locked Cam", -1)

	var cameras := _find_cameras(scene_root)
	for cam in cameras:
		var path := scene_root.get_path_to(cam)
		camera_selector.add_item(str(path))
		camera_selector.set_item_metadata(camera_selector.item_count - 1, path)

	_select_current_item()

func _find_cameras(root: Node) -> Array[Camera3D]:
	var result: Array[Camera3D] = []

	if root is Camera3D:
		result.append(root)

	for child in root.get_children():
		result.append_array(_find_cameras(child))

	return result

func _select_current_item() -> void:
	if scene_root == null or not scene_root.has_meta(META_KEY):
		camera_selector.select(0)
		return

	var saved_path: NodePath = scene_root.get_meta(META_KEY)

	for i in camera_selector.item_count:
		if camera_selector.get_item_metadata(i) == saved_path:
			camera_selector.select(i)
			return

	camera_selector.select(0)

func _on_camera_selected(index: int) -> void:
	if scene_root == null:
		return

	var path = camera_selector.get_item_metadata(index)

	if path == null:
		scene_root.remove_meta(META_KEY)
	else:
		scene_root.set_meta(META_KEY, path)

	_resolve_locked_camera()
	_mark_scene_dirty()

func _assign_selected_camera() -> void:
	if scene_root == null:
		return

	var selected := editor_interface.get_selection().get_selected_nodes()
	if selected.is_empty():
		return

	var node := selected[0]
	if node is Camera3D:
		var path := scene_root.get_path_to(node)
		scene_root.set_meta(META_KEY, path)
		_rebuild_camera_selector()
		_resolve_locked_camera()
		_mark_scene_dirty()

func _clear_locked_camera() -> void:
	if scene_root == null:
		return

	scene_root.remove_meta(META_KEY)
	locked_camera = null
	_rebuild_camera_selector()
	_mark_scene_dirty()

func _resolve_locked_camera() -> void:
	locked_camera = null

	if scene_root == null:
		return

	if not scene_root.has_meta(META_KEY):
		return

	var path: NodePath = scene_root.get_meta(META_KEY)

	if scene_root.has_node(path):
		var node := scene_root.get_node(path)
		if node is Camera3D:
			locked_camera = node

func _update_visibility() -> void:
	var selected := editor_interface.get_selection().get_selected_nodes()
	var selected_is_locked := (
		locked_camera != null
		and selected.size() == 1
		and selected[0] == locked_camera
	)

	var should_render := locked_camera != null and not selected_is_locked

	preview_rect.visible = should_render

	if scene_root == null:
		status_label.text = "No active scene."
	elif locked_camera == null:
		status_label.text = "Assign a Camera3D for this scene."
	elif selected_is_locked:
		status_label.text = "Using Godot built-in Camera3D inspector preview."
	else:
		status_label.text = "LockedViewCamera: %s" % locked_camera.name

func _update_preview_camera() -> void:
	if locked_camera == null:
		return

	preview.world_3d = locked_camera.get_world_3d()

	preview_camera.global_transform = locked_camera.global_transform
	preview_camera.projection = locked_camera.projection
	preview_camera.fov = locked_camera.fov
	preview_camera.size = locked_camera.size
	preview_camera.near = locked_camera.near
	preview_camera.far = locked_camera.far
	preview_camera.keep_aspect = locked_camera.keep_aspect
	preview_camera.cull_mask = locked_camera.cull_mask
	preview_camera.environment = locked_camera.environment
	preview_camera.attributes = locked_camera.attributes

func _mark_scene_dirty() -> void:
	if editor_interface.has_method("mark_scene_as_unsaved"):
		editor_interface.mark_scene_as_unsaved()
