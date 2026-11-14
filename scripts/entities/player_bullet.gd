## 我方子弹：向上直线飞行，仅命中敌人
class_name PlayerBullet
extends Area2D

var speed := 780.0
var damage := 3
var direction := Vector2.UP

var _hit := false
var _view := Vector2(540, 960)

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("player_bullets")
	z_index = 12
	_view = get_viewport_rect().size
	area_entered.connect(_on_area_entered)


func configure(texture_path: String, radius: float) -> void:
	var tex := load(texture_path)
	if tex != null and sprite != null:
		sprite.texture = tex
	var shape := CircleShape2D.new()
	shape.radius = maxf(3.0, radius)
	if hit_shape != null:
		hit_shape.shape = shape


func _process(delta: float) -> void:
	position += direction * speed * delta
	if position.y < -60.0 or position.y > _view.y + 60.0 or position.x < -60.0 or position.x > _view.x + 60.0:
		queue_free()


func _on_area_entered(area: Node) -> void:
	if _hit or not is_instance_valid(area):
		return
	if not area.is_in_group("enemies"):
		return
	_hit = true
	if area.has_method("take_damage"):
		area.take_damage(damage)
	var game := get_tree().get_first_node_in_group("game")
	if game != null:
		game.spawn_explosion(global_position, 9.0, Color(0.55, 0.9, 1.0))
	queue_free()
