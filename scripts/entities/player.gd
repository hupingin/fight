## 我方战机：方向键移动 + 空格射击 + 受击无敌帧
class_name Player
extends Area2D

signal health_changed(current: int, maximum: int)
signal died

const SPEED := 350.0
const FIRE_COOLDOWN := 0.115
const BULLET_DAMAGE := 3
const MARGIN := 26.0

var max_hp := 100
var hp := 100
var alive := true
var invincible := false

var _cooldown := 0.0
var _inv_time := 0.0
var _tilt := 0.0
var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	z_index = 10
	hp = max_hp
	spawn_protection(1.0)
	_build_thruster()
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_cooldown = maxf(0.0, _cooldown - delta)

	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0

	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta

	var view := get_viewport_rect().size
	position.x = clampf(position.x, MARGIN, view.x - MARGIN)
	position.y = clampf(position.y, MARGIN + 20.0, view.y - MARGIN)

	_tilt = lerpf(_tilt, dir.x * 0.22, minf(1.0, delta * 12.0))
	sprite.rotation = _tilt

	if _inv_time > 0.0:
		_inv_time -= delta
		sprite.modulate.a = 0.35 + 0.65 * absf(sin(_inv_time * 17.0))
		if _inv_time <= 0.0:
			invincible = false
			sprite.modulate.a = 1.0

	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J):
		_try_shoot()


func _try_shoot() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = FIRE_COOLDOWN
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return
	game.spawn_player_bullet(global_position + Vector2(-11, -22), BULLET_DAMAGE)
	game.spawn_player_bullet(global_position + Vector2(11, -22), BULLET_DAMAGE)
	AudioManager.play("shoot", randf_range(0.94, 1.08), -7.0)


func take_damage(amount: int) -> void:
	if not alive or invincible:
		return
	# 难度承伤倍率：容易 0.7 / 中等 1.0 / 困难 1.25
	var scale := float(LevelData.difficulty(GameState.difficulty).get("damage_taken", 1.0))
	hp = maxi(0, hp - maxi(1, int(round(amount * scale))))
	health_changed.emit(hp, max_hp)
	AudioManager.play("hurt", randf_range(0.95, 1.08))
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		game.shake(7.0)
		game.flash(Color(1.0, 0.15, 0.25, 0.3))
	if hp <= 0:
		_die()
	else:
		spawn_protection(1.15)


func spawn_protection(duration: float) -> void:
	invincible = true
	_inv_time = maxf(_inv_time, duration)


func _die() -> void:
	if not alive:
		return
	alive = false
	invincible = true
	set_deferred("monitoring", false)
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		game.spawn_explosion(global_position, 64.0, Color(0.55, 0.9, 1.0))
		game.shake(18.0)
	AudioManager.play("big_explode", 0.82)
	died.emit()
	queue_free()


func _on_area_entered(area: Node) -> void:
	if not alive:
		return
	if area.is_in_group("boss"):
		take_damage(int(area.get("contact_damage")))
	elif area.is_in_group("enemies"):
		take_damage(25)
		if area.has_method("destroy_by_ram"):
			area.destroy_by_ram()
	elif area.is_in_group("enemy_bullets"):
		take_damage(int(area.get("damage")))
		if is_instance_valid(area):
			area.queue_free()


func _build_thruster() -> void:
	var p := CPUParticles2D.new()
	p.name = "Thruster"
	p.position = Vector2(0, 24)
	p.amount = 14
	p.lifetime = 0.3
	p.local_coords = false
	p.direction = Vector2(0, 1)
	p.spread = 12.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.texture = Explosion.dot_texture()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.93, 0.65, 0.9))
	ramp.set_color(1, Color(1.0, 0.32, 0.08, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.z_index = -1
	add_child(p)
