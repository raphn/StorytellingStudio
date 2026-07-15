extends PanelContainer
class_name CharacterEditor

@export var scene_editor	: ComicSceneEditor
@export var actors			: RuntimeActors

@export_category("Scene")
@export var close_btn	: Button
@export var actors_root	: VBoxContainer
@export var new_char	: Button
@export var close_btn2	: Button

var proj_dt		: ProjectData
var scene_data	: SceneData

const SCENE_CHAR_EDITOR = preload("uid://d3n5tky3titk2")


func _ready() -> void:
	close_btn.pressed.connect(_close_window)
	close_btn2.pressed.connect(_close_window)
	new_char.pressed.connect(_create_char)


func open_project(proj:ProjectData, at_scene:SceneData) -> void:
	proj_dt = proj
	scene_data = at_scene
	
	# Preload all actors as "actor_editor" interface
	for i in proj_dt.characters.keys():
		_create_interface_for(proj_dt.characters.get(i))
	
	# TODO Instantiate all actors in scene
	pass


## Create new character data on project and interface
func _create_char() -> void:
	
	var n_char := proj_dt.create_new_character_and_save()
	if n_char:
		_create_interface_for(n_char)
		print_debug("New character created!")
	else:
		print_debug("New character NOT created!")

func _create_interface_for(char_dt:CharacterData) -> void:
	var c_edit := SCENE_CHAR_EDITOR.instantiate() as SceneCharEditor
	actors_root.add_child(c_edit)
	
	c_edit.setup_from(char_dt, actors, scene_data)
	
	c_edit.made_project_changes.connect(func(): scene_editor.set_dirty())
	c_edit.link_character.connect(scene_editor._link_character)
	c_edit.unlink_character.connect(scene_editor._unlink_character)

func _close_window() -> void:
	visible = false
