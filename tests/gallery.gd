extends Node2D
## Lays out every placeholder SVG with its file name, on the paper colour the game uses.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/gallery.tscn -- --shot=/tmp/gallery.png
const ROOT := "res://assets/svg"

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#ededed"))
	var x := 16.0
	var y := 16.0
	var row_h := 0.0
	for folder in ["op", "furn", "yard", "fx", "ui"]:
		for file in DirAccess.get_files_at("%s/%s" % [ROOT, folder]):
			if not file.ends_with(".svg"):
				continue
			var tex: Texture2D = load("%s/%s/%s" % [ROOT, folder, file])
			var size := tex.get_size()
			var scale_f := minf(1.0, 200.0 / maxf(size.x, size.y))
			var cell_w := maxf(size.x * scale_f, 84.0) + 14.0
			if x + cell_w > 1580.0:
				x = 16.0
				y += row_h + 24.0
				row_h = 0.0
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2(scale_f, scale_f)
			s.position = Vector2(x, y)
			add_child(s)
			var l := Label.new()
			l.text = file.get_basename()
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_color", Color.BLACK)
			l.position = Vector2(x, y + size.y * scale_f)
			add_child(l)
			x += cell_w
			row_h = maxf(row_h, size.y * scale_f)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
			get_tree().quit()
