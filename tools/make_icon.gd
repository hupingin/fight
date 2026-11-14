## 开发工具：把游戏图标 SVG 光栅化为多尺寸 PNG，供打包 ICO 使用
## 用法：godot --headless --path . --script res://tools/make_icon.gd
extends SceneTree


func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/game-plane.svg")
	if svg.is_empty():
		push_error("无法读取 SVG")
		quit(1)
		return
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("SVG 解析失败: %s" % err)
		quit(1)
		return
	print("原始尺寸: ", img.get_size())
	for size in [256, 48, 32, 16]:
		var copy := img.duplicate() as Image
		copy.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var out := "res://.tools/icon_%d.png" % size
		copy.save_png(out)
		print("写出: ", out)
	quit(0)
