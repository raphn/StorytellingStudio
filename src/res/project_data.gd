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
@export var characters: Dictionary[int, CharacterData] = {}

## Increasing Scene ID numeration
@export var scene_id := 0

## Store scene information under unique ID
@export var scenes: Dictionary[int, SceneData] = {}


# ============================ || LAYOUTS ............... || ================= #

@export var print_settings : PrintingSettings

@export var editing_zoom := 1.0
@export var editing_scroll := Vector2.ZERO

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
const SCENE_FOLDER_NAME := "scns"
const CURRENT_DATA_VERSION := 3


# =============== || SCENE MANAGEMENT .......... || ========================== #

## Create new CharacterData, await saving amd returns the id of the new character
func create_new_character_and_save() -> CharacterData:
	var curr_id := character_id
	character_id += 1
	
	var n_char := CharacterData.new()
	n_char.ID = curr_id
	n_char.model_id = &"Rigger"
	characters.set(curr_id, n_char)
	
	save_modifications()
	return n_char

## Create new SceneData, await saving amd returns the id of the new scene
func create_new_scene_and_save() -> int:
	var curr_id := scene_id
	scene_id += 1
	
	var scene := SceneData.new()
	scene.ID = curr_id
	scenes.set(curr_id, scene)
	print_debug("New scene data created with id: '", curr_id, "'\n\t>>> ", scenes.get(curr_id))
	
	save_modifications()
	return curr_id


# =============== || DATA VERSION MANAGEMEN .... || ========================== #

## Updates the data model on old saved data
func check_update_data_model() -> void:
	if characters == null:
		characters = {}
	if scenes == null:
		scenes = {}
	if page_layouts == null:
		page_layouts = {}
	if settings == null:
		settings = {}
	if print_settings == null:
		print_settings = PrintingSettings.new()
	
	_check_update_characters()
	_check_update_scenes()
	_check_update_layouts()
	
	data_version = CURRENT_DATA_VERSION
	_verify_meta()

func _check_update_characters() -> void:
	var updated_characters: Dictionary[int, CharacterData] = {}
	var highest_character_id := -1
	
	for id in characters.keys():
		var character_id_key := int(id)
		var character := characters.get(id) as CharacterData
		if character == null:
			character = CharacterData.new()
		
		if character.ID < 0:
			character.ID = character_id_key
		if character.model_id == &"":
			character.model_id = &"Rigger"
		if character.display_name == "":
			character.display_name = "Character"
		if character.linked_scenes < 0:
			character.linked_scenes = 0
		
		highest_character_id = maxi(highest_character_id, character_id_key)
		highest_character_id = maxi(highest_character_id, character.ID)
		updated_characters[character_id_key] = character
	
	characters = updated_characters
	character_id = maxi(character_id, highest_character_id + 1)

func _check_update_scenes() -> void:
	var updated_scenes: Dictionary[int, SceneData] = {}
	var highest_scene_id := -1
	
	for id in scenes.keys():
		var scene_id_key := int(id)
		var scene := scenes.get(id) as SceneData
		if scene == null:
			scene = SceneData.new()
		
		if scene.ID < 0:
			scene.ID = scene_id_key
		
		_check_update_scene(scene)
		highest_scene_id = maxi(highest_scene_id, scene_id_key)
		highest_scene_id = maxi(highest_scene_id, scene.ID)
		updated_scenes[scene_id_key] = scene
	
	scenes = updated_scenes
	scene_id = maxi(scene_id, highest_scene_id + 1)

func _check_update_scene(scene: SceneData) -> void:
	if scene.actors == null:
		scene.actors = PackedByteArray()
	if scene.actor_keyframes == null:
		scene.actor_keyframes = {}
	if scene.current_frame < -1:
		scene.current_frame = -1
	
	var clean_actors := PackedByteArray()
	for character_id_value in scene.actors:
		var actor_id := int(character_id_value)
		if actor_id < 0 or clean_actors.find(actor_id) >= 0:
			continue
		clean_actors.append(actor_id)
	scene.actors = clean_actors
	
	var updated_keyframes: Dictionary[int, SceneFrame] = {}
	for frame_id in scene.actor_keyframes.keys():
		var frame_key := int(frame_id)
		if frame_key < 0:
			continue
		
		var frame := scene.actor_keyframes.get(frame_id) as SceneFrame
		if frame == null:
			frame = SceneFrame.new()
		
		_check_update_scene_frame(frame)
		updated_keyframes[frame_key] = frame
	
	scene.actor_keyframes = updated_keyframes
	if scene.current_frame >= 0:
		scene.ensure_scene_frame(scene.current_frame)

func _check_update_scene_frame(frame: SceneFrame) -> void:
	if frame.character_keyframes == null:
		frame.character_keyframes = {}
	
	var updated_character_keyframes: Dictionary[int, RigKeyframe] = {}
	for character_id_key in frame.character_keyframes.keys():
		var character_key := int(character_id_key)
		if character_key < 0:
			continue
		
		var keyframe := frame.character_keyframes.get(character_id_key) as RigKeyframe
		if keyframe == null:
			keyframe = RigKeyframe.new()
		
		_check_update_rig_keyframe(keyframe)
		updated_character_keyframes[character_key] = keyframe
		frame.character_id = character_key
	
	frame.character_keyframes = updated_character_keyframes

func _check_update_rig_keyframe(keyframe: RigKeyframe) -> void:
	if keyframe.handle_transforms == null:
		keyframe.handle_transforms = {}
	if keyframe.frame_shots == null:
		keyframe.frame_shots = []
	
	var updated_transforms: Dictionary[StringName, Transform3D] = {}
	for handle_key in keyframe.handle_transforms.keys():
		updated_transforms[StringName(str(handle_key))] = keyframe.handle_transforms[handle_key]
	keyframe.handle_transforms = updated_transforms
	
	if keyframe.frame_shots.is_empty():
		keyframe.current_frame_shot = -1
	else:
		keyframe.current_frame_shot = clampi(keyframe.current_frame_shot, 0, keyframe.frame_shots.size() - 1)

func _check_update_layouts() -> void:
	if front_cover == null:
		front_cover = LayoutData.new()
	if back_cover == null:
		back_cover = LayoutData.new()
	
	_check_update_layout(front_cover)
	_check_update_layout(back_cover)
	
	if page_layouts.is_empty():
		_initialize_pages()
		_check_update_layout(front_cover)
		_check_update_layout(back_cover)
	
	var updated_page_layouts: Dictionary[int, LayoutData] = {}
	var highest_page := -1
	for page_key in page_layouts.keys():
		var page_number := int(page_key)
		var layout := page_layouts.get(page_key) as LayoutData
		if layout == null:
			layout = LayoutData.new()
		
		_check_update_layout(layout)
		highest_page = maxi(highest_page, page_number)
		updated_page_layouts[page_number] = layout
	
	page_layouts = updated_page_layouts
	last_added_page = maxi(last_added_page, highest_page)
	
	if page_number_opened_on_the_left == -9:
		page_number_opened_on_the_left = 0

func _check_update_layout(layout: LayoutData) -> void:
	if layout.frames == null:
		layout.frames = []
	
	var updated_frames: Array[VectorGraphData] = []
	for frame in layout.frames:
		var graph_data := frame as VectorGraphData
		if graph_data == null:
			continue
		
		_check_update_vector_graph_data(graph_data)
		updated_frames.append(graph_data)
	
	layout.frames = updated_frames

func _check_update_vector_graph_data(graph_data: VectorGraphData) -> void:
	if graph_data.vertices == null:
		graph_data.vertices = []
	
	var updated_vertices: Array[VectorGraphVertex] = []
	for vertex in graph_data.vertices:
		var graph_vertex := vertex as VectorGraphVertex
		if graph_vertex == null:
			graph_vertex = VectorGraphVertex.new()
		updated_vertices.append(graph_vertex)
	
	graph_data.vertices = VectorPathGeometry.sanitize_vertices(updated_vertices)
	graph_data.curve_segments_per_edge = maxi(graph_data.curve_segments_per_edge, 1)
	graph_data.size = graph_data.size.max(Vector2(8, 8))
	graph_data.custom_minimum_size = graph_data.custom_minimum_size.max(Vector2.ZERO)
	graph_data.outline_width = maxf(graph_data.outline_width, 0.0)

func _verify_meta() -> void:
	if ID < 0:
		return
	
	var this_proj_folder := str(ID).lpad(32, "0")
	var full_proj_folder_path := PROJECTS_FOLDER + "/" + this_proj_folder
	var proj_data_path := full_proj_folder_path + "/proj.tres"
	var meta_data_path := full_proj_folder_path + "/" + META_NAME
	
	var should_save_meta := not FileAccess.file_exists(meta_data_path)
	if not should_save_meta:
		var meta := ResourceLoader.load(meta_data_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ProjectMetaData
		should_save_meta = (
			meta == null
			or meta.data_version != data_version
			or meta.project_id != ID
			or meta.display_name != display_name
			or meta.created_unix_time != created_unix_time
			or meta.modified_unix_time != modified_unix_time
			or meta.proj_path != proj_data_path
		)
	
	if should_save_meta:
		Utils.ensure_folder(full_proj_folder_path)
		ProjectMetaData.save_meta_of(self, proj_data_path, meta_data_path)


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


# =============== || FRAME SHOTS & SCENES ...... || ========================== #

## Returns the folder used to store rendered images for one scene pose frame.
## id_of_scene: SceneData.ID for the working scene.
## id_of_pose_frame: pose frame index from SceneData.current_frame / actor_keyframes key.
## Returns: user:// path and creates all missing directories before returning it.
static func get_frame_folder_path(id_of_scene:int, id_of_pose_frame:int) -> String:
	var scene_folder := str(id_of_scene).lpad(32, "0")
	var pose_frame_folder := str(id_of_pose_frame).lpad(32, "0")
	
	var frame_folder := "%s/%s/%s/fr_%s" % [PROJECTS_FOLDER, SCENE_FOLDER_NAME, scene_folder, pose_frame_folder]
	Utils.ensure_folder(frame_folder)
	
	return frame_folder + "/"


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
