# Autoload Architecture

This folder contains the game's global singletons ("autoloads"), registered
under **Project Settings → Autoload**. Together they form the backbone the
rest of the game is built on — scenes should talk to these rather than to
each other directly wherever possible.

## Load Order (IMPORTANT)

Autoloads initialize top-to-bottom in the order they appear in
**Project Settings → Autoload**. An autoload can only safely reference
another autoload that has *already* loaded — so the list must be kept in
this exact order:

| # | Autoload         | Depends on                        |
|---|-------------------|------------------------------------|
| 1 | `EventBus`        | *(none)*                          |
| 2 | `GameManager`     | EventBus                          |
| 3 | `SettingsManager` | EventBus                          |
| 4 | `SceneManager`    | EventBus, GameManager             |
| 5 | `SaveManager`     | EventBus, GameManager, SceneManager |
| 6 | `AudioManager`    | EventBus, SettingsManager          |

If you ever add a new autoload, figure out its dependencies first, then
insert it in the correct position in this list (both here and in the
Project Settings autoload list itself).

## Files

### `event_bus.gd` → `EventBus`
Global signal hub. **Pure signal declarations only — no logic, no state.**
Every other system emits and/or listens to signals here instead of holding
direct references to each other. This is what keeps scenes and autoloads
decoupled — a UI button doesn't need to know GameManager exists, it just
emits `EventBus.game_started`.

If you catch yourself writing an `if` statement or a variable in this file,
that logic belongs somewhere else (usually GameManager).

Signal groups: game state, scene transitions, player events, save/load,
audio requests, settings changes.

### `game_manager.gd` → `GameManager`
The "brain." Tracks `current_state` (`MAIN_MENU`, `PLAYING`, `PAUSED`,
`GAME_OVER`) via the `GameState` enum, and reacts to EventBus signals to
drive transitions between them (e.g. `player_died` → `GAME_OVER`).

Also holds **runtime-only** session data like `score` and `current_level`.
This is *not* the same as persisted save data — anything that needs to
survive a restart belongs in SaveManager, not here.

Key methods: `change_state()`, `is_playing()`, `add_score()`.

### `settings_manager.gd` → `SettingsManager`
Persistent **user preferences**: master/music/SFX volume, fullscreen,
resolution. Backed by a `ConfigFile` at `user://settings.cfg` (NOT
`res://` — see note below). Applies values directly to `AudioServer` and
`DisplayServer`, and fires `EventBus.settings_changed` so UI can refresh.

Assumes `Music` and `SFX` audio buses exist in the Audio Bus Layout —
falls back gracefully to `Master` if they don't (yet).

Key methods: `set_master_volume()`, `set_music_volume()`, `set_sfx_volume()`,
`set_fullscreen()`.

### `scene_manager.gd` → `SceneManager`
Centralizes scene loading so `get_tree().change_scene_to_file()` isn't
scattered across the codebase. Two modes:

- `change_scene(path)` — instant swap, deferred for safety. Use this for
  most transitions (menus, small scenes).
- `change_scene_async(path)` — threaded load with an optional loading
  screen (`scenes/ui/loading_screen.tscn`, not required to exist). Use for
  heavier scenes/levels.

Also exposes `reload_current_scene()` and tracks `current_scene_path`,
which SaveManager reads/writes on save/load.

### `save_manager.gd` → `SaveManager`
Handles **game progress** persistence — separate from SettingsManager,
which is user prefs, not save data. Serializes a data dictionary to JSON
at `user://saves/save_slot_<N>.save`.

Currently saves: `score`, `current_level`, `scene_path`, `timestamp`.
**Extend the dictionary in `save_game()`/`load_game()`** as you add systems
(inventory, unlocked levels, player position, etc.) — keep all save data
flowing through this one file rather than letting other systems write
their own save files.

Key methods: `save_game(slot)`, `load_game(slot)`, `has_save(slot)`,
`delete_save(slot)`. All default to `current_slot` so they can be called
with no arguments for quick-save/quick-load.

### `audio_manager.gd` → `AudioManager`
Plays SFX/music without needing an `AudioStreamPlayer` in every scene.

- SFX: a pool of 8 `AudioStreamPlayer`s cycled round-robin, so overlapping
  sounds don't cut each other off.
- Music: two players (A/B) crossfaded via `Tween` when switching tracks,
  so track changes aren't a hard cut.

Volume itself is controlled at the **bus level** by SettingsManager —
AudioManager just plays streams onto the correct bus, it doesn't manage
volume math.

**`SFX_LIBRARY` and `MUSIC_LIBRARY` are empty by default** — add entries
as you bring in real audio files:
```gdscript
const SFX_LIBRARY := {
    "click": preload("res://audio/sfx/click.ogg"),
}
```
Calling code should always go through names (`"click"`), never raw paths,
so all sound references live in one place.

## `res://` vs `user://`

- `res://` = project source files, bundled with the exported game.
  **Read-only at runtime** in an exported build.
- `user://` = writable, per-user directory outside the project. Used for
  anything generated/changed at runtime: save files, settings, logs.

SaveManager and SettingsManager both write to `user://` for this reason.
Writing to `res://` at runtime works in the editor (misleadingly) but
**fails in an exported build**.

To browse `user://` during development: **Project → Open User Data Folder**
in the Godot editor menu (the FileSystem dock only shows `res://`, so this
menu option is the easiest way in).

## Communication Pattern

Prefer this flow to avoid tangled dependencies:
- Scene/UI → emits signal on EventBus
- EventBus → notifies listening autoloads (GameManager, AudioManager, etc.)
- Autoload → reacts, updates its own state, possibly emits a follow-up signal

Avoid autoloads reaching deep into each other's internals directly when a
signal would do — it keeps the dependency chain (the table above) shallow
and makes it easier to reorder or swap out a system later without breaking
five other files.

## Adding a New Autoload

1. Decide its dependencies (what does it need to read/call on `_ready()`?).
2. Add its signals to `EventBus` if other systems need to react to it.
3. Write the script with the same header-comment format used here.
4. Register it in **Project Settings → Autoload**, positioned after all
   its dependencies.
5. Update the table and file list in this README.

## Documentation Convention

Every script uses two layers of comments, kept consistent across all
autoloads:

1. **Header block** (top of file) — a `#` comment block explaining the
   file's purpose, what it depends on, and where it must sit in the
   autoload load order. This is for humans skimming the file list.

2. **Doc comments** (`##`) — placed directly above every function and
   exported/public variable. These aren't just visual — Godot reads `##`
   comments and shows them as **tooltips when hovering the symbol** in the
   script editor, and picks them up in the built-in docs panel.

   Format used throughout:
```gdscript
   ## One-line summary of what this does.
   ## Second line for extra detail if needed.
   ## [param name] What this parameter is for.
   ## [return] What gets returned, if anything.
   func my_function(name: String) -> bool:
```

   Internal/private helpers (prefixed with `_`) still get a `##` comment,
   but can be a bit terser since they're implementation details, not
   part of the public API other scripts call.

**When adding a new autoload or function, follow this same format** —
header block once at the top of the file, `##` doc comment above every
function and public variable. Keeping this consistent means anyone
(including future-you) can hover a symbol in the editor and immediately
understand it, without needing to dig through the implementation.
