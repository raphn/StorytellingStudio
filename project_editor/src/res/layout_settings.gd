extends Resource
class_name PrintingSettings

@export var unit	: int = 0
@export var width	: float = 11.0
@export var height	: float = 17.0

const INCH_TO_CM: float = 2.54


static func inches_to_centimeters(inches: float) -> float:
	return inches * INCH_TO_CM

static func centimeters_to_inches(centimeters: float) -> float:
	return centimeters / INCH_TO_CM
