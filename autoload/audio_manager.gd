extends Node

# ============================================================
# AUDIOMANAGER
# Plays SFX/music without needing an AudioStreamPlayer in every
# scene. Pools SFX players to handle overlapping sounds, and
# handles music crossfading between tracks.
# Depends on: EventBus, SettingsManager (for volume/bus levels,
# already applied by SettingsManager itself on bus volumes)
# Must be registered LAST in Project Settings > Autoload.
# ============================================================

## Number of pooled AudioStreamPlayers used for SFX, allowing this
## many overlapping sound effects to play simultaneously without
## cutting each other off.
const SFX_POOL_SIZE := 8

## Maps SFX name keys to their preloaded AudioStream. Add entries as
## you bring in real audio files, e.g.:
## "click": preload("res://audio/sfx/click.ogg")
const SFX_LIBRARY := {
	# "click": preload("res://audio/sfx/click.ogg"),
	# "hit": preload("res://audio/sfx/hit.ogg"),
}

## Maps music track name keys to their preloaded AudioStream. Add
## entries as you bring in real audio files, e.g.:
## "main_menu": preload("res://audio/music/main_menu.ogg")
const MUSIC_LIBRARY := {
	# "main_menu": preload("res://audio/music/main_menu.ogg"),
	# "level_1": preload("res://audio/music/level_1.ogg"),
}

## Pool of AudioStreamPlayer nodes used for SFX playback, cycled
## round-robin so multiple overlapping sounds can play at once.
var _sfx_pool: Array[AudioStreamPlayer] = []

## Index of the next pooled SFX player to use (round-robin cursor).
var _sfx_pool_index: int = 0

## First of two music players used for crossfading between tracks.
var _music_player_a: AudioStreamPlayer

## Second of two music players used for crossfading between tracks.
var _music_player_b: AudioStreamPlayer

## Whichever of _music_player_a/_music_player_b is currently the
## "active" (audible/fading-in) player.
var _active_music_player: AudioStreamPlayer

## Name key of the currently playing (or fading-in) music track.
## Empty string if no music is playing.
var _current_track: String = ""


## Connects to EventBus so audio can be triggered without holding a
## direct reference to AudioManager, and builds the SFX pool and the
## two music players used for crossfading.
func _ready() -> void:
	EventBus.play_sfx_requested.connect(play_sfx)
	EventBus.play_music_requested.connect(play_music)
	EventBus.stop_music_requested.connect(stop_music)

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(player)
		_sfx_pool.append(player)

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music_player_b)

	_active_music_player = _music_player_a


## Plays a one-shot sound effect using the next available pooled
## player (round-robin), so overlapping calls don't interrupt each
## other. Logs a warning if the name isn't found in SFX_LIBRARY.
## [param sfx_name] Key into SFX_LIBRARY identifying which sound to play.
func play_sfx(sfx_name: String) -> void:
	if not SFX_LIBRARY.has(sfx_name):
		push_warning("AudioManager: SFX '%s' not found in library" % sfx_name)
		return

	var player := _sfx_pool[_sfx_pool_index]
	player.stream = SFX_LIBRARY[sfx_name]
	player.play()

	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE


## Starts playing a music track, crossfading out any currently
## playing track and crossfading in the new one over fade_duration
## seconds. Does nothing if the requested track is already playing.
## Logs a warning if the name isn't found in MUSIC_LIBRARY.
## [param track_name] Key into MUSIC_LIBRARY identifying which track to play.
## [param fade_duration] Crossfade length in seconds (default 1.0).
func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if not MUSIC_LIBRARY.has(track_name):
		push_warning("AudioManager: Music track '%s' not found in library" % track_name)
		return

	if track_name == _current_track:
		return

	_current_track = track_name

	var next_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	next_player.stream = MUSIC_LIBRARY[track_name]
	next_player.volume_db = -80
	next_player.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_active_music_player, "volume_db", -80, fade_duration)
	tween.tween_property(next_player, "volume_db", 0, fade_duration)
	tween.chain().tween_callback(_active_music_player.stop)

	_active_music_player = next_player


## Fades out and stops whatever music is currently playing.
## [param fade_duration] Fade-out length in seconds (default 1.0).
func stop_music(fade_duration: float = 1.0) -> void:
	_current_track = ""
	var tween := create_tween()
	tween.tween_property(_active_music_player, "volume_db", -80, fade_duration)
	tween.tween_callback(_active_music_player.stop)
