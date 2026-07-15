extends PanelContainer
class_name SceneCharEditor

@export_category("Scene")
@export var label			: Label
@export var linked_scenes	: Label
@export var thumbnail		: TextureRect
@export var model_picker	: OptionButton
@export var char_name		: LineEdit
@export var char_color		: ColorPickerButton
@export var add_remove_btn	: Button

var catalog			: RuntimeActors
var current_scene	: SceneData
var data			: CharacterData

signal made_project_changes
signal link_character(char:CharacterData)
signal unlink_character(char:CharacterData)


## Register to all signals
func _ready() -> void:
	char_name.text_changed.connect(_update_char_name)
	model_picker.item_selected.connect(_update_model_selected)
	char_color.color_changed.connect(_update_color)
	add_remove_btn.toggled.connect(_update_is_on_scene)

func setup_from(dt:CharacterData, actors_list:RuntimeActors, scene:SceneData) -> void:
	data = dt
	catalog = actors_list
	current_scene = scene
	
	if data.model_id == "":
		data.model_id = &"Rigger"
	
	model_picker.clear()
	for actor_name in catalog.actors.keys():
		model_picker.add_item(actor_name)
	
	_refresh_from_data()


func _refresh_from_data() -> void:
	
	label.text = "ID: %d" % data.ID
	
	# Set selected model
	for i in range(model_picker.item_count):
		if model_picker.get_item_text(i) == data.model_id:
			model_picker.selected = i
			break
	
	char_name.text = data.display_name
	char_color.color = data.color
	
	var is_on_scene := data.ID in current_scene.actors
	
	add_remove_btn.set_pressed_no_signal(is_on_scene)
	_refresh_on_scene_btn_visuals(is_on_scene)
	
	_refresh_linked_scenes()


# SIGNALS

func _update_char_name(new_name:String) -> void:
	data.display_name = new_name
	made_project_changes.emit()

func _update_model_selected(id:int) -> void:
	data.model_id = model_picker.get_item_text(id)
	made_project_changes.emit()

func _update_color(col:Color) -> void:
	data.color = col
	made_project_changes.emit()


func _update_is_on_scene(on_scene:bool) -> void:
	if on_scene:
		link_character.emit(data)
	else:
		unlink_character.emit(data)
	_refresh_on_scene_btn_visuals(on_scene)
	_refresh_linked_scenes.call_deferred()

func _refresh_on_scene_btn_visuals(on_scene:bool) -> void:
	add_remove_btn.self_modulate = Color.CHARTREUSE if on_scene else Color.CORAL
	add_remove_btn.text = "Yes!" if on_scene else "No."


func _refresh_linked_scenes() -> void:
	var txt := ""
	for s in data.get_all_linked_scenes():
		txt += "\n Scene ID %d" % s
	
	linked_scenes.text = "Not linked to any scenes!" if txt == "" else "Linked to: %s" % txt
