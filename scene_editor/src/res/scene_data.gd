extends Resource
class_name SceneData

## RuntimeAsset id of the actors in this scene
@export var actors : PackedStringArray

@export var frames : Array[SceneFrame]
@export var current_frame : int = -1
