## 选关界面：难度切换（容易/中等/困难）+ 锁定 / 已解锁 / 已通关 与每关最高分
extends Control

const SPACE_BG := preload("res://scripts/fx/space_bg.gd")

var _difficulty := LevelData.DEFAULT_DIFFICULTY
var _content: Control


func _ready() -> void:
	get_tree().paused = false
	AudioManager.start_bgm()
	var saved := str(SaveManager.setting("last_difficulty", LevelData.DEFAULT_DIFFICULTY))
	if LevelData.is_difficulty(saved):
		_difficulty = saved
	_build()


func _build() -> void:
	var bg := Control.new()
	bg.set_script(SPACE_BG)
	add_child(bg)
	bg.setup("#060f18", "#000000", "#7fc3ff", 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var back := UIKit.button("‹ 返回", Vector2(96, 40), UIKit.MUTED)
	back.position = Vector2(24, 26)
	back.add_theme_font_size_override("font_size", 15)
	back.pressed.connect(_go_back)
	add_child(back)

	var title := UIKit.glow_label("选 择 关 卡", 30, UIKit.CYAN)
	title.position = Vector2(0, 34)
	title.size = Vector2(540, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var subtitle := UIKit.label("S E L E C T   M I S S I O N", 11, UIKit.MUTED)
	subtitle.position = Vector2(0, 82)
	subtitle.size = Vector2(540, 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_build_content()


## 难度切换器 + 关卡卡片 + 进度摘要，切换难度时整段重建
func _build_content() -> void:
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	_build_difficulty_selector()

	var levels: Array = LevelData.levels()
	# 关卡卡片放入滚动容器，关卡多时上下滑动浏览
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 152)
	scroll.size = Vector2(540, 706)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_style_scrollbar(scroll)

	var cards := Control.new()
	cards.custom_minimum_size = Vector2(540, float(levels.size()) * 126.0 + 8.0)
	cards.size = cards.custom_minimum_size
	scroll.add_child(cards)

	var y := 6.0
	for lv in levels:
		var level_id := int(lv.get("level_id", 1))
		_build_card(cards, lv, level_id, y)
		y += 126.0

	var unlocked := SaveManager.unlocked_level()
	var cleared_count := 0
	for lv in levels:
		if bool(SaveManager.level_record(int(lv.get("level_id", 1)), _difficulty).get("cleared", false)):
			cleared_count += 1

	var progress := UIKit.label("%s难度已通关 %d / %d      已解锁 %d 关" % [
		LevelData.difficulty_label(_difficulty), cleared_count, levels.size(), mini(unlocked, levels.size())],
		12, UIKit.MUTED)
	progress.position = Vector2(0, 872)
	progress.size = Vector2(540, 20)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(progress)

	var tip := UIKit.label("通关任意难度即解锁下一关 · 关卡较多时上下滑动浏览", 11, UIKit.DIM)
	tip.position = Vector2(0, 896)
	tip.size = Vector2(540, 20)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tip)


func _build_difficulty_selector() -> void:
	var caption := UIKit.label("难度", 12, UIKit.DIM)
	caption.position = Vector2(28, 112)
	caption.size = Vector2(60, 26)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(caption)

	var ids: Array = LevelData.difficulty_ids()
	var width := 128.0
	var gap := 12.0
	var x := 92.0
	for id in ids:
		var diff_id := str(id)
		var selected: bool = diff_id == _difficulty
		var color := LevelData.difficulty_color(diff_id)
		var button := UIKit.button(LevelData.difficulty_label(diff_id), Vector2(width, 34),
			color if selected else UIKit.DIM)
		button.position = Vector2(x, 108)
		button.add_theme_font_size_override("font_size", 15)
		if selected:
			button.add_theme_stylebox_override("normal", UIKit.box(
				Color(color.r, color.g, color.b, 0.22), color, 2, 5))
		button.pressed.connect(_select_difficulty.bind(diff_id))
		_content.add_child(button)
		x += width + gap


func _select_difficulty(id: String) -> void:
	if id == _difficulty:
		return
	_difficulty = id
	SaveManager.set_setting("last_difficulty", id)
	AudioManager.play("click", 1.1, -6.0)
	_build_content()


func _build_card(parent: Control, level: Dictionary, level_id: int, y: float) -> void:
	var unlocked := SaveManager.is_level_unlocked(level_id)
	var record := SaveManager.level_record(level_id, _difficulty)
	var cleared := bool(record.get("cleared", false))
	var best := int(record.get("high_score", 0))
	var diff_color := LevelData.difficulty_color(_difficulty)

	var accent := diff_color
	var border := Color(diff_color.r, diff_color.g, diff_color.b, 0.55)
	var bg := Color(0.03, 0.075, 0.1, 0.9)
	if cleared:
		border = Color(0.34, 0.9, 0.65, 0.6)
		bg = Color(0.03, 0.09, 0.08, 0.9)
	elif not unlocked:
		accent = UIKit.DIM
		border = Color(0.18, 0.24, 0.3, 0.5)
		bg = Color(0.02, 0.03, 0.04, 0.85)

	var card := Panel.new()
	card.position = Vector2(24, y)
	card.size = Vector2(492, 112)
	card.add_theme_stylebox_override("panel", UIKit.box(bg, border, 1, 6))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(card)

	var number := UIKit.label("%02d" % level_id, 32, accent)
	number.position = Vector2(22, 30)
	number.size = Vector2(60, 46)
	card.add_child(number)

	var name_text := str(level.get("name", "关卡"))
	var name_label := UIKit.label(name_text, 21, UIKit.TEXT if unlocked else UIKit.DIM)
	name_label.position = Vector2(86, 16)
	card.add_child(name_label)

	var goal := _goal_desc(level)
	var goal_label := UIKit.label(goal, 12, UIKit.MUTED if unlocked else UIKit.DIM)
	goal_label.position = Vector2(86, 48)
	card.add_child(goal_label)

	var best_text := "最高分 " + UIKit.format_score(best) if best > 0 else "尚无记录"
	var best_label := UIKit.label(best_text, 12, UIKit.AMBER if best > 0 else UIKit.DIM)
	best_label.position = Vector2(86, 72)
	card.add_child(best_label)

	var status_text := "未解锁"
	var status_color := UIKit.DIM
	if cleared:
		status_text = "已通关"
		status_color = UIKit.GREEN
	elif unlocked:
		status_text = "已解锁"
		status_color = diff_color
	var status := UIKit.label(status_text, 11, status_color)
	status.position = Vector2(346, 16)
	status.size = Vector2(120, 18)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(status)

	var play := UIKit.button("挑战" if unlocked else "锁定", Vector2(116, 42), accent if unlocked else UIKit.DIM)
	play.position = Vector2(350, 54)
	play.add_theme_font_size_override("font_size", 15)
	play.disabled = not unlocked
	if unlocked:
		play.pressed.connect(func():
			AudioManager.play("click", 1.0, -6.0)
			GameState.start_level(level_id, _difficulty)
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		)
	card.add_child(play)

	if cleared:
		var star := UIKit.label("★", 14, UIKit.GREEN)
		star.position = Vector2(196, 18)
		card.add_child(star)


## 纯黑背景上默认滚动条几乎不可见，换成细青色指示条
func _style_scrollbar(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.add_theme_stylebox_override("scroll", UIKit.box(Color(0.16, 0.32, 0.42, 0.35), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber", UIKit.box(Color(0.33, 0.78, 1.0, 0.55), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", UIKit.box(Color(0.45, 0.86, 1.0, 0.8), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", UIKit.box(Color(0.55, 0.92, 1.0, 0.9), Color(0, 0, 0, 0), 0, 3))


func _goal_desc(level: Dictionary) -> String:
	var goal: Dictionary = level.get("goal", {})
	match str(goal.get("type", "kills")):
		"kills":
			return "目标：击落 %d 架敌机" % int(goal.get("value", 20))
		"survive":
			return "目标：生存 %d 秒" % int(goal.get("value", 60))
		"boss":
			return "目标：击败关卡 Boss"
	return str(level.get("brief", ""))


func _go_back() -> void:
	AudioManager.play("click", 1.0, -6.0)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_go_back()
