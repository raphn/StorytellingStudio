extends PanelContainer
class_name PickableFrame

@export var frame_thumbnail		: TextureRect
@export var is_in_use_feedback	: TextureRect


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			prints("Picked MOUSE", self)
	elif event is InputEventScreenTouch:
		if event.pressed:
			prints("Picked TOUCH", self)
