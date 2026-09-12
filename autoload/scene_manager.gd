extends Node

# ============================================================
# SCENEMANAGER
# Centralizes scene loading/transitions instead of scattering
# get_tree().change_scene_to_file() calls across the codebase.
# Supports simple instant swaps and async loading (for bigger
# scenes where you want a loading screen).
# Depends on: EventBus, GameManager
# Must be registered AFTER both in Project Settings > Autoload.
# ============================================================

## The res:// path of the currently active scene.
var current_scene_path: String = ""

## True while an async scene load is in progress. Used to guard
## against overlapping/duplicate scene change requests.
var is_loading: bool = false

## Path to an optional loading screen scene shown during
## change_scene_async(). If this file doesn't exist, async loads
## simply skip showing a loading screen (no error).
const LOADING_SCREEN_PATH := "res://scenes/ui/loading_screen.tscn"

## Instance of the loading screen, if currently shown. Null otherwise.
var _loading_screen: Node = null

## Internal: the scene path currently being loaded async, tracked
## so _process() knows what to poll ResourceLoader for.
var _pending_scene_path: String = ""


## Connects to EventBus so scenes can request a scene change without
## holding a direct reference to SceneManager, and records the
## initial scene as the current one.
func _ready() -> void:
	EventBus.scene_change_requested.connect(change_scene)
	current_scene_path = get_tree().current_scene.scene_file_path


## Instantly swaps to a new scene. This is the default choice for
## most transitions (menus, small scenes). Deferred internally so
## it's safe to call from mid-frame contexts like signal callbacks.
## [param scene_path] The res:// path of the scene to load.
func change_scene(scene_path: String) -> void:
	if is_loading:
		return

	call_deferred("_deferred_change_scene", scene_path)


## Internal implementation of change_scene(), called deferred so the
## scene swap happens at a safe point in the frame (not mid-physics-step
## or mid-signal-emission).
## [param scene_path] The res:// path of the scene to load.
func _deferred_change_scene(scene_path: String) -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneManager: Failed to change scene to %s (error %s)" % [scene_path, err])
		return

	current_scene_path = scene_path
	EventBus.scene_changed.emit(scene_path)


## Loads a scene asynchronously (threaded) and shows a loading screen
## while it loads, if one is configured. Use this for heavier scenes
## (big levels) where an instant swap would cause a noticeable hitch.
## [param scene_path] The res:// path of the scene to load.
func change_scene_async(scene_path: String) -> void:
	if is_loading:
		return
	is_loading = true

	if ResourceLoader.exists(LOADING_SCREEN_PATH):
		_loading_screen = load(LOADING_SCREEN_PATH).instantiate()
		get_tree().root.add_child(_loading_screen)

	ResourceLoader.load_threaded_request(scene_path)
	set_process(true)
	_pending_scene_path = scene_path


## Polls the threaded loader's progress each frame while is_loading
## is true. On success, swaps to the loaded scene and cleans up the
## loading screen. On failure, logs an error and resets loading state.
## Does nothing (and effectively idles) when is_loading is false.
func _process(_delta: float) -> void:
	if not is_loading:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_pending_scene_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass # could emit progress[0] here for a progress bar
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_pending_scene_path)
			get_tree().paused = false
			get_tree().change_scene_to_packed(packed_scene)
			current_scene_path = _pending_scene_path

			if _loading_screen:
				_loading_screen.queue_free()
				_loading_screen = null

			is_loading = false
			set_process(false)
			EventBus.scene_changed.emit(_pending_scene_path)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneManager: Async load failed for %s" % _pending_scene_path)
			is_loading = false
			set_process(false)


## Reloads whatever scene is currently active. Handy for a "Retry"
## button on a game-over screen.
func reload_current_scene() -> void:
	change_scene(current_scene_path)
