extends PanelContainer
class_name LayoutSettingsEditor

@export var measure_option : OptionButton
@export var page_w : SpinBox
@export var page_h : SpinBox

@export var apply_cancel_panel : Control
@export var accept : Button
@export var cancel : Button

var editing : PrintingSettings
var type_tracker := 0

signal printing_changed




func setup_from(sett:PrintingSettings) -> void:
	editing = sett
	type_tracker = editing.unit
	
	_refresh_from_data()


func _refresh_from_data() -> void:
	page_h.set_value_no_signal(editing.height)
	page_w.set_value_no_signal(editing.width)
	measure_option.selected = editing.unit
	
	apply_cancel_panel.visible = false

func _set_dirty() -> void:
	apply_cancel_panel.visible = true


func _accept() -> void:
	editing.unit = measure_option.selected
	editing.width = page_w.value
	editing.height = page_h.value
	
	_refresh_from_data()
	
	# notify all
	printing_changed.emit()

func _cancel() -> void:
	_refresh_from_data()


func _on_measure_option_button_item_selected(index: int) -> void:
	var changed := index != type_tracker
	type_tracker = index
	
	match index:
		0:
			page_w.suffix = '"'
			page_h.suffix = '"'
			
			if changed:
				var n_w := PrintingSettings.centimeters_to_inches(page_w.value)
				page_w.set_value_no_signal(n_w)
				var n_h := PrintingSettings.centimeters_to_inches(page_h.value)
				page_h.set_value_no_signal(n_h)
		1:
			page_w.suffix = "cm"
			page_h.suffix = "cm"
			
			if changed:
				var n_w := PrintingSettings.inches_to_centimeters(page_w.value)
				page_w.set_value_no_signal(n_w)
				var n_h := PrintingSettings.inches_to_centimeters(page_h.value)
				page_h.set_value_no_signal(n_h)
	
	_set_dirty()
