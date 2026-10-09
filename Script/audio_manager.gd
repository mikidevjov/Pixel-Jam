extends Node

const SETTINGS_FILE_PATH := "user://settings.cfg"

# Map of descriptive names & filenames to loaded streams
var music_tracks: Dictionary = {}
var sfx_tracks: Dictionary = {}

var music_player: AudioStreamPlayer
var current_music_track: String = ""

# SFX player pool
const SFX_POOL_SIZE := 8
var sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

# Cooldown per SFX to avoid multi-trigger stacking on the same frame
var _last_sfx_time: Dictionary = {}
const SFX_MIN_INTERVAL: float = 0.04

# Default volume offsets per sound effect (dB)
const SFX_VOLUME_OFFSETS := {
	"movement_player": -7.0,
	"movement_darksouls": -8.0,
	"movement_boss_darksoul": -3.0,
	"gun_fire": -4.0,
	"laser_fire": -3.0,
	"laser-fire": -3.0,
	"falling_player": -2.0,
	"falling_tile": -5.0,
	"dust_pickup": -2.0,
	"boss_very_dead": 0.0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_load_audio_assets()
	_apply_saved_bus_volumes()


func _setup_audio_players() -> void:
	var music_bus := "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	var sfx_bus := "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	# Background Music Player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = music_bus
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)

	# Sound Effects Player Pool
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = sfx_bus
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_pool.append(p)


func _load_audio_assets() -> void:
	# Background music tracks
	_register_music("main_menu", "res://Assets/Music+SFX/mainmenu_song.ogg")
	_register_music("mainmenu_song", "res://Assets/Music+SFX/mainmenu_song.ogg")
	_register_music("stage1", "res://Assets/Music+SFX/Stage1_song(v2).ogg")
	_register_music("Stage1_song(v2)", "res://Assets/Music+SFX/Stage1_song(v2).ogg")
	_register_music("stage2", "res://Assets/Music+SFX/Stage2_song.ogg")
	_register_music("Stage2_song", "res://Assets/Music+SFX/Stage2_song.ogg")
	_register_music("stage3", "res://Assets/Music+SFX/stage3_song.ogg")
	_register_music("stage3_song", "res://Assets/Music+SFX/stage3_song.ogg")
	_register_music("game_over", "res://Assets/Music+SFX/game_over.ogg")
	_register_music("win", "res://Assets/Music+SFX/win_song.ogg")
	_register_music("win_song", "res://Assets/Music+SFX/win_song.ogg")

	# Sound effects
	_register_sfx("gun_fire", "res://Assets/Music+SFX/SFX/gun_fire.ogg")
	_register_sfx("laser_fire", "res://Assets/Music+SFX/SFX/laser-fire.ogg")
	_register_sfx("laser-fire", "res://Assets/Music+SFX/SFX/laser-fire.ogg")
	_register_sfx("movement_player", "res://Assets/Music+SFX/SFX/movement_player.ogg")
	_register_sfx("falling_player", "res://Assets/Music+SFX/SFX/falling_player.ogg")
	_register_sfx("falling_tile", "res://Assets/Music+SFX/SFX/falling_tile.ogg")
	_register_sfx("Dust_Pickup", "res://Assets/Music+SFX/SFX/Dust_Pickup.ogg")
	_register_sfx("dust_pickup", "res://Assets/Music+SFX/SFX/Dust_Pickup.ogg")
	_register_sfx("boss_very_dead", "res://Assets/Music+SFX/SFX/boss_very_dead.ogg")
	_register_sfx("movement_boss_darksoul", "res://Assets/Music+SFX/SFX/movement_boss_darksoul.ogg")
	_register_sfx("movement_darksouls", "res://Assets/Music+SFX/SFX/movement_darksouls.ogg")


func _register_music(track_name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			music_tracks[track_name.to_lower()] = stream


func _register_sfx(sfx_name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			sfx_tracks[sfx_name.to_lower()] = stream


## Play background music. If the requested track is already playing, it will NOT restart.
func play_music(track_name: String, loop: bool = true) -> void:
	var key := track_name.to_lower()
	if not music_tracks.has(key):
		push_warning("AudioManager: Music track '%s' not found." % track_name)
		return

	# If the same track is currently playing, keep it playing seamlessly
	if current_music_track == key and music_player.playing:
		return

	var stream: AudioStream = music_tracks[key]
	var ogg := stream as AudioStreamOggVorbis
	if ogg:
		ogg.loop = loop

	music_player.stop()
	music_player.stream = stream
	current_music_track = key
	music_player.play()


## Stop currently playing background music.
func stop_music() -> void:
	if music_player and music_player.playing:
		music_player.stop()
	current_music_track = ""


## Check if background music is actively playing.
func is_music_playing() -> bool:
	return music_player != null and music_player.playing


## Return the key of the current music track.
func get_current_music() -> String:
	return current_music_track


## Play a sound effect from the pool.
func play_sfx(sfx_name: String, extra_volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var key := sfx_name.to_lower()
	if not sfx_tracks.has(key):
		push_warning("AudioManager: SFX '%s' not found." % sfx_name)
		return

	# Check multi-trigger rate limit
	var now := Time.get_ticks_msec() / 1000.0
	if _last_sfx_time.has(key) and (now - _last_sfx_time[key]) < SFX_MIN_INTERVAL:
		return
	_last_sfx_time[key] = now

	# Find an available player or use round-robin
	var player: AudioStreamPlayer = null
	for p in sfx_pool:
		if not p.playing:
			player = p
			break

	if not player:
		player = sfx_pool[_sfx_pool_index]
		_sfx_pool_index = (_sfx_pool_index + 1) % sfx_pool.size()

	var stream: AudioStream = sfx_tracks[key]
	var base_offset: float = SFX_VOLUME_OFFSETS.get(key, 0.0)

	player.stream = stream
	player.volume_db = base_offset + extra_volume_db
	player.pitch_scale = pitch_scale
	player.play()


func _apply_saved_bus_volumes() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) != OK:
		return

	var master_vol: float = config.get_value("audio", "master_volume", 1.0)
	var music_vol: float = config.get_value("audio", "music_volume", 1.0)
	var sfx_vol: float = config.get_value("audio", "sfx_volume", 1.0)

	_apply_volume_to_bus("Master", master_vol)
	_apply_volume_to_bus("Music", music_vol)
	_apply_volume_to_bus("SFX", sfx_vol)


func _apply_volume_to_bus(bus_name: String, linear_vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		if linear_vol <= 0.001:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(linear_vol))
