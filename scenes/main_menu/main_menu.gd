extends Control

# ============================================================
# MAIN MENU
# Entry point scene. Wires up UI buttons to GameManager/
# SceneManager/EventBus rather than handling game logic itself.
# Depends on: EventBus, GameManager, SceneManager, SaveManager (all autoloads)
# Button nodes are referenced via "Access as Unique Name" (%NodeName)
# rather than relative paths — mark each button node with this in
# the Scene tree dock (right-click → Access as Unique Name).
# ============================================================

## Path to the level select scene, loaded when "Play" is pressed.
const LEVEL_SELECT_PATH := "res://scenes/ui/level_select.tscn"

## Path to the settings menu scene, if/when you build one.
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_menu.tscn"

@onready var play_button: Button = %PlayButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


## Connects button signals and hides "Continue" if there's no save file yet.
func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	AudioManager.play_music("main_menu")

	continue_button.visible = SaveManager.has_save()

	# Ensure we're in the correct game state while on the menu.
	GameManager.change_state(GameManager.GameState.MAIN_MENU)


## Starts a fresh game: fires game_started (resets score via GameManager)
## and transitions to the first level.
func _on_play_pressed() -> void:
	EventBus.game_started.emit()
	SceneManager.change_scene(LEVEL_SELECT_PATH)


## Loads the existing save file, which itself triggers a scene change
## to whatever scene was saved (see SaveManager.load_game()).
func _on_continue_pressed() -> void:
	SaveManager.load_game()


## Opens the settings scene. Swap this out for a popup/overlay instead
## of a full scene change later if you'd prefer settings-over-menu.
func _on_settings_pressed() -> void:
	if ResourceLoader.exists(SETTINGS_SCENE_PATH):
		SceneManager.change_scene(SETTINGS_SCENE_PATH)
	else:
		push_warning("MainMenu: Settings scene not found yet at %s" % SETTINGS_SCENE_PATH)


## Quits the game. On web exports this does nothing (browsers block it),
## so you may want to hide the Quit button entirely for HTML5 builds.
func _on_quit_pressed() -> void:
	get_tree().quit()
