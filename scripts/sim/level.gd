extends RefCounted
## Base class for every map. A map script overrides _build() and describes its
## rooms, doors, windows, furniture and yard with the helpers below; this class
## turns room rectangles into walls, finds doors' sides, builds the room graph and
## generates posts for up to twenty operators a side.
## All units are metres; y grows downward (south).

const Geom = preload("res://scripts/sim/geom.gd")
const MAX_TEAM := 20
const EXT_T := 0.22         # exterior wall thickness
const INT_T := 0.12         # partition thickness
const CHECK_AREA := 10.5    # rooms this small are "check" rooms (PF10): looked into, not entered
const SWEEP_AREA := 60.0    # rooms this big are swept after entry

# ---------------------------------------------------------------- map description
var id := "base"
var map_name := "Base"
var title := "THE VIOLENCE"
var notes: Array = []        # title block lines
var W := 36.0
var H := 24.0
var time_limit := 300.0
var default_sizes := [3, 5]
var stage_hint := "Team A forms up at the stage line; team B holds the building."
var fenced := true

# ---------------------------------------------------------------- built data
var geom: Geom
var props: Array = []        # [{key, r: Rect2, rot: deg, under?}] sprites to draw
var windows: Array = []      # [{r: Rect2, axis: "h"|"v"}]
var walls: Array = []        # indices of obstacles drawn as walls (poche)
var doors := {}              # id -> {id, c, n, t, half, a, b, hinge, arch}
var rooms := {}              # name -> {rects: [Rect2], label: Vector2, title, exterior, area}
var openings: Array = []     # [{c, out, kind, vps: [Vector2]}] for exposure and scanning
var corners: Array = []      # [{p, room}] room corners for eye discipline
var decor: Array = []        # [{type, ...}] drawing-only items
var spawns := {}             # "A1" -> {p, face}
var patrol: Array = []       # waypoints for hunting
var stage_a: Array = []      # [{r: Rect2, face: float}] where team A forms up
var dims: Array = []         # [{a, b, text, ticks}] dimension strings; generated when empty
var adj := {}                # room -> [door ids]
var buildings: Array = []    # [Rect2] bounding boxes of connected interior rooms
var skip_posts := false      # templates for the city: no posts, no patrol, no building boxes
var corners_by_room := {}    # room -> [Vector2] (same points as corners)
var windows_by_room := {}    # room -> [{c, n_in}] windows opening into that room

var _door_defs: Array = []   # [{c, w, id, arch, hinge}]
var _win_defs: Array = []    # [{c, w}]
var _room_cells := {}        # Vector2i (2 m) -> [[Rect2, name]]
var _open_cells := {}        # Vector2i (4 m) -> [opening index]
var _indexed := false


func build() -> void:
	geom = Geom.new()
	geom.setup(W, H)
	if fenced:
		_fence()
	_build()
	geom.build_index()
	_index()
	_annotate()


## Override: describe the map.
func _build() -> void:
	pass


# ================================================================== description helpers
func _wall(r: Rect2, name := "wall") -> void:
	walls.append(geom.add(r, Geom.WALL, 3.0, name))


## Horizontal wall along y from x0 to x1 with gaps [[a, b, "door"|"window"|"gap"], ...].
func _hwall(x0: float, x1: float, y: float, t: float, gaps: Array, name := "wall") -> void:
	var x := x0
	for g in gaps:
		if g[0] > x:
			_wall(Rect2(x, y - t / 2, g[0] - x, t), name)
		if g[2] == "window":
			var r := Rect2(g[0], y - t / 2, g[1] - g[0], t)
			geom.add(r, Geom.WINDOW, 0.0, "window", true, 0.9, 2.1)
			windows.append({"r": r, "axis": "h"})
		x = g[1]
	if x1 > x:
		_wall(Rect2(x, y - t / 2, x1 - x, t), name)


func _vwall(y0: float, y1: float, x: float, t: float, gaps: Array, name := "wall") -> void:
	var y := y0
	for g in gaps:
		if g[0] > y:
			_wall(Rect2(x - t / 2, y, t, g[0] - y), name)
		if g[2] == "window":
			var r := Rect2(x - t / 2, g[0], t, g[1] - g[0])
			geom.add(r, Geom.WINDOW, 0.0, "window", true, 0.9, 2.1)
			windows.append({"r": r, "axis": "v"})
		y = g[1]
	if y1 > y:
		_wall(Rect2(x - t / 2, y, t, y1 - y), name)


func _prop(key: String, r: Rect2, kind: int, h: float, rot := 0.0, name := "") -> void:
	if kind >= 0:
		geom.add(r, kind, h, name if name != "" else key)
	if key != "":
		props.append({"key": key, "r": r, "rot": rot})


## Shorthand: a prop by top-left corner and size.
func _p(key: String, x: float, y: float, w: float, h: float, kind: int, height: float, rot := 0.0, name := "") -> void:
	_prop(key, Rect2(x, y, w, h), kind, height, rot, name)


func _trunk(c: Vector2, canopy := 3.6) -> void:
	geom.add(Rect2(c - Vector2(0.22, 0.22), Vector2(0.44, 0.44)), Geom.WALL, 6.0, "tree trunk")
	props.append({"key": "yard/tree", "r": Rect2(c - Vector2(canopy, canopy) / 2, Vector2(canopy, canopy)), "rot": 0.0, "under": true})


## Drawing-only plan notation: dash_rect, rect, steps, text, road, parking, pool, hatch.
func _decor(type: String, data: Dictionary) -> void:
	var d := data.duplicate()
	d["type"] = type
	decor.append(d)


## A swimming pool: drawn as water, blocks movement but not sight or bullets.
func _pool(r: Rect2) -> void:
	geom.add(r, Geom.LOW, 0.0, "pool")
	_decor("pool", {"r": r})


func _fence() -> void:
	var t := 0.12
	_wall(Rect2(0, 0, W, t), "fence")
	_wall(Rect2(0, H - t, W, t), "fence")
	_wall(Rect2(0, 0, t, H), "fence")
	_wall(Rect2(W - t, 0, t, H), "fence")


## A room made of one or more rectangles. opts: deck (unwalled exterior floor such as a
## porch or walkway), label (Vector2), nowalls (walls drawn by hand), hall (a corridor or
## stair hall: never treated as a small check room).
func _room(name: String, room_title: String, rects: Array, opts := {}) -> void:
	var area := 0.0
	var big: Rect2 = rects[0]
	for r in rects:
		area += (r as Rect2).get_area()
		if (r as Rect2).get_area() > big.get_area():
			big = r
	rooms[name] = {"rects": rects, "label": opts.get("label", big.get_center()), "title": room_title,
		"exterior": opts.get("deck", false), "deck": opts.get("deck", false), "area": area,
		"nowalls": opts.get("nowalls", false) or opts.get("deck", false), "hall": opts.get("hall", false)}


## A door centred at (x, y) on a room edge; w is the clear opening. opts: id, arch (no
## leaf: a cased opening, roll-up or dock door), hinge (+1/-1).
func _door(x: float, y: float, w := 0.9, opts := {}) -> void:
	# 0.9 m is the narrowest clear opening a 0.3 m body radius always fits through on
	# the 0.25 m navigation grid
	w = maxf(w, 0.9)
	_door_defs.append({"c": Vector2(x, y), "w": w, "id": opts.get("id", ""), "arch": opts.get("arch", false),
		"hinge": opts.get("hinge", 1)})


func _window(x: float, y: float, w := 1.2) -> void:
	_win_defs.append({"c": Vector2(x, y), "w": w})


## Register a door record by hand (for gates in hand-built walls).
func _add_door(did: String, c: Vector2, n: Vector2, half: float, arch := false, hinge := 1) -> void:
	var a := _side_room(c - n * 0.35)
	var b := _side_room(c + n * 0.35)
	doors[did] = {"id": did, "c": c, "n": n, "t": Vector2(-n.y, n.x), "half": half, "a": a, "b": b,
		"hinge": hinge, "arch": arch}


func _side_room(p: Vector2) -> String:
	var rm := room_at(p)
	return "OUT" if is_exterior(rm) else rm


static func _k(v: float) -> int:
	return int(round(v * 100.0))


## Walls from room rectangles. Every rectangle edge of a walled room becomes wall,
## except where both sides belong to the same room. A side that is outdoors (or a
## deck) makes it an exterior wall. Doors and windows cut gaps.
func _auto_walls() -> void:
	var hl := {}   # y key -> [[x0, x1]]
	var vl := {}   # x key -> [[y0, y1]]
	var hy := {}   # y key -> y
	var vx := {}
	for nm in rooms:
		var rm: Dictionary = rooms[nm]
		if rm["nowalls"]:
			continue
		for rv in rm["rects"]:
			var r: Rect2 = rv
			for y in [r.position.y, r.end.y]:
				var ky := _k(y)
				hy[ky] = y
				if not hl.has(ky):
					hl[ky] = []
				hl[ky].append([r.position.x, r.end.x])
			for x in [r.position.x, r.end.x]:
				var kx := _k(x)
				vx[kx] = x
				if not vl.has(kx):
					vl[kx] = []
				vl[kx].append([r.position.y, r.end.y])
	# assign doors and windows to lines
	var gaps_h := {}
	var gaps_v := {}
	var pending: Array = []
	for d in _door_defs:
		pending.append({"c": d["c"], "w": d["w"], "kind": "door", "def": d})
	for wd in _win_defs:
		pending.append({"c": wd["c"], "w": wd["w"], "kind": "window", "def": wd})
	for g in pending:
		var c: Vector2 = g["c"]
		var half: float = g["w"] / 2.0
		var placed := false
		var ky2 := _k(c.y)
		if hl.has(ky2):
			for iv in hl[ky2]:
				if c.x - half >= iv[0] - 0.01 and c.x + half <= iv[1] + 0.01:
					if not gaps_h.has(ky2):
						gaps_h[ky2] = []
					gaps_h[ky2].append([c.x - half, c.x + half, g["kind"]])
					g["axis"] = "h"
					placed = true
					break
		if not placed:
			var kx2 := _k(c.x)
			if vl.has(kx2):
				for iv in vl[kx2]:
					if c.y - half >= iv[0] - 0.01 and c.y + half <= iv[1] + 0.01:
						if not gaps_v.has(kx2):
							gaps_v[kx2] = []
						gaps_v[kx2].append([c.y - half, c.y + half, g["kind"]])
						g["axis"] = "v"
						placed = true
						break
		if not placed:
			push_warning("%s: opening at %s is not on any wall" % [id, str(c)])
			g["axis"] = "?"
	for ky3 in hl:
		_line_walls(true, hy[ky3], hl[ky3], gaps_h.get(ky3, []))
	for kx3 in vl:
		_line_walls(false, vx[kx3], vl[kx3], gaps_v.get(kx3, []))
	# door records
	var n_auto := 0
	for g in pending:
		if g["kind"] != "door" or g["axis"] == "?":
			continue
		var d: Dictionary = g["def"]
		var n := Vector2(0, 1) if g["axis"] == "h" else Vector2(1, 0)
		var did: String = d["id"]
		if did == "":
			n_auto += 1
			did = "D%d" % n_auto
			while doors.has(did):
				n_auto += 1
				did = "D%d" % n_auto
		_add_door(did, d["c"], n, d["w"] / 2.0, d["arch"], d["hinge"])


## One wall line: split the union of edge intervals at every endpoint, classify each
## piece by the rooms on either side, cut gaps, then merge into runs.
func _line_walls(horiz: bool, v: float, ivs: Array, gaps: Array) -> void:
	var cuts := {}
	for iv in ivs:
		cuts[_k(iv[0])] = iv[0]
		cuts[_k(iv[1])] = iv[1]
	for g in gaps:
		cuts[_k(g[0])] = g[0]
		cuts[_k(g[1])] = g[1]
	var keys := cuts.keys()
	keys.sort()
	var pts: Array = []
	for k in keys:
		pts.append(cuts[k])
	# pieces: [a, b, kind ("wall"|"door"|"window"), t]
	var pieces: Array = []
	for i in range(pts.size() - 1):
		var a: float = pts[i]
		var b: float = pts[i + 1]
		if b - a < 0.005:
			continue
		var m := (a + b) / 2.0
		var covered := false
		for iv in ivs:
			if m > iv[0] and m < iv[1]:
				covered = true
				break
		if not covered:
			continue
		var p1 := Vector2(m, v - 0.06) if horiz else Vector2(v - 0.06, m)
		var p2 := Vector2(m, v + 0.06) if horiz else Vector2(v + 0.06, m)
		var r1 := room_at(p1)
		var r2 := room_at(p2)
		if r1 == r2 and not is_exterior(r1):
			continue
		var t := EXT_T if (is_exterior(r1) or is_exterior(r2)) else INT_T
		var kind := "wall"
		for g in gaps:
			if m > g[0] and m < g[1]:
				kind = g[2]
		pieces.append([a, b, kind, t])
	# merge consecutive wall pieces of equal thickness into runs
	var runs: Array = []
	for pc in pieces:
		if pc[2] != "wall":
			runs.append(pc.duplicate())
			continue
		if not runs.is_empty():
			var last: Array = runs[-1]
			if last[2] == "wall" and absf(last[1] - pc[0]) < 0.005 and absf(last[3] - pc[3]) < 0.001:
				last[1] = pc[1]
				continue
		runs.append(pc.duplicate())
	for i in runs.size():
		var rn: Array = runs[i]
		var a2: float = rn[0]
		var b2: float = rn[1]
		var t2: float = rn[3]
		if rn[2] == "door":
			continue
		if rn[2] == "window":
			var wr := Rect2(a2, v - t2 / 2, b2 - a2, t2) if horiz else Rect2(v - t2 / 2, a2, t2, b2 - a2)
			geom.add(wr, Geom.WINDOW, 0.0, "window", true, 0.9, 2.1)
			windows.append({"r": wr, "axis": "h" if horiz else "v"})
			continue
		# extend free ends by half a thickness to close corners; never into a gap
		var prev_gap: bool = i > 0 and runs[i - 1][2] != "wall" and absf(runs[i - 1][1] - a2) < 0.005
		var next_gap: bool = i < runs.size() - 1 and runs[i + 1][2] != "wall" and absf(runs[i + 1][0] - b2) < 0.005
		var ext := EXT_T / 2.0
		if not prev_gap:
			a2 -= ext
		if not next_gap:
			b2 += ext
		var r := Rect2(a2, v - t2 / 2, b2 - a2, t2) if horiz else Rect2(v - t2 / 2, a2, t2, b2 - a2)
		_wall(r, "wall")


# ================================================================== queries
func is_exterior(rm: String) -> bool:
	if rm == "OUT":
		return true
	var r = rooms.get(rm, null)
	return r == null or r["exterior"]


func room_at(p: Vector2) -> String:
	if _indexed:
		var k := Vector2i(int(floor(p.x / 2.0)), int(floor(p.y / 2.0)))
		var lst = _room_cells.get(k, null)
		if lst == null:
			return "OUT"
		for e in lst:
			if (e[0] as Rect2).has_point(p):
				return e[1]
		return "OUT"
	for name in rooms:
		for r in rooms[name]["rects"]:
			if r.has_point(p):
				return name
	return "OUT"


## Doors and rooms of one building (the city overrides these; a single map is one site).
func building_doors(_bi: int) -> Array:
	return doors.keys()


func building_rooms(_bi: int) -> Array:
	return rooms.keys()


func room_area(name: String) -> float:
	return rooms[name]["area"] if rooms.has(name) else 0.0


## Interior rooms seat 2-4 entering operators (about 4.5 m2 each), five in rooms of
## 40 m2 or more; the rest of the element holds outside as rear security.
func room_capacity(name: String) -> int:
	var area := room_area(name)
	if area >= 40.0:
		return 5
	return clampi(int(area / 4.5), 2, 4)


func is_check_room(name: String) -> bool:
	return rooms.has(name) and not rooms[name]["exterior"] and not rooms[name]["hall"] and room_area(name) <= CHECK_AREA


func needs_sweep(name: String) -> bool:
	if not rooms.has(name):
		return false
	var a := room_area(name)
	return a >= SWEEP_AREA or (rooms[name]["rects"].size() > 1 and a >= 40.0)


func is_inside(p: Vector2) -> bool:
	return not is_exterior(room_at(p))


## Inward direction of a door when entering room `into`.
func inward(door_id: String, into: String) -> Vector2:
	var d: Dictionary = doors[door_id]
	return d["n"] if d["b"] == into else -d["n"]


## The room on the other side of a door from `into`.
func from_room(door_id: String, into: String) -> String:
	var d: Dictionary = doors[door_id]
	return d["a"] if d["b"] == into else d["b"]


## Distance from point p (inside a room rect) to that rect's edge along dir.
func extent_along(p: Vector2, dir: Vector2) -> float:
	var r = _rect_at(p)
	if r == null:
		return 2.0
	var best := 99.0
	if dir.x > 0.01:
		best = minf(best, (r.end.x - p.x) / dir.x)
	if dir.x < -0.01:
		best = minf(best, (r.position.x - p.x) / dir.x)
	if dir.y > 0.01:
		best = minf(best, (r.end.y - p.y) / dir.y)
	if dir.y < -0.01:
		best = minf(best, (r.position.y - p.y) / dir.y)
	return best


## The room rectangle containing p (grown by 1 cm), or null.
func _rect_at(p: Vector2):
	if _indexed:
		for dx in [0, -1, 1]:
			for dy in [0, -1, 1]:
				var lst = _room_cells.get(Vector2i(int(floor((p.x + dx * 0.02) / 2.0)), int(floor((p.y + dy * 0.02) / 2.0))), null)
				if lst == null:
					continue
				for e in lst:
					if (e[0] as Rect2).grow(0.01).has_point(p):
						return e[0]
		return null
	for name in rooms:
		for r in rooms[name]["rects"]:
			if r.grow(0.01).has_point(p):
				return r
	return null


## Indices of openings within r of p.
func openings_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := int(floor((p.x - r) / 4.0))
	var x1 := int(floor((p.x + r) / 4.0))
	var y0 := int(floor((p.y - r) / 4.0))
	var y1 := int(floor((p.y + r) / 4.0))
	var r2 := r * r
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var lst = _open_cells.get(Vector2i(cx, cy), null)
			if lst == null:
				continue
			for i in lst:
				if openings[i]["c"].distance_squared_to(p) <= r2:
					out.append(i)
	out.sort()
	return out


func stage_centre() -> Vector2:
	if stage_a.is_empty():
		var c := Vector2.ZERO
		var n := 0
		for k in spawns:
			if k.begins_with("A"):
				c += spawns[k]["p"]
				n += 1
		return c / maxf(1.0, n)
	var s := Vector2.ZERO
	for st in stage_a:
		s += (st["r"] as Rect2).get_center()
	return s / stage_a.size()


# ================================================================== annotation
func _index() -> void:
	_room_cells.clear()
	for name in rooms:
		for rv in rooms[name]["rects"]:
			var r: Rect2 = rv
			for cy in range(int(floor(r.position.y / 2.0)), int(floor(r.end.y / 2.0)) + 1):
				for cx in range(int(floor(r.position.x / 2.0)), int(floor(r.end.x / 2.0)) + 1):
					var k := Vector2i(cx, cy)
					if not _room_cells.has(k):
						_room_cells[k] = []
					_room_cells[k].append([r, name])
	_indexed = true


func _annotate() -> void:
	# openings: windows look out; exterior doors look out; interior doors both ways
	for w in windows:
		var r: Rect2 = w["r"]
		var c := r.get_center()
		var outward := _outward(c, w["axis"])
		openings.append({"c": c, "out": outward, "kind": "window", "vps": [c - outward * 1.2]})
	for did in doors:
		var d: Dictionary = doors[did]
		var vps := [d["c"] + d["n"] * 1.2, d["c"] - d["n"] * 1.2]
		openings.append({"c": d["c"], "out": d["n"], "kind": "door", "id": did, "vps": vps})
	_open_cells.clear()
	for i in openings.size():
		var oc: Vector2 = openings[i]["c"]
		var k := Vector2i(int(floor(oc.x / 4.0)), int(floor(oc.y / 4.0)))
		if not _open_cells.has(k):
			_open_cells[k] = []
		_open_cells[k].append(i)
	for name in rooms:
		if rooms[name]["exterior"]:
			continue
		for rv in rooms[name]["rects"]:
			var r: Rect2 = rv
			for k in 4:
				var p: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][k]
				var inset: Vector2 = (r.get_center() - p).normalized() * 0.35
				if room_at(p + inset) == name:
					corners.append({"p": p + inset, "room": name})
					if not corners_by_room.has(name):
						corners_by_room[name] = []
					corners_by_room[name].append(p + inset)
	for w in windows:
		var wr: Rect2 = w["r"]
		var wc := wr.get_center()
		var wn := Vector2(0, 1) if w["axis"] == "h" else Vector2(1, 0)
		for sgn in [1.0, -1.0]:
			var rm: String = room_at(wc + wn * 0.4 * sgn)
			if rm != "OUT" and rooms.has(rm) and not rooms[rm]["exterior"]:
				if not windows_by_room.has(rm):
					windows_by_room[rm] = []
				windows_by_room[rm].append({"c": wc, "n_in": wn * sgn})
	# room graph
	adj = {"OUT": []}
	for name in rooms:
		adj[name] = []
	for did in doors:
		var d: Dictionary = doors[did]
		for side in [d["a"], d["b"]]:
			if not adj.has(side):
				adj[side] = []
			if not adj[side].has(did):
				adj[side].append(did)
	if skip_posts:
		return
	_find_buildings()
	_posts()
	if patrol.is_empty():
		_gen_patrol()


func _outward(c: Vector2, axis: String) -> Vector2:
	var n := Vector2(0, 1) if axis == "h" else Vector2(1, 0)
	if is_exterior(room_at(c + n * 0.4)):
		return n
	if is_exterior(room_at(c - n * 0.4)):
		return -n
	return -n


## Bounding boxes of connected groups of interior rooms (for dimension strings).
func _find_buildings() -> void:
	buildings.clear()
	var seen := {}
	for name in rooms:
		if rooms[name]["exterior"] or seen.has(name):
			continue
		var stack: Array = [name]
		seen[name] = true
		var box: Rect2 = rooms[name]["rects"][0]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for rv in rooms[cur]["rects"]:
				box = box.merge(rv)
			for did in adj.get(cur, []):
				var d: Dictionary = doors[did]
				for nb in [d["a"], d["b"]]:
					if nb != "OUT" and not seen.has(nb) and not is_exterior(nb):
						seen[nb] = true
						stack.append(nb)
			# rooms sharing a wall count as one building even without a door
			for other in rooms:
				if seen.has(other) or rooms[other]["exterior"]:
					continue
				var touch := false
				for ra in rooms[cur]["rects"]:
					for rb in rooms[other]["rects"]:
						if (ra as Rect2).grow(0.05).intersects(rb):
							touch = true
				if touch:
					seen[other] = true
					stack.append(other)
		buildings.append(box)


# ================================================================== posts for 20 a side
## Called by the navigator once it knows which floor is reachable: any post that landed
## in a pocket (behind furniture, too close to a wall for the grid) moves to the
## nearest reachable cell.
func snap_posts(nav) -> void:
	for k in spawns:
		var p: Vector2 = spawns[k]["p"]
		var c: Vector2i = nav.cell_of(p)
		if nav.reach[c.y * nav.nx + c.x] != 1:
			spawns[k]["p"] = nav.cell_centre(nav.nearest_free(p))
	for i in patrol.size():
		var q: Vector2 = patrol[i]
		var cq: Vector2i = nav.cell_of(q)
		if nav.reach[cq.y * nav.nx + cq.x] != 1:
			patrol[i] = nav.cell_centre(nav.nearest_free(q))


func _posts() -> void:
	_posts_a()
	_posts_b()


func _taken(p: Vector2, gap: float) -> bool:
	for k in spawns:
		if (spawns[k]["p"] as Vector2).distance_to(p) < gap:
			return true
	return false


## Team A: rows in the stage rectangles, front row first; blocks of five slots share a
## rectangle so each element of five starts together.
func _posts_a() -> void:
	if stage_a.is_empty():
		return
	var lists: Array = []
	for st in stage_a:
		var r: Rect2 = st["r"]
		var f := Vector2.from_angle(st["face"])
		var c := r.get_center()
		var cands: Array = []
		var x := r.position.x + 0.45
		while x <= r.end.x - 0.3:
			var y := r.position.y + 0.45
			while y <= r.end.y - 0.3:
				var p := Vector2(x, y)
				if not geom.blocked_disc(p, 0.4):
					cands.append([-(p - c).dot(f), absf((p - c).dot(f.orthogonal())), p])
				y += 0.9
			x += 0.9
		cands.sort_custom(func(a, b): return a[0] < b[0] - 0.3 or (absf(a[0] - b[0]) <= 0.3 and a[1] < b[1]))
		var pts: Array = []
		for cd in cands:
			pts.append(cd[2])
		lists.append(pts)
	var used := []
	for i in lists.size():
		used.append(0)
	for i in MAX_TEAM:
		var sid := "A%d" % (i + 1)
		if spawns.has(sid):
			continue
		var ri := (i / 5) % lists.size()
		var placed := false
		for attempt in lists.size():
			var rr := (ri + attempt) % lists.size()
			var pts2: Array = lists[rr]
			while used[rr] < pts2.size():
				var p2: Vector2 = pts2[used[rr]]
				used[rr] += 1
				if not _taken(p2, 0.8):
					spawns[sid] = {"p": p2, "face": stage_a[rr]["face"]}
					placed = true
					break
			if placed:
				break
		if not placed:
			spawns[sid] = {"p": stage_a[0]["r"].get_center(), "face": stage_a[0]["face"]}


## Team B: defensive squads, one per room. Each block of five posts (B1-B5, B6-B10...)
## shares a room; rooms are picked big, deep and with few windows first, then spread
## through the building. Inside
## the room, posts cover its doors (outside doors first) and then its windows.
func _posts_b() -> void:
	var cands: Array = []
	for name in rooms:
		if not rooms[name]["exterior"] and not rooms[name]["hall"] and room_area(name) >= 20.0:
			cands.append(name)
	if cands.is_empty():
		for name in rooms:
			if not rooms[name]["exterior"] and room_area(name) >= 6.0:
				cands.append(name)
	cands.sort_custom(func(a, b): return room_area(a) > room_area(b) or (room_area(a) == room_area(b) and a < b))
	var chosen: Array = []
	for block in MAX_TEAM / 5:
		var slots: Array = []
		for j in 5:
			var sid := "B%d" % (block * 5 + j + 1)
			if not spawns.has(sid):
				slots.append(sid)
		if slots.is_empty():
			continue
		var best := ""
		var best_s := -INF
		for name in cands:
			if chosen.has(name):
				continue
			# big, deep (far from the attackers' stage) and with few windows
			var s := minf(room_area(name), 60.0) * 0.1
			s += minf((rooms[name]["label"] as Vector2).distance_to(stage_centre()), 40.0) * 0.3
			for op in room_openings(name):
				if op["kind"] == "window":
					s -= 0.5
			if not chosen.is_empty():
				var dmin := INF
				for cn in chosen:
					dmin = minf(dmin, (rooms[name]["label"] as Vector2).distance_to(rooms[cn]["label"]))
				s += minf(dmin, 30.0) * 0.5
			if s > best_s:
				best_s = s
				best = name
		var taken: Array = []
		for k in spawns:
			taken.append(spawns[k]["p"])
		var posts: Array = []
		if best != "":
			chosen.append(best)
			posts = cover_posts(best, slots.size(), taken)
		for j in slots.size():
			var post = posts[j] if j < posts.size() else _outside_post(stage_centre())
			if post == null:
				post = {"p": Vector2(W / 2.0, H / 2.0), "face": 0.0}
			spawns[slots[j]] = post


## A room's openings, outside doors first, then inside doors, then windows; n_in points
## into the room.
func room_openings(name: String) -> Array:
	var out: Array = []
	for did in adj.get(name, []):
		var d: Dictionary = doors[did]
		var other: String = d["a"] if d["b"] == name else d["b"]
		out.append({"c": d["c"], "n_in": inward(did, name), "kind": "door", "id": did,
			"rank": 0 if is_exterior(other) else 1, "other": other})
	for wi in windows_by_room.get(name, []):
		out.append({"c": wi["c"], "n_in": wi["n_in"], "kind": "window", "rank": 2, "other": "OUT"})
	out.sort_custom(func(a, b): return a["rank"] < b["rank"])
	return out


## n posts inside a room, each covering one of its openings (round-robin, or only the
## given opening): 2-5 m back from it, off its axis (out of the fatal funnel), with a clear
## view of it, near cover where possible, 1.2 m from each other and clear of doorways.
## With a navigator, posts are restricted to reachable floor.
func cover_posts(name: String, n: int, taken: Array, nav = null, only := {}) -> Array:
	var ops: Array = room_openings(name) if only.is_empty() else [only]
	var out: Array = []
	var used: Array = taken.duplicate()
	var step := 0.5 if room_area(name) < 100.0 else 1.0
	var room_doors: Array = []
	for did in adj.get(name, []):
		room_doors.append(doors[did]["c"])
	for i in n:
		var op: Dictionary = ops[i % ops.size()] if not ops.is_empty() else {}
		var best = null
		var best_s := -INF
		var fallback = null
		for rv in rooms[name]["rects"]:
			var r: Rect2 = rv
			var x := r.position.x + 0.45
			while x <= r.end.x - 0.4:
				var y := r.position.y + 0.45
				while y <= r.end.y - 0.4:
					var p := Vector2(x, y)
					y += step
					if room_at(p) != name:
						continue
					if nav != null:
						if not nav.reachable(p):
							continue
					elif geom.blocked_disc(p, 0.38):
						continue
					var clash := false
					for q in used:
						if (q as Vector2).distance_to(p) < 1.2:
							clash = true
							break
					if clash:
						continue
					var near_door := false
					for dc in room_doors:
						if (dc as Vector2).distance_to(p) < 1.1:
							near_door = true
							break
					if near_door:
						continue
					if fallback == null:
						fallback = p
					var s := 0.0
					if not op.is_empty():
						var v: Vector2 = p - op["c"]
						var dist := v.length()
						s -= absf(dist - 3.2)
						var ang := absf(v.angle_to(op["n_in"]))
						if ang > 0.35 and ang < 1.2:
							s += 1.0
						if not geom.sight_clear(p, 1.1, op["c"] + op["n_in"] * 0.2, 1.3):
							continue
					if geom.dist_to_kinds(p, [Geom.COVER, Geom.WALL], 1.0) < 0.75:
						s += 0.6
					if s > best_s:
						best_s = s
						best = p
				x += step
		if best == null:
			best = fallback
		if best == null:
			continue
		var face := 0.0
		if not op.is_empty():
			face = (op["c"] - best).angle()
		out.append({"p": best, "face": face, "op": op})
		used.append(best)
	return out


func _room_post(name: String, stage: Vector2):
	var best = null
	var best_s := -INF
	var room_doors: Array = adj.get(name, [])
	for rv in rooms[name]["rects"]:
		var r: Rect2 = rv
		var x := r.position.x + 0.5
		while x <= r.end.x - 0.45:
			var y := r.position.y + 0.5
			while y <= r.end.y - 0.45:
				var p := Vector2(x, y)
				y += 0.5
				if room_at(p) != name or geom.blocked_disc(p, 0.38) or _taken(p, 1.5):
					continue
				var dd := 99.0
				for did in room_doors:
					dd = minf(dd, p.distance_to(doors[did]["c"]))
				if dd < 1.3:
					continue
				var s := minf(dd, 6.0)
				if geom.dist_to_kinds(p, [Geom.COVER, Geom.WALL], 1.0) < 0.75:
					s += 1.2
				if s > best_s:
					best_s = s
					best = p
			x += 0.5
	if best == null:
		return null
	var face := 0.0
	var bd := INF
	for did in room_doors:
		var dc: Vector2 = doors[did]["c"]
		var dist := dc.distance_to(stage)
		if dist < bd:
			bd = dist
			face = (dc - best).angle()
	return {"p": best, "face": face}


func _outside_post(stage: Vector2):
	var best = null
	var best_s := -INF
	var y := 1.0
	while y < H - 1.0:
		var x := 1.0
		while x < W - 1.0:
			var p := Vector2(x, y)
			x += 1.0
			if room_at(p) != "OUT" or geom.blocked_disc(p, 0.4) or _taken(p, 3.0):
				continue
			var db := 99.0
			for b in buildings:
				var q := Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))
				db = minf(db, q.distance_to(p))
			if db < 2.0 or db > 8.0:
				continue
			var s := p.distance_to(stage) * 0.5
			if geom.dist_to_kinds(p, [Geom.COVER, Geom.WALL], 1.2) < 1.0:
				s += 4.0
			if s > best_s:
				best_s = s
				best = p
		y += 1.0
	if best == null:
		return null
	var face: float = (stage - best).angle()
	var bd := INF
	for did in adj.get("OUT", []):
		var dc: Vector2 = doors[did]["c"]
		if dc.distance_to(best) < bd:
			bd = dc.distance_to(best)
			face = (dc - best).angle()
	return {"p": best, "face": face}


## Hunting waypoints: every interior room, then open ground on a 7 m lattice, ordered
## as a nearest-neighbour tour from the stage.
func _gen_patrol() -> void:
	var pts: Array = []
	for name in rooms:
		if rooms[name]["exterior"]:
			continue
		var p: Vector2 = rooms[name]["label"]
		if not geom.blocked_disc(p, 0.35):
			pts.append(p)
	var y := 3.5
	while y < H - 2.0:
		var x := 3.5
		while x < W - 2.0:
			var q := Vector2(x, y)
			if room_at(q) == "OUT" and not geom.blocked_disc(q, 0.5):
				pts.append(q)
			x += 7.0
		y += 7.0
	var cur := stage_centre()
	patrol.clear()
	while not pts.is_empty():
		var bi := 0
		for i in pts.size():
			if (pts[i] as Vector2).distance_to(cur) < (pts[bi] as Vector2).distance_to(cur):
				bi = i
		cur = pts[bi]
		patrol.append(cur)
		pts.remove_at(bi)
