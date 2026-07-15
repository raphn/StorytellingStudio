extends Node
class_name GEN

var app_data : AppData
var opened_project : ProjectData

# Local instances
var home_screen		: HomeScreen
var project_editor	: ProjectEditor
var scene_editor	: ComicSceneEditor

# consts
const APP_DATA_PATH := "user://app.tres"

# Scenes
const HOME_SCREEN = preload("uid://cdi4fhpqo0h2l")
const PROJECT_EDITOR = preload("uid://b5vbirvobwqec")
const COMIC_SCENE_EDITOR = preload("uid://r1ihhbkxfiwr")


func _ready() -> void:
	_load_app_data()
	_open_home_screen()

## Load the app settings
func _load_app_data() -> void:
	if FileAccess.file_exists(APP_DATA_PATH):
		app_data = ResourceLoader.load(APP_DATA_PATH) as AppData
	
	if app_data == null:
		app_data = AppData.new()
		app_data.resource_path = APP_DATA_PATH
		ResourceSaver.save(app_data)

func _open_loading_screen() -> bool:
	LoadingScreen.start()
	await get_tree().process_frame
	return true


# =============== || HOME SCREEN ............... || ========================== #

func _open_home_screen() -> void:
	home_screen = HOME_SCREEN.instantiate() as HomeScreen
	add_child(home_screen)

func start_editing_project(proj:ProjectData) -> void:
	
	LoadingScreen.start()
	await get_tree().process_frame
	
	remove_child(home_screen)
	home_screen.queue_free()
	
	opened_project = proj
	app_data.history.insert(0, opened_project.ID)
	print("Opening project :: ", opened_project.display_name)
	
	_open_project_editor.call_deferred()
	LoadingScreen.set_progress(0.5)


# =============== || PROJECT EDITING............ || ========================== #

## Starts Project Editing context
func _open_project_editor() -> void:
	project_editor = PROJECT_EDITOR.instantiate() as ProjectEditor
	add_child(project_editor)
	project_editor.open.call_deferred(opened_project)
	
	await project_editor.finished_opening_project
	LoadingScreen.set_progress(1.0)
	
	await get_tree().process_frame
	LoadingScreen.close_fade_out()

## Removes the current instance of Project Editor context
func _close_project_editor() -> void:
	if project_editor:
		remove_child(project_editor)
		project_editor.queue_free()

## Exits to home screen
func exit_project_edition() -> void:
	_close_project_editor()
	_open_home_screen.call_deferred()


# =============== || SCENE EDITING ............. || ========================== #

func start_editing_new_scene() -> void:
	await _open_loading_screen()
	
	print_debug("Creating new Scene Data on the project and opening it")
	var new_scene_id := opened_project.create_new_scene_and_save()
	
	LoadingScreen.set_progress(0.25)
	await _switch_to_scene_editor(new_scene_id)
	
	print_debug("Editing new scene!")

## Move from Project Editing context to Scene Editing Context
func start_editing_scene(scene_ID:int) -> void:
	await _open_loading_screen()
	_switch_to_scene_editor(scene_ID)

## Manages LoadingScreen, instantiates new SceneEditor node and opens a scene to start editing
func _switch_to_scene_editor(scene_ID:int) -> void:
	print_debug("Opening scene ID '", scene_ID, "'")
	_close_project_editor()
	LoadingScreen.set_progress(0.5)
	
	scene_editor = COMIC_SCENE_EDITOR.instantiate() as ComicSceneEditor
	add_child(scene_editor)
	LoadingScreen.set_progress(0.75)
	
	# Configure Scene Editor with desired scene
	scene_editor.star_scene_editing(opened_project, scene_ID)
	LoadingScreen.set_progress(1.0)
	
	await get_tree().process_frame
	LoadingScreen.close_fade_out()

## Move back from Scene Editing Context to Project Editing context 
func finish_editing_scene() -> void:
	await _open_loading_screen()
	_close_scene_editor()
	_open_project_editor()

func _close_scene_editor() -> void:
	if scene_editor:
		remove_child(scene_editor)
		scene_editor.queue_free()


# =============================================================== || Statics
static func get_instance(from:Node) -> GEN:
	return from.get_tree().root.get_node("GEN") as GEN
