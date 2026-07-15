@tool
extends Node3D
## Editor/runtime generator for an Actor3D HumanRig tree.
## Reads Skeleton3D bone naming conventions, creates TransformHandle3D controls,
## configures SkeletonModifier3D nodes, and refreshes actor rig references for pose capture.
class_name RuntimeRigBuilder

## Packed scene used for every generated TransformHandle3D control.
const HANDLE_SCENE := preload("res://scene_editor/handles/transform_handle_3d.tscn")

## Render layer assigned to generated handles so rig controls can be separated from actor meshes.
const HANDLE_RENDER_LAYERS := 2
## Bitmask representing X/Y/Z all locked for TransformHandle3D axis lock fields.
const AXIS_LOCK_ALL := 7
## Default offset distance from a middle limb bone to its pole control.
const DEFAULT_POLE_DISTANCE := 0.65
## Default offset distance from an aim bone to its target control.
const DEFAULT_AIM_DISTANCE := 0.75

## Built-in human limb conventions for the default actor rig.
## Each dictionary maps skeleton bone names to generated handle names and TwoBoneIK3D node names.
const CONVENTIONAL_IKS := [
	{
		"node": "L_ARM_IK",
		"root": "arm.l",
		"mid": "forearm.l",
		"end": "hand.l",
		"group": "Arms",
		"target": "L_ARM_IK",
		"pole": "L_ARM_POLE",
		"pole_offset": Vector3.FORWARD,
	},
	{
		"node": "R_ARM_IK",
		"root": "arm.r",
		"mid": "forearm.r",
		"end": "hand.r",
		"group": "Arms",
		"target": "R_ARM_IK",
		"pole": "R_ARM_POLE",
		"pole_offset": Vector3.FORWARD,
	},
	{
		"node": "L_LEG_IK",
		"root": "leg.l",
		"mid": "shin.l",
		"end": "foot.l",
		"group": "Legs",
		"target": "L_LEG_IK",
		"pole": "L_LEG_POLE",
		"pole_offset": Vector3.BACK,
	},
	{
		"node": "R_LEG_IK",
		"root": "leg.r",
		"mid": "shin.r",
		"end": "foot.r",
		"group": "Legs",
		"target": "R_LEG_IK",
		"pole": "R_LEG_POLE",
		"pole_offset": Vector3.BACK,
	},
]

## Optional explicit Actor3D root to rebuild. If empty, the builder searches its parents.
@export var actor_root: Actor3D
## Optional explicit Skeleton3D to inspect. If empty, actor_root.model_root or first child Skeleton3D is used.
@export var skeleton: Skeleton3D
## Name of the rig controller root created under the Actor3D.
@export var human_rig_name := "HumanRig"
## Offset distance used when placing generated IK pole handles from each middle bone.
@export var pole_distance := DEFAULT_POLE_DISTANCE
## Offset distance used when placing generated aim handles from each aim bone.
@export var aim_distance := DEFAULT_AIM_DISTANCE
## Inspector button entry point. Pressing this clears generated rig children and rebuilds them.
@export_tool_button("Rebuild Rig") var rebuild_rig_button : Callable:
	get:
		return rebuild_runtime_rig
## Legacy inspector trigger kept for simple checkbox-style rebuild workflows.
## Setting it true immediately calls rebuild_runtime_rig and resets back to false.
@export var build_in_editor := false:
	set(value):
		build_in_editor = false
		if value:
			rebuild_runtime_rig()


## Clears generated HumanRig children and rebuilds the rig from current actor/skeleton state.
## Returns: nothing; prints an error and aborts if no Actor3D can be resolved.
func rebuild_runtime_rig() -> void:
	var actor := _resolve_actor()
	if actor == null:
		printerr("RuntimeRigBuilder needs an Actor3D root.")
		return
	
	var human_rig := actor.get_node_or_null(human_rig_name)
	if human_rig != null:
		for child in human_rig.get_children():
			human_rig.remove_child(child)
			child.free()
	
	actor.controllers.clear()
	build_runtime_rig()


## Builds or refreshes HumanRig groups, handles, modifiers, and actor references.
## Returns: nothing; prints an error and aborts if Actor3D or Skeleton3D cannot be resolved.
func build_runtime_rig() -> void:
	var actor := _resolve_actor()
	var target_skeleton := _resolve_skeleton(actor)
	if actor == null or target_skeleton == null:
		printerr("RuntimeRigBuilder needs an Actor3D root and a Skeleton3D.")
		return
	
	var human_rig := _ensure_marker(actor, human_rig_name)
	_ensure_marker(human_rig, "Arms")
	_ensure_marker(human_rig, "Legs")
	_ensure_marker(human_rig, "IKS")
	_ensure_marker(human_rig, "AIM")
	_ensure_marker(human_rig, "ROTATORS")
	
	for ik_data in CONVENTIONAL_IKS:
		_build_ik(target_skeleton, human_rig, ik_data)
	
	_build_named_iks(target_skeleton, human_rig)
	_build_aim(target_skeleton, "head", "HEAD_TARGET", human_rig)
	_build_named_aims(target_skeleton, human_rig)
	_build_rotator_chains(target_skeleton, human_rig)
	_refresh_actor_exports(actor, target_skeleton, human_rig)


## Resolves the Actor3D that should own the generated HumanRig.
## Returns: actor_root when set, otherwise the first Actor3D found while walking parents, or null.
func _resolve_actor() -> Actor3D:
	if actor_root != null:
		return actor_root
	var current := get_parent()
	while current != null:
		if current is Actor3D:
			return current as Actor3D
		current = current.get_parent()
	return null

## Resolves the Skeleton3D that should be inspected/configured by the builder.
## actor: resolved Actor3D used to read model_root or search child skeletons.
## Returns: explicit skeleton, actor.model_root, first Skeleton3D below actor/self, or null.
func _resolve_skeleton(actor: Actor3D) -> Skeleton3D:
	if skeleton != null:
		return skeleton
	if actor != null and actor.model_root != null:
		return actor.model_root
	if actor != null:
		return _find_first_skeleton(actor)
	return _find_first_skeleton(self)

## Recursively searches for a Skeleton3D under a node.
## node: subtree root to inspect.
## Returns: first Skeleton3D found in depth-first order, or null.
func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found:
			return found
	return null

## Builds one conventional or dictionary-described TwoBoneIK3D setup.
## target_skeleton: skeleton that owns the named root/mid/end bones and modifier node.
## human_rig: HumanRig root where handle groups are created.
## ik_data: dictionary with node/root/mid/end/group/target/pole/pole_offset entries.
## Returns: nothing; skips the setup when required bones are missing.
func _build_ik(target_skeleton: Skeleton3D, human_rig: Node3D, ik_data: Dictionary) -> void:
	var root_bone := String(ik_data["root"])
	var mid_bone := String(ik_data["mid"])
	var end_bone := String(ik_data["end"])
	if not _has_bones(target_skeleton, [root_bone, mid_bone, end_bone]):
		return
	
	var group := _ensure_marker(human_rig, String(ik_data["group"]))
	var target_handle := _ensure_handle(group, String(ik_data["target"]))
	var pole_handle := _ensure_handle(group, String(ik_data["pole"]))
	
	_place_at_bone(target_handle, target_skeleton, end_bone, Vector3.ZERO)
	_place_at_bone(pole_handle, target_skeleton, mid_bone, Vector3(ik_data["pole_offset"]) * pole_distance)
	_configure_ik_handle(target_handle)
	_configure_pole_handle(pole_handle)
	
	var ik_node := _ensure_modifier(target_skeleton, String(ik_data["node"]), "TwoBoneIK3D")
	if ik_node:
		_configure_two_bone_ik(ik_node, target_skeleton, root_bone, mid_bone, end_bone, target_handle, pole_handle)

## Builds generic IK setups from IKROOT.*, IKMID.*, and IKEND.* skeleton bone naming.
## target_skeleton: skeleton whose bones are scanned for naming-convention IK chains.
## human_rig: HumanRig root where the IKS group and generated handles live.
## Returns: nothing; only complete root->mid->end naming chains are generated.
func _build_named_iks(target_skeleton: Skeleton3D, human_rig: Node3D) -> void:
	var ik_group := _ensure_marker(human_rig, "IKS")
	for root_idx in range(target_skeleton.get_bone_count()):
		var root_name := target_skeleton.get_bone_name(root_idx)
		if not root_name.begins_with("IKROOT."):
			continue
		
		var base_name := root_name.trim_prefix("IKROOT.")
		var mid_name := _find_child_bone_with_prefix(target_skeleton, root_idx, "IKMID.")
		if mid_name == "":
			continue
		
		var mid_idx := target_skeleton.find_bone(mid_name)
		var end_name := _find_child_bone_with_prefix(target_skeleton, mid_idx, "IKEND.")
		if end_name == "":
			continue
		
		var target_handle := _ensure_handle(ik_group, "%s_IK" % base_name.to_upper())
		var pole_handle := _ensure_handle(ik_group, "%s_POLE" % base_name.to_upper())
		_place_at_bone(target_handle, target_skeleton, end_name, Vector3.ZERO)
		_place_at_bone(pole_handle, target_skeleton, mid_name, Vector3.FORWARD * pole_distance)
		_configure_ik_handle(target_handle)
		_configure_pole_handle(pole_handle)
		
		var ik_node := _ensure_modifier(target_skeleton, "%s_IK" % base_name.to_upper(), "TwoBoneIK3D")
		if ik_node:
			_configure_two_bone_ik(ik_node, target_skeleton, root_name, mid_name, end_name, target_handle, pole_handle)

## Builds one AimModifier3D handle/modifier pair for a named bone.
## target_skeleton: skeleton containing bone_name and receiving the AimModifier3D node.
## bone_name: skeleton bone to aim toward the generated target handle.
## handle_name: TransformHandle3D name created under parent.
## parent: HumanRig group that should contain the generated aim handle.
## Returns: nothing; skips setup when bone_name is not found.
func _build_aim(target_skeleton: Skeleton3D, bone_name: String, handle_name: String, parent: Node3D) -> void:
	if target_skeleton.find_bone(bone_name) < 0:
		return
	
	var handle := _ensure_handle(parent, handle_name)
	_place_at_bone(handle, target_skeleton, bone_name, Vector3.FORWARD * -aim_distance)
	_configure_aim_handle(handle)
	
	var aim_node := _ensure_modifier(target_skeleton, "%s_AIM" % bone_name.to_upper(), "AimModifier3D")
	if aim_node:
		_configure_aim_modifier(aim_node, target_skeleton, bone_name, handle)

## Builds generic aim setups from AIM.* skeleton bone naming.
## target_skeleton: skeleton whose bones are scanned for AIM.* markers.
## human_rig: HumanRig root where the AIM group and generated handles live.
## Returns: nothing; creates one target/modifier per matching AIM.* bone.
func _build_named_aims(target_skeleton: Skeleton3D, human_rig: Node3D) -> void:
	var aim_group := _ensure_marker(human_rig, "AIM")
	for bone_idx in range(target_skeleton.get_bone_count()):
		var marker_name := target_skeleton.get_bone_name(bone_idx)
		if not marker_name.begins_with("AIM."):
			continue
		
		var bone_name := marker_name.trim_prefix("AIM.")
		_build_aim(target_skeleton, marker_name, "%s_TARGET" % bone_name.to_upper(), aim_group)

## Builds rotator control groups from ROT_INIT.* skeleton bone naming.
## target_skeleton: skeleton whose bones are scanned and later driven by RuntimeRigRotator.
## human_rig: HumanRig root where ROTATORS groups are created.
## Returns: nothing; each ROT_INIT.* chain gets ROT_CONTROL, AIM_CONTROL, and a RuntimeRigRotator driver.
func _build_rotator_chains(target_skeleton: Skeleton3D, human_rig: Node3D) -> void:
	var rotators_root := _ensure_marker(human_rig, "ROTATORS")
	for bone_idx in range(target_skeleton.get_bone_count()):
		var marker_name := target_skeleton.get_bone_name(bone_idx)
		if not marker_name.begins_with("ROT_INIT."):
			continue
		
		var base_name := marker_name.trim_prefix("ROT_INIT.")
		var chain := _collect_rotation_chain(target_skeleton, bone_idx)
		var chain_root := _ensure_marker(rotators_root, base_name.to_upper())
		var rot_control := _ensure_handle(chain_root, "ROT_CONTROL")
		var aim_control := _ensure_handle(chain_root, "AIM_CONTROL")
		_place_at_bone(rot_control, target_skeleton, marker_name, Vector3.RIGHT * 0.2)
		_place_at_bone(aim_control, target_skeleton, marker_name, Vector3.FORWARD * 0.35)
		_configure_rotation_handle(rot_control)
		_configure_rotation_handle(aim_control)
		
		var driver := _ensure_rotator_driver(chain_root, "ROTATOR_DRIVER")
		driver.skeleton_path = _get_path_to_safe(driver, target_skeleton)
		driver.root_bone_name = marker_name
		driver.controlled_bone_names = chain
		driver.rot_control_path = _get_path_to_safe(driver, rot_control)
		driver.aim_control_path = _get_path_to_safe(driver, aim_control)

## Collects controlled bones below a ROT_INIT.* root.
## target_skeleton: skeleton being inspected.
## root_idx: bone index for the ROT_INIT.* chain root.
## Returns: bone names that should copy ROT_CONTROL rotation, stopping before leaves or ROT_END.*.
func _collect_rotation_chain(target_skeleton: Skeleton3D, root_idx: int) -> PackedStringArray:
	var chain := PackedStringArray()
	var current_idx := root_idx
	while true:
		var children := target_skeleton.get_bone_children(current_idx)
		if children.is_empty():
			break
		
		var child_idx := int(children[0])
		var child_name := target_skeleton.get_bone_name(child_idx)
		if child_name.begins_with("ROT_END."):
			break
		
		if target_skeleton.get_bone_children(child_idx).is_empty():
			break
		
		chain.append(child_name)
		current_idx = child_idx
	return chain

## Writes TwoBoneIK3D settings for one generated IK modifier node.
## ik_node: TwoBoneIK3D node to configure through generic set() calls.
## target_skeleton: skeleton used to resolve bone indexes from names.
## root_bone: first bone in the IK chain.
## mid_bone: middle bone in the IK chain.
## end_bone: end bone targeted by the generated IK handle.
## target_handle: TransformHandle3D used as the IK target node.
## pole_handle: TransformHandle3D used as the IK pole node.
## Returns: nothing; mutates ik_node settings.
func _configure_two_bone_ik(ik_node: Node, target_skeleton: Skeleton3D, root_bone: String, mid_bone: String, end_bone: String, target_handle: Node3D, pole_handle: Node3D) -> void:
	ik_node.set("setting_count", 1)
	ik_node.set("settings/0/root_bone_name", root_bone)
	ik_node.set("settings/0/root_bone", target_skeleton.find_bone(root_bone))
	ik_node.set("settings/0/middle_bone_name", mid_bone)
	ik_node.set("settings/0/middle_bone", target_skeleton.find_bone(mid_bone))
	ik_node.set("settings/0/end_bone_name", end_bone)
	ik_node.set("settings/0/end_bone", target_skeleton.find_bone(end_bone))
	ik_node.set("settings/0/target_node", _get_path_to_safe(ik_node, target_handle))
	ik_node.set("settings/0/pole_node", _get_path_to_safe(ik_node, pole_handle))
	ik_node.set("settings/0/use_virtual_end", false)
	ik_node.set("settings/0/extend_end_bone", false)

## Writes AimModifier3D settings for one generated aim modifier node.
## aim_node: AimModifier3D node to configure through generic set() calls.
## target_skeleton: skeleton used to resolve apply bone index from bone_name.
## bone_name: skeleton bone affected by the aim modifier.
## handle: TransformHandle3D used as the modifier target/reference node.
## Returns: nothing; mutates aim_node settings.
func _configure_aim_modifier(aim_node: Node, target_skeleton: Skeleton3D, bone_name: String, handle: Node3D) -> void:
	aim_node.set("setting_count", 1)
	aim_node.set("settings/0/amount", 1.0)
	aim_node.set("settings/0/apply_bone_name", bone_name)
	aim_node.set("settings/0/apply_bone", target_skeleton.find_bone(bone_name))
	aim_node.set("settings/0/reference_type", 1)
	aim_node.set("settings/0/reference_node", _get_path_to_safe(aim_node, handle))
	aim_node.set("settings/0/forward_axis", 4)
	aim_node.set("settings/0/use_euler", false)
	aim_node.set("settings/0/relative", true)

## Gets or creates a Marker3D child under parent.
## parent: node that should contain the marker.
## marker_name: name/path segment for the marker child.
## Returns: existing Marker3D child or a newly created one with owner assigned for scene saving.
func _ensure_marker(parent: Node, marker_name: String) -> Marker3D:
	var existing := parent.get_node_or_null(marker_name) as Marker3D
	if existing:
		return existing
	
	var marker := Marker3D.new()
	marker.name = marker_name
	parent.add_child(marker)
	_assign_owner(marker)
	return marker

## Gets or creates a TransformHandle3D child under parent.
## parent: node that should contain the handle.
## handle_name: name/path segment for the handle child.
## Returns: existing TransformHandle3D child or a newly instantiated handle scene.
func _ensure_handle(parent: Node, handle_name: String) -> TransformHandle3D:
	var existing := parent.get_node_or_null(handle_name) as TransformHandle3D
	if existing:
		return existing
	
	var handle := HANDLE_SCENE.instantiate() as TransformHandle3D
	handle.name = handle_name
	parent.add_child(handle)
	_assign_owner(handle)
	return handle


## Gets or creates a SkeletonModifier3D-like node by Godot class name.
## parent: node that should contain the modifier, usually the Skeleton3D.
## modifier_name: name/path segment for the modifier child.
## type_name: engine class name passed to ClassDB.instantiate, such as "TwoBoneIK3D".
## Returns: existing child node, newly instantiated modifier node, or null if type_name cannot be instantiated.
func _ensure_modifier(parent: Node, modifier_name: String, type_name: String) -> Node:
	var existing := parent.get_node_or_null(modifier_name)
	if existing != null:
		return existing
	
	var modifier := ClassDB.instantiate(type_name) as Node
	if modifier == null:
		printerr("Could not instantiate modifier type '%s'." % type_name)
		return null
	
	modifier.name = modifier_name
	
	parent.add_child(modifier)
	_assign_owner(modifier)
	return modifier

## Gets or creates a RuntimeRigRotator driver under a rotator group.
## parent: ROTATORS/<chain> group that should contain the driver.
## driver_name: name/path segment for the driver child.
## Returns: existing driver node or newly created RuntimeRigRotator.
func _ensure_rotator_driver(parent: Node, driver_name: String) -> Node:
	var existing := parent.get_node_or_null(driver_name)
	if existing:
		return existing
	
	var driver := RuntimeRigRotator.new()
	driver.name = driver_name
	parent.add_child(driver)
	_assign_owner(driver)
	return driver

## Places a generated handle at a skeleton bone plus local offset.
## handle: TransformHandle3D/Node3D to position.
## target_skeleton: skeleton containing bone_name.
## bone_name: skeleton bone used as the placement origin.
## local_offset: offset in skeleton space applied from the bone position.
## Returns: nothing; writes global_position when possible or local position when outside the tree.
func _place_at_bone(handle: Node3D, target_skeleton: Skeleton3D, bone_name: String, local_offset: Vector3) -> void:
	var bone_idx := target_skeleton.find_bone(bone_name)
	if bone_idx < 0:
		return
	
	var skeleton_global := _get_node_global_transform_safe(target_skeleton)
	var bone_global := skeleton_global * target_skeleton.get_bone_global_pose(bone_idx)
	var target_position := bone_global.origin + skeleton_global.basis * local_offset
	var handle_parent := handle.get_parent() as Node3D
	if handle.is_inside_tree():
		handle.global_position = target_position
	elif handle_parent:
		handle.position = _get_node_global_transform_safe(handle_parent).affine_inverse() * target_position
	else:
		handle.position = target_position

## Configures a target IK handle for translation-only control.
## handle: generated TransformHandle3D to configure.
## Returns: nothing; mutates render layer, visible operations, and axis locks.
func _configure_ik_handle(handle: TransformHandle3D) -> void:
	handle.render_layers = HANDLE_RENDER_LAYERS
	handle.show_rotate_handles = false
	handle.show_scale_handles = false
	handle.locked_rotation_axes = AXIS_LOCK_ALL
	handle.locked_scale_axes = AXIS_LOCK_ALL

## Configures an IK pole handle, reusing IK target settings with a smaller visual size.
## handle: generated TransformHandle3D to configure.
## Returns: nothing; mutates handle properties.
func _configure_pole_handle(handle: TransformHandle3D) -> void:
	_configure_ik_handle(handle)
	handle.handle_length = 0.7

## Configures an aim target handle.
## handle: generated TransformHandle3D to configure.
## Returns: nothing; leaves translation/rotation available but locks scale.
func _configure_aim_handle(handle: TransformHandle3D) -> void:
	handle.render_layers = HANDLE_RENDER_LAYERS
	handle.show_scale_handles = false
	handle.locked_scale_axes = AXIS_LOCK_ALL

## Configures a rotator handle for rotation-only control.
## handle: generated TransformHandle3D to configure.
## Returns: nothing; hides translation/scale and locks those operations.
func _configure_rotation_handle(handle: TransformHandle3D) -> void:
	handle.render_layers = HANDLE_RENDER_LAYERS
	handle.show_translate_handles = false
	handle.show_scale_handles = false
	handle.locked_position_axes = AXIS_LOCK_ALL
	handle.locked_scale_axes = AXIS_LOCK_ALL

## Verifies that every named bone exists on a skeleton.
## target_skeleton: skeleton to query.
## bone_names: array of String/StringName values to find.
## Returns: true only when every requested bone is present.
func _has_bones(target_skeleton: Skeleton3D, bone_names: Array) -> bool:
	for bone_name in bone_names:
		if target_skeleton.find_bone(String(bone_name)) < 0:
			return false
	return true

## Finds the first direct child bone whose name starts with a prefix.
## target_skeleton: skeleton to query.
## parent_idx: bone index whose direct children should be inspected.
## prefix: required String prefix, such as "IKMID." or "IKEND.".
## Returns: matching bone name, or an empty string when no direct child matches.
func _find_child_bone_with_prefix(target_skeleton: Skeleton3D, parent_idx: int, prefix: String) -> String:
	for child_idx in target_skeleton.get_bone_children(parent_idx):
		var bone_name := target_skeleton.get_bone_name(int(child_idx))
		if bone_name.begins_with(prefix):
			return bone_name
	return ""

## Reads a global transform without requiring the node to be inside the scene tree.
## node: Node3D whose world transform is needed for editor-time rig generation.
## Returns: node.global_transform when inside tree, otherwise manually composes parent transforms.
func _get_node_global_transform_safe(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	
	var xform := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		var parent_3d := parent as Node3D
		xform = parent_3d.transform * xform
		parent = parent.get_parent()
	return xform

## Builds a relative NodePath without triggering Godot errors for half-attached editor nodes.
## from_node: node that will store/use the path.
## to_node: target node the path should resolve to.
## Returns: relative NodePath, "." for identical nodes, or empty NodePath when no common ancestor exists.
func _get_path_to_safe(from_node: Node, to_node: Node) -> NodePath:
	if from_node == null or to_node == null:
		return NodePath()
	
	if from_node.is_inside_tree() and to_node.is_inside_tree():
		return from_node.get_path_to(to_node)
	
	var common_ancestor := _find_common_ancestor(from_node, to_node)
	if common_ancestor == null:
		return NodePath()
	
	var parts := PackedStringArray()
	var current := from_node
	while current != common_ancestor:
		parts.append("..")
		current = current.get_parent()
	
	var down_parts := PackedStringArray()
	current = to_node
	while current != common_ancestor:
		down_parts.insert(0, String(current.name))
		current = current.get_parent()
	
	parts.append_array(down_parts)
	if parts.is_empty():
		return NodePath(".")
	
	return NodePath("/".join(parts))

## Finds the nearest common ancestor between two nodes without requiring them to be inside the SceneTree.
## a: first node.
## b: second node.
## Returns: shared ancestor node, or null when the nodes are in disconnected trees.
func _find_common_ancestor(a: Node, b: Node) -> Node:
	var ancestors: Array[Node] = []
	var current := a
	while current != null:
		ancestors.append(current)
		current = current.get_parent()
	
	current = b
	while current != null:
		if current in ancestors:
			return current
		current = current.get_parent()
	
	return null

## Refreshes Actor3D exported references and controller cache after a build.
## actor: Actor3D that owns the generated rig.
## target_skeleton: Skeleton3D selected by the builder.
## human_rig: generated or existing HumanRig root.
## Returns: nothing; only writes exported Node references when safe in the editor tree.
func _refresh_actor_exports(actor: Actor3D, target_skeleton: Skeleton3D, human_rig: Marker3D) -> void:
	var skeleton_path := _get_path_to_safe(actor, target_skeleton)
	var human_rig_path := _get_path_to_safe(actor, human_rig)
	var can_assign_skeleton := actor.is_inside_tree() and target_skeleton.is_inside_tree()
	var can_assign_human_rig := actor.is_inside_tree() and human_rig.is_inside_tree()
	if actor.model_root != target_skeleton and can_assign_skeleton and skeleton_path != NodePath():
		actor.model_root = target_skeleton
	if actor.human_rig != human_rig and can_assign_human_rig and human_rig_path != NodePath():
		actor.human_rig = human_rig
	if actor.has_method("refresh_controllers"):
		actor.refresh_controllers()

## Assigns scene ownership to generated nodes so they can be saved into edited PackedScenes.
## node: newly created node that should belong to the current edited scene.
## Returns: nothing; leaves owner unchanged when no scene owner can be resolved.
func _assign_owner(node: Node) -> void:
	var scene_owner := owner
	if scene_owner == null and Engine.is_editor_hint() and get_tree() != null:
		scene_owner = get_tree().edited_scene_root
	if scene_owner != null:
		node.owner = scene_owner
