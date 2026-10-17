extends RefCounted
## Faction marks for the city. The plan stays greyscale (blood is the only colour), so
## each faction has a tone and a pattern: the pattern on its members' shoulders is the
## pattern that hatches its buildings on the map.
##   police: solid dark   Kilbride Crew: dots   Corvino Family: bands
##   Los Halcones: diagonal hatch   Zarya Bratva: cross-hatch   paramedics: white cross

const TONE := {0: Color("#2e2e2e"), 1: Color("#4c4c4c"), 2: Color("#5e5e5e"), 3: Color("#3e3e3e"),
	4: Color("#555555"), 5: Color("#8a8a8a")}
const PATTERN := {0: "solid", 1: "dots", 2: "bands", 3: "hatch", 4: "check", 5: "cross"}
const NEUTRAL := Color("#9a9a96")
## Alert pips are interface, not art: the three states the rules name.
const ALERT := [Color("#4f9d5a"), Color("#d4b13a"), Color("#b8322f")]


static func faction(fi: int) -> Color:
	return TONE.get(fi, NEUTRAL)


static func pattern(fi: int) -> String:
	return PATTERN.get(fi, "")


static func hexs(fi: int) -> String:
	return "#" + faction(fi).to_html(false)


## Sprite set for an operator: police (patrol or QRF), paramedics, the four gangs, or the
## two teams of a normal match.
static func look(o, w) -> String:
	if o.civ:
		return "c"
	if w == null or not w.city:
		return "a" if o.team == 0 else "b"
	if o.medic:
		return "pmed" if o.faction == 0 else "med"
	if o.faction == 0:
		var tm: Dictionary = w.teams[o.team] if o.team >= 0 and o.team < w.teams.size() else {}
		return "qrf" if tm.get("kind", "") == "qrf" else "pd"
	return "g%d" % clampi(o.faction, 1, 4)


## Fill a rectangle (canvas pixels) with a faction's pattern. Hairlines, so the pattern
## reads as a tone from far out and as marks close up.
static func fill_pattern(ci: CanvasItem, r: Rect2, pat: String, col: Color, step: float) -> void:
	match pat:
		"solid":
			ci.draw_rect(r, Color(col, col.a * 0.35))
		"bands":
			var y := ceilf(r.position.y / step) * step
			while y < r.end.y:
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col, -1.0)
				y += step
		"dots":
			var y2 := ceilf(r.position.y / step) * step
			var row := 0
			while y2 < r.end.y:
				var x2 := ceilf(r.position.x / step) * step + (step * 0.5 if row % 2 == 1 else 0.0)
				while x2 < r.end.x:
					ci.draw_rect(Rect2(x2 - step * 0.12, y2 - step * 0.12, step * 0.24, step * 0.24), col)
					x2 += step
				y2 += step
				row += 1
		"hatch":
			_diag(ci, r, col, step, 1.0)
		"check":
			_diag(ci, r, col, step * 1.2, 1.0)
			_diag(ci, r, col, step * 1.2, -1.0)


## Diagonal lines clipped to a rectangle (sgn 1: rising to the right, -1: falling).
static func _diag(ci: CanvasItem, r: Rect2, col: Color, step: float, sgn: float) -> void:
	var w := r.size.x
	var h := r.size.y
	var s := -h
	s = ceilf((r.position.x + s) / step) * step - r.position.x
	while s < w:
		# line x = s + t (t from 0..h) going up (sgn 1) or down (sgn -1)
		var t0 := maxf(0.0, -s)
		var t1 := minf(h, w - s)
		if t1 > t0:
			var a := Vector2(s + t0, h - t0) if sgn > 0.0 else Vector2(s + t0, t0)
			var b := Vector2(s + t1, h - t1) if sgn > 0.0 else Vector2(s + t1, t1)
			ci.draw_line(r.position + a, r.position + b, col, -1.0)
		s += step
