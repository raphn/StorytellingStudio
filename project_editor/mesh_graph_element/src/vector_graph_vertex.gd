extends Resource
class_name VectorGraphVertex

@export var position := Vector2.ZERO
@export var in_handle := Vector2.ZERO
@export var out_handle := Vector2.ZERO


func copy() -> Resource:
	var vertex: Resource = get_script().new()
	vertex.position = position
	vertex.in_handle = in_handle
	vertex.out_handle = out_handle
	return vertex
