## 多语言管理器（Autoload）
## 全部文案集中在 data/i18n.json，新增语言只需在该 JSON 加一个同键集合的语言段。
extends Node

signal locale_changed(locale: String)

const I18N_PATH := "res://data/i18n.json"
const FALLBACK_LOCALE := "zh_CN"
const LANGUAGE_IDS: Array = ["zh_CN", "en", "ja", "fr", "de", "ru"]
const LANGUAGE_NAMES: Array = ["简体中文", "English", "日本語", "Français", "Deutsch", "Русский"]

var locale: String = FALLBACK_LOCALE
var _tables: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tables()
	var saved := str(SaveManager.setting("language", ""))
	if is_valid_locale(saved):
		locale = saved
	else:
		locale = _detect_locale()
	TranslationServer.set_locale(locale)


func _load_tables() -> void:
	var parsed: Variant = LevelData.read_json(I18N_PATH, {})
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[I18n] 语言包解析失败，界面将显示原文键")
		return
	for key in parsed.keys():
		if typeof(parsed[key]) == TYPE_DICTIONARY:
			_tables[str(key)] = parsed[key]


func _detect_locale() -> String:
	var raw := TranslationServer.get_locale().to_lower().lstrip(" ")
	if raw.begins_with("zh"):
		return "zh_CN"
	if raw.begins_with("ja"):
		return "ja"
	if raw.begins_with("fr"):
		return "fr"
	if raw.begins_with("de"):
		return "de"
	if raw.begins_with("ru"):
		return "ru"
	if raw.begins_with("en"):
		return "en"
	return FALLBACK_LOCALE


static func is_valid_locale(code: String) -> bool:
	return LANGUAGE_IDS.has(code)


static func language_ids() -> Array:
	return LANGUAGE_IDS.duplicate()


static func language_name(code: String) -> String:
	var index := LANGUAGE_IDS.find(code)
	if index < 0:
		return code
	return str(LANGUAGE_NAMES[index])


## 切换语言。persist=false 供开发截图工具临时切语言，不写存档。
func set_locale(code: String, persist: bool = true) -> void:
	if not is_valid_locale(code) or code == locale:
		return
	locale = code
	TranslationServer.set_locale(code)
	if persist:
		SaveManager.set_setting("language", code)
	locale_changed.emit(code)


## 翻译文案；args 非空时按 GDScript % 格式填充。缺键回退中文，再回退键名。
func t(key: String, args: Array = []) -> String:
	var text := ""
	var current: Variant = _tables.get(locale, {})
	if typeof(current) == TYPE_DICTIONARY:
		text = str((current as Dictionary).get(key, ""))
	if text == "":
		var fallback: Variant = _tables.get(FALLBACK_LOCALE, {})
		if typeof(fallback) == TYPE_DICTIONARY:
			text = str((fallback as Dictionary).get(key, ""))
	if text == "":
		return key
	if args.is_empty():
		return text
	return text % args
