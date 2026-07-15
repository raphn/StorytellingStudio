extends VSlider

@export var action_name := "action"


func _ready() -> void:
	drag_ended.connect(_ended)
	value_changed.connect(_value_changed)

func _ended(_end:bool) -> void:
	value = 0.0

func _value_changed(new_value: float) -> void:
	var up_action := StringName(action_name + "_up")
	var down_action := StringName(action_name + "_down")
	
	if new_value > 0.0:
		Input.action_press(up_action, new_value)
		Input.action_release(down_action)
	elif new_value < 0.0:
		Input.action_press(down_action, absf(new_value))
		Input.action_release(up_action)
	else:
		Input.action_release(up_action)
		Input.action_release(down_action)
