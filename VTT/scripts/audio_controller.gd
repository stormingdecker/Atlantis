extends Node

# AudioController — process-global audio.
#
# Owns:
#   - A dedicated AudioStreamPlayer for background music, with crossfade
#     when the track changes.
#   - Transient AudioStreamPlayers spawned per ambient SFX trigger, freed
#     when playback finishes.
#
# All triggers come from SessionState. The GM panel never touches an
# AudioStreamPlayer directly.

const MUSIC_FADE_DURATION := 1.5
const STOP_FADE_DURATION := 1.0
const SILENT_DB := -60.0

# Ambience sits UNDER the music — a quiet always-on bed. Target level is low so
# it never competes with music or the table.
const AMBIENCE_DB := -12.0
const AMBIENCE_FADE_DURATION := 2.0

var _music_player: AudioStreamPlayer
var _music_fader: Tween

var _ambience_player: AudioStreamPlayer
var _ambience_fader: Tween


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = 0.0
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = "Master"
	_ambience_player.volume_db = AMBIENCE_DB
	add_child(_ambience_player)

	SessionState.background_music_changed.connect(_on_music_changed)
	SessionState.background_music_stopped.connect(_on_music_stopped)
	SessionState.ambient_sfx_triggered.connect(_on_sfx_triggered)
	SessionState.ambience_changed.connect(_on_ambience_changed)


# === Music ===============================================================

# Test hooks: let the headless harness sample the crossfade envelope without
# any audio device (the volume_db tween runs on the scene clock).
func get_music_volume_db() -> float:
	return _music_player.volume_db if _music_player != null else 0.0


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func _on_music_changed(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioController: failed to load music %s" % path)
		return
	_configure_loop(stream)
	_crossfade_to(stream)


func _on_music_stopped() -> void:
	if _music_fader and _music_fader.is_valid():
		_music_fader.kill()
	_music_fader = create_tween()
	_music_fader.tween_property(_music_player, "volume_db", SILENT_DB, STOP_FADE_DURATION)
	_music_fader.tween_callback(_music_player.stop)
	_music_fader.tween_callback(func(): _music_player.volume_db = 0.0)


func _crossfade_to(stream: AudioStream) -> void:
	if _music_fader and _music_fader.is_valid():
		_music_fader.kill()

	if not _music_player.playing:
		# Fade in from silence.
		_music_player.stream = stream
		_music_player.volume_db = SILENT_DB
		_music_player.play()
		_music_fader = create_tween()
		_music_fader.tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_DURATION)
		return

	# Out → swap → in.
	_music_fader = create_tween()
	_music_fader.tween_property(_music_player, "volume_db", SILENT_DB, MUSIC_FADE_DURATION / 2.0)
	_music_fader.tween_callback(func():
		_music_player.stream = stream
		_music_player.play()
	)
	_music_fader.tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_DURATION / 2.0)


func _configure_loop(stream: AudioStream) -> void:
	# Different stream types expose looping differently. Set the most
	# common ones; for the rest, the audio will simply not loop.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


# === Ambience ============================================================
#
# A looping atmosphere bed, crossfaded on map change and faded out when a map
# has none. Independent of music, at a low fixed target level.

func _on_ambience_changed(path: String) -> void:
	if path == "":
		_fade_out_ambience()
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioController: failed to load ambience %s" % path)
		return
	_configure_loop(stream)
	if _ambience_fader and _ambience_fader.is_valid():
		_ambience_fader.kill()
	if not _ambience_player.playing:
		_ambience_player.stream = stream
		_ambience_player.volume_db = SILENT_DB
		_ambience_player.play()
		_ambience_fader = create_tween()
		_ambience_fader.tween_property(_ambience_player, "volume_db", AMBIENCE_DB, AMBIENCE_FADE_DURATION)
		return
	# Out → swap → in.
	_ambience_fader = create_tween()
	_ambience_fader.tween_property(_ambience_player, "volume_db", SILENT_DB, AMBIENCE_FADE_DURATION / 2.0)
	_ambience_fader.tween_callback(func():
		_ambience_player.stream = stream
		_ambience_player.play()
	)
	_ambience_fader.tween_property(_ambience_player, "volume_db", AMBIENCE_DB, AMBIENCE_FADE_DURATION / 2.0)


func _fade_out_ambience() -> void:
	if not _ambience_player.playing:
		return
	if _ambience_fader and _ambience_fader.is_valid():
		_ambience_fader.kill()
	_ambience_fader = create_tween()
	_ambience_fader.tween_property(_ambience_player, "volume_db", SILENT_DB, STOP_FADE_DURATION)
	_ambience_fader.tween_callback(_ambience_player.stop)


# === SFX =================================================================

func _on_sfx_triggered(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioController: failed to load sfx %s" % path)
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
