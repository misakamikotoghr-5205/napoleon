extends Node
## 德厚当 - background music director (autoload or child node).
##
## Loads res://audio/music/music.json and the .ogg files next to it, crossfades two
## AudioStreamPlayers between looping tracks, plays one-shot stingers, and exposes a master
## music volume plus a dialogue "duck".
##
## Robustness contract: a missing manifest, a missing/unimported file, an unknown track id, a
## Dummy audio driver or calling things before the node is in the tree never raise an error or a
## warning - the call is simply skipped.

const MUSIC_DIR: String = "res://audio/music/"
const MANIFEST_PATH: String = "res://audio/music/music.json"
const MUSIC_BUS: String = "Music"
const SILENT_DB: float = -80.0
const DUCK_DB: float = -8.0           ## applied while dialogue / the counter is open
const STINGER_DUCK_DB: float = -5.0   ## music dips a little while a stinger rings

class Slot:
	var player: AudioStreamPlayer
	var tween: Tween
	var track_id: String = ""
	var base_db: float = 0.0
	var fading_out: bool = false

var _tracks: Dictionary = {}          # id -> manifest entry (Dictionary)
var _streams: Dictionary = {}         # id -> AudioStream (only for files that loaded)
var _slots: Array[Slot] = []
var _active: int = -1                 # index of the front slot, -1 when nothing plays
var _current_id: String = ""
var _volume_linear: float = 1.0
var _duck_on: bool = false
var _stinger_count: int = 0
var _manifest_loaded: bool = false
var _silent_driver: bool = false      ## headless / Dummy audio: keep state, never start playback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup()


## Release every playback before the node goes away, otherwise the audio server keeps the
## streams alive past exit ("resources still in use" / leaked ObjectDB instances).
func _exit_tree() -> void:
	for slot in _slots:
		_kill_tween(slot)
		slot.player.stop()
		slot.player.stream = null
	for child in get_children():
		if child is AudioStreamPlayer:
			var p: AudioStreamPlayer = child
			p.stop()
			p.stream = null
	_streams.clear()
	_stinger_count = 0
	_active = -1
	_current_id = ""


## Start (or crossfade to) a looping track. Same track already playing -> no-op.
func play(track_id: String, fade_s: float = 1.5) -> void:
	_setup()
	if not _manifest_loaded:
		return
	if track_id == _current_id and _active >= 0 and _slots[_active].player.playing:
		return
	if _silent_driver:
		if _entry(track_id).is_empty():
			return
		_current_id = track_id
		return
	var stream: AudioStream = _load_stream(track_id)
	if stream == null:
		return
	var entry: Dictionary = _entry(track_id)
	_apply_loop(stream, bool(entry.get("loop", true)))
	var new_idx: int = 0
	if _active >= 0:
		new_idx = 1 - _active
	else:
		new_idx = 0 if not _slots[0].player.playing else 1
	var fresh: Slot = _slots[new_idx]
	var old: Slot = null
	if _active >= 0:
		old = _slots[_active]
	_kill_tween(fresh)
	fresh.player.stop()
	fresh.player.stream = stream
	fresh.player.bus = _pick_bus()
	fresh.track_id = track_id
	fresh.base_db = float(entry.get("volume_db", 0.0))
	fresh.fading_out = false
	var target_db: float = _target_db(fresh)
	var fade: float = maxf(fade_s, 0.0)
	if fade > 0.0:
		fresh.player.volume_db = SILENT_DB
	else:
		fresh.player.volume_db = target_db
	fresh.player.play()
	if fade > 0.0:
		_tween_to(fresh, target_db, fade, false)
	if old != null:
		_fade_out(old, fade)
	_active = new_idx
	_current_id = track_id


## Fade the current music out and stop it.
func stop(fade_s: float = 1.0) -> void:
	_setup()
	if not _manifest_loaded:
		return
	if _active >= 0:
		_fade_out(_slots[_active], maxf(fade_s, 0.0))
	_active = -1
	_current_id = ""


## One-shot, non-looping sting. Silently ignored when the id or file is unknown.
func stinger(id: String) -> void:
	_setup()
	if not _manifest_loaded or _silent_driver:
		return
	var stream: AudioStream = _load_stream(id)
	if stream == null:
		return
	_apply_loop(stream, false)
	var entry: Dictionary = _entry(id)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = _pick_bus()
	var base_db: float = float(entry.get("volume_db", 0.0))
	player.volume_db = maxf(base_db + _master_db(), SILENT_DB)
	add_child(player)
	_stinger_count += 1
	player.finished.connect(_on_stinger_finished.bind(player))
	player.play()
	_apply_levels(0.3)


## Master music volume, 0..1 (linear). The game persists it; call this on load.
func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	_setup()
	if _manifest_loaded:
		_apply_levels(0.05)


func get_volume_linear() -> float:
	return _volume_linear


## true while dialogue / the pawn counter is open: music sits 8 dB lower.
func duck(on: bool) -> void:
	_duck_on = on
	_setup()
	if _manifest_loaded:
		_apply_levels(0.3)


func current_track() -> String:
	return _current_id


func has_track(track_id: String) -> bool:
	_setup()
	if not _manifest_loaded:
		return false
	return _load_stream(track_id) != null


# --------------------------------------------------------------------------------------------

func _setup() -> void:
	if _manifest_loaded or not is_inside_tree():
		return
	_manifest_loaded = true
	_silent_driver = AudioServer.get_driver_name() == "Dummy"
	_load_manifest()
	for _i in 2:
		var slot := Slot.new()
		slot.player = AudioStreamPlayer.new()
		slot.player.volume_db = SILENT_DB
		add_child(slot.player)
		_slots.append(slot)


func _load_manifest() -> void:
	_tracks = {}
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	var root: Dictionary = data
	var listed: Variant = root.get("tracks", {})
	if typeof(listed) == TYPE_DICTIONARY:
		_tracks = listed


func _entry(track_id: String) -> Dictionary:
	var raw: Variant = _tracks.get(track_id, {})
	if typeof(raw) == TYPE_DICTIONARY:
		var entry: Dictionary = raw
		return entry
	return {}


func _load_stream(track_id: String) -> AudioStream:
	var entry: Dictionary = _entry(track_id)
	if entry.is_empty():
		return null
	var stream: AudioStream = null
	if _streams.has(track_id):
		stream = _streams[track_id]
	else:
		var file_name: String = str(entry.get("file", ""))
		if file_name == "":
			return null
		var path: String = MUSIC_DIR + file_name
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				stream = res
		elif FileAccess.file_exists(path):
			stream = AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			return null
		_streams[track_id] = stream
	return stream


func _apply_loop(stream: AudioStream, looping: bool) -> void:
	if stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = looping
		ogg.loop_offset = 0.0


func _pick_bus() -> StringName:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return StringName(MUSIC_BUS)
	return &"Master"


func _master_db() -> float:
	return linear_to_db(maxf(_volume_linear, 0.0001))


func _duck_total_db() -> float:
	var total: float = 0.0
	if _duck_on:
		total += DUCK_DB
	if _stinger_count > 0:
		total += STINGER_DUCK_DB
	return total


func _target_db(slot: Slot) -> float:
	return maxf(slot.base_db + _master_db() + _duck_total_db(), SILENT_DB)


func _kill_tween(slot: Slot) -> void:
	if slot.tween != null and slot.tween.is_valid():
		slot.tween.kill()
	slot.tween = null


func _tween_to(slot: Slot, target_db: float, seconds: float, stop_after: bool) -> void:
	_kill_tween(slot)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(slot.player, "volume_db", target_db, seconds)
	if stop_after:
		tw.tween_callback(_on_slot_faded_out.bind(slot))
	slot.tween = tw


func _fade_out(slot: Slot, seconds: float) -> void:
	slot.fading_out = true
	if seconds <= 0.0 or not slot.player.playing:
		_kill_tween(slot)
		slot.player.stop()
		slot.player.volume_db = SILENT_DB
		slot.fading_out = false
		return
	_tween_to(slot, SILENT_DB, seconds, true)


func _on_slot_faded_out(slot: Slot) -> void:
	if slot.fading_out:
		slot.player.stop()
		slot.fading_out = false


func _apply_levels(seconds: float) -> void:
	for slot in _slots:
		if slot.fading_out or not slot.player.playing:
			continue
		var target_db: float = _target_db(slot)
		if seconds <= 0.0:
			_kill_tween(slot)
			slot.player.volume_db = target_db
		else:
			_tween_to(slot, target_db, seconds, false)


func _on_stinger_finished(player: AudioStreamPlayer) -> void:
	_stinger_count = maxi(_stinger_count - 1, 0)
	player.queue_free()
	_apply_levels(0.6)
