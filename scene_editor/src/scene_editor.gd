extends Node3D
## Main editor controller for opening a SceneData, linking characters, instantiating actors,
## and saving actor pose keyframes when TransformHandle3D edits finish.
class_name ComicSceneEditor

## Node3D parent
@export var scene_root		: Node3D
## For gizmo drawing
@export var master_cam		: Camera3D
## Make actors (models) intro costumized characters
@export var char_editor		: CharacterEditor
## Panel containing frame editing UI; hidden while the scene 3D editor is active.
@export var frame_editor	: PanelContainer

@export_category("Database")
## List of available actors (models)
@export var actors : RuntimeActors

@export_group("Pose Frames Actions")
## Moves to next saved pose frame
@export var next_pose_frame		: Button
## Moves to previus saved pose frame
@export var previus_pose_frame	: Button
## Moves to previus saved pose frame
@export var add_pose_frame	: Button

@export_group("Shot Frames Actions")
## Moves to next saved FrameShot in the current pose RigKeyframe.
@export var next_shot_frame		: Button
## Moves to previus saved FrameShot in the current pose RigKeyframe.
@export var previus_shot_frame	: Button
## Captures the FrameShot generator camera into the current pose RigKeyframe.
@export var add_shot_frame	: Button
## Captures the first FrameShot when the current pose frame has no shots yet.
@export var add_shot_frame_camera	: Button
## Camera used to compose and capture FrameShot resources.
@export var frame_shot_camera		: SelfControlledCamera3D
## Menu shown when the current pose RigKeyframe already has at least one FrameShot.
@export var camera_editing_options	: Control
## Menu shown when the current pose RigKeyframe has no FrameShots.
@export var no_cam_selected_options	: Control
## Label displaying the selected FrameShot index.
@export var current_camera_label	: Label
## Generate texture to be used inside frames on the project pages
@export var capture_snapshot		: Button


@export_category("App navigation")
## Opens the character/linking panel for the current scene.
@export var add_char_btn	: Button
## Leaves scene editing and returns to the parent workflow through GEN.
@export var go_back_btn		: Button


@export_category("Save load")
## Debounce timer used to delay project saves after pose/link changes.
@export var save_timer		: Timer
## Label used to show edited/saved state feedback to the user.
@export var save_feedback	: Label

## Application singleton/helper used for navigation and shared app actions.
var gen			: GEN
## Project currently being edited; owns characters and scenes.
var project		: ProjectData
## SceneData currently open in this editor.
var editing		: SceneData
## All instantiated actors (Actor3D models)
var instantiated_actors : Dictionary[int, Actor3D]

## Emitted after a scene is opened and linked characters have been restored.
signal finished_open_scene


## Connects UI buttons and save timer callbacks once this editor enters the scene tree.
## Returns: nothing; prepares the editor to open a SceneData later.
func _ready() -> void:
	
	gen = GEN.get_instance(self)
	
	add_char_btn.pressed.connect(_open_character_list)
	go_back_btn.pressed.connect(gen.finish_editing_scene)
	next_pose_frame.pressed.connect(_go_to_next_pose_frame)
	previus_pose_frame.pressed.connect(_go_to_previus_pose_frame)
	add_pose_frame.pressed.connect(_add_pose_frame)
	next_shot_frame.pressed.connect(_go_to_next_frame_shot)
	previus_shot_frame.pressed.connect(_go_to_previus_frame_shot)
	add_shot_frame.pressed.connect(_add_frame_shot)
	add_shot_frame_camera.pressed.connect(_add_frame_shot)
	save_timer.timeout.connect(_save_modifications)
	capture_snapshot.pressed.connect(_capture_save_frame_shot)

## Opens a project scene for editing and restores linked actor instances.
## proj: ProjectData that contains the target scene and character definitions.
## scene_id: key into proj.scenes selecting the SceneData to edit.
## Returns: nothing; emits finished_open_scene on success and shows feedback on missing scene IDs.
func star_scene_editing(proj:ProjectData, scene_id:int) -> void:
	
	project = proj
	
	editing = project.scenes.get(scene_id)
	print_debug(project.scenes)
	
	if editing == null:
		printerr("No scene with ID '", scene_id, "'")
		Feedback.push("Error: NO ID when opening the scene editor!", Feedback.Type.Err)
		return
	
	editing.set_current_frame(editing.get_current_frame_index())
	editing.ensure_linked_character_keyframes()
	_clear_instantiated_actors()
	
	# Notify character creator
	char_editor.open_project(project, editing)
	
	# Close frame editor subviewport
	frame_editor.visible = false
	_instantiate_linked_characters()
	_refresh_pose_frame_nav()
	_refresh_frame_shot_nav()
	
	finished_open_scene.emit()


## Shows the character editor/list so the user can link or unlink characters.
## Returns: nothing; mutates char_editor visibility.
func _open_character_list() -> void:
	char_editor.visible = true

## Displays the character on scene and create frames for it
## chr: CharacterData being linked to this SceneData and instantiated as an Actor3D.
## Returns: nothing; creates/restores actor pose, updates scene links, and marks the project dirty.
func _link_character(chr:CharacterData) -> void:
	
	print_debug("Linking character ", chr.display_name, " to scene ", editing.ID, "!")
	
	var n_actor := _instantiate_character(chr)
	if n_actor:
		if not editing.apply_actor_keyframe(chr, n_actor):
			editing.capture_actor_keyframe(chr, n_actor)
	
	chr.link_scene(editing.ID)
	editing.link_character(chr)
	_refresh_pose_frame_nav()
	_refresh_frame_shot_nav()
	
	set_dirty()

## Remove from SceneData and hide character in "hidden_characters" to faster "undo"
## chr: CharacterData being unlinked from the current scene.
## Returns: nothing; hides any existing actor instance, updates scene links, and marks the project dirty.
func _unlink_character(chr:CharacterData) -> void:
	
	print_debug("Unlinking character ", chr.display_name, " to scene ", editing.ID, "!")
	if instantiated_actors.has(chr.ID):
		instantiated_actors[chr.ID].visible = false
	
	chr.unlink_scene(editing.ID)
	editing.unlink_character(chr.ID)
	_refresh_pose_frame_nav()
	_refresh_frame_shot_nav()
	set_dirty()


## Instantiates all CharacterData IDs already linked in editing.actors.
## Returns: nothing; applies saved poses when available for each restored actor.
func _instantiate_linked_characters() -> void:
	for character_id in editing.actors:
		var chr := project.characters.get(character_id) as CharacterData
		if chr == null:
			continue
		
		var n_actor := _instantiate_character(chr)
		if n_actor:
			editing.apply_actor_keyframe(chr, n_actor)

## Gets or creates the live Actor3D instance for one character.
## chr: CharacterData that supplies model ID, color, and stable character ID.
## Returns: existing or newly-instantiated Actor3D, or null if the actor catalog cannot instantiate it.
func _instantiate_character(chr: CharacterData) -> Actor3D:
	if chr == null:
		return null
	
	if instantiated_actors.has(chr.ID):
		var existing := instantiated_actors[chr.ID]
		existing.visible = true
		return existing
	
	var n_actor := actors.instantiate_character(chr.model_id, scene_root) as Actor3D
	if n_actor == null:
		return null
	
	instantiated_actors[chr.ID] = n_actor
	n_actor.setup_from(master_cam, chr)
	_connect_actor_pose_signals(chr, n_actor)
	return n_actor

## Hooks every TransformHandle3D controller so pose edits save back into SceneData.
## chr: CharacterData whose ID is bound into each callback.
## actor: Actor3D whose controllers should emit transform_change_finished to this editor.
## Returns: nothing; avoids duplicate signal connections.
func _connect_actor_pose_signals(chr: CharacterData, actor: Actor3D) -> void:
	actor.refresh_controllers()
	for controller in actor.controllers:
		var callback := Callable(self, "_on_actor_transform_change_finished").bind(chr.ID)
		if not controller.transform_change_finished.is_connected(callback):
			controller.transform_change_finished.connect(callback)


## Saves a character pose after a TransformHandle3D drag finishes.
## _old_transform: handle transform before the drag; currently unused because the full rig pose is captured.
## _new_transform: handle transform after the drag; currently unused because the full rig pose is captured.
## character_id: CharacterData.ID bound when the controller signal was connected.
## Returns: nothing; captures current actor rig pose and schedules a project save.
func _on_actor_transform_change_finished(_old_transform: Transform3D, _new_transform: Transform3D, character_id: int) -> void:
	if editing == null or project == null:
		return
	
	var chr := project.characters.get(character_id) as CharacterData
	var actor := instantiated_actors.get(character_id) as Actor3D
	if chr == null or actor == null:
		return
	
	editing.capture_actor_keyframe(chr, actor)
	set_dirty()

## Removes all live actor instances before opening a different scene.
## Returns: nothing; queue_frees valid actor nodes and clears instantiated_actors.
func _clear_instantiated_actors() -> void:
	for actor in instantiated_actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	
	instantiated_actors.clear()

## Captures every currently instantiated actor into the active SceneData pose frame.
## Returns: true when at least one actor pose was captured; false when no editable scene/project/actors exist.
func _capture_current_pose_frame() -> bool:
	if editing == null or project == null:
		return false
	
	var captured := false
	for character_id in instantiated_actors.keys():
		var chr := project.characters.get(character_id) as CharacterData
		var actor := instantiated_actors.get(character_id) as Actor3D
		if chr == null or actor == null:
			continue
		
		editing.capture_actor_keyframe(chr, actor)
		captured = true
	
	return captured

## Applies the active SceneData pose frame to all instantiated actors.
## Returns: nothing; missing character data or missing frame poses are skipped safely.
func _apply_current_pose_frame() -> void:
	if editing == null or project == null:
		return
	
	for character_id in instantiated_actors.keys():
		var chr := project.characters.get(character_id) as CharacterData
		var actor := instantiated_actors.get(character_id) as Actor3D
		if chr == null or actor == null:
			continue
		
		editing.apply_actor_keyframe(chr, actor)


## Creates a new pose frame by copying the currently visible actor poses into fresh RigKeyframes.
## Returns: nothing; selects the new frame, refreshes navigation text, and schedules saving.
func _add_pose_frame() -> void:
	if editing == null:
		return
	
	_capture_current_pose_frame()
	editing.add_pose_frame()
	_capture_current_pose_frame()
	_refresh_pose_frame_nav()
	set_dirty()

## Navigates to the next saved pose frame.
## Returns: nothing; saves the current pose frame before switching and applying the next frame.
func _go_to_next_pose_frame() -> void:
	if editing == null:
		return
	
	_go_to_pose_frame(editing.get_next_pose_frame_index())

## Navigates to the previous saved pose frame.
## Returns: nothing; saves the current pose frame before switching and applying the previous frame.
func _go_to_previus_pose_frame() -> void:
	if editing == null:
		return
	
	_go_to_pose_frame(editing.get_previus_pose_frame_index())

## Switches to a specific saved pose frame and applies it to instantiated actors.
## frame_index: SceneData.actor_keyframes key to select.
## Returns: nothing; captures the outgoing frame first so unsaved handle edits are preserved.
func _go_to_pose_frame(frame_index: int) -> void:
	if editing == null:
		return
	
	var captured := _capture_current_pose_frame()
	editing.set_current_frame(frame_index)
	_apply_current_pose_frame()
	_refresh_pose_frame_nav()
	_apply_current_frame_shot()
	_refresh_frame_shot_nav()
	if captured:
		set_dirty()


## Updates the pose-frame navigation label and button enabled states.
## Returns: nothing; finds the Label beside the exported buttons from the current scene tree.
func _refresh_pose_frame_nav() -> void:
	if editing == null:
		return
	
	var frame_count := editing.get_pose_frame_indices().size()
	var label := _get_pose_frame_label()
	if label:
		label.text = "Frame: %d/%d" % [editing.get_current_frame_index() + 1, max(frame_count, 1)]
	
	var can_navigate := frame_count > 1
	next_pose_frame.disabled = not can_navigate
	previus_pose_frame.disabled = not can_navigate

## Finds the label inside PoseFrameNav without requiring another exported scene reference.
## Returns: Label sibling of the pose navigation buttons, or null if the UI structure changed.
func _get_pose_frame_label() -> Label:
	if add_pose_frame == null or add_pose_frame.get_parent() == null:
		return null
	
	return add_pose_frame.get_parent().get_node_or_null("Label") as Label


## Gets RigKeyframes for all instantiated actors on the active pose frame.
## ensure_existing: when true, captures the current pose first so every live actor has a RigKeyframe.
## Returns: Array of RigKeyframe resources for the active SceneFrame.
func _get_current_pose_rig_keyframes(ensure_existing := false) -> Array[RigKeyframe]:
	var keyframes: Array[RigKeyframe] = []
	if editing == null:
		return keyframes
	
	if ensure_existing:
		_capture_current_pose_frame()
	
	var frame := editing.ensure_scene_frame(editing.get_current_frame_index())
	for character_id in instantiated_actors.keys():
		var keyframe := frame.get_character_keyframe(character_id)
		if keyframe:
			keyframes.append(keyframe)
	
	return keyframes

## Gets the first current pose RigKeyframe that can provide camera-shot state.
## Returns: first RigKeyframe for the active frame, or null when no actor pose exists yet.
func _get_frame_shot_source_keyframe() -> RigKeyframe:
	var keyframes := _get_current_pose_rig_keyframes(false)
	if keyframes.is_empty():
		return null
	
	return keyframes[0]

## Captures the FrameShot generator camera into every current actor RigKeyframe.
## Returns: nothing; refreshes camera-shot UI and schedules saving when at least one keyframe was updated.
func _add_frame_shot() -> void:
	if frame_shot_camera == null:
		return
	
	var keyframes := _get_current_pose_rig_keyframes(true)
	if keyframes.is_empty():
		_refresh_frame_shot_nav()
		return
	
	for keyframe in keyframes:
		keyframe.add_frame_shot_from_camera(frame_shot_camera)
	
	_refresh_frame_shot_nav()
	set_dirty()

## Navigates to the next FrameShot stored on the current pose RigKeyframe.
## Returns: nothing; applies the selected shot to frame_shot_camera.
func _go_to_next_frame_shot() -> void:
	var keyframe := _get_frame_shot_source_keyframe()
	if keyframe == null:
		_refresh_frame_shot_nav()
		return
	
	_go_to_frame_shot(keyframe.get_next_frame_shot_index())

## Navigates to the previous FrameShot stored on the current pose RigKeyframe.
## Returns: nothing; applies the selected shot to frame_shot_camera.
func _go_to_previus_frame_shot() -> void:
	var keyframe := _get_frame_shot_source_keyframe()
	if keyframe == null:
		_refresh_frame_shot_nav()
		return
	
	_go_to_frame_shot(keyframe.get_previus_frame_shot_index())

## Selects and applies a specific FrameShot index for the current pose frame.
## shot_index: FrameShot index to select across all current RigKeyframes.
## Returns: nothing; invalid shot indexes only refresh the UI.
func _go_to_frame_shot(shot_index: int) -> void:
	if shot_index < 0 or frame_shot_camera == null:
		_refresh_frame_shot_nav()
		return
	
	var applied := false
	for keyframe in _get_current_pose_rig_keyframes(false):
		if keyframe.apply_frame_shot(shot_index, frame_shot_camera):
			applied = true
		elif keyframe.has_frame_shots():
			keyframe.current_frame_shot = clampi(shot_index, 0, keyframe.frame_shots.size() - 1)
	
	_refresh_frame_shot_nav()
	if applied:
		set_dirty()

## Captures the current FrameShot SubViewport render and writes it to disk.
## The output folder comes from ProjectData.get_frame_folder_path(editing.ID, editing.current_frame).
## Saves two PNG files: a full-size render for final frame use and a smaller thumbnail for cheap list loading.
## Returns: nothing; updates the selected FrameShot image paths and schedules the project save on success.
func _capture_save_frame_shot() -> void:
	if editing == null or frame_shot_camera == null:
		return
	
	var source_keyframe := _get_frame_shot_source_keyframe()
	if source_keyframe == null or not source_keyframe.has_frame_shots():
		_refresh_frame_shot_nav()
		return
	
	var shot_index := source_keyframe.get_current_frame_shot_index()
	if shot_index < 0:
		_refresh_frame_shot_nav()
		return
	
	var shot_viewport := frame_shot_camera.get_viewport() as SubViewport
	if shot_viewport == null:
		printerr("FrameShot capture failed: FrameShotCamera3D is not inside a SubViewport.")
		return
	
	await RenderingServer.frame_post_draw
	
	var full_image := shot_viewport.get_texture().get_image()
	if full_image == null or full_image.is_empty():
		printerr("FrameShot capture failed: SubViewport image is empty.")
		return
	
	var frame_folder := ProjectData.get_frame_folder_path(editing.ID, editing.get_current_frame_index())
	var shot_name := "shot_%s" % str(shot_index).lpad(4, "0")
	var full_path := frame_folder + shot_name + ".png"
	var thumbnail_path := frame_folder + shot_name + "_thumb.png"
	
	var full_err := full_image.save_png(full_path)
	if full_err != OK:
		printerr("FrameShot full image save failed: %s" % error_string(full_err))
		return
	
	var thumbnail_image := full_image.duplicate() as Image
	_resize_thumbnail(thumbnail_image)
	var thumbnail_err := thumbnail_image.save_png(thumbnail_path)
	if thumbnail_err != OK:
		printerr("FrameShot thumbnail save failed: %s" % error_string(thumbnail_err))
		return
	
	for keyframe in _get_current_pose_rig_keyframes(false):
		if shot_index >= 0 and shot_index < keyframe.frame_shots.size() and keyframe.frame_shots[shot_index] != null:
			keyframe.frame_shots[shot_index].set_saved_images(full_path, thumbnail_path)
	
	save_feedback.text = "Shot saved!"
	save_feedback.modulate = Color.LIGHT_SEA_GREEN
	#set_dirty()


## Resizes a rendered frame image into a thumbnail while preserving aspect ratio.
## thumbnail_image: mutable Image duplicated from the full-size viewport render.
## Returns: nothing; edits thumbnail_image in-place to fit inside a 256px maximum side.
func _resize_thumbnail(thumbnail_image: Image) -> void:
	if thumbnail_image == null or thumbnail_image.is_empty():
		return
	
	var max_side := 256
	var size := thumbnail_image.get_size()
	var longest_side := maxi(size.x, size.y)
	if longest_side <= max_side:
		return
	
	var scale := float(max_side) / float(longest_side)
	var thumbnail_size := Vector2i(maxi(1, roundi(float(size.x) * scale)), maxi(1, roundi(float(size.y) * scale)))
	thumbnail_image.resize(thumbnail_size.x, thumbnail_size.y, Image.INTERPOLATE_LANCZOS)


## Applies the currently selected FrameShot, if any, when switching pose frames.
## Returns: true when a shot was found and applied to frame_shot_camera; otherwise false.
func _apply_current_frame_shot() -> bool:
	var keyframe := _get_frame_shot_source_keyframe()
	if keyframe == null or not keyframe.has_frame_shots() or frame_shot_camera == null:
		return false
	
	return keyframe.apply_frame_shot(keyframe.get_current_frame_shot_index(), frame_shot_camera)

## Updates FrameShot menu visibility, navigation buttons, and current camera label.
## Returns: nothing; CameraEditingOptions is shown only when the active pose keyframe has shots.
func _refresh_frame_shot_nav() -> void:
	var keyframe := _get_frame_shot_source_keyframe()
	var has_shots := keyframe != null and keyframe.has_frame_shots()
	
	if camera_editing_options:
		camera_editing_options.visible = has_shots
	if no_cam_selected_options:
		no_cam_selected_options.visible = not has_shots
	if frame_editor:
		frame_editor.visible = has_shots
	
	next_shot_frame.disabled = not has_shots or keyframe.frame_shots.size() <= 1
	previus_shot_frame.disabled = next_shot_frame.disabled
	
	if current_camera_label:
		if has_shots:
			current_camera_label.text = "Current camera ID: %d/%d" % [keyframe.get_current_frame_shot_index() + 1, keyframe.frame_shots.size()]
		else:
			current_camera_label.text = "Current camera ID: none"


## Marks the project as edited and restarts the deferred save timer.
## Returns: nothing; updates save_feedback immediately and lets _save_modifications persist later.
func set_dirty() -> void:
	save_timer.stop()
	save_timer.start()
	
	save_feedback.text = "...edited"
	save_feedback.modulate = Color.CORAL

## Persists project changes after the debounce timer fires.
## Returns: nothing; calls ProjectData.save_modifications and updates save_feedback on completion.
func _save_modifications() -> void:
	project.save_modifications()
	save_feedback.text = "Saved!"
	save_feedback.modulate = Color.LIGHT_SEA_GREEN
