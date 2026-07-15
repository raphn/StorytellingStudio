# Runtime Actor Rig And Keyframe Plan

This file is the source of truth for the actor rig/keyframe system requested in the pasted spec. Keep it updated as implementation lands.

## 1. Data Model Foundation

- [x] Add `RigKeyframe` as a `Resource`.
  - Captures `TransformHandle3D` local transforms under a rig root.
  - Stores transforms by stable relative `NodePath` key.
  - Can skip unchanged handles when given a baseline keyframe.
  - Can apply saved transforms back onto a matching rig.
- [x] Add `ActorKeyFrames` as a `Resource`.
  - Owns `char_id`.
  - Owns `actor_id`.
  - Stores an ordered array of `RigKeyframe` resources.
  - Provides capture/apply helpers for a rig root.
- [x] Add `Actor3D` convenience helpers.
  - Refresh controller cache from `human_rig`.
  - Capture a `RigKeyframe`.
  - Apply a `RigKeyframe`.

## 2. Runtime Rig Builder Tool

- [x] Add `RuntimeRigBuilder` as an `@tool` `Node3D` script.
  - Finds or accepts an `Actor3D` root.
  - Finds or accepts a `Skeleton3D`.
  - Ensures `HumanRig` and controller groups exist.
  - Builds named IK handles for conventional limbs.
  - Builds generic IK handles from `IKROOT.*`, `IKMID.*`, `IKEND.*` bone naming.
  - Builds aim handles for `head` and `AIM.*` bone naming.
  - Builds rotation controller groups for `ROT_INIT.*` chains.
  - Refreshes `Actor3D.human_rig` and `Actor3D.controllers`.
- [x] Add `RuntimeRigRotator` helper.
  - Applies `ROT_CONTROL` local rotation to controlled skeleton bones.
  - Applies `AIM_CONTROL` local rotation to the rotation-root bone.

## 3. Scene Integration

- [x] Attach `RuntimeRigBuilder` to actor source scenes or provide an editor workflow for running it.
- [x] Regenerate/refresh `res://scene_editor/character_poser/models/male/_default__rigger/rigger_scene.tscn` through the builder workflow.
- [x] Confirm generated `TwoBoneIK3D` and `AimModifier3D` settings through headless scene validation.
- [x] Ensure all current actor `PackedScene`s live under `res://scene_editor/character_poser/models/`.
- [x] Ensure the current actor is cataloged in `res://runtime_assets/run_time_actors.tres` with a unique `StringName`.

## 4. Character And Scene Pose Integration

- [x] Add pose/keyframe storage to scene or framed-character data.
- [x] Connect linked characters to `ActorKeyFrames` resources.
- [x] Capture actor keyframes when pose edits are committed.
- [x] Restore the active actor pose when switching frame or opening a scene.
- [x] Handle actor model changes by preserving compatible keyframe paths and ignoring incompatible handles.

## 5. Validation

- [x] Run `godot --headless --path . --quit`.
- [x] Run temporary in-memory validation that instantiates the current rigger actor scene, captures/applies a keyframe, and invokes `RuntimeRigBuilder`.
- [x] Add lightweight headless validation scripts for resource creation and keyframe capture/apply.
- [x] Add a test scene or editor fixture for `RuntimeRigBuilder`.
- [x] Verify generated controllers on mobile and desktop input paths at script/API level.
- [x] Verify saved project data can round-trip pose resources at resource/API level.
