extends Resource
## Serialized pose snapshot for an actor HumanRig.
## Stores only TransformHandle3D local transforms so poses can be reapplied to compatible actor instances
## without depending on the actor's global scene placement.
class_name RigKeyframe

const FrameShotScript := preload("res://scene_editor/character_poser/src/res/frame_shot.gd")

## Relative NodePath string -> local Transform3D for each captured TransformHandle3D.
## Keys are relative to the rig root passed to capture_from/from_rig.
@export var handle_transforms: Dictionary[StringName, Transform3D] = {}

## True when this keyframe was captured against a baseline and may contain only changed handles.
@export var stores_only_changes := false
## Ordered FrameShot list captured for this pose keyframe.
## Each shot stores the frame-shot generator camera transform/projection for this rig pose.
@export var frame_shots: Array[Resource] = []
## Currently selected FrameShot index for camera-shot navigation. -1 means no shot is selected.
@export var current_frame_shot := -1


## Factory helper that creates and fills a RigKeyframe from a rig tree.
## rig_root: node whose descendants are scanned for TransformHandle3D controls.
## baseline: optional RigKeyframe used to skip transforms that have not changed.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: the newly created RigKeyframe resource.
static func from_rig(rig_root: Node, baseline: Resource = null, tolerance := 0.0001) -> RigKeyframe:
	var keyframe: Resource = RigKeyframe.new()
	keyframe.capture_from(rig_root, baseline, tolerance)
	return keyframe


## Replaces this resource's stored pose with transforms found under a rig tree.
## rig_root: node whose descendants are scanned for TransformHandle3D controls.
## baseline: optional RigKeyframe used to keep only transforms that differ from a previous pose.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: nothing; updates handle_transforms and stores_only_changes.
func capture_from(rig_root: Node, baseline: Resource = null, tolerance := 0.0001) -> void:
	handle_transforms.clear()
	stores_only_changes = baseline != null
	
	if rig_root == null:
		return
	
	_capture_handles(rig_root, rig_root, baseline, tolerance)

## Applies stored handle transforms to a compatible rig tree.
## rig_root: node used as the root for resolving saved relative handle paths.
## Returns: nothing; missing handles are skipped so poses can survive model/controller changes.
func apply_to(rig_root: Node) -> void:
	if rig_root == null:
		return
	
	for key in handle_transforms.keys():
		var handle := rig_root.get_node_or_null(NodePath(String(key))) as TransformHandle3D
		if handle:
			handle.transform = handle_transforms[key]

## Checks whether this keyframe contains pose data for a specific handle path.
## handle_key: relative path key produced from rig_root.get_path_to(handle).
## Returns: true when handle_transforms has a value for handle_key.
func has_handle(handle_key: StringName) -> bool:
	return handle_transforms.has(handle_key)

## Reads a stored transform for one handle.
## handle_key: relative path key produced from rig_root.get_path_to(handle).
## fallback: value returned when the handle was not captured in this keyframe.
## Returns: the stored Transform3D or fallback.
func get_handle_transform(handle_key: StringName, fallback := Transform3D.IDENTITY) -> Transform3D:
	return handle_transforms.get(handle_key, fallback)

## Writes or replaces one handle transform in this keyframe.
## handle_key: relative path key produced from rig_root.get_path_to(handle).
## value: local Transform3D to store for that handle.
## Returns: nothing; mutates handle_transforms.
func set_handle_transform(handle_key: StringName, value: Transform3D) -> void:
	handle_transforms[handle_key] = value

## Removes one handle transform from this keyframe.
## handle_key: relative path key produced from rig_root.get_path_to(handle).
## Returns: nothing; missing keys are ignored by Dictionary.erase.
func erase_handle(handle_key: StringName) -> void:
	handle_transforms.erase(handle_key)

## Reports whether this keyframe contains any captured handles.
## Returns: true when handle_transforms has no entries.
func is_empty() -> bool:
	return handle_transforms.is_empty()


## Reports whether this pose has any camera shots attached.
## Returns: true when frame_shots contains at least one FrameShot.
func has_frame_shots() -> bool:
	return not frame_shots.is_empty()


## Gets the selected FrameShot index, normalizing invalid selections.
## Returns: selected FrameShot index, or -1 when no shots exist.
func get_current_frame_shot_index() -> int:
	if frame_shots.is_empty():
		current_frame_shot = -1
		return -1
	
	current_frame_shot = clampi(current_frame_shot, 0, frame_shots.size() - 1)
	return current_frame_shot


## Gets the currently selected FrameShot.
## Returns: selected FrameShot resource, or null when no shots exist.
func get_current_frame_shot() -> Resource:
	var shot_index := get_current_frame_shot_index()
	if shot_index < 0:
		return null
	
	return frame_shots[shot_index]


## Captures the camera as a new FrameShot appended to this keyframe.
## camera: FrameShot generator camera to capture.
## Returns: captured FrameShot, or null when camera is null.
func add_frame_shot_from_camera(camera: Camera3D) -> Resource:
	if camera == null:
		return null
	
	var frame_shot: Resource = FrameShotScript.from_camera(camera)
	frame_shots.append(frame_shot)
	current_frame_shot = frame_shots.size() - 1
	return frame_shot


## Replaces or creates a FrameShot at a specific index.
## index: target FrameShot index to write.
## camera: FrameShot generator camera to capture.
## Returns: captured FrameShot, or null when index is negative or camera is null.
func capture_frame_shot(index: int, camera: Camera3D) -> Resource:
	if index < 0 or camera == null:
		return null
	
	while frame_shots.size() <= index:
		frame_shots.append(null)
	
	var frame_shot: Resource = FrameShotScript.from_camera(camera)
	frame_shots[index] = frame_shot
	current_frame_shot = index
	return frame_shot


## Applies a stored FrameShot to a camera.
## index: FrameShot index to apply.
## camera: camera that should receive the saved shot settings.
## Returns: true when a valid shot existed and was applied; otherwise false.
func apply_frame_shot(index: int, camera: Camera3D) -> bool:
	if index < 0 or index >= frame_shots.size() or frame_shots[index] == null:
		return false
	
	current_frame_shot = index
	return frame_shots[index].apply_to(camera)


## Finds the next saved FrameShot index.
## Returns: next index, wrapping to 0, or -1 when no shots exist.
func get_next_frame_shot_index() -> int:
	return _get_relative_frame_shot_index(1)


## Finds the previous saved FrameShot index.
## Returns: previous index, wrapping to the last shot, or -1 when no shots exist.
func get_previus_frame_shot_index() -> int:
	return _get_relative_frame_shot_index(-1)


## Recursive capture worker used by capture_from.
## node: current node being scanned.
## rig_root: root used to make stable relative paths for every found handle.
## baseline: optional RigKeyframe used to skip unchanged transforms.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: nothing; appends captured transforms into handle_transforms.
func _capture_handles(node: Node, rig_root: Node, baseline: Resource, tolerance: float) -> void:
	if node is TransformHandle3D:
		var handle := node as TransformHandle3D
		var handle_key := StringName(str(rig_root.get_path_to(handle)))
		var current_transform := handle.transform
		
		if baseline != null and baseline.has_handle(handle_key):
			var baseline_transform: Transform3D = baseline.get_handle_transform(handle_key)
			if _transforms_equal(current_transform, baseline_transform, tolerance):
				return
		
		handle_transforms[handle_key] = current_transform
	
	for child in node.get_children():
		_capture_handles(child, rig_root, baseline, tolerance)

## Finds a FrameShot index relative to current_frame_shot.
## direction: positive moves forward, negative moves backward.
## Returns: wrapped FrameShot index, or -1 when no shots exist.
func _get_relative_frame_shot_index(direction: int) -> int:
	if frame_shots.is_empty():
		current_frame_shot = -1
		return -1
	
	if current_frame_shot < 0 or current_frame_shot >= frame_shots.size():
		current_frame_shot = 0
	else:
		current_frame_shot = wrapi(current_frame_shot + signi(direction), 0, frame_shots.size())
	
	return current_frame_shot

## Compares two transforms using per-vector squared-distance checks.
## a: first transform being compared.
## b: second transform being compared.
## tolerance: maximum allowed distance per origin/basis vector before transforms are considered different.
## Returns: true when origin and all basis vectors are within tolerance.
func _transforms_equal(a: Transform3D, b: Transform3D, tolerance: float) -> bool:
	var tolerance_squared := tolerance * tolerance
	if a.origin.distance_squared_to(b.origin) > tolerance_squared:
		return false
	if a.basis.x.distance_squared_to(b.basis.x) > tolerance_squared:
		return false
	if a.basis.y.distance_squared_to(b.basis.y) > tolerance_squared:
		return false
	if a.basis.z.distance_squared_to(b.basis.z) > tolerance_squared:
		return false
	return true
