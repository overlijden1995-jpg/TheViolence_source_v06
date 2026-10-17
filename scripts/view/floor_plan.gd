extends Node2D
## Draws any level as an architectural floor plan: paper, grid, site notation (roads,
## parking, pools), floors, poche walls, window triple-lines, door swings, room
## lettering, dimension strings and a title block. Everything here is greyscale;
## colour is reserved for blood.
## The site painters are static so a city lot can draw its template with them.

const Geom = preload("res://scripts/sim/geom.gd")
const PX := 40.0

const PAPER := Color("#f6f6f4")
const GRID := Color("#e6e6e3")
const GRID_MAJOR := Color("#d8d8d4")
const INK := Color("#1c1c1c")
const LINE := Color("#3a3a3a")
const FAINT := Color("#8f8f8f")
const HOUSE_FLOOR := Color("#fbfbfa")
const DECK := Color("#f0f0ee")
const ROAD := Color("#e7e7e4")

var level


func setup(lv) -> void:
	level = lv
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var font: Font = ThemeDB.fallback_font
	var W: float = level.W * PX
	var H: float = level.H * PX
	# paper sheet with a margin for the title block
	draw_rect(Rect2(-60, -60, W + 120, H + 170), Color("#ffffff"))
	draw_rect(Rect2(-60, -60, W + 120, H + 170), INK, false, 2.0)
	draw_rect(Rect2(-48, -48, W + 96, H + 146), LINE, false, 1.0)
	draw_rect(Rect2(0, 0, W, H), PAPER)
	# grid: 1 m faint, 5 m darker
	for x in range(0, int(level.W) + 1):
		draw_line(Vector2(x * PX, 0), Vector2(x * PX, H), GRID_MAJOR if x % 5 == 0 else GRID, 1.0)
	for y in range(0, int(level.H) + 1):
		draw_line(Vector2(0, y * PX), Vector2(W, y * PX), GRID_MAJOR if y % 5 == 0 else GRID, 1.0)
	if not level.fenced:
		_dash_rect(self, Rect2(2, 2, W - 4, H - 4), FAINT)
	paint_site(self, level, font)
	paint_labels(self, level, font)
	# dimension strings
	if not level.dims.is_empty():
		for dm in level.dims:
			_dimension(dm["a"], dm["b"], dm["text"], font)
			var horiz: bool = absf(dm["b"].x - dm["a"].x) > absf(dm["b"].y - dm["a"].y)
			for tk in dm.get("ticks", []):
				if horiz:
					draw_line(Vector2(tk * PX, (dm["a"].y - 0.15) * PX), Vector2(tk * PX, (dm["a"].y + 0.15) * PX), LINE, 1.0)
				else:
					draw_line(Vector2((dm["a"].x - 0.15) * PX, tk * PX), Vector2((dm["a"].x + 0.15) * PX, tk * PX), LINE, 1.0)
	else:
		for b in level.buildings:
			var box: Rect2 = b
			var ytop := box.position.y - 0.9
			var xr := box.end.x + 0.9
			_dimension(Vector2(box.position.x, ytop), Vector2(box.end.x, ytop), "%.2f m" % box.size.x, font)
			_dimension(Vector2(xr, box.position.y), Vector2(xr, box.end.y), "%.2f" % box.size.y, font)
	# title block, scale bar, legend
	var tb := Rect2(W - 560, H + 14, 560, 92)
	draw_rect(tb, Color("#ffffff"))
	draw_rect(tb, INK, false, 1.5)
	draw_line(Vector2(tb.position.x, tb.position.y + 30), Vector2(tb.end.x, tb.position.y + 30), LINE, 1.0)
	draw_line(Vector2(tb.position.x + 360, tb.position.y + 30), Vector2(tb.position.x + 360, tb.end.y), LINE, 1.0)
	draw_string(font, tb.position + Vector2(12, 21), _spaced(level.title), HORIZONTAL_ALIGNMENT_LEFT, 536, 14, INK)
	for i in mini(3, level.notes.size()):
		draw_string(font, tb.position + Vector2(12, 50 + 16 * i), level.notes[i], HORIZONTAL_ALIGNMENT_LEFT, 340, 11, LINE if i < 2 else FAINT)
	draw_string(font, tb.position + Vector2(372, 50), "COVER: solid fill / hatched", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE)
	draw_string(font, tb.position + Vector2(372, 66), "CONCEALMENT: outline only", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE)
	draw_string(font, tb.position + Vector2(372, 82), "WINDOWS: sill 0.9 m, head 2.1 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE)
	var sb := Vector2(0, H + 40)
	for k in 5:
		var seg := Rect2(sb.x + k * PX, sb.y, PX, 8)
		draw_rect(seg, INK if k % 2 == 0 else Color("#ffffff"))
		draw_rect(seg, INK, false, 1.0)
	for k in [0, 1, 5]:
		draw_string(font, sb + Vector2(k * PX - 3, 24), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE)
	draw_string(font, sb + Vector2(5 * PX + 12, 9), "m", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE)


## Site notation, floors, walls (poche), fence posts, rails, windows and doors.
static func paint_site(ci: CanvasItem, lv, font: Font) -> void:
	for d in lv.decor:
		_decor(ci, d, font)
	# floors: interior rooms plain, decks (porches, walkways, patios) boarded
	for name in lv.rooms:
		var rm: Dictionary = lv.rooms[name]
		for rv in rm["rects"]:
			var r: Rect2 = rv
			if rm["deck"]:
				ci.draw_rect(_r(r), DECK)
				_boards(ci, r)
			elif not rm["exterior"]:
				ci.draw_rect(_r(r), HOUSE_FLOOR)
	# walls
	for idx in lv.walls:
		var o: Dictionary = lv.geom.obs[idx]
		var r2: Rect2 = _r(o["r"])
		match o["name"]:
			"fence":
				ci.draw_rect(r2, Color("#9a9a9a"))
			"perimeter":
				ci.draw_rect(r2, Color("#5a5a5a"))
				_hatch(ci, r2, Color("#2a2a2a"), 7.0)
				ci.draw_rect(r2, INK, false, 1.0)
			_:
				ci.draw_rect(r2, INK)
	# fence posts every 2 m
	for idx2 in lv.walls:
		var o2: Dictionary = lv.geom.obs[idx2]
		if o2["name"] != "fence":
			continue
		var fr: Rect2 = o2["r"]
		if fr.size.x >= fr.size.y:
			var x := ceilf(fr.position.x / 2.0) * 2.0
			while x <= fr.end.x:
				ci.draw_rect(Rect2(x * PX - 2, fr.get_center().y * PX - 3, 4, 6), LINE)
				x += 2.0
		else:
			var y := ceilf(fr.position.y / 2.0) * 2.0
			while y <= fr.end.y:
				ci.draw_rect(Rect2(fr.get_center().x * PX - 3, y * PX - 2, 6, 4), LINE)
				y += 2.0
	# railings and chain-link (concealment lines) as thin double lines
	for o3 in lv.geom.obs:
		var nm: String = o3["name"]
		if nm.ends_with("rail") or nm == "chain-link":
			var rr: Rect2 = _r(o3["r"])
			ci.draw_rect(rr, Color("#ffffff"))
			ci.draw_rect(rr, LINE, false, 1.0)
	# windows: white gap, three thin lines, jamb ticks
	for win in lv.windows:
		var wr: Rect2 = _r(win["r"])
		ci.draw_rect(wr, Color("#ffffff"))
		if win["axis"] == "h":
			for f in [0.0, 0.5, 1.0]:
				var y2: float = wr.position.y + wr.size.y * f
				ci.draw_line(Vector2(wr.position.x, y2), Vector2(wr.end.x, y2), LINE, 1.0)
			ci.draw_line(wr.position, Vector2(wr.position.x, wr.end.y), INK, 2.0)
			ci.draw_line(Vector2(wr.end.x, wr.position.y), wr.end, INK, 2.0)
		else:
			for f in [0.0, 0.5, 1.0]:
				var x2: float = wr.position.x + wr.size.x * f
				ci.draw_line(Vector2(x2, wr.position.y), Vector2(x2, wr.end.y), LINE, 1.0)
			ci.draw_line(wr.position, Vector2(wr.end.x, wr.position.y), INK, 2.0)
			ci.draw_line(Vector2(wr.position.x, wr.end.y), wr.end, INK, 2.0)
	# doors: leaf and quarter arc swinging into the interior room; arches get jamb ticks
	for did in lv.doors:
		var dd: Dictionary = lv.doors[did]
		var c: Vector2 = dd["c"]
		var t: Vector2 = dd["t"]
		var n: Vector2 = dd["n"]
		var half: float = dd["half"]
		if dd.get("arch", false):
			for sgn in [-1.0, 1.0]:
				var j: Vector2 = c + t * half * sgn
				ci.draw_line((j - n * 0.18) * PX, (j + n * 0.18) * PX, INK, 2.0)
			ci.draw_dashed_line((c - t * half) * PX, (c + t * half) * PX, FAINT, 1.0, 5.0)
			continue
		var into: Vector2 = n if not lv.is_exterior(dd["b"]) else -n
		var hinge: Vector2 = c + t * half * float(dd["hinge"])
		var closed: Vector2 = c - t * half * float(dd["hinge"])
		var leaf := minf(half * 2.0, 1.0)
		if half * 2.0 > 1.25:
			# double door: two leaves from both jambs
			for sgn2 in [-1.0, 1.0]:
				var hg: Vector2 = c + t * half * sgn2
				var oe: Vector2 = hg + into * half
				ci.draw_line(hg * PX, oe * PX, INK, 2.0)
				var a0: float = (c - hg).angle()
				ci.draw_arc(hg * PX, half * PX, a0, a0 + angle_difference(a0, (oe - hg).angle()), 14, FAINT, 1.0, true)
			continue
		var open_end: Vector2 = hinge + into * leaf
		ci.draw_line(hinge * PX, open_end * PX, INK, 2.0)
		var a1: float = (closed - hinge).angle()
		var a2: float = (open_end - hinge).angle()
		ci.draw_arc(hinge * PX, leaf * PX, a1, a1 + angle_difference(a1, a2), 18, FAINT, 1.0, true)


## Room lettering, sized by floor area.
static func paint_labels(ci: CanvasItem, lv, font: Font) -> void:
	for name2 in lv.rooms:
		var rm2: Dictionary = lv.rooms[name2]
		if rm2["exterior"] and not rm2["deck"]:
			continue
		if rm2["title"] == "":
			continue
		var area: float = rm2["area"]
		var fs := 8 if area < 8.0 else (9 if area < 20.0 else (10 if area < 50.0 else (11 if area < 150.0 else 13)))
		_label(ci, font, rm2["label"] * PX, _spaced(rm2["title"]), fs, LINE)


static func _decor(ci: CanvasItem, d: Dictionary, font: Font) -> void:
	match d["type"]:
		"dash_rect":
			_dash_rect(ci, _r(d["r"]), FAINT)
		"rect":
			var r: Rect2 = _r(d["r"])
			ci.draw_rect(r, Color("#eeeeec"))
			ci.draw_rect(r, LINE, false, 1.0)
		"steps":
			var rs: Rect2 = d["r"]
			var n: int = d.get("n", 3)
			for k in n:
				var f := float(k) / maxf(1.0, n - 1)
				if d.get("axis", "v") == "v":
					var x := rs.end.x - f * rs.size.x
					ci.draw_line(Vector2(x, rs.position.y) * PX, Vector2(x, rs.end.y) * PX, FAINT, 1.0)
				else:
					var y := rs.position.y + f * rs.size.y
					ci.draw_line(Vector2(rs.position.x, y) * PX, Vector2(rs.end.x, y) * PX, FAINT, 1.0)
		"text":
			ci.draw_string(font, d["p"] * PX, d["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, d.get("size", 10), FAINT)
		"road":
			var rr: Rect2 = _r(d["r"])
			ci.draw_rect(rr, ROAD)
			if d.get("axis", "h") == "h":
				ci.draw_line(rr.position, Vector2(rr.end.x, rr.position.y), FAINT, 1.0)
				ci.draw_line(Vector2(rr.position.x, rr.end.y), rr.end, FAINT, 1.0)
				var cy := rr.get_center().y
				ci.draw_dashed_line(Vector2(rr.position.x, cy), Vector2(rr.end.x, cy), Color("#b5b5b1"), 2.0, 18.0)
			else:
				ci.draw_line(rr.position, Vector2(rr.position.x, rr.end.y), FAINT, 1.0)
				ci.draw_line(Vector2(rr.end.x, rr.position.y), rr.end, FAINT, 1.0)
				var cx := rr.get_center().x
				ci.draw_dashed_line(Vector2(cx, rr.position.y), Vector2(cx, rr.end.y), Color("#b5b5b1"), 2.0, 18.0)
		"parking":
			var pr: Rect2 = d["r"]
			var stall: float = d.get("stall", 2.7)
			if d.get("axis", "v") == "v":
				var x2 := pr.position.x
				while x2 <= pr.end.x + 0.01:
					ci.draw_line(Vector2(x2, pr.position.y) * PX, Vector2(x2, pr.end.y) * PX, Color("#b0b0ac"), 1.5)
					x2 += stall
				ci.draw_line(Vector2(pr.position.x, pr.end.y) * PX, pr.end * PX, Color("#b0b0ac"), 1.0)
			else:
				var y2 := pr.position.y
				while y2 <= pr.end.y + 0.01:
					ci.draw_line(Vector2(pr.position.x, y2) * PX, Vector2(pr.end.x, y2) * PX, Color("#b0b0ac"), 1.5)
					y2 += stall
		"pool":
			var pl: Rect2 = _r(d["r"])
			ci.draw_rect(pl.grow(10.0), Color("#ebebe8"))
			ci.draw_rect(pl.grow(10.0), LINE, false, 1.0)
			ci.draw_rect(pl, Color("#e2e4e6"))
			var y3 := pl.position.y + 8.0
			while y3 < pl.end.y - 4.0:
				var x3 := pl.position.x + 6.0
				while x3 < pl.end.x - 14.0:
					ci.draw_arc(Vector2(x3 + 6.0, y3), 6.0, PI * 1.1, PI * 1.9, 6, Color("#a9adb1"), 1.0)
					x3 += 22.0
				y3 += 14.0
			ci.draw_rect(pl, INK, false, 1.5)
		"hatch":
			var hr: Rect2 = _r(d["r"])
			_hatch(ci, hr, Color(0, 0, 0, 0.12), 9.0)
			ci.draw_rect(hr, FAINT, false, 1.0)


static func _boards(ci: CanvasItem, r: Rect2) -> void:
	var col := Color("#dcdcd8")
	if r.size.y >= r.size.x:
		var x := r.position.x
		while x < r.end.x:
			ci.draw_line(Vector2(x, r.position.y) * PX, Vector2(x, r.end.y) * PX, col, 1.0)
			x += 0.15
	else:
		var y := r.position.y
		while y < r.end.y:
			ci.draw_line(Vector2(r.position.x, y) * PX, Vector2(r.end.x, y) * PX, col, 1.0)
			y += 0.15


static func _hatch(ci: CanvasItem, r: Rect2, col: Color, step: float) -> void:
	var x := -r.size.y
	while x < r.size.x:
		var a := Vector2(x, r.size.y)
		var b := Vector2(x + r.size.y, 0)
		if a.x < 0:
			a = Vector2(0, r.size.y + a.x)
		if b.x > r.size.x:
			b = Vector2(r.size.x, b.x - r.size.x)
		ci.draw_line(r.position + a, r.position + b, col, 1.0)
		x += step


static func _r(r: Rect2) -> Rect2:
	return Rect2(r.position * PX, r.size * PX)


static func _dash_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		ci.draw_dashed_line(p[k], p[(k + 1) % 4], col, 1.0, 6.0)


static func _spaced(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " " if s[i] != " " else "  "
	return out


static func _label(ci: CanvasItem, font: Font, centre: Vector2, text: String, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, centre + Vector2(-w / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _dimension(a: Vector2, b: Vector2, text: String, font: Font) -> void:
	var pa := a * PX
	var pb := b * PX
	draw_line(pa, pb, LINE, 1.0)
	var n := (pb - pa).normalized().orthogonal() * 5.0
	var t := (pb - pa).normalized() * 4.0
	for p in [pa, pb]:
		draw_line(p - n, p + n, LINE, 1.0)
		draw_line(p - t - n * 0.8, p + t + n * 0.8, INK, 1.4)
	var mid := (pa + pb) / 2.0
	if absf(pb.x - pa.x) > absf(pb.y - pa.y):
		_label(self, font, mid + Vector2(0, -9), text, 10, LINE)
	else:
		draw_set_transform(mid + Vector2(10, 0), PI / 2.0)
		_label(self, font, Vector2.ZERO, text, 10, LINE)
		draw_set_transform(Vector2.ZERO, 0.0)
