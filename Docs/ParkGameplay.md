# Park gameplay

Flow: Entrance → false/real Cat Vision trails → Playground → Maze → Abandoned Park → Old Crow → City.

`ParkGameplay` was added to `Scenes/Levels/Park.tscn`; it is independent from the authored environment nodes. Its Areas are deliberately designer-movable and each shape is visible in the Godot editor.

## Components

- `Scripts/Park/cat_vision_trail.gd` (`CatVisionTrail`): owner/false trail visibility driven by the existing `CatVisionManager.cat_state_changed` signal.
- `Scripts/Park/park_memory_trigger.gd` (`ParkMemoryTrigger`): one-shot, optional Cat Vision memory Area; supports audio, visual scene and Journal ID.
- `Scripts/Park/memory_sequence_controller.gd` and `memory_interactable.gd`: E-interaction sequence. Edit `sequence` on the controller and `stage_id` on each Area.
- `Scripts/Park/maze_sequence_controller.gd` and `maze_path_trigger.gd`: movable numbered navigation Areas. Change `sequence_length`, reset behaviour, and each `sequence_index` in Inspector.
- `Scripts/Park/silent_watcher.gd`: place targets via `position_targets`; it only changes target while outside the camera view.
- `Scripts/Park/purr_dog_encounter.gd`: reacts to the existing global Purr event; audio and fear-zone references are optional.
- `Scripts/Park/old_crow.gd`: automatic, adaptive dialogue. It opens the exit once finished.
- `Scripts/Park/park_exit_trigger.gd`: existing portal behaviour gated by `park_exit_opened`; target level remains an Inspector field.

## Persistence

Park flags are stored in the existing `user://memory_journal.json` as `_park_state`, preserving prior Journal entries. Flags are `owner_trail_discovered`, `playground_memory_completed`, `maze_completed`, `other_world_memory_seen`, `silent_encounter_seen`, `crow_conversation_completed`, and `park_exit_opened`; one-shot events use `triggered_event_ids`.

## Scene layout

`Gameplay/Entrance` contains the three trails and first owner memory. `Gameplay/Playground` contains the Swing → Carousel → Slide controller and Areas. `Gameplay/Maze` holds ordered Path0–Path3 plus OtherWorldMemory. `Gameplay/AbandonedArea` holds the SilentWatcher and DogEncounter. `Gameplay/Finale/OldCrow` sits at the existing Crow Oak; the existing `Portals/PortalToCity` is now gated.

## Designer setup

Move any Area or trail without code. Assign optional audio/VFX resources directly to `ParkMemoryTrigger`; add a new memory by copying an Area and supplying a unique `event_id`. Add Cat Vision markers/trails by copying `CatVisionTrail`. Add Silent positions as `Marker3D` nodes and reference them in `position_targets`. Set the City target via `PortalToCity.target_level_id`.

Current visual/audio content intentionally uses existing geometry and small glowing trail placeholders. Child shadows, animation, dog/human art, patrol AI, and bespoke memory VFX remain art/design placement work; all their script hooks accept null assets safely.

## Park rebuild notes

The current hierarchy is `Zone01_Entrance`, `Zone02_Investigation`, `Zone03_Danger`, `Zone04_CatVisionPuzzle`, `Zone05_QuietEncounter`, `Zone06_Crows`, and `Zone07_Exit`. It anchors clues to the existing entrance fork, central/maze route, Abandoned Zone, Playground, Silent spawn cover, Crow Oak and City overlook. Every E object in those zones now has an explicit `*Mesh` child: glove, cup, fabric, crushed grass, bench, tree trunk, feathers, lamp, toy/ribbon, newspaper, paw print, panic trace, crow or scarf.

`Scripts/Park/park_interactive_object.gd` is a thin reusable Area3D component; it uses the existing JournalManager E prompt/input and exposes ID/text, one-shot, Cat Vision gating/visibility, flags, Calm delta, short dialogue and optional activation in the Inspector. Collision shapes act as the editor debug visualization but are not rendered in builds.

Legacy invisible memory/path areas are disabled in Park. The old Playground sequence areas remain only as disabled compatibility nodes; the physical Cat Vision clue props are the active puzzle.

The existing glowing rectangular trail meshes need replacement with final footprint/scent VFX. QuietTrace, OtherWorldTree and OwnerMemorySpot need final shadow/silhouette VFX; the Crow placeholder and SilentWatcher need final animated art. Paper, feathers, crushed grass and scarf currently use named interaction volumes placed on final environmental landmarks.
