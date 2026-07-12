extends Resource
class_name ProjectMetaData

@export var data_version := 0
@export var project_id := -1
@export var display_name := "Untitled Comic"

@export var created_unix_time := 0
@export var modified_unix_time := 0

@export var proj_path := ""


## Loads the relative ProjectData and returns it
func get_related_project() -> ProjectData:
	var proj_dt := ResourceLoader.load(proj_path) as ProjectData
	if proj_dt:
		return proj_dt
	else:
		return null

## Creates a ProjectMetaData Resource related to the projec data passed in "from"
static func save_meta_of(from:ProjectData, proj_dt_path:String, at_path:String) -> void:
	var meta := ProjectMetaData.new()
	
	meta.data_version = from.data_version
	meta.project_id = from.ID
	
	meta.display_name = from.display_name
	meta.created_unix_time = from.created_unix_time
	meta.modified_unix_time = from.modified_unix_time
	
	meta.proj_path = proj_dt_path
	
	ResourceSaver.save(meta, at_path)
