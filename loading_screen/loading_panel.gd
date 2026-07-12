extends PanelContainer
class_name LoadingPanel

@export var colors : Gradient
@export var s_box : StyleBoxFlat
@export var bar : HSlider

signal previus_animation_done


func animate_opening() -> void:
	visible = true
	bar.value = 0.0
	
	var load_tween := create_tween()
	load_tween.tween_property(bar, "value", 1.0, 0.25).set_ease(Tween.EASE_IN)
	
	await load_tween.finished
	close_loading_screen()


func start_loading() -> void:
	visible = true
	bar.value = 0.0
	modulate.a = 1.0

func set_progress(value:float) -> void:
	bar.value = value

func close_loading_screen() -> void:
	var close_tween := create_tween()
	close_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	close_tween.finished.connect(func(): visible = false; previus_animation_done.emit())
