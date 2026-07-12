@tool
extends Container
class_name ProportionalCenterContainer


## Portion of the available width assigned to children.
## At 0.6, the remaining 40% becomes 20% padding on each side.
@export_range(0.0, 1.0, 0.01) var horizontal_fill := 0.6:
	set(value):
		horizontal_fill = clampf(value, 0.0, 1.0)
		update_minimum_size()
		queue_sort()


## Portion of the available height assigned to children.
## At 0.6, the remaining 40% becomes 20% padding above and below.
@export_range(0.0, 1.0, 0.01) var vertical_fill := 0.6:
	set(value):
		vertical_fill = clampf(value, 0.0, 1.0)
		update_minimum_size()
		queue_sort()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_sort_children()

		NOTIFICATION_CHILD_ORDER_CHANGED:
			update_minimum_size()
			queue_sort()


func _sort_children() -> void:
	var content_size := Vector2(
		size.x * horizontal_fill,
		size.y * vertical_fill
	)

	var content_position := (size - content_size) * 0.5
	var content_rect := Rect2(content_position, content_size)

	for child in get_children():
		if child is Control and child.visible and not child.top_level:
			fit_child_in_rect(child, content_rect)


func _get_minimum_size() -> Vector2:
	var largest_child_minimum := Vector2.ZERO

	for child in get_children():
		if child is Control and child.visible and not child.top_level:
			largest_child_minimum = largest_child_minimum.max(
				child.get_combined_minimum_size()
			)

	var minimum := Vector2.ZERO

	if horizontal_fill > 0.0:
		minimum.x = largest_child_minimum.x / horizontal_fill

	if vertical_fill > 0.0:
		minimum.y = largest_child_minimum.y / vertical_fill

	return minimum
