extends Button

@export var feedback : TextureRect


func _ready() -> void:
	Input.action_release("draw")
	toggled.connect(_just_toggled)

func _just_toggled(on:bool) -> void:
	if on:
		Input.action_press("draw")
	else:
		Input.action_release("draw")
	feedback.visible = on
