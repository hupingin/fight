## 主菜单：开始 / 选关 / 设置（音量、开关、重置存档）
extends Control

const SPACE_BG := preload("res://scripts/fx/space_bg.gd")

var _settings_box: Control
var _hi_label: Label
var _footer: Label
var _stats_label: Label
var _reset_dialog: ConfirmationDialog


func _ready() -> void:
	get_tree().paused = false
	AudioManager.start_bgm()
	_build()


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

	var title := UIKit.glow_label("星 际 战 机", 50, UIKit.CYAN)
	title.position = Vector2(0, 268)
	title.size = Vector2(540, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var en := UIKit.label("S T A R   R A I D E R", 12, UIKit.MUTED)
	en.position = Vector2(0, 336)
	en.size = Vector2(540, 20)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(en)

	var line := UIKit.separator(240, Color(0.3, 0.65, 0.85, 0.4))
	line.position = Vector2(150, 372)
	add_child(line)

	var tagline := UIKit.label("纯本地单机 · 10 关挑战 · 三档难度", 12, UIKit.DIM)
	tagline.position = Vector2(0, 386)
	tagline.size = Vector2(540, 20)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tagline)

	var buttons := [
		["开始游戏", UIKit.CYAN, _on_start],
		["选择关卡", UIKit.BLUE, _on_levels],
		["设置", UIKit.MUTED, _on_settings],
		["退出游戏", Color("#ff8b95"), _on_quit],
	]
	var y := 452.0
	for item in buttons:
		var button := UIKit.button(str(item[0]), Vector2(280, 54), item[1])
		button.position = Vector2(130, y)
		button.pressed.connect(item[2])
		button.pressed.connect(func(): AudioManager.play("click", 1.0, -6.0))
		add_child(button)
		y += 68.0

	_hi_label = UIKit.label("历史最高分  " + UIKit.format_score(SaveManager.high_score()), 13, UIKit.AMBER)
	_hi_label.position = Vector2(0, 744)
	_hi_label.size = Vector2(540, 20)
	_hi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hi_label)

	var diff_id := str(SaveManager.setting("last_difficulty", LevelData.DEFAULT_DIFFICULTY))
	if not LevelData.is_difficulty(diff_id):
		diff_id = LevelData.DEFAULT_DIFFICULTY
	var diff_label := UIKit.label("当前难度  %s  ·  可在选关界面切换" % LevelData.difficulty_label(diff_id),
		12, LevelData.difficulty_color(diff_id))
	diff_label.position = Vector2(0, 768)
	diff_label.size = Vector2(540, 20)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(diff_label)

	_footer = UIKit.label("v1.0  ·  存档 user://save_data.json", 11, UIKit.DIM)
	_footer.position = Vector2(0, 906)
	_footer.size = Vector2(540, 18)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)


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
	panel.position = Vector2(50, 196)
	panel.size = Vector2(440, 556)
	_settings_box.add_child(panel)

	var title := UIKit.glow_label("设  置", 26, UIKit.CYAN)
	title.position = Vector2(0, 22)
	title.size = Vector2(440, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var bgm_value := UIKit.label("", 13, UIKit.CYAN)
	bgm_value.position = Vector2(316, 92)
	bgm_value.size = Vector2(90, 20)
	bgm_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(bgm_value)
	_build_slider_row(panel, "背景音乐", 74, float(SaveManager.setting("bgm_volume", 0.5)), bgm_value, "bgm_volume")

	var sfx_value := UIKit.label("", 13, UIKit.CYAN)
	sfx_value.position = Vector2(316, 152)
	sfx_value.size = Vector2(90, 20)
	sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(sfx_value)
	_build_slider_row(panel, "音效音量", 134, float(SaveManager.setting("sfx_volume", 0.85)), sfx_value, "sfx_volume")

	var sfx_toggle := UIKit.checkbox("音效开关")
	sfx_toggle.position = Vector2(34, 192)
	sfx_toggle.button_pressed = bool(SaveManager.setting("sfx_enabled", true))
	sfx_toggle.toggled.connect(func(on: bool): SaveManager.set_setting("sfx_enabled", on))
	panel.add_child(sfx_toggle)

	var shake_toggle := UIKit.checkbox("屏幕震动")
	shake_toggle.position = Vector2(34, 232)
	shake_toggle.button_pressed = bool(SaveManager.setting("screen_shake", true))
	shake_toggle.toggled.connect(func(on: bool): SaveManager.set_setting("screen_shake", on))
	panel.add_child(shake_toggle)

	var divider := UIKit.separator(372, Color(0.2, 0.42, 0.52, 0.5))
	divider.position = Vector2(34, 286)
	panel.add_child(divider)

	var stats: Dictionary = SaveManager.data.get("stats", {})
	_stats_label = UIKit.label(
		"累计游玩 %d 次    总击杀 %d" % [int(stats.get("total_plays", 0)), int(stats.get("total_kills", 0))],
		12, UIKit.MUTED)
	_stats_label.position = Vector2(34, 302)
	panel.add_child(_stats_label)

	var global_label := UIKit.label("历史最高分 " + UIKit.format_score(SaveManager.high_score()), 12, UIKit.MUTED)
	global_label.position = Vector2(34, 326)
	panel.add_child(global_label)

	var reset := UIKit.button("重置存档", Vector2(372, 46), UIKit.RED)
	reset.position = Vector2(34, 380)
	reset.pressed.connect(_confirm_reset)
	panel.add_child(reset)

	var close := UIKit.button("关闭", Vector2(372, 46), UIKit.CYAN)
	close.position = Vector2(34, 440)
	close.pressed.connect(_close_settings)
	panel.add_child(close)

	var tip := UIKit.label("存档损坏时会自动回退默认值，不会崩溃", 11, UIKit.DIM)
	tip.position = Vector2(34, 500)
	panel.add_child(tip)


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
		_reset_dialog.title = "重置存档"
		_reset_dialog.dialog_text = "将清除最高分、关卡解锁进度与全部统计数据。\n此操作不可撤销，确定继续？"
		_reset_dialog.ok_button_text = "确认重置"
		_reset_dialog.cancel_button_text = "取消"
		_reset_dialog.confirmed.connect(_do_reset)
		add_child(_reset_dialog)
	_reset_dialog.popup_centered()


func _do_reset() -> void:
	SaveManager.reset()
	AudioManager.apply_settings()
	if _hi_label != null:
		_hi_label.text = "历史最高分  " + UIKit.format_score(SaveManager.high_score())
	if _stats_label != null:
		_stats_label.text = "累计游玩 0 次    总击杀 0"
	AudioManager.play("click", 0.8, -4.0)


func _close_settings() -> void:
	if _settings_box != null:
		_settings_box.queue_free()
		_settings_box = null
	_set_chrome_visible(true)
	if _hi_label != null:
		_hi_label.text = "历史最高分  " + UIKit.format_score(SaveManager.high_score())
	AudioManager.play("click", 1.1, -6.0)


## 设置面板打开时隐藏面板下方的主菜单小字，避免透出叠字。
func _set_chrome_visible(on: bool) -> void:
	if _hi_label != null:
		_hi_label.visible = on
	if _footer != null:
		_footer.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings_box != null:
			_close_settings()
