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
var hold_keys: Array = []
var auto_kill := false
var god_mode := false
var scroll_y := -1.0
var click_point := Vector2(-1, -1)


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
		_click_later()

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


## 自查用：点击指定屏幕坐标（先等 UI 构建完成）
func _click_later() -> void:
	await get_tree().create_timer(0.6).timeout
	var motion := InputEventMouseMotion.new()
	motion.position = click_point
	motion.global_position = click_point
	Input.parse_input_event(motion)

	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_point
		event.global_position = click_point
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
