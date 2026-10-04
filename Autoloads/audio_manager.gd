extends Node

const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"

# ─── 音乐 ─────────────────────────────────
var music_audio_player_count := 2
var audio_music_player_index := 0
var music_players: Array[AudioStreamPlayer]
var current_music: AudioStream = null
var music_fade_tween: Tween = null

# ─── 音效 ─────────────────────────────────
var sfx_audio_player_count := 6
var sfx_players: Array[AudioStreamPlayer]
var sfx_player_index := 0

# ═════════════════════════════════════════
# 初始化
# ═════════════════════════════════════════
func _ready() -> void:
	init_music_audio_manager()
	init_sfx_audio_manager()

func init_music_audio_manager() -> void:
	for i in music_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.bus = MUSIC_BUS
		audio_player.volume_db = 0.0
		add_child(audio_player)
		music_players.append(audio_player)

func init_sfx_audio_manager() -> void:
	for i in sfx_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.bus = SFX_BUS     # ← 修复
		add_child(audio_player)
		sfx_players.append(audio_player)

# ═════════════════════════════════════════
# 音乐
# ═════════════════════════════════════════

func play_music(audio: AudioStream) -> void:
	if audio == null or audio == current_music:
		return
	current_music = audio

	_kill_music_tween()
	_get_current_player().stream = audio
	_get_current_player().volume_db = 0.0
	_get_current_player().play()

func play_music_fade(audio: AudioStream, fade_time := 0.3) -> void:
	if audio == null or audio == current_music:
		return

	var old_player := _get_current_player()
	current_music = audio

	audio_music_player_index = (audio_music_player_index + 1) % music_audio_player_count
	var new_player := _get_current_player()

	new_player.stream = audio
	new_player.volume_db = -40.0
	new_player.play()

	_kill_music_tween()
	music_fade_tween = create_tween().set_parallel(true)
	music_fade_tween.tween_property(old_player, "volume_db", -40.0, fade_time)
	music_fade_tween.tween_property(new_player, "volume_db", 0.0, fade_time)
	music_fade_tween.chain().tween_callback(old_player.stop)

func stop_music(fade_time := 0.3) -> void:
	if not _is_music_playing():
		return
	current_music = null

	var player := _get_current_player()
	_kill_music_tween()
	music_fade_tween = create_tween()
	music_fade_tween.tween_property(player, "volume_db", -40.0, fade_time)
	music_fade_tween.tween_callback(player.stop)

func set_music_paused(paused: bool) -> void:
	for p in music_players:
		p.stream_paused = paused

# ═════════════════════════════════════════
# 音效
# ═════════════════════════════════════════

func play_sfx(audio: AudioStream, volume_db := 0.0) -> void:
	if audio == null:
		return
	var player := _get_free_sfx_player()
	player.stream = audio
	player.volume_db = volume_db
	player.play()

func stop_all_sfx() -> void:
	for p in sfx_players:
		p.stop()

# ═════════════════════════════════════════
# 内部
# ═════════════════════════════════════════
func _get_current_player() -> AudioStreamPlayer:
	return music_players[audio_music_player_index]

func _is_music_playing() -> bool:
	for p in music_players:
		if p.playing:
			return true
	return false

func _kill_music_tween() -> void:
	if music_fade_tween and music_fade_tween.is_valid():
		music_fade_tween.kill()
	music_fade_tween = null

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	sfx_player_index = (sfx_player_index + 1) % sfx_audio_player_count
	return sfx_players[sfx_player_index]
