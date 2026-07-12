extends PanelContainer
class_name ScenePicker

@export var actor_thumbs_root : GridContainer
@export var open_scene_btn : Button

var data	: SceneData
var scn_id	: int


func _ready() -> void:
	open_scene_btn.pressed.connect(_open_scene)

func setup_from(scene:SceneData, id:int) -> void:
	print_debug("Setting up scene picker for\n\tscene: ", scene, "\n\tID: ", id)
	
	data = scene
	scn_id = id
	
	# TODO Load thumbnail
	if data.actors.is_empty():
		actor_thumbs_root.visible = false
	
	# TODO Load present characters thumbnails

func _open_scene() -> void:
	var gen := GEN.get_instance(self)
	gen.start_editing_scene(scn_id)
