@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	dock = preload("res://addons/locked_view_camera/locked_view_camera_dock.gd").new()
	dock.name = "Locked Camera"
	dock.editor_interface = get_editor_interface()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()
