## Boss：独立血条 + 按血量分段的攻击阶段
class_name Boss
extends Area2D

signal health_changed(current: float, maximum: float)
signal phase_changed(index: int, total: int)
signal defeated

var data: Dictionary = {}
var hp := 1000.0
var max_hp := 1000.0
var phases: Array = []
var phase_index := 0
var contact_damage := 30
var score_value := 6000

var _t := 0.0
var _fire_timer := 2.0
var _entering := true
var _target_y := 190.0
var _dead := false
var _phase_flash := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


func configure(config: Dictionary) -> void:
	data = config


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	z_index = 8
	max_hp = float(data.get("hp", 1000.0))
	hp = max_hp
	contact_damage = int(data.get("contact_damage", 30))
	score_value = int(data.get("score", 6000))
	_target_y = float(data.get("enter_y", 190.0))
	var raw_phases: Variant = data.get("phases", [])
	phases = raw_phases if typeof(raw_phases) == TYPE_ARRAY and not (raw_phases as Array).is_empty() else [
		{"threshold": 1.0, "interval": 1.6, "pattern": "fan5", "bullet": "heavy", "speed": 180, "damage": 14, "move": "sway"}
	]
	var texture_path := str(data.get("texture", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	var scale_value := float(data.get("scale", 1.6))
	sprite.scale = Vector2(scale_value, scale_value)
	var shape := CircleShape2D.new()
	shape.radius = 100.0 * scale_value * 0.36
	hit_shape.shape = shape
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	if _entering:
		position.y = move_toward(position.y, _target_y, 130.0 * delta)
		if absf(position.y - _target_y) < 1.0:
			_entering = false
			_fire_timer = 1.2
		return

	var phase: Dictionary = phases[phase_index]
	var sway_speed := 1.0 if str(phase.get("move", "sway")) == "sway" else 1.9
	position.x = 270.0 + sin(_t * 0.72 * sway_speed) * 132.0
	position.y = _target_y + sin(_t * 1.35) * 12.0

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_shoot(phase)
		_fire_timer = maxf(0.4, float(phase.get("interval", 1.5)))


func _shoot(phase: Dictionary) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	var pattern := str(phase.get("pattern", "fan5"))
	var bullet_id := str(phase.get("bullet", "heavy"))
	var bullet_speed := float(phase.get("speed", 180.0))
	var bullet_damage := int(phase.get("damage", 14))
	var origin := global_position + Vector2(0, 46)
	AudioManager.play("enemy_shoot", randf_range(0.75, 0.9), -6.0)
	var down := Vector2.DOWN
	match pattern:
		"fan5":
			for angle in [-46.0, -23.0, 0.0, 23.0, 46.0]:
				game.spawn_enemy_bullet(origin, down.rotated(deg_to_rad(angle)), bullet_id, bullet_speed, bullet_damage)
		"spread3":
			for angle in [-18.0, 0.0, 18.0]:
				game.spawn_enemy_bullet(origin, down.rotated(deg_to_rad(angle)), bullet_id, bullet_speed, bullet_damage)
		"ring":
			for i in 14:
				var dir := down.rotated(TAU * float(i) / 14.0)
				game.spawn_enemy_bullet(global_position, dir, bullet_id, bullet_speed, bullet_damage)
			for angle in [-12.0, 12.0]:
				game.spawn_enemy_bullet(origin, down.rotated(deg_to_rad(angle)), bullet_id, bullet_speed + 70.0, bullet_damage)
		"aimed":
			var player = game.get("player")
			var target: Vector2 = origin + down * 200.0
			if player != null and is_instance_valid(player):
				target = player.global_position
			for angle in [-10.0, 0.0, 10.0]:
				var dir := (target - origin).normalized().rotated(deg_to_rad(angle))
				game.spawn_enemy_bullet(origin, dir, bullet_id, bullet_speed, bullet_damage)


func take_damage(amount: float) -> void:
	if _dead or _entering:
		return
	hp = maxf(0.0, hp - amount)
	health_changed.emit(hp, max_hp)
	if sprite != null:
		sprite.modulate = Color(1.8, 1.8, 1.8)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	_check_phase()
	if hp <= 0.0:
		_die()


func _check_phase() -> void:
	var ratio := hp / max_hp
	while phase_index + 1 < phases.size():
		var next_threshold := float(phases[phase_index + 1].get("threshold", 0.0))
		if ratio > next_threshold:
			break
		phase_index += 1
		_phase_flash = 1.0
		phase_changed.emit(phase_index, phases.size())
		AudioManager.play("warn", 0.7, -8.0)
		var game := get_tree().get_first_node_in_group("game")
		if game != null:
			game.shake(10.0)
			game.spawn_explosion(global_position, 90.0, Color(1.0, 0.4, 0.3))
		# 换阶段时放一圈弹幕制造压力
		var phase: Dictionary = phases[phase_index]
		for i in 16:
			var dir := Vector2.DOWN.rotated(TAU * float(i) / 16.0)
			if game != null:
				game.spawn_enemy_bullet(global_position, dir, str(phase.get("bullet", "orb")), 150.0, int(phase.get("damage", 10)))


func _die() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	AudioManager.play("big_explode", 0.7)
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		game.shake(20.0)
		game.flash(Color(1.0, 0.7, 0.3, 0.45))
		for i in 10:
			var offset := Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0))
			game.spawn_explosion(global_position + offset, randf_range(28.0, 62.0), Color(1.0, 0.62, 0.25))
	defeated.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.3, 0.0), 0.45)
	await get_tree().create_timer(0.45).timeout
	queue_free()
