extends Control

# ============================================================
# SETTINGS MENU
# Lets the player adjust audio/display settings, backed by
# SettingsManager. Volume sliders preview live via AudioServer as
# you drag; nothing is PERSISTED to disk until "Apply" is pressed.
# Depends on: SettingsManager, SceneManager, AudioManager (SFX preview)
# Node references use "Access as Unique Name" (%NodeName) — mark
# each control in the Scene tree dock (right-click → Access as
# Unique Name).
# ============================================================

## Scene to return to when "Back" is pressed.
const RETURN_SCENE_PATH := "res://scenes/main_menu/main_menu.tscn"

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton
@onready var apply_button: Button = %ApplyButton

# --- Staged values (not yet persisted to disk) ---
var _staged_master: float
var _staged_music: float
var _staged_sfx: float
var _staged_fullscreen: bool


## Populates controls with SettingsManager's current values, connects
## signals, and connects the SFX slider's drag_ended for a preview blip.
func _ready() -> void:
	_staged_master = SettingsManager.master_volume
	_staged_music = SettingsManager.music_volume
	_staged_sfx = SettingsManager.sfx_volume
	_staged_fullscreen = SettingsManager.fullscreen

	master_slider.value = _staged_master
	music_slider.value = _staged_music
	sfx_slider.value = _staged_sfx
	fullscreen_check.button_pressed = _staged_fullscreen

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)


## Stages master volume AND previews it live on the Master bus.
## [param value] New slider value (0.0–1.0).
func _on_master_changed(value: float) -> void:
	_staged_master = value
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value)
	)


## Stages music volume AND previews it live on the Music bus.
## [param value] New slider value (0.0–1.0).
func _on_music_changed(value: float) -> void:
	_staged_music = value
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	else:
		push_warning("SettingsMenu: 'Music' bus not found — add it in the Audio panel")


## Stages SFX volume AND previews it live on the SFX bus.
## [param value] New slider value (0.0–1.0).
func _on_sfx_changed(value: float) -> void:
	_staged_sfx = value
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	else:
		push_warning("SettingsMenu: 'SFX' bus not found — add it in the Audio panel")


## Plays a short blip sound when the player releases the SFX slider,
## so they can actually hear the volume they just set (SFX bus has
## no continuous sound like Master/Music usually do).
## [param value_changed] Unused — required by drag_ended's signature.
func _on_sfx_drag_ended(value_changed: bool) -> void:
	AudioManager.play_sfx("click")


## Stages a new fullscreen value without applying/persisting it yet.
## [param toggled_on] true if fullscreen was just enabled.
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	_staged_fullscreen = toggled_on


## Commits all staged values to SettingsManager and persists to disk.
func _on_apply_pressed() -> void:
	SettingsManager.master_volume = _staged_master
	SettingsManager.music_volume = _staged_music
	SettingsManager.sfx_volume = _staged_sfx
	SettingsManager.fullscreen = _staged_fullscreen
	SettingsManager.apply_settings()
	SettingsManager.save_settings()


## Returns to the previous menu. Reverts any live audio preview back
## to the last persisted values, since staged changes were never saved.
func _on_back_pressed() -> void:
	SettingsManager.apply_settings()
	SceneManager.change_scene(RETURN_SCENE_PATH)
