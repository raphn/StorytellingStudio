extends Node3D
class_name ComicSceneEditor

@export var add_char_btn : Button
@export var char_editor : CharacterEditor

@export var frame_editor : PanelContainer

var controller	: GEN
var project		: ProjectData
var editing		: SceneData

signal finished_open_scene


func star_scene_editing(gen:GEN, scene_id:int) -> void:
	controller = gen
	project = gen.opened_project
	
	editing = project.scenes.get(scene_id)
	print_debug(project.scenes)
	
	if editing == null:
		printerr("No scene with ID '", scene_id, "'")
		Feedback.push("Error: NO ID when opening the scene editor!", Feedback.Type.Err)
	
	char_editor.open_project(project)
	frame_editor.visible = false
	
	finished_open_scene.emit()

func _on_add_character_id_pressed(id: int) -> void:
	
	
	pass # Replace with function body.
