extends PanelContainer
class_name PickableFrame

@export var frame_thumbnail		: TextureRect
@export var is_in_use_feedback	: TextureRect

var frame_path := ""
var thumbnail_path := ""

signal picked(frame: PickableFrame)

func setup_from(frame_path:String) -> void:
	thumbnail_path = frame_path
	self.frame_path = _get_full_size_path(frame_path)
	
	if is_in_use_feedback:
		is_in_use_feedback.visible = false
	
	if frame_thumbnail:
		frame_thumbnail.texture = _load_texture(frame_path)

func set_in_use(is_in_use: bool) -> void:
	if is_in_use_feedback:
		is_in_use_feedback.visible = is_in_use

func is_null_option() -> bool:
	return thumbnail_path == "res://graphs/empty.png"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			picked.emit(self)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			picked.emit(self)
			accept_event()

func _get_full_size_path(path: String) -> String:
	if path == "res://graphs/empty.png":
		return ""
	if path.ends_with("_thumb.png"):
		return path.trim_suffix("_thumb.png") + ".png"
	return path

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	
	if path.begins_with("res://"):
		return load(path) as Texture2D
	
	if not FileAccess.file_exists(path):
		return null
	
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		printerr("Could not load frame thumbnail '%s': %s" % [path, error_string(err)])
		return null
	
	return ImageTexture.create_from_image(image)
