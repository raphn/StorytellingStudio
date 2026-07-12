extends FoldableContainer
class_name MobileDebug

@export var label : Label
@export var copy_btn : Button


func _ready() -> void:
	copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(label.text))

func push(msn:String) -> void:
	label.text += msn + "\n"
	label.lines_skipped = maxi(0, label.get_line_count() - 30)
