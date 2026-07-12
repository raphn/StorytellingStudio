extends GraphElement
class_name FloatingToolbar

@export var undo_btn : Button
@export var redo_btn : Button
@export var reset_btn : Button
@export var copy_btn : Button
@export var accept_btn : Button
@export var delete_btn : Button

signal undo_request
signal redo_request
signal reset_request
signal copy_requesy
signal accept_request
signal del_frame_request


func _ready() -> void:
	undo_btn.pressed.connect(func(): undo_request.emit())
	redo_btn.pressed.connect(func(): redo_request.emit())
	reset_btn.pressed.connect(func(): reset_request.emit())
	copy_btn.pressed.connect(func(): copy_requesy.emit())
	accept_btn.pressed.connect(func(): accept_request.emit())
	delete_btn.pressed.connect(func(): del_frame_request.emit())
