extends Node

var loading_panel : LoadingPanel

const LOADING_PANEL = preload("uid://bdo121553nakp")


func _ready() -> void:
	loading_panel = LOADING_PANEL.instantiate() as LoadingPanel
	add_child(loading_panel)
	
	loading_panel.animate_opening.call_deferred()


func start() -> void:
	loading_panel.start_loading()

func set_progress(value:float) -> void:
	loading_panel.set_progress(value)

func close_fade_out() -> void:
	loading_panel.close_loading_screen()
