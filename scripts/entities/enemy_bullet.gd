## 敌方子弹 / 激光：只命中玩家，出屏自动销毁
class_name EnemyBullet
extends Area2D

var velocity := Vector2(0, 200)
var damage := 10

var _view := Vector2(540, 960)

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemy_bullets")
	z_index = 11
	_view = get_viewport_rect().size


func configure(def: Dictionary, dir: Vector2, bullet_speed: float, bullet_damage: int) -> void:
	velocity = dir.normalized() * bullet_speed
	damage = bullet_damage
	var texture_path := str(def.get("texture", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	var scale_value := float(def.get("scale", 1.0))
	sprite.scale = Vector2(scale_value, scale_value)
	if bool(def.get("rotate", false)):
		sprite.rotation = dir.angle() - PI * 0.5
	var shape := CircleShape2D.new()
	shape.radius = maxf(3.0, float(def.get("radius", 6.0)))
	if hit_shape != null:
		hit_shape.shape = shape


func _process(delta: float) -> void:
	position += velocity * delta
	if position.y > _view.y + 60.0 or position.y < -80.0 or position.x < -60.0 or position.x > _view.x + 60.0:
		queue_free()
