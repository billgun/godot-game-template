extends Node

# ============================================================
# EVENTBUS
# Global signal hub — pure signal declarations only, NO logic.
# Other autoloads/scenes emit signals here; anything can listen.
# Keep this file free of functions/state — route logic to
# GameManager or the relevant autoload instead.
# ============================================================

# --- Game state signals ---

## Emitted when a new game/run begins (e.g. player pressed "Start").
signal game_started

## Emitted when the game is paused (e.g. pause menu opened).
signal game_paused

## Emitted when the game resumes from a paused state.
signal game_resumed

## Emitted when the player has lost/the run has ended.
signal game_over

## Emitted whenever GameManager's state changes.
## [param new_state] The new state name, e.g. "PLAYING", "PAUSED".
signal game_state_changed(new_state: String)

# --- Scene signals ---

## Emit this to request a scene change without holding a direct
## reference to SceneManager. SceneManager listens for this.
## [param scene_path] The res:// path of the scene to load.
signal scene_change_requested(scene_path: String)

## Emitted by SceneManager after a scene finishes loading/swapping.
## [param scene_path] The res:// path of the scene now active.
signal scene_changed(scene_path: String)

# --- Player signals ---

## Emitted when the player node enters the tree and is ready.
## [param player] Reference to the spawned player node.
signal player_spawned(player: Node)

## Emitted when the player's health reaches zero / player dies.
signal player_died

## Emitted whenever the player's health value changes.
## [param current] Current health value.
## [param max] Maximum health value.
signal player_health_changed(current: float, max: float)

# --- Save/Load signals ---

## Emit this to request a save without holding a direct reference
## to SaveManager. SaveManager listens for this.
## [param slot] The save slot number to write to.
signal save_requested(slot: int)

## Emit this to request a load without holding a direct reference
## to SaveManager. SaveManager listens for this.
## [param slot] The save slot number to read from.
signal load_requested(slot: int)

## Emitted by SaveManager after a save finishes successfully.
## [param slot] The save slot that was written.
signal save_completed(slot: int)

## Emitted by SaveManager after a load finishes successfully.
## [param slot] The save slot that was read.
signal load_completed(slot: int)

# --- Audio signals ---

## Emit this to play a one-shot sound effect via AudioManager.
## [param sfx_name] Key into AudioManager's SFX_LIBRARY.
signal play_sfx_requested(sfx_name: String)

## Emit this to start/crossfade to a music track via AudioManager.
## [param track_name] Key into AudioManager's MUSIC_LIBRARY.
signal play_music_requested(track_name: String)

## Emit this to fade out and stop the currently playing music.
signal stop_music_requested

## Emitted when a volume value changes (e.g. from a settings menu).
## [param bus_name] Name of the audio bus affected ("Master", "Music", "SFX").
## [param value] New linear volume value (0.0–1.0).
signal volume_changed(bus_name: String, value: float)

# --- Settings signals ---

## Emitted whenever any setting is changed and applied, so UI
## elements (sliders, checkboxes) can refresh their displayed values.
signal settings_changed
