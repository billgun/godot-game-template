extends Node

# ============================================================
# GAMEMANAGER
# The "brain" of the game. Tracks current game state and
# reacts to EventBus signals to drive state transitions.
# Depends on: EventBus
# Must be registered AFTER EventBus in Project Settings > Autoload.
# ============================================================

## The set of high-level states the game can be in.
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

## The game's current state. Read this to branch logic elsewhere
## (e.g. only process player input when current_state == PLAYING).
var current_state: GameState = GameState.MAIN_MENU

## The state the game was in immediately before the current one.
## Useful for things like "resume to whatever we were doing before pause".
var previous_state: GameState = GameState.MAIN_MENU

## Runtime-only: the currently loaded level's identifier.
## NOT persisted automatically — SaveManager reads this when saving.
var current_level: String = ""

## Runtime-only: the player's current score for this session.
## NOT persisted automatically — SaveManager reads this when saving.
var score: int = 0


## Connects to EventBus signals on startup so GameManager can react
## to state-changing events fired from anywhere in the game.
func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.player_died.connect(_on_player_died)


## Transitions the game to a new state, updates previous_state,
## applies any side effects (e.g. pausing the SceneTree), and
## broadcasts the change via EventBus.
## [param new_state] The GameState to transition into.
func change_state(new_state: GameState) -> void:
	previous_state = current_state
	current_state = new_state
	EventBus.game_state_changed.emit(GameState.keys()[new_state])

	match new_state:
		GameState.MAIN_MENU:
			get_tree().paused = false
		GameState.PLAYING:
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = false


## Handler for EventBus.game_started. Resets the session score
## and transitions into the PLAYING state.
func _on_game_started() -> void:
	score = 0
	change_state(GameState.PLAYING)


## Handler for EventBus.game_paused. Transitions into PAUSED,
## which also pauses the SceneTree (see change_state).
func _on_game_paused() -> void:
	change_state(GameState.PAUSED)


## Handler for EventBus.game_resumed. Transitions back into PLAYING.
func _on_game_resumed() -> void:
	change_state(GameState.PLAYING)


## Handler for EventBus.player_died. Transitions into GAME_OVER
## and broadcasts EventBus.game_over for UI/other systems to react to.
func _on_player_died() -> void:
	change_state(GameState.GAME_OVER)
	EventBus.game_over.emit()


## Convenience check for whether the game is actively being played
## (useful for gating input handling, spawning, etc.).
## [return] true if current_state == PLAYING.
func is_playing() -> bool:
	return current_state == GameState.PLAYING


## Adds to the current session score.
## [param amount] Points to add (can be negative to subtract).
func add_score(amount: int) -> void:
	score += amount
