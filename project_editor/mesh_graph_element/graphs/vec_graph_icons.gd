extends Node

var dark_mode := false

const CURSOR_SKEW_HORIZONTAL := preload("res://project_editor/mesh_graph_element/graphs/cursor_skew_horizontal.png")
const CURSOR_SKEW_HORIZONTAL_DARK = preload("uid://dgoyjf7c16w88")

const CURSOR_SKEW_VERTICAL := preload("res://project_editor/mesh_graph_element/graphs/cursor_skew_vertical.png")
const CURSOR_SKEW_VERTICAL_DARK = preload("uid://dv6hialyow0gf")

const RESIZE_DIAGONAL_LEFT := preload("res://project_editor/mesh_graph_element/graphs/resize_diagnonal_left.png")
const RESIZE_DIAGNONAL_LEFT_DARK = preload("uid://cwsy7a8xk1cjp")

const RESIZE_DIAGONAL_RIGHT := preload("res://project_editor/mesh_graph_element/graphs/resize_diagnonal_right.png")
const RESIZE_DIAGNONAL_RIGHT_DARK = preload("uid://hf0suykdobjk")

const RESIZE_HORIZONTAL := preload("res://project_editor/mesh_graph_element/graphs/resize_horizontal.png")
const RESIZE_HORIZONTAL_DARK = preload("uid://d2t8l4u2hv4h6")

const RESIZE_VERTICAL := preload("res://project_editor/mesh_graph_element/graphs/resize_vertical.png")
const RESIZE_VERTICAL_DARK = preload("uid://d2um4x0r8yper")


func get_cursor_skew_horizontal() -> Texture2D:
	return CURSOR_SKEW_HORIZONTAL if dark_mode else CURSOR_SKEW_HORIZONTAL_DARK

func get_cursor_skew_vertical() -> Texture2D:
	return CURSOR_SKEW_VERTICAL if dark_mode else CURSOR_SKEW_VERTICAL_DARK

func get_resize_diagonal_left() -> Texture2D:
	return RESIZE_DIAGONAL_LEFT if dark_mode else RESIZE_DIAGNONAL_LEFT_DARK

func get_resize_diagonal_right() -> Texture2D:
	return RESIZE_DIAGONAL_RIGHT if dark_mode else RESIZE_DIAGNONAL_RIGHT_DARK

func get_resize_horizontal() -> Texture2D:
	return RESIZE_HORIZONTAL if dark_mode else RESIZE_HORIZONTAL_DARK

func get_resize_vertical() -> Texture2D:
	return RESIZE_VERTICAL if dark_mode else RESIZE_VERTICAL_DARK
