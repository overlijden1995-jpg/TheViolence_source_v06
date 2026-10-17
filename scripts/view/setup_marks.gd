extends Node2D
## Setup-mode notation: selection ring, facing ticks and team letters.

const PX := 40.0

var main


func _draw() -> void:
	if main == null or main.mode != "setup":
		return
	var font: Font = ThemeDB.fallback_font
	for id in main.cfgs:
		var c: Dictionary = main.cfgs[id]
		if not c["enabled"]:
			continue
		var p: Vector2 = c["pos"] * PX
		draw_line(p, p + Vector2.from_angle(c["face"]) * 34.0, Color(0, 0, 0, 0.5), 1.0)
		draw_arc(p, 18.0, 0, TAU, 24, Color(0, 0, 0, 0.25), 1.0)
		if id == main.sel:
			draw_arc(p, 24.0, 0, TAU, 32, Color("#1c1c1c"), 2.0)
			draw_string(font, p + Vector2(26, -14), "selected", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#1c1c1c"))
	var hint: String = main.level.stage_hint + " Up to twenty each. Click to place, right-click to face."
	draw_string(font, Vector2(0, -16), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#444444"))
