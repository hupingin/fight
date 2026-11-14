## 存档管理器（Autoload）
## 单文件 JSON：user://save_data.json
## 结构见 需求.md 7.4；读失败/损坏时回退默认值，绝不崩溃。
extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

signal data_changed


var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"high_score": 0,
		"unlocked_level": 1,
		"level_records": {},
		"settings": {
			"bgm_volume": 0.5,
			"sfx_volume": 0.85,
			"sfx_enabled": true,
			"screen_shake": true,
		},
		"stats": {
			"total_plays": 0,
			"total_kills": 0,
			"total_score": 0,
			"total_time": 0.0,
		},
	}


func load_data() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SaveManager] 无法打开存档，本次使用默认值")
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = null
	if raw.strip_edges() != "":
		parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveManager] 存档损坏，已回退默认存档")
		data = _default_data()
		save_data()
		return
	data = _merge(_default_data(), parsed)
	data_changed.emit()


func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] 写入存档失败：%s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	data_changed.emit()


## 递归补全缺省字段，同时丢弃类型不符的脏数据。
## 注意：缺省值为空字典的字段（如 level_records）必须原样采纳读入内容，
## 否则会因默认结构为空而把整段记录丢掉。
func _merge(base: Dictionary, incoming: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in incoming.keys():
		var value: Variant = incoming[key]
		if not out.has(key):
			out[key] = value
			continue
		if typeof(out[key]) == TYPE_DICTIONARY:
			if typeof(value) == TYPE_DICTIONARY:
				out[key] = _merge(out[key], value)
		elif typeof(out[key]) == TYPE_INT:
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				out[key] = int(value)
		elif typeof(out[key]) == TYPE_FLOAT:
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				out[key] = float(value)
		elif typeof(out[key]) == typeof(value):
			out[key] = value
	return out


# ---------------------------------------------------------------- 设置
func setting(key: String, default_value: Variant = null) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = value
	save_data()


# ---------------------------------------------------------------- 查询
func high_score() -> int:
	return int(data.get("high_score", 0))


func unlocked_level() -> int:
	return maxi(1, int(data.get("unlocked_level", 1)))


func is_level_unlocked(level_id: int) -> bool:
	return level_id <= unlocked_level()


func level_record(level_id: int, difficulty: String = LevelData.DEFAULT_DIFFICULTY) -> Dictionary:
	var records: Dictionary = data.get("level_records", {})
	var entry: Variant = records.get(str(level_id), {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {"high_score": 0, "cleared": false}
	var rec: Variant = entry.get(difficulty, null)
	if typeof(rec) != TYPE_DICTIONARY:
		# 兼容旧版单层结构：{"1": {"high_score": x, "cleared": y}} 视为中等难度记录
		if entry.has("high_score") or entry.has("cleared"):
			rec = entry
		else:
			return {"high_score": 0, "cleared": false}
	return {
		"high_score": int(rec.get("high_score", 0)),
		"cleared": bool(rec.get("cleared", false)),
	}


## 任意难度通关过就算通关（用于解锁判断与总进度）
func level_cleared_any(level_id: int) -> bool:
	var records: Dictionary = data.get("level_records", {})
	var entry: Variant = records.get(str(level_id), {})
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	if bool(entry.get("cleared", false)):
		return true
	for key in entry.keys():
		var rec: Variant = entry[key]
		if typeof(rec) == TYPE_DICTIONARY and bool(rec.get("cleared", false)):
			return true
	return false


# ---------------------------------------------------------------- 结算写入
## 返回本次结算附加信息，供结算界面展示。
func submit_run(level_id: int, difficulty: String, score: int, cleared: bool, kills: int, play_time: float) -> Dictionary:
	if not LevelData.is_difficulty(difficulty):
		difficulty = LevelData.DEFAULT_DIFFICULTY
	if not data.has("level_records"):
		data["level_records"] = {}
	var records: Dictionary = data["level_records"]
	var key := str(level_id)
	var entry: Variant = records.get(key, {})
	if typeof(entry) != TYPE_DICTIONARY:
		entry = {}
	# 旧版单层结构升级为按难度分桶
	if entry.has("high_score") or entry.has("cleared"):
		entry = {
			"normal": {
				"high_score": int(entry.get("high_score", 0)),
				"cleared": bool(entry.get("cleared", false)),
			}
		}
	var rec: Variant = entry.get(difficulty, {})
	if typeof(rec) != TYPE_DICTIONARY:
		rec = {}
	var old_best := int(rec.get("high_score", 0))
	var new_record := score > old_best
	rec["high_score"] = maxi(old_best, score)
	if cleared:
		rec["cleared"] = true
	entry[difficulty] = rec
	records[key] = entry
	data["level_records"] = records

	var global_record := score > int(data.get("high_score", 0))
	data["high_score"] = maxi(int(data.get("high_score", 0)), score)

	var unlocked_next := false
	if cleared:
		var next_id := level_id + 1
		if next_id > int(data.get("unlocked_level", 1)):
			# 最后一关通关后不再把解锁进度推到不存在的关卡
			data["unlocked_level"] = mini(next_id, maxi(1, LevelData.level_count()))
			unlocked_next = true

	var stats: Dictionary = data.get("stats", {})
	stats["total_plays"] = int(stats.get("total_plays", 0)) + 1
	stats["total_kills"] = int(stats.get("total_kills", 0)) + kills
	stats["total_score"] = int(stats.get("total_score", 0)) + score
	stats["total_time"] = float(stats.get("total_time", 0.0)) + play_time
	data["stats"] = stats

	save_data()
	return {
		"new_record": new_record,
		"global_record": global_record,
		"unlocked_next": unlocked_next,
		"best": int(rec["high_score"]),
	}


func reset() -> void:
	data = _default_data()
	save_data()
