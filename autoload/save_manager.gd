extends Node

# ============================================================
# SAVEMANAGER
# Handles saving/loading game progress (not user settings —
# see SettingsManager for that). Serializes a data dictionary
# to disk per save slot using JSON.
# Depends on: EventBus, GameManager (reads state to build save
# data), SceneManager (to know current scene on save/restore)
# Must be registered AFTER both in Project Settings > Autoload.
# ============================================================

## Directory where save files are stored. Uses user:// since this
## data must be writable at runtime (res:// is read-only when exported).
const SAVE_DIR := "user://saves/"

## Filename prefix for save files, before the slot number.
const SAVE_FILE_PREFIX := "save_slot_"

## File extension used for save files.
const SAVE_FILE_EXT := ".save"

## The save slot used by default when save_game()/load_game() are
## called with no explicit slot argument (e.g. for quick-save/quick-load).
var current_slot: int = 1


## Connects to EventBus so save/load can be triggered without holding
## a direct reference to SaveManager, and ensures the save directory
## exists on disk.
func _ready() -> void:
	EventBus.save_requested.connect(save_game)
	EventBus.load_requested.connect(load_game)

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Builds the full file path for a given save slot.
## [param slot] The save slot number.
## [return] The user:// path to that slot's save file.
func _get_save_path(slot: int) -> String:
	return "%s%s%d%s" % [SAVE_DIR, SAVE_FILE_PREFIX, slot, SAVE_FILE_EXT]


## Gathers current game data (from GameManager/SceneManager), writes
## it as JSON to the given slot, and emits EventBus.save_completed.
## Extend the save_data dictionary here as new systems (inventory,
## unlocked levels, etc.) need to persist their own state.
## [param slot] Slot to save into. Defaults to current_slot.
func save_game(slot: int = current_slot) -> void:
	var save_data := {
		"score": GameManager.score,
		"current_level": GameManager.current_level,
		"scene_path": SceneManager.current_scene_path,
		"timestamp": Time.get_unix_time_from_system(),
		# Add more fields here as your game grows:
		# "player_position": ...,
		# "inventory": ...,
		# "unlocked_levels": ...,
	}

	var file := FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for writing (slot %d)" % slot)
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	current_slot = slot
	EventBus.save_completed.emit(slot)


## Reads the JSON save file for the given slot, restores it into
## GameManager, and asks SceneManager to load the saved scene.
## Emits EventBus.load_completed on success. Logs a warning if the
## slot has no save file, or an error if reading/parsing fails.
## [param slot] Slot to load from. Defaults to current_slot.
func load_game(slot: int = current_slot) -> void:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: No save file found in slot %d" % slot)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading (slot %d)" % slot)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("SaveManager: Failed to parse save file (slot %d)" % slot)
		return

	var save_data: Dictionary = json.data

	GameManager.score = save_data.get("score", 0)
	GameManager.current_level = save_data.get("current_level", "")

	current_slot = slot
	EventBus.load_completed.emit(slot)

	var scene_path: String = save_data.get("scene_path", "")
	if scene_path != "":
		SceneManager.change_scene(scene_path)


## Checks whether a save file exists for the given slot, without
## reading its contents. Useful for showing/hiding a "Continue"
## button or listing populated slots in a save/load menu.
## [param slot] Slot to check. Defaults to current_slot.
## [return] true if a save file exists for that slot.
func has_save(slot: int = current_slot) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


## Deletes the save file for the given slot, if one exists.
## [param slot] Slot to delete. Defaults to current_slot.
func delete_save(slot: int = current_slot) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_get_save_path(slot))
