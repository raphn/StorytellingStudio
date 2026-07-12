extends PanelContainer
class_name ProjectPicker

@export var title		: Label
@export var descript	: Label
@export var open_btn	: Button

var data : ProjectMetaData

signal start_editing


## Configuration
func setup_from(proj_meta:ProjectMetaData) -> void:
	data = proj_meta
	
	title.text = data.display_name
	
	var creation := Time.get_datetime_string_from_unix_time(data.created_unix_time)
	var last_edited := Time.get_datetime_string_from_unix_time(data.modified_unix_time)
	descript.text = "Created: %s\nEdited: %s" % [creation, last_edited]
	
	open_btn.pressed.connect(_open_project)

## Called on open button is clicked
func _open_project() -> void:
	start_editing.emit()
