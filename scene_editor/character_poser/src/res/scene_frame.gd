extends Resource
## Data for one scene frame in the scene editor.
## Stores frame-local pose snapshots so a frame can restore character rigs even if the broader timeline is sparse.
class_name SceneFrame

## Last/touched character ID for this frame. Kept for compatibility with earlier single-character frame data.
@export var character_id : int

## CharacterData.ID -> RigKeyframe resource for every character posed on this frame.
@export var character_keyframes: Dictionary[int, RigKeyframe] = {}


## Gets a frame-local pose for one character.
## character_id_value: CharacterData.ID whose frame pose should be read.
## Returns: RigKeyframe resource for the character on this frame, or null when absent.
func get_character_keyframe(character_id_value: int) -> RigKeyframe:
	return character_keyframes.get(character_id_value)

## Gets or creates the frame-local pose resource for one character.
## character_id_value: CharacterData.ID that must have a pose slot on this frame.
## Returns: existing or newly-created RigKeyframe, or null when character_id_value is invalid.
func ensure_character_keyframe(character_id_value: int) -> RigKeyframe:
	if character_id_value < 0:
		return null
	
	var keyframe := get_character_keyframe(character_id_value)
	if keyframe == null:
		keyframe = RigKeyframe.new()
		set_character_keyframe(character_id_value, keyframe)
	
	return keyframe

## Stores or replaces a frame-local pose for one character.
## character_id_value: CharacterData.ID that owns the pose.
## keyframe: RigKeyframe resource captured from that character's actor.
## Returns: nothing; invalid IDs and null keyframes are ignored.
func set_character_keyframe(character_id_value: int, keyframe: RigKeyframe) -> void:
	if character_id_value < 0 or keyframe == null:
		return
	
	character_id = character_id_value
	character_keyframes[character_id_value] = keyframe

## Removes any frame-local pose for one character.
## character_id_value: CharacterData.ID whose pose should be removed from this frame.
## Returns: nothing; missing entries are ignored by Dictionary.erase.
func remove_character(character_id_value: int) -> void:
	character_keyframes.erase(character_id_value)
