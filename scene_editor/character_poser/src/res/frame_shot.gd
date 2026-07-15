extends Resource
## Serializable camera shot captured from the frame-shot generator camera.
## Stores Camera3D view/projection settings so a comic frame camera can be restored later.
class_name FrameShot

## Camera transform in the scene coordinate space.
@export var camera_transform := Transform3D.IDENTITY
## Camera3D projection mode captured from the source camera.
@export var projection := Camera3D.PROJECTION_PERSPECTIVE
## Perspective field of view in degrees.
@export var fov := 75.0
## Orthographic camera size.
@export var size := 1.0
## Frustum offset used by Camera3D.
@export var frustum_offset := Vector2.ZERO
## Near clipping distance.
@export var near := 0.05
## Far clipping distance.
@export var far := 4000.0
## Camera cull mask so frame shots render the same layers as the generator camera.
@export_flags_3d_render var cull_mask := 0xFFFFF
## Horizontal camera offset.
@export var h_offset := 0.0
## Vertical camera offset.
@export var v_offset := 0.0
## Camera3D keep-aspect mode.
@export var keep_aspect := Camera3D.KEEP_HEIGHT
## Full-resolution PNG path saved from the FrameShot SubViewport render.
@export var full_size_image_path := ""
## Smaller PNG path saved for low-cost selection/list thumbnails.
@export var thumbnail_image_path := ""


## Factory helper that captures a Camera3D into a new FrameShot resource.
## camera: Camera3D/SelfControlledCamera3D used as the source of transform and projection data.
## Returns: newly captured FrameShot resource, or an empty default FrameShot resource when camera is null.
static func from_camera(camera: Camera3D) -> Resource:
	var frame_shot: Resource = load("res://scene_editor/character_poser/src/res/frame_shot.gd").new()
	frame_shot.capture_from(camera)
	return frame_shot


## Captures transform and Camera3D projection/render settings from a camera node.
## camera: Camera3D/SelfControlledCamera3D used as the shot generator.
## Returns: nothing; leaves this resource unchanged when camera is null.
func capture_from(camera: Camera3D) -> void:
	if camera == null:
		return
	
	camera_transform = camera.global_transform if camera.is_inside_tree() else camera.transform
	projection = camera.projection
	fov = camera.fov
	size = camera.size
	frustum_offset = camera.frustum_offset
	near = camera.near
	far = camera.far
	cull_mask = camera.cull_mask
	h_offset = camera.h_offset
	v_offset = camera.v_offset
	keep_aspect = camera.keep_aspect


## Applies this saved shot back onto a camera node.
## camera: Camera3D/SelfControlledCamera3D that should receive the saved transform/projection data.
## Returns: true when camera was available and data was applied; false when camera is null.
func apply_to(camera: Camera3D) -> bool:
	if camera == null:
		return false
	
	if camera.is_inside_tree():
		camera.global_transform = camera_transform
	else:
		camera.transform = camera_transform
	camera.projection = projection
	camera.fov = fov
	camera.size = size
	camera.frustum_offset = frustum_offset
	camera.near = near
	camera.far = far
	camera.cull_mask = cull_mask
	camera.h_offset = h_offset
	camera.v_offset = v_offset
	camera.keep_aspect = keep_aspect
	
	if camera is SelfControlledCamera3D:
		camera.set("_yaw", camera.rotation.y)
		camera.set("_pitch", camera.rotation.x)
	
	return true


## Stores render output paths produced by ComicSceneEditor._capture_save_frame_shot().
## full_size_path: PNG path for the full SubViewport render.
## thumbnail_path: PNG path for the smaller listing thumbnail.
## Returns: nothing; updates this FrameShot metadata for later loading.
func set_saved_images(full_size_path: String, thumbnail_path: String) -> void:
	full_size_image_path = full_size_path
	thumbnail_image_path = thumbnail_path
