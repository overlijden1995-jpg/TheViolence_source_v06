extends Node2D
## Who holds what. Two instances:
##   "static": every held building hatched in its owner's pattern, the lot outlined, the
##   spawn points and ambulance bases tagged. Redrawn only when a building changes hands.
##   "dynamic": capture bars over buildings being dominated, assault targets, and open
##   incidents with the buildings their QRF will search. Redrawn every few frames.

const Palette = preload("res://scripts/view/palette.gd")
const PX := 40.0
const INK := Color("#1c1c1c")

var lv
var director
var mode := "static"
var show_tint := true
var fill := true          # patterns over the rooms (far out); close in, only outlines and tags
var font: Font
var bold: Font


func setup(level, dir, m: String) -> void:
	lv = level
	director = dir
	mode = m
	font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.8
	bold = fv
	queue_redraw()


func _draw() -> void:
	if lv == null or director == null:
		return
	if mode == "static":
		_draw_static()
	else:
		_draw_dynamic()


func _draw_static() -> void:
	if not show_tint:
		return
	var bs_all: Array = director.bstate
	for bi in bs_all.size():
		var b: Dictionary = lv.bldgs[bi]
		var bs: Dictionary = bs_all[bi]
		var ow: int = bs["owner"]
		var lot: Dictionary = lv.lots[b["lot"]]
		var lr: Rect2 = lot["rect"]
		if ow >= 0:
			var col := Color(Palette.faction(ow), 0.55)
			var pat := Palette.pattern(ow)
			if fill:
				for rn in b["rooms"]:
					for rv in lv.rooms[rn]["rects"]:
						Palette.fill_pattern(self, _r(rv), pat, col, 1.7 * PX)
			else:
				# close in: a small badge of the pattern at the lot's front corner
				var lr_px := _r(lr)
				var badge := Rect2(lr_px.end.x - 150.0, (lr_px.position.y + 14.0) if lot["side"] == 0 else (lr_px.end.y - 70.0), 56.0, 56.0)
				draw_rect(badge, Color(1, 1, 1, 0.9))
				Palette.fill_pattern(self, badge, pat, Color(Palette.faction(ow), 1.0), 9.0)
				draw_rect(badge, INK, false, 2.0)
			draw_rect(_r(lr).grow(-6.0), Color(Palette.faction(ow), 0.9), false, 5.0)
			var tag: String = director.w.factions[ow]["tag"]
			var tp := Vector2(lr.end.x - 0.4, lr.position.y + 1.85 if lot["side"] == 0 else lr.end.y - 0.55) * PX
			var tw := bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
			draw_string(bold, tp - Vector2(tw, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(Palette.faction(ow), 0.9))
		else:
			draw_rect(_r(lr).grow(-6.0), Color(0.6, 0.6, 0.6, 0.6), false, 2.0)
		if b["spawn"]:
			_tag(lr, lot, "SPAWN POINT" if b["kind"] == "school" else "SPAWN POINT  ·  AMBULANCE BASE")
		elif b["kind"] == "police":
			_tag(lr, lot, "POLICE  ·  QRF BASE")


func _tag(lr: Rect2, lot: Dictionary, text: String) -> void:
	var y: float = lr.position.y + 4.2 if lot["side"] == 0 else lr.end.y - 3.0
	var p := Vector2(lr.position.x + 1.6, y) * PX
	var w := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_rect(Rect2(p + Vector2(-10, -32), Vector2(w + 20, 44)), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(p + Vector2(-10, -32), Vector2(w + 20, 44)), INK, false, 2.0)
	draw_string(bold, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)


func _draw_dynamic() -> void:
	var bs_all: Array = director.bstate
	for bi in bs_all.size():
		var bs: Dictionary = bs_all[bi]
		var b: Dictionary = lv.bldgs[bi]
		if bs["cap"] > 0.0 and bs["cap_fac"] >= 0:
			var c: Vector2 = b["centre"] * PX
			var wbar := 420.0
			var f: float = clampf(bs["cap"] / director.CAPTURE_TIME, 0.0, 1.0)
			var top := c + Vector2(-wbar / 2.0, -60.0)
			draw_rect(Rect2(top - Vector2(6, 6), Vector2(wbar + 12, 46)), Color(1, 1, 1, 0.92))
			Palette.fill_pattern(self, Rect2(top, Vector2(wbar * f, 34)), Palette.pattern(bs["cap_fac"]), INK, 9.0)
			draw_rect(Rect2(top, Vector2(wbar * f, 34)), Color(INK, 0.25))
			draw_rect(Rect2(top, Vector2(wbar, 34)), INK, false, 3.0)
			var txt := "%s  TAKING IT  %d s" % [director.w.factions[bs["cap_fac"]]["tag"], int(ceilf(director.CAPTURE_TIME - bs["cap"]))]
			draw_string(bold, top + Vector2(10, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
		if bs["target_of"] >= 0:
			var lr: Rect2 = lv.lots[b["lot"]]["rect"]
			_dashed_rect(_r(lr).grow(14.0), INK, 6.0, 40.0)
	# open incidents: the report point and the buildings being searched
	for inc in director.incidents:
		if inc["state"] == "clear" and director.w.t - inc.get("clear_t", 0.0) > 45.0:
			continue
		var p: Vector2 = inc["p"] * PX
		var pulse := 0.5 + 0.5 * sin(director.w.t * 4.0)
		draw_arc(p, 90.0 + 50.0 * pulse, 0.0, TAU, 40, Color(0.1, 0.1, 0.1, 0.85), 6.0)
		draw_arc(p, 30.0, 0.0, TAU, 20, INK, 6.0)
		var label := "INCIDENT %d  ·  %s%s" % [inc["id"], inc["state"].to_upper(), ("  ·  %d DUPLICATE%s" % [inc["dups"], "" if inc["dups"] == 1 else "S"]) if inc["dups"] > 0 else ""]
		draw_string(bold, p + Vector2(110, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
		if inc["state"] != "clear":
			var k := 0
			for bi2 in inc["search"]:
				k += 1
				var lr2: Rect2 = lv.lots[lv.bldgs[bi2]["lot"]]["rect"]
				_dashed_rect(_r(lr2).grow(8.0), INK, 5.0, 28.0)
				draw_string(bold, _r(lr2).position + Vector2(14, 46), "SEARCH %d" % k, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)


func _dashed_rect(r: Rect2, col: Color, wd: float, dash: float) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		draw_dashed_line(p[k], p[(k + 1) % 4], col, wd, dash)


static func _r(r: Rect2) -> Rect2:
	return Rect2(r.position * PX, r.size * PX)
