extends Node2D
## Static notation drawn over the furniture: cover is hatched (it stops rounds),
## concealment is outlined with a dotted line (it only hides you).

const Geom = preload("res://scripts/sim/geom.gd")
const PX := 40.0

var level


func setup(lv) -> void:
	level = lv
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	for o in level.geom.obs:
		var r: Rect2 = Rect2(o["r"].position * PX, o["r"].size * PX)
		if o["kind"] == Geom.COVER:
			_hatch(r, Color(0, 0, 0, 0.22))
		elif o["kind"] == Geom.CONCEAL and not o["name"].ends_with("rail") and o["name"] != "chain-link":
			var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for k in 4:
				draw_dashed_line(p[k], p[(k + 1) % 4], Color(0, 0, 0, 0.45), 1.0, 2.5)


func _hatch(r: Rect2, col: Color) -> void:
	var step := 6.0
	var x := -r.size.y
	while x < r.size.x:
		var a := Vector2(x, r.size.y)
		var b := Vector2(x + r.size.y, 0)
		# clip the 45 degree line to the rectangle
		if a.x < 0:
			a = Vector2(0, r.size.y + a.x)
		if b.x > r.size.x:
			b = Vector2(r.size.x, b.x - r.size.x)
		draw_line(r.position + a, r.position + b, col, 1.0)
		x += step
	draw_rect(r, Color(0, 0, 0, 0.55), false, 1.0)
