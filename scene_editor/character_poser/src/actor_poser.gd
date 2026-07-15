extends Node3D

## Runtime root for an instantiated actor model.
## Owns the skeleton reference, the generated HumanRig controller tree, pose capture/apply helpers,
## and the per-character material color setup used when a CharacterData is linked into a scene.
class_name Actor3D

## Camera used by TransformHandle3D controllers so handles can calculate screen-space picking.
@export var main_cam : Camera3D
## Skeleton driven by IK, aim modifiers, rotator drivers, and captured rig keyframes.
@export var model_root : Skeleton3D
## Root node that contains generated TransformHandle3D controls for this actor instance.
@export var human_rig : Marker3D

## Cached/generated TransformHandle3D list consumed by scene-editor pose signal wiring.
## refresh_controllers() rebuilds this from human_rig whenever the rig tree is generated or changed.
var controllers : Array[TransformHandle3D]

## Runtime material assigned to mesh surfaces so one actor model can represent a specific character color.
var main_mat : StandardMaterial3D


## Initializes this actor instance for scene editing.
## camera: scene editor camera assigned to every TransformHandle3D under human_rig.
## chr: character data that provides display color and model ownership context.
## Returns: nothing; mutates controller camera references and mesh materials in-place.
func setup_from(camera:Camera3D, chr:CharacterData) -> void:
	main_cam = camera
	
	_set_camera_recussive(human_rig)
	
	main_mat = StandardMaterial3D.new()
	main_mat.albedo_color = chr.color
	_set_colored_material_recursive(model_root)


## Rebuilds the cached controller list from the current HumanRig tree.
## This is called after RuntimeRigBuilder changes the rig and before ComicSceneEditor connects
## transform_change_finished signals, ensuring every generated TransformHandle3D can save poses.
## Returns: nothing; clears controllers first and leaves it empty when human_rig is missing.
func refresh_controllers() -> void:
	controllers.clear()
	if human_rig == null:
		return
	
	_collect_controllers(human_rig)


## Captures the current TransformHandle3D pose tree into a RigKeyframe resource.
## baseline: optional RigKeyframe used to omit unchanged handles from the new capture.
## tolerance: maximum transform difference treated as unchanged when comparing to baseline.
## Returns: a RigKeyframe containing local handle transforms relative to human_rig, or an empty keyframe if human_rig is missing.
func capture_keyframe(baseline: Resource = null, tolerance := 0.0001) -> RigKeyframe:
	if human_rig == null:
		return RigKeyframe.new()
	
	return RigKeyframe.from_rig(human_rig, baseline, tolerance)

## Applies a saved rig pose back onto this actor's HumanRig controls.
## keyframe: RigKeyframe previously captured from a compatible actor rig.
## Returns: nothing; silently skips null keyframes or actors without a HumanRig.
func apply_keyframe(keyframe: RigKeyframe) -> void:
	if keyframe == null or human_rig == null:
		return
	
	keyframe.apply_to(human_rig)


## Recursive worker used by refresh_controllers().
## node: current subtree root being scanned for TransformHandle3D controls.
## Returns: nothing; appends each discovered TransformHandle3D to controllers in tree order.
func _collect_controllers(node: Node) -> void:
	if node is TransformHandle3D:
		controllers.append(node)
	
	for child in node.get_children():
		_collect_controllers(child)


## Recursively assigns main_cam to every TransformHandle3D in the generated rig tree.
## node: current subtree root being scanned; null is accepted so callers can pass optional rig roots safely.
## Returns: nothing; mutates handle camera references in-place.
func _set_camera_recussive(node:Node3D) -> void:
	if node == null:
		return
	
	if node is TransformHandle3D:
		node.camera = main_cam
	
	for child in node.get_children():
		_set_camera_recussive(child)

## Recursively assigns the character color material to mesh instances under the model skeleton.
## node: current subtree root being scanned; null is accepted so missing model roots do not crash setup.
## Returns: nothing; mutates MeshInstance3D surface override material 0 in-place.
func _set_colored_material_recursive(node:Node3D) -> void:
	if node == null:
		return
	
	if node is MeshInstance3D:
		node.set_surface_override_material(0, main_mat)
	
	for child in node.get_children():
		_set_colored_material_recursive(child)
