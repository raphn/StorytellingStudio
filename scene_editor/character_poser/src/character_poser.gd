extends Node3D
class_name CharacterPoser3D

@export var main_cam : Camera3D
@export var human_rig : Marker3D

@export var controllers : Array[TransformHandle3D]


func _ready() -> void:
	_set_camera_recussive(human_rig)


func _set_camera_recussive(node:Node3D) -> void:
	if node is TransformHandle3D:
		node.camera = main_cam
	
	for child in node.get_children():
		_set_camera_recussive(child)
