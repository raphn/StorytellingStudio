extends Node
class_name Utils

static func ensure_folder(path:String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
