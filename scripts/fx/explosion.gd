## 爆炸特效：扩散闪光 + 加算混合粒子（火花 + 烟尘）
class_name Explosion
extends Node2D

static var _dot: ImageTexture

var radius := 34.0
var color := Color(1.0, 0.72, 0.28)
var _t := 0.0
var _life := 0.85


static func dot_texture() -> ImageTexture:
	if _dot != null:
		return _dot
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in 16:
		for y in 16:
			var d := Vector2(float(x) - 7.5, float(y) - 7.5).length() / 8.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	_dot = ImageTexture.create_from_image(img)
	return _dot


static func create(pos: Vector2, blast_radius: float, tint: Color) -> Explosion:
	var fx := Explosion.new()
	fx.position = pos
	fx.radius = blast_radius
	fx.color = tint
	return fx


func _ready() -> void:
	z_index = 30
	_spawn_sparks()
	_spawn_smoke()


func _spawn_sparks() -> void:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.amount = int(clampf(radius * 1.0, 12.0, 44.0))
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.96
	p.local_coords = false
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = radius * 2.6
	p.initial_velocity_max = radius * 6.6
	p.damping_min = radius * 3.0
	p.damping_max = radius * 7.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 0.35, 0.05, 0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.emitting = true
	add_child(p)


func _spawn_smoke() -> void:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.amount = int(clampf(radius * 0.35, 5.0, 14.0))
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = radius * 0.8
	p.initial_velocity_max = radius * 2.2
	p.gravity = Vector2(0, -6)
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g * 0.7, color.b * 0.5, 0.55))
	ramp.set_color(1, Color(color.r * 0.4, color.g * 0.2, 0.05, 0))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / 0.26, 0.0, 1.0)
	var flash_alpha := clampf(1.0 - _t / 0.26, 0.0, 1.0)
	if flash_alpha > 0.0:
		draw_circle(Vector2.ZERO, radius * (0.35 + k * 1.5), Color(1, 0.96, 0.88, flash_alpha * 0.85))
		draw_circle(Vector2.ZERO, radius * (0.5 + k * 1.9), Color(color.r, color.g, color.b, flash_alpha * 0.35))
