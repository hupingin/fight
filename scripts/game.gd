## 关卡主控：生成敌人、波次、Boss、计分与结算
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/player_bullet.tscn")
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const SPACE_BG := preload("res://scripts/fx/space_bg.gd")

var level: Dictionary = {}
var level_id := 1
var difficulty: String = LevelData.DEFAULT_DIFFICULTY
var diff: Dictionary = {}

var score := 0
var kills := 0
var elapsed := 0.0
var state := "playing"          # playing / paused / over
var boss_spawned := false
var boss_defeated := false
var boss: Node = null
var waves_fired: Array = []
var spawn_timer := 1.5
var last_hp := 100

var player: Node = null
var hud: CanvasLayer
var camera: Camera2D
var enemies_root: Node2D
var bullets_root: Node2D
var ebullets_root: Node2D
var fx_root: Node2D
var bg: Control
var starfield: Node2D

var _shake := 0.0
var _ending := false


func _ready() -> void:
	add_to_group("game")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Engine.time_scale = 1.0

	level_id = clampi(GameState.current_level_id, 1, maxi(1, LevelData.level_count()))
	level = LevelData.level(level_id)
	if level.is_empty():
		push_error("[Game] 找不到关卡配置 level_id=%d" % level_id)
	difficulty = GameState.difficulty
	diff = LevelData.difficulty(difficulty)

	_build_world()
	_spawn_player()
	_build_hud()
	_begin()


# ---------------------------------------------------------------- 场景搭建
func _build_world() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "Background"
	bg_layer.layer = -100
	add_child(bg_layer)

	var bg_cfg: Dictionary = level.get("background", {})
	bg = Control.new()
	bg.set_script(SPACE_BG)
	bg_layer.add_child(bg)
	bg.setup(str(bg_cfg.get("top", "#08131f")), str(bg_cfg.get("bottom", "#000000")),
		str(bg_cfg.get("star", "#7fc3ff")), 1.0)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(270, 480)
	add_child(camera)
	camera.make_current()

	enemies_root = _make_root("Enemies")
	bullets_root = _make_root("PlayerBullets")
	ebullets_root = _make_root("EnemyBullets")
	fx_root = _make_root("FX")


func _make_root(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	add_child(root)
	return root


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(270, 820)
	player.health_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	add_child(player)


func _build_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.retry_pressed.connect(_on_retry)
	hud.next_pressed.connect(_on_next)
	hud.menu_pressed.connect(_to_menu)
	hud.pause_resume.connect(_resume)
	hud.pause_restart.connect(_on_retry)
	hud.pause_menu.connect(_to_menu)
	hud.set_level_text(level_id, str(level.get("name", "")), difficulty)
	hud.set_hi(SaveManager.high_score())
	hud.set_score(0)
	hud.set_hp(int(player.max_hp), int(player.max_hp))
	hud.set_goal_text(_goal_text())


func _begin() -> void:
	hud.banner("LV.%02d  %s" % [level_id, str(level.get("name", ""))],
		"%s · %s" % [str(level.get("subtitle", level.get("brief", ""))), LevelData.difficulty_label(difficulty) + "难度"], 1.9)
	hud.fade_hint(6.5)
	spawn_timer = 1.2


# ---------------------------------------------------------------- 主循环
func _process(delta: float) -> void:
	_update_shake(delta)
	if state != "playing":
		return
	elapsed += delta
	if bg != null:
		bg.set_speed(1.0 + minf(1.4, elapsed / 55.0))
	_update_spawning(delta)
	_update_waves()
	_maybe_spawn_boss()
	_check_goal()
	hud.set_goal_text(_goal_text())


func _update_shake(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 26.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func _update_spawning(delta: float) -> void:
	if is_instance_valid(boss):
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if _alive_enemies() < int(level.get("max_alive", 8)):
		_spawn_random()
	spawn_timer = _current_interval()


func _current_interval() -> float:
	var config: Dictionary = level.get("spawn_interval", {})
	var start := float(config.get("start", 1.5))
	var end := float(config.get("end", 0.8))
	var estimate := maxf(4.0, float(level.get("estimate", 60.0)))
	var t := clampf(elapsed / estimate, 0.0, 1.0)
	return lerpf(start, end, t) * randf_range(0.85, 1.2) * float(diff.get("spawn_interval", 1.0))


func _spawn_random() -> void:
	var pool: Array = level.get("enemy_pool", ["viper"])
	if pool.is_empty():
		return
	var enemy_id := str(pool[randi() % pool.size()])
	_spawn_enemy(enemy_id, Vector2(randf_range(64.0, 476.0), -60.0))


func _spawn_enemy(enemy_id: String, spawn_pos: Vector2) -> Node:
	var config: Dictionary = LevelData.enemy(enemy_id).duplicate(true)
	if config.is_empty():
		return null
	config["hp"] = float(config.get("hp", 3)) * float(level.get("hp_multiplier", 1.0)) * float(diff.get("enemy_hp", 1.0))
	config["speed"] = float(config.get("speed", 100)) * float(level.get("speed_multiplier", 1.0)) * float(diff.get("enemy_speed", 1.0))
	config["score"] = int(round(float(config.get("score", 100)) * (1.0 + 0.35 * float(level_id - 1)) * float(diff.get("score", 1.0))))
	# 难度修正敌机开火间隔与弹速
	var raw_fire: Variant = config.get("fire", {"type": "none"})
	var fire: Dictionary = (raw_fire if typeof(raw_fire) == TYPE_DICTIONARY else {"type": "none"}).duplicate(true)
	if str(fire.get("type", "none")) != "none":
		fire["interval"] = float(fire.get("interval", 2.0)) * float(diff.get("enemy_fire_interval", 1.0))
		fire["speed"] = float(fire.get("speed", 220.0)) * float(diff.get("enemy_bullet_speed", 1.0))
	config["fire"] = fire
	var enemy := ENEMY_SCENE.instantiate()
	enemy.configure(config)
	enemy.position = spawn_pos
	enemies_root.add_child(enemy)
	return enemy


func _alive_enemies() -> int:
	var total := 0
	for child in enemies_root.get_children():
		if is_instance_valid(child) and child.is_in_group("enemies"):
			total += 1
	return total


func _update_waves() -> void:
	var waves: Array = level.get("waves", [])
	for i in waves.size():
		if waves_fired.has(i):
			continue
		var wave: Dictionary = waves[i]
		if elapsed < float(wave.get("at", 99999.0)):
			continue
		waves_fired.append(i)
		_fire_wave(wave)


func _fire_wave(wave: Dictionary) -> void:
	var count := int(wave.get("count", 3))
	var enemy_id := str(wave.get("enemy", "viper"))
	var gap := float(wave.get("gap", 0.22))
	var formation := str(wave.get("formation", "line"))
	var center := randf_range(170.0, 370.0)
	for i in count:
		if state != "playing":
			return
		var spawn_pos := Vector2(center, -60.0)
		var offset := float(i) - (float(count) - 1.0) * 0.5
		match formation:
			"line":
				spawn_pos.x = clampf(center + offset * 62.0, 50.0, 490.0)
			"column":
				spawn_pos.y = -60.0 - float(i) * 54.0
			"vee":
				spawn_pos.x = clampf(center + offset * 78.0, 50.0, 490.0)
				spawn_pos.y = -60.0 - absf(offset) * 46.0
		_spawn_enemy(enemy_id, spawn_pos)
		await get_tree().create_timer(gap, false).timeout


# ---------------------------------------------------------------- Boss
func _maybe_spawn_boss() -> void:
	if boss_spawned:
		return
	var boss_config: Variant = level.get("boss", null)
	if typeof(boss_config) != TYPE_DICTIONARY:
		return
	var trigger: Dictionary = level.get("boss_trigger", {})
	var trigger_type := str(trigger.get("type", "time"))
	var trigger_value := float(trigger.get("value", 10.0))
	var ready_to_spawn := false
	if trigger_type == "time":
		ready_to_spawn = elapsed >= trigger_value
	elif trigger_type == "kills":
		ready_to_spawn = kills >= int(trigger_value)
	if not ready_to_spawn:
		return
	boss_spawned = true
	_spawn_boss(boss_config)


func _spawn_boss(boss_config: Dictionary) -> void:
	var scaled := boss_config.duplicate(true)
	scaled["hp"] = float(scaled.get("hp", 1000.0)) * float(diff.get("boss_hp", 1.0))
	scaled["score"] = int(round(float(scaled.get("score", 6000)) * float(diff.get("score", 1.0))))
	var raw_phases: Variant = scaled.get("phases", [])
	if typeof(raw_phases) == TYPE_ARRAY:
		var phases: Array = []
		for raw in raw_phases:
			var phase: Dictionary = (raw if typeof(raw) == TYPE_DICTIONARY else {}).duplicate(true)
			phase["interval"] = float(phase.get("interval", 1.5)) * float(diff.get("boss_fire_interval", 1.0))
			phase["speed"] = float(phase.get("speed", 180.0)) * float(diff.get("boss_bullet_speed", 1.0))
			phases.append(phase)
		scaled["phases"] = phases
	boss = BOSS_SCENE.instantiate()
	boss.configure(scaled)
	boss.position = Vector2(270, -150)
	boss.health_changed.connect(func(current, maximum): hud.update_boss(current, maximum))
	boss.defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(_on_boss_phase)
	enemies_root.add_child(boss)
	hud.show_boss(str(boss_config.get("name", "BOSS")), float(boss.max_hp))
	hud.banner("警 告", "母舰接近 · " + str(boss_config.get("name", "")), 1.5)
	AudioManager.play("warn", 0.8, -3.0)
	shake(9.0)


func _on_boss_phase(index: int, _total: int) -> void:
	hud.banner("阶段 %d" % (index + 1), "母舰火力模式切换", 1.1)


func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	hud.hide_boss()
	hud.banner("母舰击毁", "BOSS DESTROYED", 1.2)
	await get_tree().create_timer(1.5, false).timeout
	_complete()


# ---------------------------------------------------------------- 玩家回调
func _on_player_hp(current: int, maximum: int) -> void:
	last_hp = current
	if hud != null:
		hud.set_hp(current, maximum)


func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	state = "over"
	AudioManager.play("gameover", 0.9)
	hud.banner("机体损毁", "MISSION FAILED", 1.2)
	await get_tree().create_timer(1.8, false).timeout
	_finish(false)


# ---------------------------------------------------------------- 计分 / 特效
func add_score(points: int) -> void:
	score += points
	hud.set_score(score)
	if score > SaveManager.high_score():
		hud.set_hi(score)


func on_enemy_killed(where: Vector2, points: int) -> void:
	kills += 1
	add_score(points)
	spawn_popup(where, "+" + UIKit.format_score(points), UIKit.CYAN)


func spawn_popup(where: Vector2, text: String, color: Color) -> void:
	var label := UIKit.label(text, 15, color)
	label.position = where + Vector2(-18, -12)
	label.z_index = 40
	fx_root.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48.0, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.chain().tween_callback(label.queue_free)


func spawn_player_bullet(where: Vector2, damage: int) -> void:
	_spawn_player_bullet_deferred.call_deferred(where, damage)


func _spawn_player_bullet_deferred(where: Vector2, damage: int) -> void:
	var bullet_def := LevelData.bullet("player_plasma")
	var bullet := PLAYER_BULLET_SCENE.instantiate()
	bullets_root.add_child(bullet)
	bullet.global_position = where
	bullet.damage = damage
	bullet.speed = 820.0
	bullet.configure(str(bullet_def.get("texture", "res://assets/player-bullet-01-plasma.svg")),
		float(bullet_def.get("radius", 5.0)))


func spawn_enemy_bullet(where: Vector2, direction: Vector2, bullet_id: String, bullet_speed: float, damage: int) -> void:
	# 可能在物理信号回调链中被调用，必须延迟到物理刷新之外再创建碰撞体
	_spawn_enemy_bullet_deferred.call_deferred(where, direction, bullet_id, bullet_speed, damage)


func _spawn_enemy_bullet_deferred(where: Vector2, direction: Vector2, bullet_id: String, bullet_speed: float, damage: int) -> void:
	var bullet_def := LevelData.bullet(bullet_id)
	if bullet_def.is_empty():
		bullet_def = LevelData.bullet("orb")
	var bullet := ENEMY_BULLET_SCENE.instantiate()
	ebullets_root.add_child(bullet)
	bullet.global_position = where
	bullet.configure(bullet_def, direction, bullet_speed, damage)


func spawn_explosion(where: Vector2, radius_value: float, tint: Color) -> void:
	fx_root.add_child(Explosion.create(where, radius_value, tint))


func shake(amount: float) -> void:
	if not bool(SaveManager.setting("screen_shake", true)):
		return
	_shake = maxf(_shake, amount)


func flash(color: Color) -> void:
	if hud != null:
		hud.flash(color)


# ---------------------------------------------------------------- 目标 / 结算
func _goal_text() -> String:
	var goal: Dictionary = level.get("goal", {})
	match str(goal.get("type", "kills")):
		"kills":
			return "目标 · 击落 %d / %d" % [kills, int(goal.get("value", 20))]
		"survive":
			return "目标 · 生存 %s / %s" % [UIKit.format_time(elapsed), UIKit.format_time(float(goal.get("value", 60)))]
		"boss":
			return "目标 · 击毁 " + str(level.get("name", "BOSS"))
	return ""


func _check_goal() -> void:
	if _ending:
		return
	var goal: Dictionary = level.get("goal", {})
	match str(goal.get("type", "kills")):
		"kills":
			if kills >= int(goal.get("value", 20)):
				_complete()
		"survive":
			if elapsed >= float(goal.get("value", 60)):
				_complete()


func _complete() -> void:
	if _ending:
		return
	_ending = true
	state = "over"
	AudioManager.play("clear", 1.0)
	hud.banner("关卡完成", "MISSION COMPLETE", 1.1)
	for bullet in ebullets_root.get_children():
		if is_instance_valid(bullet):
			bullet.queue_free()
	await get_tree().create_timer(1.7, false).timeout
	_finish(true)


func _finish(cleared: bool) -> void:
	var bonus := 0
	if cleared:
		bonus = 1000 + last_hp * 20 + level_id * 500
	add_score(bonus)

	var info := SaveManager.submit_run(level_id, difficulty, score, cleared, kills, elapsed)
	var par_score := maxf(1.0, float(level.get("par_score", 5000)))
	var rank := "D"
	if cleared:
		var ratio := float(score) / par_score
		rank = "C"
		if ratio >= 1.7:
			rank = "S"
		elif ratio >= 1.2:
			rank = "A"
		elif ratio >= 0.85:
			rank = "B"

	var can_next := cleared and level_id < LevelData.level_count()
	hud.show_result({
		"cleared": cleared,
		"level_name": "LV.%02d  %s · %s" % [level_id, str(level.get("name", "")), LevelData.difficulty_label(difficulty)],
		"score": score,
		"best": int(info.get("best", 0)),
		"new_record": bool(info.get("new_record", false)),
		"kills": kills,
		"time": elapsed,
		"bonus": bonus,
		"rank": rank,
		"can_next": can_next,
	})
	get_tree().paused = true


# ---------------------------------------------------------------- 流程控制
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _ending:
			_toggle_pause()


func _toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		get_tree().paused = true
		hud.show_pause()
		AudioManager.play("click", 0.9, -6.0)
	elif state == "paused":
		_resume()


func _resume() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	state = "playing"
	camera.offset = Vector2.ZERO
	hud.hide_pause()
	AudioManager.play("click", 1.1, -6.0)


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_next() -> void:
	GameState.start_level(level_id + 1)
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
