extends Resource
class_name CharacterData

@export var ID := -1

## -1 = Rigger dummy || 0 = Framy dummy
@export var model_id : StringName

@export var display_name := "Character"

@export var color := Color.WHITE

@export var linked_scenes := 0


func link_scene(id: int) -> void:
	assert(id >= 0 and id < 64, "Scene ID must be between 0 and 63.")
	linked_scenes |= 1 << id

func unlink_scene(id: int) -> void:
	assert(id >= 0 and id < 64, "Scene ID must be between 0 and 63.")
	linked_scenes &= ~(1 << id)

func get_all_linked_scenes() -> PackedByteArray:
	var scenes := PackedByteArray()
	
	for id in range(64):
		if linked_scenes & (1 << id):
			scenes.append(id)
	
	return scenes
