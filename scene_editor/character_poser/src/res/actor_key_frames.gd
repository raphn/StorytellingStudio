extends Resource
## Per-character animation/pose timeline for one actor model.
## Kept as a reusable timeline resource for actor-specific pose sequences, while SceneData now stores
## scene pose frames directly as frame index -> SceneFrame for clearer scene navigation.
class_name ActorKeyFrames

## CharacterData.ID that owns this keyframe timeline.
@export var char_id := -1
## Runtime actor catalog ID/model ID the keyframes were captured against.
## Used to know whether a pose timeline is being applied to the same actor type after model changes.
@export var actor_id: StringName
## Frame index -> RigKeyframe resource. Null entries are allowed when sparse frames have not been posed yet.
@export var keyframes: Array[RigKeyframe] = []


# ======================== || API ..................... || =================== #

## Gets the RigKeyframe stored at a frame index.
## index: zero-based scene frame index.
## Returns: the stored RigKeyframe, or null when index is outside the array.
func get_keyframe(index: int) -> RigKeyframe:
	if index < 0 or index >= keyframes.size():
		return null
	return keyframes[index]

## Stores a keyframe at a frame index, growing the sparse array when needed.
## index: zero-based scene frame index to write.
## keyframe: RigKeyframe resource to store; may be null to explicitly leave an empty slot.
## Returns: nothing; negative indexes are ignored.
func set_keyframe(index: int, keyframe: RigKeyframe) -> void:
	if index < 0:
		return
	
	_ensure_keyframe_count(index + 1)
	keyframes[index] = keyframe

## Captures a rig pose and stores it at a frame index.
## index: zero-based scene frame index to write.
## rig_root: HumanRig node whose TransformHandle3D descendants should be captured.
## baseline: optional RigKeyframe used to store only changes from a previous pose.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: the captured RigKeyframe, or null when index is negative.
func capture_keyframe(index: int, rig_root: Node, baseline: Resource = null, tolerance := 0.0001) -> RigKeyframe:
	if index < 0:
		return null
	
	var keyframe := RigKeyframe.from_rig(rig_root, baseline, tolerance)
	set_keyframe(index, keyframe)
	return keyframe

## Applies a stored keyframe to a rig tree.
## index: zero-based scene frame index to read.
## rig_root: HumanRig node used to resolve and update saved handle paths.
## Returns: true when a keyframe existed and was applied; false when no keyframe exists at index.
func apply_keyframe(index: int, rig_root: Node) -> bool:
	var keyframe := get_keyframe(index)
	if keyframe == null:
		return false
	
	keyframe.apply_to(rig_root)
	return true

## Removes a keyframe slot from the timeline.
## index: zero-based scene frame index to remove.
## Returns: nothing; indexes outside the current array are ignored.
func remove_keyframe(index: int) -> void:
	if index < 0 or index >= keyframes.size():
		return
	
	keyframes.remove_at(index)


## Grows the timeline array to at least count entries.
## count: desired minimum keyframes.size().
## Returns: nothing; appends null placeholders for missing sparse slots.
func _ensure_keyframe_count(count: int) -> void:
	while keyframes.size() < count:
		keyframes.append(null)
