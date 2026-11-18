## 战斗 HUD：分数 / 生命 / 关卡目标 / Boss 血条 / 横幅 / 暂停 / 结算
extends CanvasLayer

signal pause_resume
signal pause_restart
signal pause_menu
signal retry_pressed
signal next_pressed
signal menu_pressed

const W := 540.0
const H := 960.0

var _root: Control
var _score_label: Label
var _hi_label: Label
var _level_label: Label
var _goal_label: Label
var _hull_fill: ColorRect
var _hull_value: Label
var _hull_width := 150.0

var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _boss_bar_width := 320.0

var _banner_box: Control
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween

var _flash: ColorRect
var _hint: Label
var _hint_tween: Tween

var _pause_box: Control
var _result_box: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top()
	_build_boss_bar()
	_build_banner()
	_build_flash()
	_build_hint()


# ---------------------------------------------------------------- 构建
func _build_top() -> void:
	var score_caption := UIKit.label("S C O R E", 11, UIKit.MUTED)
	score_caption.position = Vector2(26, 16)
	_root.add_child(score_caption)

	_score_label = UIKit.glow_label("0", 36, UIKit.TEXT)
	_score_label.position = Vector2(24, 30)
	_root.add_child(_score_label)

	_hi_label = UIKit.label("HI 0", 12, UIKit.MUTED)
	_hi_label.position = Vector2(26, 82)
	_root.add_child(_hi_label)

	var hull_caption := UIKit.label("HULL", 10, UIKit.MUTED)
	hull_caption.position = Vector2(26, 108)
	_root.add_child(hull_caption)

	var bars := UIKit.bar(Vector2(_hull_width, 10), UIKit.GREEN)
	var hull_back: Panel = bars[0]
	hull_back.position = Vector2(66, 110)
	_root.add_child(hull_back)
	_hull_fill = bars[1]

	_hull_value = UIKit.label("100", 12, UIKit.MUTED)
	_hull_value.position = Vector2(226, 103)
	_root.add_child(_hull_value)

	_level_label = UIKit.label("", 15, UIKit.CYAN)
	_level_label.position = Vector2(24, 16)
	_level_label.size = Vector2(W - 50, 22)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_level_label)

	_goal_label = UIKit.label("", 12, UIKit.MUTED)
	_goal_label.position = Vector2(24, 42)
	_goal_label.size = Vector2(W - 50, 20)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_goal_label)


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.position = Vector2(0, 54)
	_boss_box.size = Vector2(W, 48)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)

	_boss_name = UIKit.label("", 12, UIKit.RED)
	_boss_name.position = Vector2(0, 0)
	_boss_name.size = Vector2(W, 18)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)

	var bars := UIKit.bar(Vector2(_boss_bar_width, 11), UIKit.RED)
	var back: Panel = bars[0]
	back.position = Vector2((W - _boss_bar_width) * 0.5, 20)
	_boss_box.add_child(back)
	_boss_fill = bars[1]


func _build_banner() -> void:
	_banner_box = Control.new()
	_banner_box.position = Vector2(0, 300)
	_banner_box.size = Vector2(W, 90)
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.modulate.a = 0.0
	_root.add_child(_banner_box)

	_banner_title = UIKit.glow_label("", 34, UIKit.CYAN)
	_banner_title.position = Vector2(0, 0)
	_banner_title.size = Vector2(W, 44)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_title)

	_banner_sub = UIKit.label("", 13, UIKit.MUTED)
	_banner_sub.position = Vector2(0, 50)
	_banner_sub.size = Vector2(W, 20)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_sub)


func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1, 0, 0, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)


func _build_hint() -> void:
	_hint = UIKit.label(I18n.t("hud.hint"), 12, UIKit.MUTED)
	_hint.position = Vector2(0, H - 42)
	_hint.size = Vector2(W, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)


# ---------------------------------------------------------------- 更新接口
func set_score(value: int) -> void:
	_score_label.text = UIKit.format_score(value)


func set_hi(value: int) -> void:
	_hi_label.text = "HI " + UIKit.format_score(value)


func set_hp(current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / maxf(1.0, float(maximum)), 0.0, 1.0)
	_hull_fill.size.x = maxf(0.0, (_hull_width - 4.0) * ratio)
	_hull_value.text = "%d%%" % int(round(ratio * 100.0))
	var color := UIKit.GREEN
	if ratio <= 0.3:
		color = UIKit.RED
	elif ratio <= 0.6:
		color = UIKit.AMBER
	_hull_fill.color = color


func set_level_text(level_id: int, level_name: String, difficulty: String = "") -> void:
	if difficulty != "" and LevelData.is_difficulty(difficulty):
		_level_label.text = "LV.%02d  %s · %s" % [level_id, level_name, LevelData.difficulty_label(difficulty)]
	else:
		_level_label.text = "LV.%02d  %s" % [level_id, level_name]


func set_goal_text(text: String) -> void:
	_goal_label.text = text


func show_boss(boss_name: String, maximum: float) -> void:
	_boss_box.visible = true
	_boss_name.text = boss_name
	_boss_fill.size.x = _boss_bar_width - 4.0
	_boss_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_boss_box, "modulate:a", 1.0, 0.35)


func update_boss(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	_boss_fill.size.x = maxf(0.0, (_boss_bar_width - 4.0) * ratio)


func hide_boss() -> void:
	_boss_box.visible = false


func banner(title: String, subtitle: String = "", hold: float = 1.9) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_box.modulate.a = 0.0
	_banner_box.scale = Vector2(1, 1)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.28)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.5)


func flash(color: Color) -> void:
	_flash.color = color
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.3)


func fade_hint(delay: float = 5.0) -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(delay)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------- 暂停
func show_pause() -> void:
	if _pause_box != null:
		return
	_pause_box = Control.new()
	_pause_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pause_box)

	var dim := UIKit.fullscreen_dim(Color(0, 0, 0, 0.78))
	_pause_box.add_child(dim)

	var panel := UIKit.panel(UIKit.CYAN)
	panel.position = Vector2(60, 300)
	panel.size = Vector2(420, 360)
	_pause_box.add_child(panel)

	var title := UIKit.glow_label(I18n.t("hud.pause_title"), 30, UIKit.CYAN)
	title.position = Vector2(0, 34)
	title.size = Vector2(420, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var tip := UIKit.label(I18n.t("hud.pause_tip"), 12, UIKit.MUTED)
	tip.position = Vector2(0, 80)
	tip.size = Vector2(420, 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tip)

	var resume := UIKit.button(I18n.t("hud.resume"), Vector2(320, 50), UIKit.CYAN)
	resume.position = Vector2(50, 130)
	resume.pressed.connect(func(): pause_resume.emit())
	panel.add_child(resume)

	var restart := UIKit.button(I18n.t("hud.restart"), Vector2(320, 50), UIKit.AMBER)
	restart.position = Vector2(50, 196)
	restart.pressed.connect(func(): pause_restart.emit())
	panel.add_child(restart)

	var menu := UIKit.button(I18n.t("hud.back_to_levels"), Vector2(320, 50), UIKit.MUTED)
	menu.position = Vector2(50, 262)
	menu.pressed.connect(func(): pause_menu.emit())
	panel.add_child(menu)


func hide_pause() -> void:
	if _pause_box != null:
		_pause_box.queue_free()
		_pause_box = null


# ---------------------------------------------------------------- 结算
func show_result(info: Dictionary) -> void:
	hide_pause()
	if _result_box != null:
		_result_box.queue_free()
	_result_box = Control.new()
	_result_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_result_box)

	var dim := UIKit.fullscreen_dim(Color(0, 0, 0, 0.84))
	_result_box.add_child(dim)

	var cleared := bool(info.get("cleared", false))
	var accent := UIKit.GREEN if cleared else UIKit.RED
	var panel := UIKit.panel(accent, Color(0.025, 0.055, 0.075, 0.98))
	panel.position = Vector2(38, 178)
	panel.size = Vector2(464, 604)
	_result_box.add_child(panel)

	var title := UIKit.glow_label(I18n.t("hud.result_clear") if cleared else I18n.t("hud.result_fail"), 30, accent)
	title.position = Vector2(0, 26)
	title.size = Vector2(464, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var sub := UIKit.label(str(info.get("level_name", "")), 13, UIKit.MUTED)
	sub.position = Vector2(0, 66)
	sub.size = Vector2(464, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	var rank := str(info.get("rank", "C"))
	var rank_color := UIKit.AMBER
	if rank == "S":
		rank_color = UIKit.CYAN
	elif rank == "A":
		rank_color = UIKit.GREEN
	elif rank == "B":
		rank_color = Color("#9fd4ff")
	var rank_label := UIKit.glow_label(rank, 46, rank_color)
	rank_label.position = Vector2(348, 92)
	rank_label.size = Vector2(86, 52)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(rank_label)

	var rank_caption := UIKit.label("RANK", 10, UIKit.MUTED)
	rank_caption.position = Vector2(348, 148)
	rank_caption.size = Vector2(86, 16)
	rank_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(rank_caption)

	var score_caption := UIKit.label(I18n.t("hud.score"), 12, UIKit.MUTED)
	score_caption.position = Vector2(20, 118)
	score_caption.size = Vector2(300, 20)
	panel.add_child(score_caption)

	var score_label := UIKit.glow_label(UIKit.format_score(int(info.get("score", 0))), 40, UIKit.TEXT)
	score_label.position = Vector2(18, 136)
	score_label.size = Vector2(320, 52)
	panel.add_child(score_label)

	var best := UIKit.label(I18n.t("hud.best") + "  " + UIKit.format_score(int(info.get("best", 0))), 13, UIKit.MUTED)
	best.position = Vector2(20, 196)
	best.size = Vector2(320, 20)
	panel.add_child(best)

	if bool(info.get("new_record", false)):
		var badge := UIKit.label(I18n.t("hud.new_record"), 12, UIKit.AMBER)
		badge.position = Vector2(20, 220)
		panel.add_child(badge)

	var line := UIKit.separator(424, Color(0.2, 0.42, 0.52, 0.5))
	line.position = Vector2(20, 250)
	panel.add_child(line)

	var rows := [
		[I18n.t("hud.kills"), str(info.get("kills", 0))],
		[I18n.t("hud.time"), UIKit.format_time(float(info.get("time", 0.0)))],
		[I18n.t("hud.bonus"), "+" + UIKit.format_score(int(info.get("bonus", 0)))],
	]
	for i in rows.size():
		var label := UIKit.label(str(rows[i][0]), 13, UIKit.MUTED)
		label.position = Vector2(24, 264 + i * 28)
		panel.add_child(label)
		var value := UIKit.label(str(rows[i][1]), 14, UIKit.TEXT)
		value.position = Vector2(0, 264 + i * 28)
		value.size = Vector2(420, 20)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(value)

	var buttons_y := 366
	var retry := UIKit.button(I18n.t("hud.retry"), Vector2(400, 52), UIKit.CYAN)
	retry.position = Vector2(32, buttons_y)
	retry.pressed.connect(func(): retry_pressed.emit())
	panel.add_child(retry)

	if bool(info.get("can_next", false)):
		var next := UIKit.button(I18n.t("hud.next"), Vector2(400, 52), UIKit.GREEN)
		next.position = Vector2(32, buttons_y + 62)
		next.pressed.connect(func(): next_pressed.emit())
		panel.add_child(next)
		var menu := UIKit.button(I18n.t("hud.back_to_levels"), Vector2(400, 46), UIKit.MUTED)
		menu.position = Vector2(32, buttons_y + 124)
		menu.pressed.connect(func(): menu_pressed.emit())
		panel.add_child(menu)
	else:
		var menu2 := UIKit.button(I18n.t("hud.back_to_levels"), Vector2(400, 52), UIKit.MUTED)
		menu2.position = Vector2(32, buttons_y + 62)
		menu2.pressed.connect(func(): menu_pressed.emit())
		panel.add_child(menu2)

	var fade := create_tween()
	_result_box.modulate.a = 0.0
	fade.tween_property(_result_box, "modulate:a", 1.0, 0.3)
