extends Resource
## Optional frame-local pose snapshot for one character.
## SceneData currently stores direct keyframe snapshots on SceneFrame, but this resource remains useful
## when a caller wants character ID, actor ID, and one RigKeyframe bundled together.
class_name FrameCharacter

## CharacterData.ID represented by this frame snapshot.
@export var character_id := -1
## Actor/model ID used when this snapshot was captured.
@export var actor_id: StringName
## RigKeyframe containing the actual TransformHandle3D pose for this character on a frame.
@export var rig_keyframe: Resource


## Captures a character actor's current rig pose into this snapshot.
## character: CharacterData that supplies character_id and actor_id/model_id metadata.
## actor: Actor3D whose HumanRig controls should be captured.
## baseline: optional RigKeyframe used to omit unchanged handles.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: nothing; updates character_id, actor_id, and rig_keyframe.
func capture_from(character: CharacterData, actor: Actor3D, baseline: Resource = null, tolerance := 0.0001) -> void:
	if character == null or actor == null:
		return
	
	character_id = character.ID
	actor_id = character.model_id
	rig_keyframe = actor.capture_keyframe(baseline, tolerance)


## Applies this snapshot to an instantiated actor.
## actor: Actor3D that should receive rig_keyframe on its HumanRig controls.
## Returns: true when a non-null actor and rig_keyframe were available; otherwise false.
func apply_to(actor: Actor3D) -> bool:
	if actor == null or rig_keyframe == null:
		return false
	
	actor.apply_keyframe(rig_keyframe)
	return true
