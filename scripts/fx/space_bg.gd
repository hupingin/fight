## 深空星空背景：竖向渐变 + 柔光星云 + 三层视差星点
class_name SpaceBg
extends Control

var top_color := Color("#08131f")
var bottom_color := Color.BLACK
var star_color := Color("#7fc3ff")
var star_speed := 1.0

var _grad_tex: GradientTexture2D
var _glow_tex: GradientTexture2D
var _stars: Node2D
var _blobs: Array = []
var _t := 0.0


func setup(top: String, bottom: String, star: String, speed := 1.0) -> void:
	top_color = Color(top)
	bottom_color = Color(bottom)
	star_color = Color(star)
	star_speed = speed
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = -100
	_refresh()


func _refresh() -> void:
	var size := get_viewport_rect().size
	if size.x <= 0.0:
		size = Vector2(540, 960)

	var gradient := Gradient.new()
	gradient.set_color(0, top_color)
	gradient.set_color(1, bottom_color)
	_grad_tex = GradientTexture2D.new()
	_grad_tex.gradient = gradient
	_grad_tex.fill = GradientTexture2D.FILL_LINEAR
	_grad_tex.fill_from = Vector2(0.5, 0.0)
	_grad_tex.fill_to = Vector2(0.5, 1.0)
	_grad_tex.width = 8
	_grad_tex.height = 256

	var glow_gradient := Gradient.new()
	glow_gradient.set_color(0, Color(1, 1, 1, 1))
	glow_gradient.set_color(1, Color(1, 1, 1, 0))
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = glow_gradient
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128

	_blobs = [
		{"pos": Vector2(size.x * 0.22, size.y * 0.28), "radius": size.x * 0.9, "alpha": 0.16, "speed": 0.05},
		{"pos": Vector2(size.x * 0.82, size.y * 0.62), "radius": size.x * 1.1, "alpha": 0.12, "speed": 0.037},
		{"pos": Vector2(size.x * 0.45, size.y * 0.9), "radius": size.x * 0.7, "alpha": 0.10, "speed": 0.07},
	]

	if _stars == null:
		_stars = Starfield.new()
		_stars.name = "Starfield"
		add_child(_stars)
	_stars.setup(star_color, star_speed, 96)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func set_speed(value: float) -> void:
	if _stars != null:
		_stars.speed_scale = value


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	if _grad_tex != null:
		draw_texture_rect(_grad_tex, rect, false)
	var tint := star_color
	for blob in _blobs:
		var alpha: float = float(blob["alpha"]) * (0.75 + 0.25 * sin(_t * float(blob["speed"]) * 10.0))
		var radius: float = blob["radius"]
		var pos: Vector2 = blob["pos"]
		draw_texture_rect(_glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false,
			Color(tint.r, tint.g, tint.b, alpha))
