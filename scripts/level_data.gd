## 关卡 / 敌人 / 弹丸配置读取（纯数据驱动，新增关卡只需加 JSON）
class_name LevelData
extends RefCounted

const LEVEL_DIR := "res://data/levels/"
const ENEMY_PATH := "res://data/enemies.json"
const BULLET_PATH := "res://data/bullets.json"
const DIFFICULTY_PATH := "res://data/difficulties.json"
const DIFFICULTY_ORDER: Array = ["easy", "normal", "hard"]
const DEFAULT_DIFFICULTY := "normal"

static var _enemies: Dictionary = {}
static var _bullets: Dictionary = {}
static var _difficulties: Dictionary = {}
static var _levels: Array = []
static var _ready_flag := false


static func ensure_loaded() -> void:
	if _ready_flag:
		return
	_ready_flag = true
	_enemies = read_json(ENEMY_PATH, {})
	_bullets = read_json(BULLET_PATH, {})
	_difficulties = read_json(DIFFICULTY_PATH, {})
	_levels.clear()
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		push_error("[LevelData] 无法打开关卡目录 " + LEVEL_DIR)
		return
	var files: Array = []
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			files.append(file_name)
	files.sort()
	for file_name in files:
		var parsed: Variant = read_json(LEVEL_DIR + file_name, null)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("level_id"):
			_levels.append(parsed)
	_levels.sort_custom(func(a, b): return int(a["level_id"]) < int(b["level_id"]))


static func read_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[LevelData] 缺少数据文件：" + path)
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return fallback
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("[LevelData] JSON 解析失败：" + path)
		return fallback
	return parsed


static func enemies() -> Dictionary:
	ensure_loaded()
	return _enemies


static func enemy(id: String) -> Dictionary:
	ensure_loaded()
	var data: Variant = _enemies.get(id, {})
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func bullets() -> Dictionary:
	ensure_loaded()
	return _bullets


static func bullet(id: String) -> Dictionary:
	ensure_loaded()
	var data: Variant = _bullets.get(id, {})
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func levels() -> Array:
	ensure_loaded()
	return _levels


static func level_count() -> int:
	ensure_loaded()
	return _levels.size()


static func level(level_id: int) -> Dictionary:
	ensure_loaded()
	for item in _levels:
		if int(item.get("level_id", -1)) == level_id:
			return item
	return {}


# ---------------------------------------------------------------- 难度
static func difficulty_ids() -> Array:
	return DIFFICULTY_ORDER.duplicate()


static func is_difficulty(id: String) -> bool:
	ensure_loaded()
	return _difficulties.has(id)


## 取难度配置；未知 id 回退中等，永远返回字典
static func difficulty(id: String) -> Dictionary:
	ensure_loaded()
	if not _difficulties.has(id):
		id = DEFAULT_DIFFICULTY
	var data: Variant = _difficulties.get(id, {})
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func difficulty_label(id: String) -> String:
	var fallback := str(difficulty(id).get("label", id))
	return _localized("difficulty." + id, fallback)


# ---------------------------------------------------------------- 多语言
## 文案缺失时回退 JSON 原文，保证语言包不完整也不会显示成键名。
static func _localized(key: String, fallback: String) -> String:
	var text := I18n.t(key)
	return fallback if text == key else text


static func level_name(level_id: int) -> String:
	return _localized("level.%d.name" % level_id, str(level(level_id).get("name", "")))


static func level_subtitle(level_id: int) -> String:
	var raw: Dictionary = level(level_id)
	var fallback := str(raw.get("subtitle", raw.get("brief", "")))
	return _localized("level.%d.subtitle" % level_id, fallback)


static func level_brief(level_id: int) -> String:
	return _localized("level.%d.brief" % level_id, str(level(level_id).get("brief", "")))


static func boss_name(level_id: int, fallback: String) -> String:
	return _localized("level.%d.boss" % level_id, fallback)


static func difficulty_color(id: String) -> Color:
	var raw := str(difficulty(id).get("color", "#54c8ff"))
	return Color.from_string(raw, Color("#54c8ff"))
