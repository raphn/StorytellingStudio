@tool
extends Node
class_name RuntimeAssetManager

@export var assets : Dictionary[StringName, PackedScene]:
	get:
		return assets
	set(val):
		assets = val
		#_verify_all_assets()
#
#@export_tool_button("Check Assets") var editor__check_assets: Callable:
	#get:
		#return _verify_all_assets
#
#
#func _verify_all_assets() -> void:
	#for key in assets.keys():
		#var scene := assets.get(key) as PackedScene
		#if not scene.has_meta(&"asset_type") or not scene.get_meta(&"asset_type") is int:
			#printerr("Asset '", key, "' has no meta data 'asset_type:int'")
