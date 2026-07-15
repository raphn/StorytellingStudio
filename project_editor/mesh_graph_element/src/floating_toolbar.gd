@tool
extends GraphElement
class_name FloatingToolbar

@export var undo_btn		: Button
@export var redo_btn		: Button
@export var reset_btn		: Button
@export var copy_btn		: Button
@export var accept_btn		: Button
@export var delete_btn		: Button
@export var frame_picker	: Button

@export_category("Buttons Visual")
@export var btn_size : int = 48
@export_tool_button("Apply size") var editor__resize: Callable:
	get:
		return _resize_buttons

signal undo_request
signal redo_request
signal reset_request
signal copy_requesy
signal accept_request
signal del_frame_request
signal display_frame_picker


func _resize_buttons() -> void:
	_refresh_size(self)

func _refresh_size(node:Control) -> void:
	for child in node.get_children():
		_refresh_size(child)
	
	if node is Button:
		node.custom_minimum_size = Vector2(btn_size, btn_size)
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		node.reset_size()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	modulate.a = 0.75
	
	undo_btn.pressed.connect(func(): undo_request.emit())
	redo_btn.pressed.connect(func(): redo_request.emit())
	reset_btn.pressed.connect(func(): reset_request.emit())
	copy_btn.pressed.connect(func(): copy_requesy.emit())
	accept_btn.pressed.connect(func(): accept_request.emit())
	delete_btn.pressed.connect(func(): del_frame_request.emit())
	frame_picker.pressed.connect(func(): display_frame_picker.emit())


func _on_mouse_entered() -> void:
	modulate.a = 1.0

func _on_mouse_exited() -> void:
	modulate.a = 0.75
