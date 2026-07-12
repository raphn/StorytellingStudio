extends PanelContainer
class_name CharacterEditor

@export var close_btn : Button


func _ready() -> void:
	close_btn.pressed.connect(func(): visible = false)


func open_project(proj:ProjectData) -> void:
	pass
