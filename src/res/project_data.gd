extends Resource
class_name ProjectData

@export var data_version := 0
@export var ID := -1
@export var display_name := "Untitled Comic"

@export var created_unix_time := 0
@export var modified_unix_time := 0


# ============================ || SCENES & CHARACTERS ... || ================= #

## Increasing Character ID numeration
@export var character_id := 0

## Store character information under unique ID
@export var characters: Array[CharacterData] = []

## Increasing Scene ID numeration
@export var scene_id := 0

## Store scene information under unique ID
@export var scenes: Dictionary[int, SceneData] = {}


# ============================ || LAYOUTS ............... || ================= #

@export var print_settings : PrintingSettings

## -9 = ID invalid
## -> -1 = Front Cover page number
## -> -2 = Back Cover page number
@export var page_number_opened_on_the_left : int = -9

## Only holds Frames on the right side
@export var front_cover 	: LayoutData

## Only holds Frames on the left Side
@export var back_cover		: LayoutData

## Dictionary of [<Page number>, <LayoutData>] || Default
@export var page_layouts	: Dictionary[int, LayoutData] = {}
@export var last_added_page : int

@export var settings := {}

signal finished_saving

const PROJECTS_FOLDER := "user://projects"
const META_NAME := "meta.tres"
const CURRENT_DATA_VERSION := 2


# =============== || SCENE MANAGEMENT .......... || ========================== #

## Create new CharacterData, await saving amd returns the id of the new character
func create_new_character_and_save() -> int:
	var curr_id := character_id
	character_id += 1
	
	characters.set(character_id, CharacterData.new())
	save()
	
	await finished_saving
	return curr_id

## Create new SceneData, await saving amd returns the id of the new scene
func create_new_scene_and_save() -> int:
	var curr_id := scene_id
	scene_id += 1
	
	scenes.set(curr_id, SceneData.new())
	print_debug("New scene data created with id: '", curr_id, "'\n\t>>> ", scenes.get(curr_id))
	
	save_modifications()
	return curr_id


# =============== || PAGE MANAGEMENT ........... || ========================== #

func add_new_page() -> int:
	var next_page := last_added_page + 2
	
	if page_layouts.has(next_page):
		printerr("! Page number '%d' already exists !!" % next_page)
		return -9
	
	page_layouts.set(next_page, LayoutData.new())
	last_added_page = next_page
	
	print("Page '%d' added!" % next_page)
	return next_page

func is_last_page(page_number:int) -> bool:
	return page_number == get_last_page()

func get_last_page() -> int:
	var pages := page_layouts.keys()
	return pages.max()

func get_next_page(current_page:int) -> int:
	var pages:PackedByteArray = page_layouts.keys() as PackedByteArray
	pages.sort()
	
	for p in pages:
		if p > current_page:
			return p
	return -2

func get_previus_page(from_page:int) -> int:
	if from_page == -2:
		return get_last_page()
	
	var pages:PackedByteArray = page_layouts.keys() as PackedByteArray
	pages.sort()
	pages.reverse()
	
	for p in pages:
		if p < from_page:
			return p
	return -1


# =============== || SAVE & LOAD ............... || ========================== #

## Save the project updating the last modified time
func save_modifications() -> void:
	modified_unix_time = int(Time.get_unix_time_from_system())
	save()
	print_debug("Project saved at: ", Time.get_date_string_from_unix_time(modified_unix_time))

## Saves: this ProjectData info + related ProjectMetaData
func save() -> void:
	var this_proj_folder := str(ID).lpad(32, "0")
	var full_proj_folder_path := PROJECTS_FOLDER + "/" + this_proj_folder
	
	# ...
	Utils.ensure_folder(full_proj_folder_path)
	
	# Path calculation
	var proj_data_path := full_proj_folder_path + "/proj.tres"
	var meta_data_path := full_proj_folder_path + "/" + META_NAME
	
	# Saving Data & MetaData
	var err := ResourceSaver.save(self, proj_data_path)
	if err == OK:
		ProjectMetaData.save_meta_of(self, proj_data_path, meta_data_path)
	else:
		printerr(error_string(err))
	
	finished_saving.emit()


# =============== || PROJECT MANAGEMENT ........ || ========================== #

## Start a new project with correct ID and initial information
static func start_new_project(named:="") -> ProjectData:
	return _start_new(_get_next_ID(), named)

## Maintain a continuous project ID by saving the current ID number in a meta file 
static func _get_next_ID() -> int:
	# ID tracker file path
	var tracker_path := PROJECTS_FOLDER + "/trmeta"
	
	# Initially track if this is the first project by checking if the meta exists
	var first_proj := not FileAccess.file_exists(tracker_path)
	
	# Open the File to writte on
	var tracker_file := FileAccess.open(tracker_path, FileAccess.WRITE)
	
	# If the tracker don't exist initialize as -1 as NON INITIALIZED
	if first_proj:
		tracker_file.store_32(-1)
	
	# ... calculate new ID
	var new_ID := tracker_file.get_32() + 1
	tracker_file.store_32(new_ID)
	
	# ...
	tracker_file.close()
	
	return new_ID

## Create a new project with initial information
static func _start_new(with_id:int, named:="") -> ProjectData:
	var n_proj := ProjectData.new()
	
	n_proj.ID = with_id
	if named != "":
		n_proj.display_name = named
	
	n_proj.created_unix_time = int(Time.get_unix_time_from_system())
	n_proj.modified_unix_time = n_proj.created_unix_time
	n_proj._initialize_pages()
	
	n_proj.save()
	return n_proj

## Initialize page instances and dictionaries
func _initialize_pages() -> void:
	# Page [-|-1]
	front_cover = LayoutData.new()
	
	# Initialize pages [0|1] and [2|3]
	page_layouts.set(0, LayoutData.new())
	page_layouts.set(2, LayoutData.new())
	last_added_page = 2
	
	# Page [-2|-]
	back_cover = LayoutData.new()
	
	# Back of the front cover on left (page 1 in right)
	page_number_opened_on_the_left = 0

## Updates the data model on old saved data
func check_update_data_model() -> void:
	if data_version == CURRENT_DATA_VERSION:
		return;
	
	if not page_layouts:
		_initialize_pages()
	
	data_version = CURRENT_DATA_VERSION

## Returns all currently existig projects
static func get_projects() -> Array[ProjectMetaData]:
	Utils.ensure_folder(PROJECTS_FOLDER)
	
	# Search existing projects
	var proj_folders := DirAccess.get_directories_at(PROJECTS_FOLDER)
	var found : Array[ProjectMetaData] = []
	
	for pf in proj_folders:
		var meta_path := PROJECTS_FOLDER + "/" + pf + "/" + META_NAME
		
		if FileAccess.file_exists(meta_path):
			var meta := ResourceLoader.load(meta_path) as ProjectMetaData
			if meta:
				found.append(meta)
	
	return found
