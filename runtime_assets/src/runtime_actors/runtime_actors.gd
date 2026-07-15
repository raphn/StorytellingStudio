extends Resource
class_name RuntimeActors

@export var actors : Dictionary[StringName, RuntimeActor]


func instantiate_character(model_id:StringName, at:Node3D) -> Node3D:
	if actors.has(model_id):
		var actor_scene := (actors.get(model_id) as RuntimeActor).scene as PackedScene
		if actor_scene:
			var inst := actor_scene.instantiate() as Actor3D
			if inst:
				at.add_child(inst)
				return inst
			else:
				printerr("Actor '%s' is not a valid Actor3D!" % model_id)
				return null
		else:
			printerr("Actor: '%s' don't have a valid PacedScene to instantiate!" % model_id)
			return null
	else:
		printerr("Actor '%s' not found!" % model_id)
		return null
