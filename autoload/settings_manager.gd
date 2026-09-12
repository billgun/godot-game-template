extends Node

# ============================================================
# SETTINGSMANAGER
# Persistent user settings (audio, display) — loaded/saved via
# ConfigFile at user://settings.cfg. Applies settings to
# AudioServer/DisplayServer directly.
# Depends on: EventBus (for settings_changed signal)
# Assumes "Music" and "SFX" audio buses exist (safely skipped
# if not yet set up in the Audio Bus Layout).
# ============================================================

## Location of the settings file. Uses user:// since this data
## must be writable at runtime (res:// is read-only when exported).
const SETTINGS_PATH := "user://settings.cfg"

## The ConfigFile instance used to read/write settings.cfg.
var config := ConfigFile.new()

# --- Defaults (used if no settings.cfg exists yet) ---

## Master bus volume, linear scale (0.0 = silent, 1.0 = full).
var master_volume: float = 1.0

## Music bus volume, linear scale (0.0 = silent, 1.0 = full).
var music_volume: float = 1.0

## SFX bus volume, linear scale (0.0 = silent, 1.0 = full).
var sfx_volume: float = 1.0

## Whether the game window is in fullscreen mode.
var fullscreen: bool = false

## Target window resolution in pixels.
var resolution: Vector2i = Vector2i(1920, 1080)


## Loads settings from disk (or creates defaults if none exist),
## then immediately applies them to the engine.
func _ready() -> void:
	load_settings()
	apply_settings()


## Reads settings.cfg from disk into the exported variables above.
## If the file doesn't exist yet, falls back to current defaults
## and writes them to disk so the file exists for next time.
func load_settings() -> void:
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		# No settings file yet — use defaults and create one
		save_settings()
		return

	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	resolution = config.get_value("display", "resolution", resolution)


## Writes the current in-memory setting values to settings.cfg on disk.
## Called automatically by each setter below — you generally don't
## need to call this manually unless batching several changes.
func save_settings() -> void:
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.save(SETTINGS_PATH)


## Applies the current in-memory setting values to the engine:
## sets AudioServer bus volumes (in dB) and DisplayServer window
## mode, then emits EventBus.settings_changed so UI can refresh.
## Safe to call even if "Music"/"SFX" buses don't exist yet.
func apply_settings() -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(master_volume)
	)
	if AudioServer.get_bus_index("Music") != -1:
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Music"),
			linear_to_db(music_volume)
		)
	if AudioServer.get_bus_index("SFX") != -1:
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("SFX"),
			linear_to_db(sfx_volume)
		)

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)

	EventBus.settings_changed.emit()


## Sets and immediately applies+persists the master volume.
## [param value] Linear volume, 0.0 (silent) to 1.0 (full).
func set_master_volume(value: float) -> void:
	master_volume = value
	apply_settings()
	save_settings()


## Sets and immediately applies+persists the music bus volume.
## [param value] Linear volume, 0.0 (silent) to 1.0 (full).
func set_music_volume(value: float) -> void:
	music_volume = value
	apply_settings()
	save_settings()


## Sets and immediately applies+persists the SFX bus volume.
## [param value] Linear volume, 0.0 (silent) to 1.0 (full).
func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	apply_settings()
	save_settings()


## Sets and immediately applies+persists fullscreen mode.
## [param value] true for fullscreen, false for windowed.
func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save_settings()
