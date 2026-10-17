extends Node2D
## The city's ground plane: the fenced back gardens, streets with sidewalks, kerbs, lane
## lines and crosswalks, the lot fences, the parked cars and the city's edge wall.

const Decals = preload("res://scripts/view/decals.gd")
const PX := 40.0
const ASPHALT := Color("#dededa")
const WALK := Color("#f0f0ed")
const KERB := Color("#9a9a96")
const GARDEN := Color("#e6e8e1")
const LINE := Color("#3a3a3a")

var lv


func setup(level) -> void:
	lv = level
	queue_redraw()


func _draw() -> void:
	if lv == null:
		return
	var W: float = lv.W * PX
	var H: float = lv.H * PX
	draw_rect(Rect2(0, 0, W, H), Color("#ebebe7"))
	# back gardens behind the lots (fenced off, nobody goes there)
	for g in lv.garden:
		var gr: Rect2 = _r(g)
		draw_rect(gr, GARDEN)
		var x := gr.position.x - gr.size.y
		while x < gr.end.x:
			var a := Vector2(maxf(x, gr.position.x), gr.end.y - maxf(0.0, gr.position.x - x))
			var b := Vector2(minf(x + gr.size.y, gr.end.x), gr.position.y + maxf(0.0, x + gr.size.y - gr.end.x))
			draw_line(a, b, Color(0, 0, 0, 0.06), 1.0)
			x += 160.0
	var st: float = lv.ST
	var sw: float = lv.SW
	# streets
	for iy in lv.NROWS + 1:
		var y0: float = iy * (lv.BH + st)
		draw_rect(Rect2(0, y0 * PX, W, st * PX), ASPHALT)
		draw_rect(Rect2(0, y0 * PX, W, sw * PX), WALK)
		draw_rect(Rect2(0, (y0 + st - sw) * PX, W, sw * PX), WALK)
	for ix in lv.NCOLS + 1:
		var x0: float = ix * (lv.BW + st)
		draw_rect(Rect2(x0 * PX, 0, st * PX, H), ASPHALT)
		draw_rect(Rect2(x0 * PX, 0, sw * PX, H), WALK)
		draw_rect(Rect2((x0 + st - sw) * PX, 0, sw * PX, H), WALK)
	# intersections: clear the sidewalk overlaps, kerb corners, crosswalks
	for iy2 in lv.NROWS + 1:
		for ix2 in lv.NCOLS + 1:
			var c: Vector2 = lv.node_pos(ix2, iy2)
			var half: float = st / 2.0
			draw_rect(Rect2((c - Vector2(half, half)) * PX, Vector2(st, st) * PX), ASPHALT)
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var cp: Vector2 = c + q * half
				draw_rect(Rect2(Vector2(minf(cp.x, cp.x - q.x * sw), minf(cp.y, cp.y - q.y * sw)) * PX, Vector2(sw, sw) * PX), WALK)
			_crosswalks(c, half - sw)
	# kerb lines and lane markings between intersections
	for iy3 in lv.NROWS + 1:
		var yc: float = lv.node_pos(0, iy3).y
		for bx in lv.NCOLS:
			var xa: float = lv.node_pos(bx, iy3).x + st / 2.0
			var xb: float = lv.node_pos(bx + 1, iy3).x - st / 2.0
			for ky in [yc - st / 2.0 + sw, yc + st / 2.0 - sw]:
				draw_line(Vector2(xa, ky) * PX, Vector2(xb, ky) * PX, KERB, 2.0)
			draw_dashed_line(Vector2(xa + 1.5, yc) * PX, Vector2(xb - 1.5, yc) * PX, Color("#b8b8b2"), 2.0, 60.0)
			for ky2 in [yc - 3.5, yc + 3.5]:
				draw_line(Vector2(xa + 1.0, ky2) * PX, Vector2(xb - 1.0, ky2) * PX, Color("#cfcfca"), 1.0)
	for ix3 in lv.NCOLS + 1:
		var xc: float = lv.node_pos(ix3, 0).x
		for by in lv.NROWS:
			var ya: float = lv.node_pos(ix3, by).y + st / 2.0
			var yb: float = lv.node_pos(ix3, by + 1).y - st / 2.0
			for kx in [xc - st / 2.0 + sw, xc + st / 2.0 - sw]:
				draw_line(Vector2(kx, ya) * PX, Vector2(kx, yb) * PX, KERB, 2.0)
			draw_dashed_line(Vector2(xc, ya + 1.5) * PX, Vector2(xc, yb - 1.5) * PX, Color("#b8b8b2"), 2.0, 60.0)
			for kx2 in [xc - 3.5, xc + 3.5]:
				draw_line(Vector2(kx2, ya + 1.0) * PX, Vector2(kx2, yb - 1.0) * PX, Color("#cfcfca"), 1.0)
	# lot fences and the city wall
	for f in lv.fences:
		draw_rect(_r(f), Color("#9a9a9a"))
	for idx in lv.walls:
		var o: Dictionary = lv.geom.obs[idx]
		if o["name"] == "perimeter":
			draw_rect(_r(o["r"]), Color("#5a5a5a"))
	# parked cars and street trees' trunks (canopies are drawn above everyone)
	for pr in lv.props:
		if pr.get("lot", 0) != -1 or pr.get("under", false):
			continue
		var tex: Texture2D = Decals.tex(pr["key"])
		var r: Rect2 = pr["r"]
		var rot: float = pr["rot"]
		var want: Vector2 = r.size * PX
		if int(rot) % 180 != 0:
			want = Vector2(want.y, want.x)
		draw_set_transform(r.get_center() * PX, deg_to_rad(rot))
		draw_texture_rect(tex, Rect2(-want / 2.0, want), false)
	draw_set_transform(Vector2.ZERO, 0.0)


func _crosswalks(c: Vector2, inner: float) -> void:
	var col := Color("#fbfbf9")
	var road := 6.0
	for side in [-1.0, 1.0]:
		# across the vertical street, north and south of the junction (on the sidewalk lines)
		var y: float = c.y + side * (inner + 1.5)
		var x := c.x - road + 0.3
		while x < c.x + road - 0.3:
			draw_rect(Rect2(Vector2(x, y - 1.0) * PX, Vector2(0.5, 2.0) * PX), col)
			x += 1.0
		# across the horizontal street, west and east
		var x2: float = c.x + side * (inner + 1.5)
		var y2 := c.y - road + 0.3
		while y2 < c.y + road - 0.3:
			draw_rect(Rect2(Vector2(x2 - 1.0, y2) * PX, Vector2(2.0, 0.5) * PX), col)
			y2 += 1.0


static func _r(r: Rect2) -> Rect2:
	return Rect2(r.position * PX, r.size * PX)
