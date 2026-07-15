extends SceneTree

## Actor scene fixture used by the headless validation pass.
const ACTOR_SCENE_PATH := "res://scene_editor/character_poser/models/male/_default__rigger/rigger_scene.tscn"


## Runs a complete smoke test for the actor pose and rig-builder flow.
## Returns: nothing directly; exits the SceneTree with code 0 on success or 1 through _fail on error.
func _init() -> void:
	var actor_scene := load(ACTOR_SCENE_PATH) as PackedScene
	if actor_scene == null:
		_fail("Actor scene failed to load.")
		return
	
	var actor := actor_scene.instantiate() as Actor3D
	if actor == null:
		_fail("Actor scene did not instantiate as Actor3D.")
		return
	
	root.add_child(actor)
	actor.refresh_controllers()
	if actor.controllers.is_empty():
		_fail("Actor has no TransformHandle3D controllers.")
		return
	
	var handle := actor.controllers[0]
	var original_transform := handle.transform
	handle.position += Vector3(0.25, 0.1, -0.2)
	
	var keyframe: RigKeyframe = actor.capture_keyframe()
	if keyframe == null or keyframe.is_empty():
		_fail("Actor keyframe capture produced no data.")
		return
	
	var shot_camera := Camera3D.new()
	root.add_child(shot_camera)
	shot_camera.position = Vector3(1.0, 2.0, 3.0)
	shot_camera.fov = 61.0
	keyframe.add_frame_shot_from_camera(shot_camera)
	shot_camera.position = Vector3.ZERO
	shot_camera.fov = 45.0
	if not keyframe.apply_frame_shot(0, shot_camera):
		_fail("FrameShot failed to apply to camera.")
		return
	if shot_camera.position.distance_to(Vector3(1.0, 2.0, 3.0)) > 0.0001 or not is_equal_approx(shot_camera.fov, 61.0):
		_fail("FrameShot did not restore camera transform/projection data.")
		return
	
	handle.transform = original_transform
	actor.apply_keyframe(keyframe)
	if handle.position.distance_to(Vector3(0.25, 0.1, -0.2) + original_transform.origin) > 0.0001:
		_fail("Actor keyframe did not restore the edited handle.")
		return
	
	var character := CharacterData.new()
	character.ID = 7
	character.model_id = &"Rigger"
	
	var scene_data := SceneData.new()
	scene_data.ID = 3
	scene_data.link_character(character)
	var linked_frame := scene_data.ensure_scene_frame(scene_data.get_current_frame_index())
	if linked_frame.get_character_keyframe(character.ID) == null:
		_fail("SceneData.link_character did not create the required initial RigKeyframe.")
		return
	scene_data.capture_actor_keyframe(character, actor)
	
	handle.transform = original_transform
	if not scene_data.apply_actor_keyframe(character, actor):
		_fail("SceneData failed to apply a captured actor keyframe.")
		return
	
	var save_path := "user://runtime_rig_validation_scene.tres"
	var save_err := ResourceSaver.save(scene_data, save_path)
	if save_err != OK:
		_fail("SceneData resource save failed: %s" % error_string(save_err))
		return
	
	var loaded_scene_data := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SceneData
	if loaded_scene_data == null:
		_fail("SceneData resource reload failed.")
		return
	
	handle.transform = original_transform
	if not loaded_scene_data.apply_actor_keyframe(character, actor):
		_fail("Reloaded SceneData failed to apply a captured actor keyframe.")
		return
	
	var builder := actor.get_node_or_null("RuntimeRigBuilder")
	if builder == null:
		_fail("Actor scene does not include RuntimeRigBuilder.")
		return
	
	builder.call("rebuild_runtime_rig")
	actor.refresh_controllers()
	if actor.controllers.is_empty():
		_fail("RuntimeRigBuilder left actor with no controllers.")
		return
	
	print("Runtime rig validation passed.")
	quit(0)


## Reports a validation failure and exits with a non-zero status.
## message: human-readable explanation of the failed validation step.
## Returns: nothing; calls quit(1) after push_error.
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
