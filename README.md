# Comics-I did

Comics-I did is a Godot 4 project for an Android-tablet-first comic staging app. The app is being built around a practical workflow: create a comic project, stage simple 3D characters and objects, capture camera-based comic frames, and arrange those frames into printable page layouts.

This repository is published so people can inspect the implementation, learn from the architecture, and understand how the app is being built. It is not an open-source project and it is not a grant of commercial reuse rights. See [LICENSE](LICENSE) for the exact terms.

## Project Goals

- Provide a touch-friendly comic creation workspace for Android tablets.
- Keep the authoring flow visual: scenes, actors, camera shots, frames, and pages should be manipulated directly.
- Store comic project data as Godot resources so projects can be saved, reopened, and evolved across data model versions.
- Support reusable runtime actors, pose data, and camera/frame data instead of treating each panel as a flat drawing.
- Keep the code available for inspection and learning while preserving the owner's right to commercialize the app and its features.

## Current Status

Implemented areas include:

- App shell with loading screen, home screen, project creation, and recent project picking.
- Project resource model for metadata, characters, scenes, page layouts, print settings, and saved project state.
- Workspace/editor screens for project navigation, scenes, pages, frame placement, and print settings.
- Scene editor pieces for character management, actor thumbnails, camera controls, minimap-style feedback, and scene picking.
- Runtime actor catalog under `runtime_assets`.
- Character poser foundations, including runtime rig building, transform handles, keyframe capture/apply resources, camera shot storage, and frame character data.
- Vector graph/page layout tooling used by the project editor for draggable, resizable, editable page elements.
- A lightweight headless validation script for runtime rig/keyframe behavior.

The project is still in active development. Some systems are prototypes or evolving editor workflows, and some filenames still preserve earlier spelling or naming decisions.

## Repository Layout

- `project.godot` - Godot project configuration.
- `home_screen/` - Home screen scenes, scripts, and UI resources.
- `loading_screen/` - Loading panel and loading screen behavior.
- `project_editor/` - Page layout, graph editing, print settings, and project workspace code.
- `scene_editor/` - Scene editing, character editing, actor posing, runtime rigs, and scene resources.
- `runtime_assets/` - Runtime asset manager and actor catalog resources.
- `src/` - Shared utilities, feedback helpers, project resources, and common controls.
- `theme/` - Shared styleboxes and theme resources.
- `addons/` - Godot editor plugin code used by this project.
- `third_party/` - Third-party assets used during development.

## Requirements

- Godot 4.7 or a compatible Godot 4.x build for this project state.
- Android export support if you are testing tablet builds.
- Blender/Krita only if you intend to edit the original model or texture source files that are included in the repository.

## Opening The Project

1. Open Godot.
2. Import or open this repository folder as a Godot project.
3. Launch the configured main scene from `project.godot`.

For a quick headless project load check:

```powershell
godot --headless --path . --quit
```

For the runtime rig validation script:

```powershell
godot --headless --path . --script res://scene_editor/character_poser/src/tests/runtime_rig_validation.gd
```

## Development Notes

- The app currently targets mobile-style portrait layouts and touch input, while still allowing desktop/editor testing.
- Project data is stored through Godot `Resource` classes such as `ProjectData`, `ProjectMetaData`, `SceneData`, `SceneFrame`, `RigKeyframe`, and `ActorKeyFrames`.
- Runtime actors are registered through `runtime_assets/run_time_actors.tres`.
- Pose editing is built around generated `HumanRig` controls and stable relative handle paths so compatible poses can survive actor/model changes.
- Page layout editing uses graph/vector element data to store frame placement and shape information.

## AI Assistance Disclosure

All product systems, feature direction, and creative intent were conceptualized and directed by the project owner.

During development, AI coding tools were used as an implementation assistant for some early or base versions of a few classes, documentation drafts, and review/debugging support. Those outputs were not treated as finished work: they were inspected, integrated, edited, and altered by the project owner as part of the normal development process.

The project owner remains responsible for the code that is kept in this repository. AI assistance does not imply that any AI tool, model provider, or generated output owns this project or its product direction.

## Licensing

This repository is source-available for inspection, learning, private study, and non-commercial evaluation only. Commercial use, redistribution, sublicensing, public hosting of copies, and production use are reserved unless a separate written agreement says otherwise.

Important boundaries:

- The license for this repository's original code is in [LICENSE](LICENSE).
- Third-party assets and plugins remain under their own terms and are not relicensed by this repository.
- The presence of source code in a public or shared repository does not mean the app is open source.
- Do not use the project name, app identity, icons, branding, or original commercial features in another product without written permission.

If you want to use this code beyond the permissions in the license, contact the project owner for a separate commercial or contribution agreement.

## Third-Party Material

This project contains third-party assets under `third_party/` and an editor plugin under `addons/`. Review the original source and license terms for those materials before reusing them outside this project.

## Contributions

This repository is currently published primarily for transparency and learning. It is not accepting external contributions by default.

If contributions are accepted later, contributors should expect to provide a clear authorship statement and agree that their contribution can be used in the commercial app.
