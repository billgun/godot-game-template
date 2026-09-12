# AGENTS.md — Project Context & Conventions

This file summarizes the project's architecture, decisions, and conventions
so an AI assistant (or any new contributor) can pick up where things left
off without re-explaining context.

## Project

A **Sokoban-style block-pushing puzzle game** in Godot 4 — chosen as a
scoped first project to build core game-dev skills (systems/state design,
save/load, UI, audio) before attempting a longer-term goal: a narrative
adventure game with puzzles, in the vein of *A Space for the Unbound*.

## Engine & Language

- Godot 4.x
- GDScript (typed, with `##` doc comments — see Documentation Convention below)

## Autoload Architecture

Six global singletons, registered under **Project Settings → Autoload** in
this exact order (each depends only on autoloads above it in the list):

| # | Autoload         | Depends on                          | Purpose |
|---|-------------------|--------------------------------------|---------|
| 1 | `EventBus`        | *(none)*                            | Global signal hub — pure signal declarations, no logic |
| 2 | `GameManager`     | EventBus                            | Tracks game state (MAIN_MENU/PLAYING/PAUSED/GAME_OVER), runtime score/level |
| 3 | `SettingsManager` | EventBus                            | Persistent audio/display settings via ConfigFile at `user://settings.cfg` |
| 4 | `SceneManager`    | EventBus, GameManager               | Centralized scene loading (instant + async w/ loading screen) |
| 5 | `SaveManager`     | EventBus, GameManager, SceneManager | Game progress persistence via JSON at `user://saves/save_slot_<N>.save` |
| 6 | `AudioManager`    | EventBus, SettingsManager            | SFX pooling (8-player round robin) + music crossfading (2-player A/B) |

Files live in `res://autoload/`. Full details and function-by-function docs
are in `res://autoload/README.md` — read that first for deep context.

**Communication pattern:** scenes/UI emit signals on `EventBus` rather than
holding direct references to other autoloads where possible. Keeps the
dependency chain shallow and reorderable.

## `res://` vs `user://`

- `res://` — project source, read-only at runtime in exported builds.
- `user://` — writable, per-user directory for save files/settings/logs.
  Browse it via **Project → Open User Data Folder** in the editor (NOT
  visible in the FileSystem dock).

SaveManager and SettingsManager both write to `user://` for this reason.

## Documentation Convention

Every script uses two comment layers:
1. **Header block** (`#` comments, top of file) — purpose, dependencies, load order.
2. **Doc comments** (`##`) above every function and public variable — shown
   as editor tooltips and in the docs panel. Format:
   ```gdscript
   ## One-line summary.
   ## [param name] What this parameter is for.
   ## [return] What gets returned, if anything.
   ```
Internal/private helpers (`_prefixed`) still get a `##` comment, kept terser.

## Node Reference Convention

Buttons/controls in scene scripts are referenced via **"Access as Unique
Name"** (`%NodeName`) rather than relative `@onready` paths. Mark nodes via
right-click → Access as Unique Name in the Scene tree dock, then reference
as `@onready var foo: Button = %Foo`.

## Audio Bus Setup

Project uses three audio buses: `Master`, `Music`, `SFX` (both routed to
Master). Bus layout saved at `res://assets/audio/default_bus_layout.tres`
and set as the project's Default Bus Layout in Project Settings → Audio →
Buses. AudioManager/SettingsManager code checks `AudioServer.get_bus_index()`
and falls back to Master gracefully if a bus is missing — but if volume
sliders stop affecting Music/SFX, check that:
1. The bus layout was actually **saved** (not just edited live in the panel)
2. Project Settings → Audio → Buses → Default Bus Layout points to the
   saved `.tres` file
3. The game was restarted after saving (buses are read at startup)

## Settings Menu Behavior

Uses an **Apply button** pattern, not live-auto-save:
- Volume sliders **preview live** via direct `AudioServer.set_bus_volume_db()`
  calls while dragging, but don't persist to disk.
- Fullscreen toggle stages a value but doesn't apply until Apply is pressed.
- `Apply` button commits staged values into `SettingsManager` and calls
  `apply_settings()` + `save_settings()`.
- `Back` button reverts any live preview back to last-persisted values via
  `SettingsManager.apply_settings()`, then navigates away — un-applied
  changes are discarded.
- SFX slider plays a preview blip (`AudioManager.play_sfx("click")`) on
  `drag_ended` since the SFX bus has no continuous sound to preview against.

## Asset Credits Tracking

`ASSET_CREDITS.md` (project root) tracks every downloaded sound/music asset:
source, license, whether attribution is required, and exact required credit
text if so. Add a row **the moment an asset is downloaded**, not later.
Sources used so far: Kenney.nl (CC0), Freesound.org (mixed licenses — check
per file).

## Scenes Built So Far

- `res://scenes/main_menu/main_menu.tscn` + `.gd` — entry point. Play/
  Continue/Settings/Quit buttons wired to GameManager/SceneManager/
  SaveManager. Continue button hidden if `SaveManager.has_save()` is false.
- `res://scenes/ui/settings_menu.tscn` + `.gd` — Apply-button pattern
  described above.

## Not Yet Built

- First puzzle level scene (`res://scenes/levels/level_01.tscn` — path
  already referenced as a constant in `main_menu.gd`, doesn't exist yet)
- Core Sokoban mechanics: grid-based movement, box-push logic, win
  condition check, level data format, undo/reset
- Level select / progression UI
- `InputManager` and `PoolManager` were discussed as *not needed yet* —
  only add if rebindable controls or high-frequency object spawning
  become requirements later

## Recommended Plugins (discussed, not yet installed)

- **Dialogic** — dialogue system, relevant once the narrative game phase starts
- **GUT (Godot Unit Test)** — unit testing framework for GDScript
- **Phantom Camera** — camera control, likely not needed for a 2D Sokoban game

## Genre Roadmap

1. **Current:** small Sokoban-style puzzle game (this project) — scoped to
   actually finish, teaches state/systems design without physics-feel headaches
2. **Future:** narrative adventure game with puzzles (À la *A Space for the
   Unbound*) — will reuse this autoload architecture, add Dialogic for
   dialogue, expand SaveManager to track story/puzzle flags
