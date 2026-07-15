extends Resource
## Persistent data for one reusable comic scene.
## Tracks linked characters, pose frame order, current frame, and per-frame character RigKeyframes.
class_name SceneData

## Unique scene ID inside ProjectData.scenes.
@export var ID := -1

## CharacterData.ID values currently linked to this scene.
@export var actors : PackedByteArray

## Currently edited frame index. -1 means no frame has been selected/created yet.
@export var current_frame : int = -1

## Pose frame index -> SceneFrame resource.
## Each SceneFrame owns the RigKeyframe pose for every character at that pose frame.
@export var actor_keyframes: Dictionary[int, SceneFrame] = {}


## Ensures there is an active frame and returns its index.
## Returns: current_frame after normalizing -1 to 0 and creating the SceneFrame if needed.
func get_current_frame_index() -> int:
	if current_frame < 0:
		current_frame = 0
	ensure_scene_frame(current_frame)
	return current_frame


## Selects the active frame for future capture/apply operations.
## index: desired frame index; negative values clamp to 0.
## Returns: nothing; creates the SceneFrame for index if needed.
func set_current_frame(index: int) -> void:
	current_frame = max(index, 0)
	ensure_scene_frame(current_frame)


## Links a character to this scene and guarantees the current SceneFrame plus character RigKeyframe exist.
## character: CharacterData being added to the scene actor list.
## Returns: the current SceneFrame containing at least one RigKeyframe for character, or null if character is null.
func link_character(character: CharacterData) -> SceneFrame:
	if character == null:
		return null
	
	if not character.ID in actors:
		actors.append(character.ID)
	
	var frame := ensure_scene_frame(get_current_frame_index())
	frame.ensure_character_keyframe(character.ID)
	return frame


## Guarantees a linked character has a pose frame and RigKeyframe even before live actor capture.
## character_id: CharacterData.ID that must exist in the active pose frame.
## frame_index: frame to check/create; -1 means use/get current_frame.
## Returns: existing or newly-created RigKeyframe, or null when character_id is invalid.
func ensure_character_keyframe(character_id: int, frame_index := -1) -> RigKeyframe:
	if character_id < 0:
		return null
	
	var target_frame_index := _normalize_frame_index(frame_index)
	var frame := ensure_scene_frame(target_frame_index)
	return frame.ensure_character_keyframe(character_id)


## Repairs/initializes the active pose frame so every linked character has a RigKeyframe.
## frame_index: frame to check/create; -1 means use/get current_frame.
## Returns: number of linked characters that now have a RigKeyframe on the resolved frame.
func ensure_linked_character_keyframes(frame_index := -1) -> int:
	var target_frame_index := _normalize_frame_index(frame_index)
	var ensured_count := 0
	for character_id in actors:
		if ensure_character_keyframe(character_id, target_frame_index) != null:
			ensured_count += 1
	return ensured_count


## Unlinks a character from this scene and removes its frame-local pose snapshots.
## character_id: CharacterData.ID to remove from actors and every SceneFrame.
## Returns: nothing; absent IDs are ignored.
func unlink_character(character_id: int) -> void:
	var index := actors.find(character_id)
	if index >= 0:
		actors.remove_at(index)
	
	for frame in actor_keyframes.values():
		if frame is SceneFrame:
			(frame as SceneFrame).remove_character(character_id)


## Gets or creates a pose SceneFrame.
## frame_index: requested pose frame index; -1 means use/get current_frame.
## Returns: SceneFrame stored in actor_keyframes at the resolved frame index.
func ensure_scene_frame(frame_index := -1) -> SceneFrame:
	var target_frame_index := frame_index
	if target_frame_index < 0:
		if current_frame < 0:
			current_frame = 0
		target_frame_index = current_frame
	
	if not actor_keyframes.has(target_frame_index) or actor_keyframes[target_frame_index] == null:
		actor_keyframes[target_frame_index] = SceneFrame.new()
	
	return actor_keyframes[target_frame_index]


## Creates a new pose SceneFrame after the current highest frame index and selects it.
## Returns: the new frame index.
func add_pose_frame() -> int:
	var new_frame_index := 0
	if not actor_keyframes.is_empty():
		new_frame_index = actor_keyframes.keys().max() + 1
	
	current_frame = new_frame_index
	ensure_scene_frame(current_frame)
	return current_frame


## Gets frame indexes currently stored in actor_keyframes in ascending order.
## Returns: sorted Array[int] of saved pose frame indexes.
func get_pose_frame_indices() -> Array[int]:
	var indices: Array[int] = []
	for frame_index in actor_keyframes.keys():
		indices.append(int(frame_index))
	indices.sort()
	return indices


## Finds the next saved pose frame after current_frame.
## Returns: next saved frame index, wrapping to the first saved frame when needed.
func get_next_pose_frame_index() -> int:
	return _get_relative_pose_frame_index(1)


## Finds the previous saved pose frame before current_frame.
## Returns: previous saved frame index, wrapping to the last saved frame when needed.
func get_previus_pose_frame_index() -> int:
	return _get_relative_pose_frame_index(-1)


## Captures an actor's current rig pose into the scene timeline and the frame snapshot.
## character: CharacterData that identifies which scene character owns the pose.
## actor: instantiated Actor3D whose HumanRig should be captured.
## frame_index: frame to capture into; -1 means use/get current_frame.
## baseline: optional RigKeyframe used to omit unchanged handles from the capture.
## Returns: captured RigKeyframe resource, or null if character/actor/timeline is unavailable.
func capture_actor_keyframe(character: CharacterData, actor: Actor3D, frame_index := -1, baseline: Resource = null) -> RigKeyframe:
	if character == null or actor == null:
		return null
	
	var target_frame_index := _normalize_frame_index(frame_index)
	var frame := ensure_scene_frame(target_frame_index)
	var keyframe := frame.ensure_character_keyframe(character.ID)
	keyframe.capture_from(actor.human_rig, baseline)
	frame.set_character_keyframe(character.ID, keyframe)
	return keyframe


## Applies a saved pose for one character/frame onto an actor instance.
## character: CharacterData whose pose should be read.
## actor: instantiated Actor3D that should receive the saved pose.
## frame_index: frame to apply from; -1 means use/get current_frame.
## Returns: true when a timeline or frame-local keyframe was found and applied; otherwise false.
func apply_actor_keyframe(character: CharacterData, actor: Actor3D, frame_index := -1) -> bool:
	if character == null or actor == null:
		return false
	
	var target_frame_index := _normalize_frame_index(frame_index)
	var frame := ensure_scene_frame(target_frame_index)
	var frame_keyframe := frame.get_character_keyframe(character.ID)
	if frame_keyframe != null:
		actor.apply_keyframe(frame_keyframe)
		return true
	
	return false


## Resolves a caller-supplied frame index into a valid frame index.
## frame_index: requested frame; -1 means current frame and non-negative values are used directly.
## Returns: valid frame index after ensuring actor_keyframes contains that SceneFrame slot.
func _normalize_frame_index(frame_index: int) -> int:
	var target_frame_index := frame_index
	if target_frame_index < 0:
		target_frame_index = get_current_frame_index()
	else:
		ensure_scene_frame(target_frame_index)
	return target_frame_index


## Finds a saved frame relative to current_frame in the sorted actor_keyframes keys.
## direction: positive moves forward; negative moves backward.
## Returns: resolved frame index, wrapping across saved frames. Creates frame 0 when no frames exist.
func _get_relative_pose_frame_index(direction: int) -> int:
	var indices := get_pose_frame_indices()
	if indices.is_empty():
		return get_current_frame_index()
	
	var current_index := indices.find(current_frame)
	if current_index < 0:
		current_index = 0
	else:
		current_index = wrapi(current_index + signi(direction), 0, indices.size())
	
	return indices[current_index]
