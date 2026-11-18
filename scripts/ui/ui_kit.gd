## 统一的 UI 外观工厂：霓虹深空风（黑底 + 青蓝描边）
class_name UIKit
extends RefCounted

const TEXT := Color("#e9f6ff")
const MUTED := Color("#7e9cb5")
const CYAN := Color("#5fe0ff")
const BLUE := Color("#3c7bff")
const RED := Color("#ff5c6e")
const AMBER := Color("#ffc25a")
const GREEN := Color("#57e8a4")
const DIM := Color("#31465c")


static func box(bg: Color, border: Color, border_width := 1, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 长文案（俄/德等）自动缩小字号，保证不超出指定宽度。
static func fitted_label(text: String, font_size: int, max_width: float, color: Color = TEXT) -> Label:
	var l := label(text, font_size, color)
	var font: Font = l.get_theme_font("font")
	if font != null:
		var size := font_size
		while size > 8:
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
				break
			size -= 1
		l.add_theme_font_size_override("font_size", size)
	return l


static func measured_width(l: Label) -> float:
	var font: Font = l.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		l.get_theme_font_size("font_size")).x


static func glow_label(text: String, font_size: int, color: Color = CYAN) -> Label:
	var l := label(text, font_size, color)
	l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.20))
	l.add_theme_constant_override("outline_size", maxi(6, int(font_size / 3.0)))
	return l


static func button(text: String, min_size: Vector2 = Vector2(260, 54), accent: Color = CYAN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_stylebox_override("normal", box(Color(0.035, 0.08, 0.11, 0.86), Color(accent.r, accent.g, accent.b, 0.45), 1, 3))
	b.add_theme_stylebox_override("hover", box(Color(0.07, 0.18, 0.24, 0.95), accent, 2, 3))
	b.add_theme_stylebox_override("pressed", box(Color(0.02, 0.05, 0.08, 1.0), accent, 2, 3))
	b.add_theme_stylebox_override("disabled", box(Color(0.025, 0.04, 0.055, 0.7), Color(0.2, 0.28, 0.34, 0.45), 1, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func panel(accent: Color = CYAN, bg: Color = Color(0.03, 0.07, 0.10, 0.94)) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(bg, Color(accent.r, accent.g, accent.b, 0.38), 1, 6))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func separator(width: int, color: Color = DIM) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func hbox(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func vbox(separation: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


## 进度条底座 + 填充块，返回 [底, 填充]。
static func bar(size: Vector2, fill_color: Color, bg: Color = Color(0.02, 0.05, 0.07, 0.9)) -> Array:
	var back := Panel.new()
	back.custom_minimum_size = size
	back.size = size
	back.add_theme_stylebox_override("panel", box(bg, Color(0.22, 0.42, 0.54, 0.55), 1, 2))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.clip_contents = true
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(size.x - 4, size.y - 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return [back, fill]


static func slider(accent: Color = CYAN) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.custom_minimum_size = Vector2(200, 26)
	s.focus_mode = Control.FOCUS_NONE
	s.add_theme_stylebox_override("slider", box(Color(0.02, 0.05, 0.07, 0.95), Color(0.22, 0.42, 0.54, 0.6), 1, 3))
	s.add_theme_stylebox_override("grabber_area", box(Color(accent.r, accent.g, accent.b, 0.75), Color(0, 0, 0, 0), 0, 2))
	s.add_theme_stylebox_override("grabber_area_highlight", box(accent, Color(0, 0, 0, 0), 0, 2))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color.WHITE
	grabber.set_corner_radius_all(2)
	grabber.content_margin_left = 5
	grabber.content_margin_right = 5
	grabber.content_margin_top = 9
	grabber.content_margin_bottom = 9
	s.add_theme_stylebox_override("grabber", grabber)
	return s


static func checkbox(text: String, accent: Color = CYAN) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 16)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", accent)
	return c


static func fullscreen_dim(color: Color = Color(0, 0, 0, 0.72)) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


static func place(control: Control, pos: Vector2, size: Vector2) -> void:
	control.position = pos
	control.size = size


static func format_score(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


static func format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [total / 60, total % 60]
