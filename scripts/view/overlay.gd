extends Node2D
## Per-frame analysis overlays (bible section 9): vision cones, recognition bars,
## aim traverse arcs, planned paths, tracers, muzzle flashes and habit callouts.

const PX := 40.0
const INK := Color("#1c1c1c")

var world
var show_cones := true
var show_rec := true
var show_aim := true
var show_paths := false
var tracers: Array = []   # {a, b, age}
var flashes: Array = []   # {p, dir, age}
var floats: Array = []    # {p, text, age}
var puffs: Array = []     # {p, age}
var ears: Array = []      # {id, dir, age}: someone just heard an enemy
var view := Rect2()       # city: only draw what is in view
var zoom := 1.0


func setup(w) -> void:
	world = w
	tracers.clear()
	flashes.clear()
	floats.clear()
	puffs.clear()
	ears.clear()


func handle(ev: Dictionary) -> void:
	match ev["type"]:
		"shot":
			tracers.append({"a": ev["from"], "b": ev["to"], "age": 0.0})
			flashes.append({"p": ev["from"], "dir": (ev["to"] - ev["from"]).angle(), "age": 0.0})
		"bad_on":
			var o = world.op_by_id(ev["id"])
			if o != null:
				_float(o.pos, "%s %s" % [ev["bad"], ev["name"].to_upper()])
		"impact":
			puffs.append({"p": ev["p"], "age": 0.0})
		"plate":
			_float(ev["p"], "plate")
		"float":
			_float(ev["p"], ev["text"])
		"heard":
			var o2 = world.op_by_id(ev["id"])
			if o2 != null:
				ears.append({"id": ev["id"], "dir": (ev["p"] - o2.pos).angle(), "age": 0.0})


## Stack labels that appear near the same spot so they never print over each other.
func _float(p: Vector2, text: String) -> void:
	var near: Array = []
	for f in floats:
		if f["p"].distance_to(p) < 1.5:
			near.append(f)
	if near.size() >= 4:
		floats.erase(near[0])
		near.remove_at(0)
	var used := {}
	for f in near:
		used[f["slot"]] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	floats.append({"p": p, "text": text, "age": 0.0, "slot": slot})


func tick_real(dt: float) -> void:
	for arr in [tracers, flashes, floats, puffs, ears]:
		for it in arr:
			it["age"] += dt
	tracers = tracers.filter(func(x): return x["age"] < 0.18)
	flashes = flashes.filter(func(x): return x["age"] < 0.07)
	floats = floats.filter(func(x): return x["age"] < 1.8)
	puffs = puffs.filter(func(x): return x["age"] < 0.4)
	ears = ears.filter(func(x): return x["age"] < 1.2)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font: Font = ThemeDB.fallback_font
	var cull: bool = world.city
	var vr := view.grow(300.0)
	for o in world.ops:
		if not o.alive() or o.mounted != null:
			continue
		var p: Vector2 = o.pos * PX
		if cull and (not vr.has_point(p) or zoom < 0.3 or o.medic):
			continue
		if o.civ or o.complying:
			continue
		if show_cones:
			var half: float = world.cone_half(o)
			var r := 7.0 * PX
			var pts := PackedVector2Array([p])
			for k in 25:
				var a: float = o.look_dir - half + 2.0 * half * k / 24.0
				pts.append(p + Vector2.from_angle(a) * r)
			draw_colored_polygon(pts, Color(0, 0, 0, 0.028 if o.team == 0 else 0.04))
			for k in [0, 24]:
				draw_line(p, pts[k + 1], Color(0, 0, 0, 0.18), 1.0)
			for a2 in [deg_to_rad(30.0), deg_to_rad(45.0)]:
				if a2 < half:
					for sgn in [-1.0, 1.0]:
						draw_dashed_line(p, p + Vector2.from_angle(o.look_dir + a2 * sgn) * r * 0.6, Color(0, 0, 0, 0.12), 1.0, 4.0)
		if show_paths and o.moving and o.path.size() > 0:
			var last := p
			for k in range(o.path_i, o.path.size()):
				var q: Vector2 = o.path[k] * PX
				draw_dashed_line(last, q, Color(0, 0, 0, 0.35), 1.0, 5.0)
				last = q
		if show_aim and not o.aim.is_empty():
			var e = world.op_by_id(o.aim["tid"])
			if e != null:
				var ep: Vector2 = e.pos * PX
				if not o.aim["on"]:
					var b: float = (e.pos - o.pos).angle()
					var a0: float = o.muzzle_dir
					draw_arc(p, 26.0, a0, a0 + angle_difference(a0, b), 12, INK, 1.4, true)
					draw_string(font, p + Vector2(14, -18), "%d ms" % int(o.aim["acq_left"] * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
				else:
					draw_dashed_line(p + Vector2.from_angle(o.muzzle_dir) * 20.0, ep, Color(0, 0, 0, 0.28), 1.0, 3.0)
	if show_rec:
		# one bar per target: the enemy closest to recognizing it, plus how many others are on it
		var best_on := {}
		for o in world.ops:
			if not o.alive():
				continue
			for eid in o.rec:
				var rv: float = o.rec[eid]
				if rv <= 0.02:
					continue
				var cur: Array = best_on.get(eid, [null, 0.02, 0])
				cur[2] += 1
				if rv > cur[1]:
					cur[0] = o
					cur[1] = rv
				best_on[eid] = cur
		for eid2 in best_on:
			var e = world.op_by_id(eid2)
			var bo: Array = best_on[eid2]
			if e == null or not e.alive() or bo[0] == null:
				continue
			if cull and (zoom < 0.3 or not vr.has_point(e.pos * PX)):
				continue
			var bv: float = bo[1]
			var base: Vector2 = e.pos * PX + Vector2(-14, -40)
			draw_rect(Rect2(base, Vector2(28, 4)), Color(1, 1, 1, 0.9))
			draw_rect(Rect2(base, Vector2(28 * minf(bv, 1.0), 4)), INK if bv >= 1.0 else Color("#6a6a6a"))
			draw_rect(Rect2(base, Vector2(28, 4)), INK, false, 1.0)
			var tag: String = bo[0].id + ("" if bo[2] <= 1 else " +%d" % (bo[2] - 1))
			draw_string(font, base + Vector2(30, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
	for tr in tracers:
		var al: float = 1.0 - tr["age"] / 0.18
		draw_line(tr["a"] * PX, tr["b"] * PX, Color(0.1, 0.1, 0.1, 0.55 * al), 1.0, true)
	for f in flashes:
		var c: Vector2 = f["p"] * PX
		var pts2 := PackedVector2Array()
		for i in 10:
			var a3: float = f["dir"] + i * TAU / 10.0
			pts2.append(c + Vector2.from_angle(a3) * (9.0 if i % 2 == 0 else 3.5))
		draw_colored_polygon(pts2, Color(1, 1, 1))
		pts2.append(pts2[0])
		draw_polyline(pts2, INK, 1.0)
	for ea in ears:
		var lo = world.op_by_id(ea["id"])
		if lo == null or not lo.alive():
			continue
		var al: float = 1.0 - ea["age"] / 1.2
		for k2 in 3:
			draw_arc(lo.pos * PX, 16.0 + 5.0 * k2, ea["dir"] - 0.45, ea["dir"] + 0.45, 6, Color(0.15, 0.15, 0.15, 0.55 * al), 1.0)
	for pf in puffs:
		draw_arc(pf["p"] * PX, 3.0 + 14.0 * pf["age"], 0, TAU, 14, Color(0.3, 0.3, 0.3, 0.5 * (1.0 - pf["age"] / 0.4)), 1.0)
	for fl in floats:
		var a4: float = clampf(1.6 - fl["age"], 0.0, 1.0)
		var pos: Vector2 = fl["p"] * PX + Vector2(-30, -48 - 14 * fl["slot"])
		draw_string(font, pos + Vector2(1, 1), fl["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, a4))
		draw_string(font, pos, fl["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.08, 0.08, 0.08, a4))
