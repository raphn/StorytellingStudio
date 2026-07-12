extends HBoxContainer

enum Type { Info, Nice, Err, Warn, Sys }

var msn_background : StyleBoxFlat

const MAX_Z := RenderingServer.CANVAS_ITEM_Z_MAX

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	msn_background = StyleBoxFlat.new()
	msn_background.bg_color = Color("17222eff")
	
	_visual_setup.call_deferred()
	get_viewport().size_changed.connect(_replace_at_bottom_left)

func _visual_setup() -> void:
	top_level = true
	z_as_relative = false
	z_index = MAX_Z
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	alignment = BoxContainer.ALIGNMENT_END
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 16
	offset_bottom = -16

	move_to_front()


# ================= || API
func push(msn:String, type:=Type.Info) -> void:
	var formated_text := _format_text(msn, type)
	_create_text_control(formated_text)


# ================= || HELPERS
func _create_text_control(content:String) -> void:
	var nt := RichTextLabel.new()
	nt.text = content
	nt.set("theme_override_styles/normal", msn_background)
	
	nt.bbcode_enabled = true
	nt.selection_enabled = true
	nt.fit_content = true
	nt.scroll_active = false
	nt.autowrap_mode = TextServer.AUTOWRAP_OFF
	nt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	nt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	add_child(nt)
	move_to_front()
	
	await get_tree().process_frame
	
	var content_size := nt.get_content_width()
	var content_height := nt.get_content_height()
	
	nt.custom_minimum_size = Vector2(content_size, content_height)
	nt.size = nt.custom_minimum_size
	
	custom_minimum_size = get_combined_minimum_size()
	size = custom_minimum_size
	
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func(): remove_child(nt); nt.queue_free())
	
	_replace_at_bottom_left()

func _replace_at_bottom_left() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT, false)

	var margin := 16.0
	position = Vector2(
		margin,
		get_viewport_rect().size.y - size.y - margin
	)

func _format_text(text:String, type:Type) -> String:
	match type:
		Type.Nice:
			return Formating.colored(text,
				Color.CORNFLOWER_BLUE.to_html())
		Type.Warn:
			return Formating.colored(Formating.bold(text),
				Color.CORAL.to_html())
		Type.Err:
			return Formating.colored(Formating.bold_italic(text),
				Color.INDIAN_RED.to_html())
		Type.Sys:
			return Formating.colored(
				Formating.italic(Formating.font_resize(text, 16)),
				Color.CADET_BLUE.to_html())
	
	# Type.Info
	return text
