## 音频管理器（Autoload）
## 统一播放 SFX 与 BGM，音量读取自 SaveManager 设置，支持音效开关。
extends Node

const SFX_FILES := {
	"shoot": "res://assets/audio/shoot.wav",
	"enemy_shoot": "res://assets/audio/enemy_shoot.wav",
	"laser": "res://assets/audio/laser.wav",
	"hit": "res://assets/audio/hit.wav",
	"explode": "res://assets/audio/explode.wav",
	"big_explode": "res://assets/audio/big_explode.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"warn": "res://assets/audio/warn.wav",
	"click": "res://assets/audio/click.wav",
	"clear": "res://assets/audio/clear.wav",
	"gameover": "res://assets/audio/gameover.wav",
}

const BGM_PATH := "res://assets/audio/bgm_loop.wav"
const POOL_SIZE := 10

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _bgm: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX_FILES.keys():
		var path: String = SFX_FILES[key]
		if ResourceLoader.exists(path):
			_cache[key] = load(path)

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	if ResourceLoader.exists(BGM_PATH):
		var stream: AudioStream = load(BGM_PATH)
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_bgm.stream = stream
	add_child(_bgm)
	_bgm.play()

	SaveManager.data_changed.connect(apply_settings)
	apply_settings()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not bool(SaveManager.setting("sfx_enabled", true)):
		return
	var stream: AudioStream = _cache.get(sound, null)
	if stream == null or _pool.is_empty():
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = linear_to_db(maxf(0.001, float(SaveManager.setting("sfx_volume", 0.85)))) + volume_db
	player.play()


func apply_settings() -> void:
	if _bgm == null:
		return
	var bgm_volume := float(SaveManager.setting("bgm_volume", 0.5))
	if bgm_volume <= 0.001:
		_bgm.stop()
		return
	_bgm.volume_db = linear_to_db(bgm_volume) - 8.0
	if not _bgm.playing and _bgm.stream != null:
		_bgm.play()


func stop_bgm() -> void:
	if _bgm != null:
		_bgm.stop()


func start_bgm() -> void:
	if _bgm != null and _bgm.stream != null and not _bgm.playing:
		_bgm.play()
