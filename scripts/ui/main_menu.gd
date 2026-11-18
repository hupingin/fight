## 主菜单：开始 / 选关 / 设置（音量、开关、语言、重置存档）
extends Control

const SPACE_BG := preload("res://scripts/fx/space_bg.gd")

var _settings_box: Control
var _hi_label: Label
var _footer: Label
var _diff_label: Label
var _stats_label: Label
var _reset_dialog: ConfirmationDialog


func _ready() -> void:
	get_tree().paused = false
	AudioManager.start_bgm()
	_build()
	if GameState.reopen_settings:
		GameState.reopen_settings = false
		_on_settings()


func _build() -> void:
	var bg := Control.new()
	bg.set_script(SPACE_BG)
	add_child(bg)
	bg.setup("#061018", "#000000", "#7fc3ff", 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 战机展示
	var ship := TextureRect.new()
	ship.texture = load("res://assets/game-plane.svg")
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_SCALE
	ship.position = Vector2(212, 128)
	ship.size = Vector2(116, 116)
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ship)
	var float_tween := create_tween().set_loops()
	float_tween.tween_property(ship, "position:y", 140.0, 2.2).set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(ship, "position:y", 128.0, 2.2).set_trans(Tween.TRANS_SINE)

	var title := UIKit.glow_label(I18n.t("app.title"), _scaled_title_size(), UIKit.CYAN)
	title.position = Vector2(0, 268)
	title.size = Vector2(540, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var en := UIKit.label(I18n.t("app.subtitle"), 12, UIKit.MUTED)
	en.position = Vector2(0, 336)
	en.size = Vector2(540, 20)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(en)

	var line := UIKit.separator(240, Color(0.3, 0.65, 0.85, 0.4))
	line.position = Vector2(150, 372)
	add_child(line)

	var tagline := UIKit.label(I18n.t("app.tagline", [LevelData.level_count()]), 12, UIKit.DIM)
	tagline.position = Vector2(0, 386)
	tagline.size = Vector2(540, 20)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)

	var buttons := [
		[I18n.t("menu.start"), UIKit.CYAN, _on_start],
		[I18n.t("menu.levels"), UIKit.BLUE, _on_levels],
		[I18n.t("menu.settings"), UIKit.MUTED, _on_settings],
		[I18n.t("menu.quit"), Color("#ff8b95"), _on_quit],
	]
	var y := 452.0
	for item in buttons:
		var button := UIKit.button(str(item[0]), Vector2(280, 54), item[1])
		button.position = Vector2(130, y)
		button.pressed.connect(item[2])
		button.pressed.connect(func(): AudioManager.play("click", 1.0, -6.0))
		add_child(button)
		y += 68.0

	_hi_label = UIKit.label(I18n.t("app.hi_score") + "  " + UIKit.format_score(SaveManager.high_score()),
		13, UIKit.AMBER)
	_hi_label.position = Vector2(0, 744)
	_hi_label.size = Vector2(540, 20)
	_hi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hi_label)

	var diff_id := str(SaveManager.setting("last_difficulty", LevelData.DEFAULT_DIFFICULTY))
	if not LevelData.is_difficulty(diff_id):
		diff_id = LevelData.DEFAULT_DIFFICULTY
	_diff_label = UIKit.label(I18n.t("app.current_difficulty", [LevelData.difficulty_label(diff_id)]),
		12, LevelData.difficulty_color(diff_id))
	_diff_label.position = Vector2(0, 768)
	_diff_label.size = Vector2(540, 20)
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_diff_label)

	_footer = UIKit.label("v1.0.2  ·  " + I18n.t("app.save_file"), 11, UIKit.DIM)
	_footer.position = Vector2(0, 906)
	_footer.size = Vector2(540, 18)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)


## 长标题（俄/德等）自动缩小字号，避免换行或溢出。
func _scaled_title_size() -> int:
	var length := I18n.t("app.title").length()
	if length <= 8:
		return 50
	if length <= 14:
		return 40
	if length <= 22:
		return 33
	return 27


# ---------------------------------------------------------------- 入口按钮
func _on_start() -> void:
	var level_id := clampi(SaveManager.unlocked_level(), 1, maxi(1, LevelData.level_count()))
	var diff := str(SaveManager.setting("last_difficulty", LevelData.DEFAULT_DIFFICULTY))
	GameState.start_level(level_id, diff)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_quit() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- 设置面板
func _on_settings() -> void:
	if _settings_box != null:
		return
	_settings_box = Control.new()
	_settings_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_box)

	var dim := UIKit.fullscreen_dim(Color(0, 0, 0, 0.8))
	_settings_box.add_child(dim)
	_set_chrome_visible(false)

	var panel := UIKit.panel(UIKit.CYAN, Color(0.025, 0.055, 0.075, 0.98))
	panel.position = Vector2(50, 186)
	panel.size = Vector2(440, 576)
	_settings_box.add_child(panel)

	var title := UIKit.glow_label(I18n.t("settings.title"), 26, UIKit.CYAN)
	title.position = Vector2(0, 14)
	title.size = Vector2(440, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var bgm_value := UIKit.label("", 13, UIKit.CYAN)
	bgm_value.position = Vector2(316, 82)
	bgm_value.size = Vector2(90, 20)
	bgm_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(bgm_value)
	_build_slider_row(panel, I18n.t("settings.bgm"), 64, float(SaveManager.setting("bgm_volume", 0.5)), bgm_value, "bgm_volume")

	var sfx_value := UIKit.label("", 13, UIKit.CYAN)
	sfx_value.position = Vector2(316, 142)
	sfx_value.size = Vector2(90, 20)
	sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(sfx_value)
	_build_slider_row(panel, I18n.t("settings.sfx"), 124, float(SaveManager.setting("sfx_volume", 0.85)), sfx_value, "sfx_volume")

	var sfx_toggle := UIKit.checkbox(I18n.t("settings.sfx_toggle"))
	sfx_toggle.position = Vector2(34, 180)
	sfx_toggle.button_pressed = bool(SaveManager.setting("sfx_enabled", true))
	sfx_toggle.toggled.connect(func(on: bool): SaveManager.set_setting("sfx_enabled", on))
	panel.add_child(sfx_toggle)

	var shake_toggle := UIKit.checkbox(I18n.t("settings.shake"))
	shake_toggle.position = Vector2(34, 218)
	shake_toggle.button_pressed = bool(SaveManager.setting("screen_shake", true))
	shake_toggle.toggled.connect(func(on: bool): SaveManager.set_setting("screen_shake", on))
	panel.add_child(shake_toggle)

	_build_language_selector(panel)

	var divider := UIKit.separator(372, Color(0.2, 0.42, 0.52, 0.5))
	divider.position = Vector2(34, 354)
	panel.add_child(divider)

	var stats: Dictionary = SaveManager.data.get("stats", {})
	_stats_label = UIKit.fitted_label(
		I18n.t("settings.stats", [int(stats.get("total_plays", 0)), int(stats.get("total_kills", 0))]),
		12, 372.0, UIKit.MUTED)
	_stats_label.position = Vector2(34, 368)
	panel.add_child(_stats_label)

	var global_label := UIKit.label(I18n.t("settings.global_hi") + " " + UIKit.format_score(SaveManager.high_score()),
		12, UIKit.MUTED)
	global_label.position = Vector2(34, 392)
	panel.add_child(global_label)

	var reset := UIKit.button(I18n.t("settings.reset"), Vector2(372, 44), UIKit.RED)
	reset.position = Vector2(34, 434)
	reset.pressed.connect(_confirm_reset)
	panel.add_child(reset)

	var close := UIKit.button(I18n.t("settings.close"), Vector2(372, 44), UIKit.CYAN)
	close.position = Vector2(34, 486)
	close.pressed.connect(_close_settings)
	panel.add_child(close)

	var tip := UIKit.fitted_label(I18n.t("settings.tip"), 11, 372.0, UIKit.DIM)
	tip.position = Vector2(34, 542)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(372, 30)
	panel.add_child(tip)
	tip.size = Vector2(372, 30)


## 六种语言按 3×2 网格排列，选中项用青色描边高亮。
func _build_language_selector(panel: Control) -> void:
	var caption := UIKit.label(I18n.t("settings.language"), 13, UIKit.TEXT)
	caption.position = Vector2(34, 256)
	panel.add_child(caption)

	var ids: Array = I18n.language_ids()
	var width := 116.0
	var height := 30.0
	var gap := 12.0
	for i in ids.size():
		var code := str(ids[i])
		var selected: bool = code == I18n.locale
		var color := UIKit.CYAN if selected else UIKit.DIM
		var button := UIKit.button(I18n.language_name(code), Vector2(width, height), color)
		button.position = Vector2(34 + float(i % 3) * (width + gap),
			280 + float(i / 3) * (height + 4))
		button.add_theme_font_size_override("font_size", 14)
		if selected:
			button.add_theme_stylebox_override("normal", UIKit.box(
				Color(color.r, color.g, color.b, 0.22), color, 2, 4))
		button.pressed.connect(_on_language_selected.bind(code))
		panel.add_child(button)


func _on_language_selected(code: String) -> void:
	if code == I18n.locale:
		return
	I18n.set_locale(code)
	AudioManager.play("click", 1.1, -6.0)
	# 重载主菜单让所有文案立即刷新，并自动重新打开设置面板。
	GameState.reopen_settings = true
	get_tree().call_deferred("reload_current_scene")


func _build_slider_row(panel: Control, text: String, y: float, value: float, value_label: Label, key: String) -> void:
	var caption := UIKit.label(text, 14, UIKit.TEXT)
	caption.position = Vector2(34, y)
	panel.add_child(caption)

	var slider := UIKit.slider(UIKit.CYAN)
	slider.position = Vector2(34, y + 26)
	slider.size = Vector2(372, 24)
	slider.value = value
	value_label.text = "%d%%" % int(round(value * 100.0))
	slider.value_changed.connect(func(v: float):
		SaveManager.data["settings"][key] = v
		value_label.text = "%d%%" % int(round(v * 100.0))
		AudioManager.apply_settings()
	)
	slider.drag_ended.connect(func(_changed: bool): SaveManager.save_data())
	panel.add_child(slider)


func _confirm_reset() -> void:
	if _reset_dialog == null:
		_reset_dialog = ConfirmationDialog.new()
		_reset_dialog.title = I18n.t("settings.reset")
		_reset_dialog.dialog_text = I18n.t("settings.reset_body")
		_reset_dialog.ok_button_text = I18n.t("settings.reset_ok")
		_reset_dialog.cancel_button_text = I18n.t("settings.cancel")
		_reset_dialog.confirmed.connect(_do_reset)
		add_child(_reset_dialog)
	_reset_dialog.popup_centered()


func _do_reset() -> void:
	var keep_locale := I18n.locale
	SaveManager.reset()
	SaveManager.set_setting("language", keep_locale)
	AudioManager.apply_settings()
	if _hi_label != null:
		_hi_label.text = I18n.t("app.hi_score") + "  " + UIKit.format_score(SaveManager.high_score())
	if _stats_label != null:
		_stats_label.text = I18n.t("settings.stats", [0, 0])
	AudioManager.play("click", 0.8, -4.0)


func _close_settings() -> void:
	if _settings_box != null:
		_settings_box.queue_free()
		_settings_box = null
	_set_chrome_visible(true)
	if _hi_label != null:
		_hi_label.text = I18n.t("app.hi_score") + "  " + UIKit.format_score(SaveManager.high_score())
	AudioManager.play("click", 1.1, -6.0)


## 设置面板打开时隐藏面板下方的主菜单小字，避免透出叠字。
func _set_chrome_visible(on: bool) -> void:
	if _hi_label != null:
		_hi_label.visible = on
	if _footer != null:
		_footer.visible = on
	if _diff_label != null:
		_diff_label.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings_box != null:
			_close_settings()
