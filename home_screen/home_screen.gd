extends PanelContainer
class_name HomeScreen

@export var new_proj_name	: LineEdit
@export var create_btn		: Button
@export var pickers_root	: VBoxContainer

@export_category("Last opened")
@export var last_opened_separator : HSeparator
@export var last_opened_container : PanelContainer

var gen : GEN

const PROJECT_PICKER = preload("uid://c2b3d07yqd6ku")


func _ready() -> void:
	gen = GEN.get_instance(self)
	
	# Display all existing projects in a list
	_list_all_existing_projects()
	
	# Connect project creation button
	create_btn.pressed.connect(_create_new)


func _list_all_existing_projects() -> void:
	# Recalls the last opened HELPER
	var projs_by_id: Dictionary[int, ProjectMetaData] = {}
	
	# List all existing projects
	var projs := ProjectData.get_projects()
	for proj in projs:
		_create_picker_interface_for(proj, pickers_root)
		projs_by_id.set(proj.project_id, proj)
	
	for id in gen.app_data.history:
		if projs_by_id.has(id):
			_create_picker_interface_for(projs_by_id.get(id), last_opened_container)
			break

func _create_picker_interface_for(proj:ProjectMetaData, where:Control) -> void:
	var picker := PROJECT_PICKER.instantiate() as ProjectPicker
	picker.setup_from(proj)
	picker.start_editing.connect(func(): gen.start_editing_project(proj.get_related_project()))
	where.add_child(picker)

func _create_new() -> void:
	gen.start_editing_project(ProjectData.start_new_project(new_proj_name.text))
