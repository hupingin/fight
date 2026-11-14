## 视差星点层：缓慢下落 + 闪烁，速度可随关卡节奏加快
class_name Starfield
extends Node2D

var star_color := Color("#7fc3ff")
var speed_scale := 1.0
var count := 96

var _stars: Array = []
var _t := 0.0
var _size := Vector2(540, 960)
var _built := false


func setup(color: Color, speed := 1.0, star_count := 96) -> void:
	star_color = color
	speed_scale = speed
	count = star_count
	_build()


func _ready() -> void:
	_size = get_viewport_rect().size
	z_index = -90
	if not _built:
		_build()


func _build() -> void:
	_built = true
	if _size.x <= 0.0:
		_size = Vector2(540, 960)
	_stars.clear()
	for i in count:
		_stars.append(_make_star(true))


func _make_star(anywhere: bool) -> Dictionary:
	var depth := randf()
	return {
		"x": randf() * _size.x,
		"y": randf() * _size.y if anywhere else randf_range(-60.0, -4.0),
		"r": lerpf(0.6, 2.0, depth),
		"spd": lerpf(16.0, 110.0, depth),
		"alpha": lerpf(0.22, 0.85, depth),
		"phase": randf() * TAU,
		"big": depth > 0.93,
	}


func _process(delta: float) -> void:
	_t += delta
	for star in _stars:
		star["y"] = float(star["y"]) + float(star["spd"]) * speed_scale * delta
		if float(star["y"]) > _size.y + 6.0:
			star["y"] = randf_range(-40.0, -4.0)
			star["x"] = randf() * _size.x
	queue_redraw()


func _draw() -> void:
	for star in _stars:
		var twinkle := 0.72 + 0.28 * sin(_t * 2.2 + float(star["phase"]))
		var color := Color(star_color.r, star_color.g, star_color.b, float(star["alpha"]) * twinkle)
		var pos := Vector2(float(star["x"]), float(star["y"]))
		var radius := float(star["r"])
		draw_circle(pos, radius, color)
		if bool(star["big"]):
			var arm := radius * 3.2
			var fade := Color(color.r, color.g, color.b, color.a * 0.35)
			draw_line(pos - Vector2(arm, 0), pos + Vector2(arm, 0), fade, 1.0)
			draw_line(pos - Vector2(0, arm), pos + Vector2(0, arm), fade, 1.0)
