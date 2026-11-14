## 敌机：数据驱动（血量/移速/移动方式/攻击方式），出屏自动销毁
class_name Enemy
extends Area2D

var data: Dictionary = {}
var hp := 3.0
var max_hp := 3.0
var speed := 100.0
var score_value := 100
var movement := "straight"
var params: Dictionary = {}
var fire: Dictionary = {}
var contact_damage := 25
var sprite_scale := 0.5

var _t := 0.0
var _base_x := 0.0
var _fire_timer := 1.0
var _hover_t := 0.0
var _warned := false
var _warn_line: Line2D
var _dead := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


func configure(config: Dictionary) -> void:
	data = config


func _ready() -> void:
	add_to_group("enemies")
	z_index = 6
	_apply_config()
	_base_x = position.x
	_fire_timer = randf_range(0.9, 2.2)
	if movement == "hover":
		_fire_timer = randf_range(0.6, 1.4)


func _apply_config() -> void:
	hp = float(data.get("hp", 3))
	max_hp = hp
	speed = float(data.get("speed", 100))
	score_value = int(data.get("score", 100))
	movement = str(data.get("movement", "straight"))
	contact_damage = int(data.get("contact_damage", 25))

	var raw_params: Variant = data.get("params", {})
	params = raw_params if typeof(raw_params) == TYPE_DICTIONARY else {}
	var raw_fire: Variant = data.get("fire", {"type": "none"})
	fire = raw_fire if typeof(raw_fire) == TYPE_DICTIONARY else {"type": "none"}

	sprite_scale = float(data.get("scale", 0.5))
	var texture_path := str(data.get("texture", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	sprite.scale = Vector2(sprite_scale, sprite_scale)

	var shape := CircleShape2D.new()
	shape.radius = 100.0 * sprite_scale * 0.34
	hit_shape.shape = shape


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_move(delta)
	if position.y > 1030.0:
		queue_free()
		return
	_update_fire(delta)


func _move(delta: float) -> void:
	var amp := float(params.get("amplitude", 60.0))
	match movement:
		"straight":
			position.y += speed * delta
		"sine":
			var freq := float(params.get("frequency", 1.5))
			position.y += speed * delta
			position.x = _base_x + sin(_t * freq * TAU) * amp
			position.x = clampf(position.x, 36.0, 504.0)
		"zigzag":
			var period := maxf(0.2, float(params.get("period", 1.0)))
			position.y += speed * delta
			position.x = _base_x + sin(_t / period * TAU) * amp
			position.x = clampf(position.x, 36.0, 504.0)
		"dive":
			speed += float(params.get("accel", 120.0)) * delta
			position.y += speed * delta
			position.x = _base_x + sin(_t * 2.2) * 22.0
		"hover":
			var hover_y := float(params.get("hover_y", 200.0))
			if position.y < hover_y:
				position.y = minf(hover_y, position.y + speed * delta)
			else:
				_hover_t += delta
				if _hover_t < float(params.get("hover_time", 4.0)):
					position.x = clampf(_base_x + sin(_t * 1.2) * 78.0, 44.0, 496.0)
				else:
					position.y += speed * delta
					position.x = move_toward(position.x, _base_x, 70.0 * delta)
		_:
			position.y += speed * delta


func _update_fire(delta: float) -> void:
	var fire_type := str(fire.get("type", "none"))
	if fire_type == "none":
		return
	if global_position.y < 24.0:
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var warn_time := float(fire.get("warn", 0.0))
	if warn_time > 0.0 and not _warned:
		_warned = true
		_show_warning(warn_time)
		_fire_timer = warn_time
		return
	_shoot(fire_type)
	_clear_warning()
	_warned = false
	_fire_timer = maxf(0.35, float(fire.get("interval", 2.0))) * randf_range(0.88, 1.15)


func _shoot(fire_type: String) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var bullet_id := str(fire.get("bullet", "orb"))
	var bullet_speed := float(fire.get("speed", 220.0))
	var bullet_damage := int(fire.get("damage", 10))
	var origin := global_position
	var down := Vector2.DOWN

	AudioManager.play("laser" if bullet_id == "laser" else "enemy_shoot", randf_range(0.92, 1.1), -9.0)

	match fire_type:
		"straight":
			game.spawn_enemy_bullet(origin + Vector2(0, 24), down, bullet_id, bullet_speed, bullet_damage)
		"twin":
			game.spawn_enemy_bullet(origin + Vector2(-18, 22), down, bullet_id, bullet_speed, bullet_damage)
			game.spawn_enemy_bullet(origin + Vector2(18, 22), down, bullet_id, bullet_speed, bullet_damage)
		"aimed":
			var player = game.get("player")
			var target: Vector2 = origin + down * 200.0
			if player != null and is_instance_valid(player):
				target = player.global_position
			var dir := (target - origin).normalized()
			game.spawn_enemy_bullet(origin + dir * 22.0, dir, bullet_id, bullet_speed, bullet_damage)
		"spread3":
			for angle in [-16.0, 0.0, 16.0]:
				game.spawn_enemy_bullet(origin + Vector2(0, 22), down.rotated(deg_to_rad(angle)), bullet_id, bullet_speed, bullet_damage)
		"fan5":
			for angle in [-40.0, -20.0, 0.0, 20.0, 40.0]:
				game.spawn_enemy_bullet(origin + Vector2(0, 20), down.rotated(deg_to_rad(angle)), bullet_id, bullet_speed, bullet_damage)
		"ring":
			for i in 12:
				var dir := Vector2.DOWN.rotated(TAU * float(i) / 12.0)
				game.spawn_enemy_bullet(origin, dir, bullet_id, bullet_speed, bullet_damage)


func _show_warning(duration: float) -> void:
	if _warn_line != null:
		return
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.3, 0.36, 0.8)
	var end_y := maxf(80.0, get_viewport_rect().size.y - global_position.y)
	line.points = PackedVector2Array([Vector2(0, 20), Vector2(0, end_y)])
	line.z_index = -1
	add_child(line)
	_warn_line = line
	var tween := create_tween().set_loops()
	tween.tween_property(line, "modulate:a", 0.12, duration * 0.5)
	tween.tween_property(line, "modulate:a", 1.0, duration * 0.5)
	AudioManager.play("warn", 1.5, -16.0)


func _clear_warning() -> void:
	if _warn_line != null and is_instance_valid(_warn_line):
		_warn_line.queue_free()
	_warn_line = null


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	AudioManager.play("hit", randf_range(0.9, 1.12), -11.0)
	if sprite != null and sprite.modulate.a > 0.0:
		sprite.modulate = Color(2.2, 2.2, 2.2)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		die(true)


func die(give_score: bool) -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	var game := get_tree().get_first_node_in_group("game")
	var blast := 24.0 + sprite_scale * 44.0
	if game != null:
		game.spawn_explosion(global_position, blast, Color(1.0, 0.66, 0.3))
		if give_score:
			game.on_enemy_killed(global_position, score_value)
	AudioManager.play("explode", randf_range(0.9, 1.15), -3.0)
	queue_free()


## 撞机：敌人同样被销毁，但不加分
func destroy_by_ram() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		game.spawn_explosion(global_position, 26.0 + sprite_scale * 30.0, Color(1.0, 0.5, 0.35))
	AudioManager.play("explode", 1.15, -6.0)
	queue_free()
