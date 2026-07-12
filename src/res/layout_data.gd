extends Resource
class_name LayoutData

## 0 = inches; 1 = centimenters
#@export var unit_type := 0
#@export var page_width := 11.0
#@export var page_height := 17.0

## Frames from left and right opened page faces;
## - Left Panel is back face and even numbered page
## - Right Panel is front face and odd numbered page
@export var frames : Array[VectorGraphData]
