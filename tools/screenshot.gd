## 开发期截图工具（仅用于自查画面，不参与游戏流程）
## 用法：
##   godot --path . res://tools/screenshot.tscn -- --scene=res://scenes/game.tscn --wait=3 --out=D:/shot.png \
##         --level=1 --hold=SPACE,LEFT --shot-at=2.0,2.6
extends Node

var target_scene := "res://scenes/main_menu.tscn"
var out_path := "user://shot.png"
var wait_time := 2.0
var level := 0
var difficulty := ""
var lang_code := ""
var hold_keys: Array = []
var auto_kill := false
var god_mode := false
var scroll_y := -1.0
var click_point := Vector2(-1, -1)
var click_point2 := Vector2(-1, -1)
var hit_amount := 0
var ram_test := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			target_scene = arg.substr(8)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--wait="):
			wait_time = float(arg.substr(7))
		elif arg.begins_with("--level="):
			level = int(arg.substr(8))
		elif arg.begins_with("--difficulty="):
			difficulty = arg.substr(13).strip_edges()
		elif arg.begins_with("--lang="):
			lang_code = arg.substr(7).strip_edges()
		elif arg.begins_with("--hold="):
			for key in arg.substr(7).split(","):
				hold_keys.append(key.strip_edges())
		elif arg == "--killall":
			auto_kill = true
		elif arg == "--god":
			god_mode = true
		elif arg.begins_with("--scroll="):
			scroll_y = float(arg.substr(9))
		elif arg.begins_with("--click="):
			var parts := arg.substr(8).split(",")
			if parts.size() == 2:
				click_point = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--click2="):
			var parts := arg.substr(9).split(",")
			if parts.size() == 2:
				click_point2 = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--hit="):
			hit_amount = int(arg.substr(6))
		elif arg == "--ram":
			ram_test = true

	if lang_code != "" and I18n.is_valid_locale(lang_code):
		I18n.set_locale(lang_code, false)

	if level > 0:
		GameState.start_level(level, difficulty)

	var packed: PackedScene = load(target_scene)
	if packed == null:
		push_error("无法加载 " + target_scene)
		get_tree().quit()
		return
	add_child(packed.instantiate())

	for key in hold_keys:
		_press(key)

	if auto_kill:
		_auto_kill_loop()

	if god_mode:
		_god_loop()

	if scroll_y >= 0.0:
		_apply_scroll()

	if click_point.x >= 0.0:
		_click_later(click_point, 0.6)
	if click_point2.x >= 0.0:
		_click_later(click_point2, 1.4)

	if hit_amount > 0:
		_hit_probe()

	if ram_test:
		_ram_probe()

	await get_tree().create_timer(wait_time).timeout
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	print("[shot] %s -> %s (%s) %dx%d" % [target_scene, out_path, err, image.get_width(), image.get_height()])
	get_tree().quit()


func _press(key_name: String) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = OS.find_keycode_from_string(key_name)
	event.keycode = event.physical_keycode
	event.pressed = true
	Input.parse_input_event(event)


## 自查用：强制玩家受击，并逐秒打印帧推进情况（定位卡死）
func _hit_probe() -> void:
	await get_tree().create_timer(1.6).timeout
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		print("[hit] no game node")
		return
	var p: Variant = game.get("player")
	if p == null or not is_instance_valid(p):
		print("[hit] no player")
		return
	print("[hit] BEFORE hp=%s invincible=%s" % [p.hp, p.invincible])
	p.take_damage(hit_amount)
	print("[hit] AFTER hp=%s invincible=%s" % [p.hp, p.invincible])
	var last_frames := Engine.get_frames_drawn()
	for i in int(wait_time):
		await get_tree().create_timer(1.0).timeout
		var frames := Engine.get_frames_drawn()
		var hp_text := "dead" if not is_instance_valid(p) else str(p.hp)
		print("[tick] %d elapsed=%.1f hp=%s frames=%d" % [i, float(game.elapsed), hp_text, frames - last_frames])
		last_frames = frames


## 自查用：让带预警激光的敌机在预警期间撞上玩家，验证受击/撞机清理链路
func _ram_probe() -> void:
	await get_tree().create_timer(1.8).timeout
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var p: Variant = game.get("player")
	if p == null or not is_instance_valid(p):
		return
	var enemy: Node = game._spawn_enemy("twinfang", p.global_position + Vector2(0, -160))
	if enemy == null:
		return
	enemy.call("_show_warning", 0.8)
	print("[ram] warning line active, hp before=%s" % p.hp)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(enemy):
		enemy.global_position = p.global_position
	await get_tree().create_timer(0.4).timeout
	print("[ram] hp after=%s invincible=%s" % [p.hp, p.invincible])


## 自查用：点击指定屏幕坐标（先等 UI 构建完成）
func _click_later(point: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)

	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## 自查用：周期性秒杀场上敌人，驱动通关流程
func _auto_kill_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(0.8).timeout
		for node in get_tree().get_nodes_in_group("enemies"):
			if node.has_method("take_damage"):
				node.take_damage(99999.0)


## 自查用：让玩家持续处于保护状态，便于观察后期 Boss 阶段
func _god_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(0.5).timeout
		var game := get_tree().get_first_node_in_group("game")
		if game == null:
			continue
		var player: Variant = game.get("player")
		if player != null and is_instance_valid(player) and player.has_method("spawn_protection"):
			player.spawn_protection(2.0)


## 自查用：滚动长列表到指定位置
func _apply_scroll() -> void:
	await get_tree().create_timer(0.8).timeout
	var target := _find_scroll(get_tree().current_scene)
	if target != null:
		target.scroll_vertical = int(scroll_y)


func _find_scroll(node: Node) -> ScrollContainer:
	if node == null:
		return null
	if node is ScrollContainer:
		return node as ScrollContainer
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null
