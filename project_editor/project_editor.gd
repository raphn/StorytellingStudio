#extends PanelContainer
extends Control
class_name ProjectEditor

enum PageType { FrontCover, First, Middle, Last, BackCover, NONE }

@export var notif_bar	: RichTextLabel
@export var home_btn	: Button
@export var recenter_btn: Button
@export var save_timer	: Timer

@export_category("Scenes foldable")
@export var no_scene_sigh	: Label
@export var scenes_scroll	: ScrollContainer
@export var scenes_root		: HBoxContainer
@export var add_scene_btn 	: Button

@export_category("Pages & Visualization")
@export var graph : DrawTable

@export_category("Page Panels")
@export var left_page : PagePanel
@export var right_page : PagePanel
@export var left_page_container : GraphElement
@export var right_page_container : GraphElement

@export_category("Buttons")
@export var flip_back_btn : Button
@export var flip_forward_btn : Button
@export var add_forward_btn : Button

var gen : GEN
var editing : ProjectData

var _r_flip_container : GraphElement
var _l_flip_container : GraphElement
var _add_page_container : GraphElement
var _page_type : PageType = PageType.NONE

## The page ID of the left PagePanel
var opened_page_number := -9
var opened_page_layout : LayoutData

const SCENE_PICKER_CONTAINER = preload("uid://b21gwhrp7l2so")

signal finished_opening_project


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gen = GEN.get_instance(self)
	
	_r_flip_container = flip_forward_btn.get_parent()
	_l_flip_container = flip_back_btn.get_parent()
	_add_page_container = add_forward_btn.get_parent()
	
	_connect_event_listeners()

func _connect_event_listeners() -> void:
	
	add_scene_btn.pressed.connect(gen.start_editing_new_scene)
	
	home_btn.pressed.connect(gen.exit_project_edition)
	save_timer.timeout.connect(_save_project)
	
	flip_forward_btn.pressed.connect(_flip_forward)
	flip_back_btn.pressed.connect(_flip_back)
	add_forward_btn.pressed.connect(_add_new_page)
	
	recenter_btn.pressed.connect(graph.recenter)


# =========================== || EDITING .............. || =================== #

## Start editing a project
func open(proj:ProjectData) -> void:
	
	# Get reference and verify current loading data
	editing = proj
	editing.check_update_data_model()
	# TODO DEBUG FEEDBACK
	
	
	# Load all available scenes
	var has_scenes := editing.scenes and not editing.scenes.is_empty()
	no_scene_sigh.visible = !has_scenes
	scenes_scroll.visible = has_scenes
	
	for id in editing.scenes.keys():
		print_debug("Adding picker for scene ID '" + str(id) + "'")
		_create_scene_picker(editing.scenes.get(id), id)
	
	
	# Resize the page to the correct metrics
	_configure_grid_to_unit()
	# TODO DEBUG FEEDBACK
	
	# Load the last editing page
	if editing.page_number_opened_on_the_left == -9 or editing.page_layouts.is_empty():
		editing.page_number_opened_on_the_left = 0
		editing.page_layouts.set(1, LayoutData.new())
	# TODO DEBUG FEEDBACK
	
	# Open last opened page
	_open_at_page(editing.page_number_opened_on_the_left)
	_set_notification_bar(true)
	
	# TODO DEBUG FEEDBACK
	graph.apply_zoom(editing.editing_zoom)
	graph.scroll_offset = editing.editing_scroll
	finished_opening_project.emit()

func _create_scene_picker(scene:SceneData, scene_id:int) -> void:
	var s_pick := SCENE_PICKER_CONTAINER.instantiate() as ScenePicker
	scenes_root.add_child(s_pick)
	s_pick.setup_from(scene, scene_id)

func set_dirty() -> void:
	save_timer.stop()
	save_timer.start()
	
	_set_notification_bar(false)


# =========================== || HELPERS

func _open_at_page(page_number:int) -> void:
	print_debug("Opening page '%d'..." % page_number)
	
	if opened_page_number != -9:
		_save_frames_to_current_page(true)
	
	opened_page_number = page_number
	_add_page_container.visible = false
	
	# Front Cover
	if opened_page_number == -1:
		# L
		left_page_container.visible = false
		_l_flip_container.visible = false
		# R
		right_page_container.visible = true
		right_page.page_number = "Front Cover"
		# Page flipper
		_r_flip_container.visible = true
		flip_forward_btn.text = "Flip"
		
		opened_page_layout = editing.front_cover
		_page_type = PageType.FrontCover
	
	# Back Cover
	elif opened_page_number == -2:
		# L
		left_page_container.visible = true
		left_page.page_number = "Back Cover"
		# Page flipper
		_l_flip_container.visible = true
		flip_back_btn.text = "Flip"
		# R
		right_page_container.visible = false
		_r_flip_container.visible = false
		
		opened_page_layout = editing.back_cover
		_page_type = PageType.BackCover
	
	# Firt Page
	elif opened_page_number == 0:
		# L
		left_page_container.visible = true
		left_page.page_number = "Cover"
		# Page flipper
		_l_flip_container.visible = true
		flip_back_btn.text = "Flip"
		# R
		right_page_container.visible = true
		right_page.page_number = "1"
		# Page flipper
		_r_flip_container.visible = true
		flip_forward_btn.text = "Flip"
		
		opened_page_layout = editing.page_layouts.get(opened_page_number)
		_page_type = PageType.First
	
	# Last page
	elif editing.is_last_page(opened_page_number):
		# L
		left_page_container.visible = true
		left_page.page_number = str(opened_page_number)
		# Page flipper
		_l_flip_container.visible = true
		flip_back_btn.text = "Flip"
		# R
		right_page_container.visible = true
		right_page.page_number = "Cover"
		# Page flipper
		_r_flip_container.visible = true
		flip_forward_btn.text = "Flip"
		# Page adder
		_add_page_container.visible = true
		
		opened_page_layout = editing.page_layouts.get(opened_page_number)
		_page_type = PageType.Last
	
	else:
		# L
		left_page_container.visible = true
		left_page.page_number = str(opened_page_number)
		# Page flipper
		_l_flip_container.visible = true
		flip_back_btn.text = "Flip"
		# R
		right_page_container.visible = true
		left_page.page_number = str(opened_page_number + 1)
		# Page flipper
		_r_flip_container.visible = true
		flip_forward_btn.text = "Flip"
		
		opened_page_layout = editing.page_layouts.get(opened_page_number)
		_page_type = PageType.Middle
	
	print_debug(".. opening page type: ", PageType.keys()[_page_type])
	
	if not opened_page_layout:
		printerr("Page layout for page '%d' not found!" % opened_page_number)
		return
	
	for frame in opened_page_layout.frames:
		VectorGraphElementRuntime.create_from(frame, graph, self)
	
	set_dirty()


func _flip_forward() -> void:
	_open_at_page(editing.get_next_page(opened_page_number))

func _flip_back() -> void:
	_open_at_page(editing.get_previus_page(opened_page_number))

func _add_new_page() -> void:
	_open_at_page(editing.add_new_page())


func _save_frames_to_current_page(and_remove:bool) -> void:
	
	var current_frames : Array[VectorGraphData] = []
	for child in graph.get_children():
		if child is VectorGraphElementRuntime:
			current_frames.append(child.get_data())
			
			if and_remove:
				graph.remove_child(child)
				child.queue_free()
				print("removed")
	
	if _page_type == PageType.FrontCover:
		editing.front_cover.frames = current_frames
	elif _page_type == PageType.BackCover:
		editing.back_cover.frames = current_frames
	else:
		editing.page_layouts.get(opened_page_number).frames = current_frames
	
	Feedback.push("Saved %d frames to page %d" % [current_frames.size(), opened_page_number])


## Refresh the page size
func _configure_grid_to_unit() -> void:
	if not editing.print_settings:
		editing.print_settings = PrintingSettings.new()
		editing.save()
	
	if editing.print_settings.unit == 0:
		graph.snapping_distance = int(PrintingSettings.centimeters_to_inches(10.0))
	else:
		graph.snapping_distance = 10
	
	var page_size := Vector2(editing.print_settings.width, editing.print_settings.height) * 50.0
	
	right_page_container.size = page_size
	left_page_container.size = page_size
	left_page_container.position_offset = Vector2(-page_size.x, 0.0)
	
	var forwart_btn_x := page_size.x + 32.0
	var height := page_size.y - 128.0
	
	_add_page_container.position_offset = Vector2(forwart_btn_x, height - 160.0)
	_r_flip_container.position_offset = Vector2(forwart_btn_x, height)
	_l_flip_container.position_offset = Vector2(-forwart_btn_x - 128, height)

func _save_project() -> void:
	if not editing:
		return
	
	# Gather frames and save to pages
	_save_frames_to_current_page(false)
	
	editing.editing_zoom = graph.zoom
	editing.editing_scroll = graph.scroll_offset
	
	editing.save()
	_set_notification_bar(true)
	Feedback.push("Project '%s' saved!" % editing.display_name)

func _set_notification_bar(proj_saved:bool) -> void:
	var notif := "Scene opened: "
	if proj_saved:
		notif += Formating.with_color(
			editing.display_name,
			Color.CADET_BLUE)
	else:
		notif += Formating.with_color(
			editing.display_name,
			Color.CHOCOLATE)
	notif_bar.text = notif
