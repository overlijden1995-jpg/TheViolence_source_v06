extends "res://scripts/sim/level.gd"
## The endless-battle city: a grid of blocks between 18 m streets. Each block has two
## rows of lots back to back, one facing the street to the north and one the street to
## the south. Every lot is a building template (the eleven maps, a police station, a
## hospital, a school, or a park or car park filler) turned so its front faces the
## street, copied into one city-wide geometry with its rooms and doors renamed per lot.
## Lots are fenced on the sides and back; the front opens on the sidewalk through a gate.
## Blocks group into twelve neighbourhoods and six police precincts.
##
## Street cross-section (18 m): sidewalk 3 | parking 2.5 | lane 3.5 | lane 3.5 | parking 2.5 | sidewalk 3.
## Traffic keeps right; vehicles run on lane rails.

const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const TplPolice = preload("res://scripts/city/tpl_police.gd")
const TplHospital = preload("res://scripts/city/tpl_hospital.gd")
const TplSchool = preload("res://scripts/city/tpl_school.gd")
const TplOpen = preload("res://scripts/city/tpl_open.gd")

const NCOLS := 6
const NROWS := 5
const BW := 150.0          # block width
const BH := 100.0          # block depth (two lot rows of up to 50 m)
const ST := 18.0           # street width
const SW := 3.0            # sidewalk width
const LANE := 1.75         # lane centre offset from the street centre line
const PARK_OFF := 4.75     # parking lane centre offset
const WALK_OFF := 7.5      # sidewalk centre line offset

## Generic lots: map index, side of the map facing its street (0 N, 1 E, 2 S, 3 W).
const GENERIC := [
	{"map": 0, "front": 3, "kind": "house", "name": "Shotgun House", "w": 3},
	{"map": 1, "front": 2, "kind": "house", "name": "Cabin", "w": 2},
	{"map": 2, "front": 3, "kind": "house", "name": "Rooming House", "w": 2},
	{"map": 3, "front": 2, "kind": "shop", "name": "Corner Store", "w": 3},
	{"map": 4, "front": 2, "kind": "house", "name": "Bungalow", "w": 3},
	{"map": 5, "front": 2, "kind": "house", "name": "Duplex", "w": 3},
	{"map": 6, "front": 0, "kind": "house", "name": "Ranch House", "w": 2},
	{"map": 7, "front": 2, "kind": "motel", "name": "Motel", "w": 1},
	{"map": 8, "front": 0, "kind": "warehouse", "name": "Warehouse", "w": 2},
	{"map": 9, "front": 2, "kind": "compound", "name": "Compound", "w": 1},
	{"map": 10, "front": 2, "kind": "apartments", "name": "Apartment Block", "w": 3},
]
const HOOD_NAMES := ["Northgate", "Mill Hill", "Riverside", "Old Town", "Ironworks", "Market Square", "Eastport",
	"Chapel Hill", "Westfield", "Docklands", "Greenpark", "Southend", "Kilbride", "Saint Agnes"]
const STREETS_H := ["Harbour Street", "Kings Street", "Market Street", "Foundry Street", "Chapel Street", "Canal Street"]
const STREETS_V := ["Mill Avenue", "Water Avenue", "Grand Avenue", "Union Avenue", "Hope Avenue", "Bridge Avenue", "Station Avenue"]
const CITY_NAME := "PORT CARRICK"

var seed_val := 1
var rng := RandomNumberGenerator.new()
var tpls := {}             # key -> {lv, nav, front, kind, name, gate: Vector2 (template-local)}
var lots: Array = []       # see _place_lot
var bldgs: Array = []      # capturable or special buildings (lots with interior rooms)
var hoods: Array = []      # [{i, name, blocks, bldgs, centre}]
var precincts: Array = []  # [{i, blocks, station, rect}]
var blocks := {}           # Vector2i -> {rect, hood, precinct}
var parked: Array = []     # [Rect2] cars parked in the street
var room_bldg := {}        # room name -> building index
var garden: Array = []     # [Rect2] fenced back gardens (drawing only)
var fences: Array = []     # [Rect2] lot fences (drawing)
var progress := 0.0        # build progress 0..1 for a loading screen
var stage_name := ""
var _lot_grid := {}        # Vector2i (10 m) -> [lot indices]
var _specials := {}        # Vector2i(bx, by * 2 + side) -> template key


func _init(s := 1) -> void:
	seed_val = s
	id = "city"
	map_name = "Endless Battle"
	title = "THE VIOLENCE  -  " + CITY_NAME
	W = NCOLS * BW + (NCOLS + 1) * ST
	H = NROWS * BH + (NROWS + 1) * ST
	time_limit = INF
	fenced = false
	skip_posts = true
	notes = ["%s: %d BLOCKS, 12 NEIGHBOURHOODS, 6 PRECINCTS" % [CITY_NAME, NCOLS * NROWS], "STREETS 18 m  ·  1 SQUARE = 1 m", "ENDLESS BATTLE"]


## The whole build as steps, so a loading screen can show progress between them.
func build_steps() -> Array:
	return [
		["Drawing up the building templates", _stage_templates],
		["Surveying the street grid", _stage_layout],
		["Building the lots", _stage_lots],
		["Parking the cars", _stage_streets],
		["Indexing the city", _stage_index],
	]


func build() -> void:
	for st in build_steps():
		st[1].call()


# ================================================================== templates
func _stage_templates() -> void:
	rng.seed = seed_val
	geom = Geom.new()
	geom.setup(W, H)
	for g in GENERIC:
		var lv = Maps.MAPS[g["map"]].new()
		_tpl_add("m%02d" % g["map"], lv, g["front"], g["kind"], g["name"])
	_tpl_add("police", TplPolice.new(), 2, "police", "Police Station")
	_tpl_add("hospital", TplHospital.new(), 2, "hospital", "Hospital")
	_tpl_add("school", TplSchool.new(), 2, "school", "School")


func _tpl_add(key: String, lv, front: int, kind: String, nm: String) -> Dictionary:
	if tpls.has(key):
		return tpls[key]
	lv.fenced = false
	lv.skip_posts = true
	lv.id = "tpl_" + key
	lv.build()
	var keep: Array = []
	for d in lv.decor:
		if d["type"] != "road" and d["type"] != "text":
			keep.append(d)
	lv.decor = keep
	var nv = Nav.new()
	nv.build(lv)
	var rec := {"key": key, "lv": lv, "nav": nv, "front": front, "kind": kind, "name": nm,
		"frontage": lv.W if front % 2 == 0 else lv.H, "depth": lv.H if front % 2 == 0 else lv.W}
	rec["gate"] = _find_gate(rec)
	tpls[key] = rec
	return rec


func _open_tpl(kind: String, w: float, d: float) -> Dictionary:
	var v := rng.randi() % 3
	var lv = TplOpen.new(kind, snappedf(w, 0.1), snappedf(d, 0.1), v)
	return _tpl_add(lv.id, lv, 2, kind, lv.map_name)


## The gate: reachable floor 0.6 m inside the template's front edge, as near the middle of
## the frontage as possible, with nothing in the way out to the edge.
func _find_gate(rec: Dictionary) -> Vector2:
	var lv = rec["lv"]
	var nv = rec["nav"]
	var front: int = rec["front"]
	var along: float = lv.W if front % 2 == 0 else lv.H
	var best := Vector2(-1, -1)
	var off := 0.0
	while off < along / 2.0:
		for sgn in [1.0, -1.0]:
			var s: float = along / 2.0 + off * sgn
			var p := _front_point(lv, front, s, 0.6)
			var q := _front_point(lv, front, s, 0.31)
			if nv.reachable(p) and not lv.geom.blocked_disc(q, 0.3):
				return p
		off += 0.25
	return _front_point(lv, front, along / 2.0, 0.6) if best.x < 0 else best


static func _front_point(lv, front: int, s: float, depth: float) -> Vector2:
	match front:
		0:
			return Vector2(s, depth)
		1:
			return Vector2(lv.W - depth, s)
		2:
			return Vector2(s, lv.H - depth)
	return Vector2(depth, s)


# ================================================================== layout
func block_rect(bx: int, by: int) -> Rect2:
	return Rect2(ST + bx * (BW + ST), ST + by * (BH + ST), BW, BH)


## Centre of the street intersection (ix 0..NCOLS, iy 0..NROWS).
func node_pos(ix: int, iy: int) -> Vector2:
	return Vector2(ix * (BW + ST) + ST / 2.0, iy * (BH + ST) + ST / 2.0)


func _stage_layout() -> void:
	for by in NROWS:
		for bx in NCOLS:
			blocks[Vector2i(bx, by)] = {"rect": block_rect(bx, by), "hood": -1, "precinct": _precinct_of(bx, by)}
	_make_hoods()
	for p in 6:
		precincts.append({"i": p, "blocks": [], "station": -1, "rect": Rect2()})
	for k in blocks:
		var pi: int = blocks[k]["precinct"]
		precincts[pi]["blocks"].append(k)
		var br: Rect2 = blocks[k]["rect"].grow(ST / 2.0)
		precincts[pi]["rect"] = br if precincts[pi]["rect"].size == Vector2.ZERO else precincts[pi]["rect"].merge(br)
	_plan_specials()


func _precinct_of(bx: int, by: int) -> int:
	var px := bx * 3 / NCOLS
	var py := 0 if by < 3 else 1
	return py * 3 + px


## Twelve contiguous neighbourhoods of one to four blocks, grown from spread seeds.
func _make_hoods() -> void:
	var keys: Array = blocks.keys()
	var seeds: Array = [keys[rng.randi() % keys.size()]]
	while seeds.size() < 12:
		var best = null
		var bd := -1.0
		for k in keys:
			if seeds.has(k):
				continue
			var dmin := INF
			for s in seeds:
				dmin = minf(dmin, Vector2(k - s).length())
			dmin += rng.randf() * 0.3
			if dmin > bd:
				bd = dmin
				best = k
		seeds.append(best)
	for i in seeds.size():
		blocks[seeds[i]]["hood"] = i
		hoods.append({"i": i, "name": HOOD_NAMES[i], "blocks": [seeds[i]], "bldgs": [], "centre": Vector2.ZERO})
	var left := keys.size() - seeds.size()
	var guard := 0
	while left > 0 and guard < 2000:
		guard += 1
		var order: Array = range(hoods.size())
		order.sort_custom(func(a, b): return hoods[a]["blocks"].size() < hoods[b]["blocks"].size())
		for hi in order:
			var opts: Array = []
			for k2 in hoods[hi]["blocks"]:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nk: Vector2i = k2 + d
					if blocks.has(nk) and blocks[nk]["hood"] < 0:
						opts.append(nk)
			if opts.is_empty() or hoods[hi]["blocks"].size() >= 4:
				continue
			var pick: Vector2i = opts[rng.randi() % opts.size()]
			blocks[pick]["hood"] = hi
			hoods[hi]["blocks"].append(pick)
			left -= 1
			break
	# anything left over (boxed in) joins a neighbour regardless of size
	for k3 in keys:
		if blocks[k3]["hood"] >= 0:
			continue
		for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk2: Vector2i = k3 + d2
			if blocks.has(nk2) and blocks[nk2]["hood"] >= 0:
				blocks[k3]["hood"] = blocks[nk2]["hood"]
				hoods[blocks[k3]["hood"]]["blocks"].append(k3)
				break
	for h in hoods:
		var c := Vector2.ZERO
		for k4 in h["blocks"]:
			c += blocks[k4]["rect"].get_center()
		h["centre"] = c / maxf(1.0, h["blocks"].size())


## Police stations near each precinct's middle, three hospitals spread across the city,
## six schools in six different neighbourhoods. At most one special per lot row.
func _plan_specials() -> void:
	for p in precincts:
		var c := Vector2.ZERO
		for k in p["blocks"]:
			c += blocks[k]["rect"].get_center()
		c /= p["blocks"].size()
		var best: Vector2i = p["blocks"][0]
		for k2 in p["blocks"]:
			if blocks[k2]["rect"].get_center().distance_to(c) < blocks[best]["rect"].get_center().distance_to(c):
				best = k2
		_specials[Vector2i(best.x, best.y * 2 + rng.randi() % 2)] = "police"
	var hosp_cols := [1, 3, 4]
	var hosp_rows := [1, 3, 2]
	for i in 3:
		var bk := Vector2i(hosp_cols[i], hosp_rows[i])
		var slot := Vector2i(bk.x, bk.y * 2 + rng.randi() % 2)
		if _specials.has(slot):
			slot.y = bk.y * 2 + (1 - slot.y % 2)
		_specials[slot] = "hospital"
	var order: Array = range(hoods.size())
	_shuffle(order)
	var n_school := 0
	for hi in order:
		if n_school >= 6:
			break
		var hb: Array = hoods[hi]["blocks"].duplicate()
		_shuffle(hb)
		for k3 in hb:
			var placed := false
			for side in [rng.randi() % 2, 1]:
				var sl := Vector2i(k3.x, k3.y * 2 + side)
				if not _specials.has(sl):
					_specials[sl] = "school"
					placed = true
					break
			if placed:
				n_school += 1
				break


## Seeded shuffle (Array.shuffle() uses the global generator, so the same seed would
## build a different city).
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


# ================================================================== lots
func _stage_lots() -> void:
	for by in NROWS:
		for bx in NCOLS:
			for side in 2:
				_pack_row(bx, by, side)
	# buildings
	for li in lots.size():
		var lot: Dictionary = lots[li]
		var rooms_in: Array = []
		var area := 0.0
		var box := Rect2()
		for rn in lot["rooms"]:
			var rm: Dictionary = rooms[rn]
			if rm["exterior"]:
				continue
			rooms_in.append(rn)
			area += rm["area"]
			for rv in rm["rects"]:
				box = rv if box.size == Vector2.ZERO else box.merge(rv)
		if rooms_in.is_empty():
			continue
		var bk: Vector2i = lot["block"]
		var b := {"i": bldgs.size(), "lot": li, "kind": lot["tpl"]["kind"], "name": lot["tpl"]["name"],
			"rooms": rooms_in, "doors": lot["doors"], "area": area, "rect": box, "centre": box.get_center(),
			"hood": blocks[bk]["hood"], "precinct": blocks[bk]["precinct"], "address": lot["address"],
			"spawn": lot["tpl"]["kind"] in ["hospital", "school"], "police": lot["tpl"]["kind"] == "police"}
		lot["bldg"] = b["i"]
		for rn2 in rooms_in:
			room_bldg[rn2] = b["i"]
		bldgs.append(b)
		if not b["police"]:
			hoods[b["hood"]]["bldgs"].append(b["i"])
		else:
			precincts[b["precinct"]]["station"] = b["i"]


func _pack_row(bx: int, by: int, side: int) -> void:
	var br := block_rect(bx, by)
	var items: Array = []
	var special: String = _specials.get(Vector2i(bx, by * 2 + side), "")
	var remaining := BW
	if special != "":
		items.append(tpls[special])
		remaining -= tpls[special]["frontage"]
	var last := ""
	var guard := 0
	while guard < 20:
		guard += 1
		if remaining >= 16.0 and rng.randf() < 0.1:
			var fw := minf(remaining, rng.randf_range(16.0, 28.0))
			items.append(_open_tpl("park" if rng.randf() < 0.55 else "parking", fw, rng.randf_range(24.0, 40.0)))
			remaining -= fw
			continue
		var cands: Array = []
		var total := 0
		for g in GENERIC:
			var key := "m%02d" % g["map"]
			if tpls[key]["frontage"] <= remaining and key != last:
				cands.append([key, g["w"]])
				total += g["w"]
		if cands.is_empty():
			break
		var r := rng.randi() % total
		for c in cands:
			r -= c[1]
			if r < 0:
				items.append(tpls[c[0]])
				remaining -= tpls[c[0]]["frontage"]
				last = c[0]
				break
	if remaining >= 10.0:
		items.append(_open_tpl("park" if rng.randf() < 0.5 else "parking", remaining, rng.randf_range(22.0, 40.0)))
		remaining = 0.0
	_shuffle(items)
	var slack := remaining / maxf(1.0, items.size())
	var x := br.position.x
	var lefts: Array = []
	for it in items:
		var lw: float = it["frontage"] + slack
		lefts.append(_place_lot(it, Rect2(x, 0, lw, 0), bx, by, side))
		x += lw
	# fences: sides and backs, and the fenced gardens behind
	for li in lefts:
		var lot: Dictionary = lots[li]
		var lr: Rect2 = lot["rect"]
		var back_y: float = lr.end.y if side == 0 else lr.position.y
		_lot_fence(Rect2(lr.position.x - 0.06, lr.position.y, 0.12, lr.size.y))
		_lot_fence(Rect2(lr.end.x - 0.06, lr.position.y, 0.12, lr.size.y))
		_lot_fence(Rect2(lr.position.x, back_y - 0.06, lr.size.x, 0.12))
	var dmax := 0.0
	for li2 in lefts:
		dmax = maxf(dmax, lots[li2]["rect"].size.y)
	if side == 0:
		garden.append(Rect2(br.position.x, br.position.y, BW, BH / 2.0))
	else:
		garden.append(Rect2(br.position.x, br.position.y + BH / 2.0, BW, BH / 2.0))


func _lot_fence(r: Rect2) -> void:
	fences.append(r)
	walls.append(geom.add(r, Geom.WALL, 2.0, "fence"))


## Rotation that turns a template's front side to face north (0) or south (2).
static func _rot_for(front: int, target: int) -> int:
	return (target - front + 4) % 4


## Place one template in a lot. Returns the lot index.
func _place_lot(rec: Dictionary, span: Rect2, bx: int, by: int, side: int) -> int:
	var lv = rec["lv"]
	var target := 0 if side == 0 else 2
	var k := _rot_for(rec["front"], target)
	var tw: float = lv.W if k % 2 == 0 else lv.H
	var th: float = lv.H if k % 2 == 0 else lv.W
	var br := block_rect(bx, by)
	var ly := br.position.y if side == 0 else br.end.y - th
	var lot_r := Rect2(span.position.x, ly, span.size.x, th)
	var origin := Vector2(span.position.x + (span.size.x - tw) / 2.0, ly)
	var li := lots.size()
	var prefix := "L%d:" % li
	var lot := {"i": li, "tpl": rec, "k": k, "rect": lot_r, "origin": origin, "tw": tw, "th": th,
		"side": side, "block": Vector2i(bx, by), "prefix": prefix, "rooms": [], "doors": [], "bldg": -1,
		"front_n": Vector2(0, -1) if side == 0 else Vector2(0, 1)}
	lots.append(lot)
	# geometry
	var base := geom.obs.size()
	var tg = lv.geom
	for o in tg.obs:
		geom.add(xf_rect(lot, o["r"]), o["kind"], o["h"], o["name"], o["move"], o["sill"], o["lintel"])
	for wi in lv.walls:
		walls.append(base + wi)
	for wnd in lv.windows:
		windows.append({"r": xf_rect(lot, wnd["r"]), "axis": _axis(wnd["axis"], k)})
	for rn in lv.rooms:
		var rm: Dictionary = lv.rooms[rn]
		var rects: Array = []
		for rv in rm["rects"]:
			rects.append(xf_rect(lot, rv))
		var nm: String = prefix + rn
		rooms[nm] = {"rects": rects, "label": xf(lot, rm["label"]), "title": rm["title"], "exterior": rm["exterior"],
			"deck": rm["deck"], "area": rm["area"], "nowalls": true, "hall": rm["hall"], "lot": li}
		lot["rooms"].append(nm)
	for did in lv.doors:
		var d: Dictionary = lv.doors[did]
		var n: Vector2 = xd(k, d["n"])
		var nid: String = prefix + did
		doors[nid] = {"id": nid, "c": xf(lot, d["c"]), "n": n, "t": Vector2(-n.y, n.x), "half": d["half"],
			"a": "OUT" if d["a"] == "OUT" else prefix + d["a"], "b": "OUT" if d["b"] == "OUT" else prefix + d["b"],
			"hinge": d["hinge"], "arch": d["arch"], "lot": li}
		lot["doors"].append(nid)
	for pr in lv.props:
		props.append({"key": pr["key"], "r": xf_rect(lot, pr["r"]), "rot": pr["rot"] + 90.0 * k, "under": pr.get("under", false), "lot": li})
	for dc in lv.decor:
		var d2: Dictionary = dc.duplicate()
		if d2.has("r"):
			d2["r"] = xf_rect(lot, d2["r"])
		if d2.has("p"):
			d2["p"] = xf(lot, d2["p"])
		if d2.has("axis"):
			d2["axis"] = _axis(d2["axis"], k)
		d2["lot"] = li
		decor.append(d2)
	# gate and address
	lot["gate_in"] = xf(lot, rec["gate"])
	var gate_out: Vector2 = lot["gate_in"]
	gate_out.y = (lot_r.position.y - SW / 2.0) if side == 0 else (lot_r.end.y + SW / 2.0)
	lot["gate_out"] = gate_out
	var street_i := by if side == 0 else by + 1
	lot["street"] = street_i
	var num := 100 * (bx + 1) + 2 * int((lot_r.get_center().x - br.position.x) / 12.0) + (0 if side == 0 else 1)
	lot["address"] = "%d %s" % [num, STREETS_H[street_i]]
	var c0 := Vector2i(int(lot_r.position.x / 10.0), int(lot_r.position.y / 10.0))
	var c1 := Vector2i(int(lot_r.end.x / 10.0), int(lot_r.end.y / 10.0))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var key := Vector2i(cx, cy)
			if not _lot_grid.has(key):
				_lot_grid[key] = []
			_lot_grid[key].append(li)
	return li


static func _axis(a: String, k: int) -> String:
	if k % 2 == 0:
		return a
	return "v" if a == "h" else "h"


## Template-local point to world.
func xf(lot: Dictionary, p: Vector2) -> Vector2:
	var lv = lot["tpl"]["lv"]
	var o: Vector2 = lot["origin"]
	match int(lot["k"]):
		1:
			return o + Vector2(lv.H - p.y, p.x)
		2:
			return o + Vector2(lv.W - p.x, lv.H - p.y)
		3:
			return o + Vector2(p.y, lv.W - p.x)
	return o + p


## World point to template-local.
func inv(lot: Dictionary, q: Vector2) -> Vector2:
	var lv = lot["tpl"]["lv"]
	var p: Vector2 = q - lot["origin"]
	match int(lot["k"]):
		1:
			return Vector2(p.y, lv.H - p.x)
		2:
			return Vector2(lv.W - p.x, lv.H - p.y)
		3:
			return Vector2(lv.W - p.y, p.x)
	return p


## Rotate a direction by k quarter turns (clockwise on screen).
static func xd(k: int, d: Vector2) -> Vector2:
	match k % 4:
		1:
			return Vector2(-d.y, d.x)
		2:
			return -d
		3:
			return Vector2(d.y, -d.x)
	return d


func xf_rect(lot: Dictionary, r: Rect2) -> Rect2:
	var a := xf(lot, r.position)
	var b := xf(lot, r.end)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


# ================================================================== streets
func _stage_streets() -> void:
	# gates on each sidewalk keep the kerb clear in front of them
	var gates_by_street := {}
	for lot in lots:
		var key := Vector2i(lot["street"], lot["side"])
		if not gates_by_street.has(key):
			gates_by_street[key] = []
		gates_by_street[key].append(lot["gate_out"].x)
	for iy in NROWS + 1:
		var yc: float = node_pos(0, iy).y
		for bx in NCOLS:
			var x0: float = node_pos(bx, iy).x + ST / 2.0
			var x1: float = node_pos(bx + 1, iy).x - ST / 2.0
			# north kerb lane borders south-facing lots of the row above (side 1); south kerb: side 0
			_kerb_h(x0, x1, yc - PARK_OFF, gates_by_street.get(Vector2i(iy, 1), []), iy > 0)
			_kerb_h(x0, x1, yc + PARK_OFF, gates_by_street.get(Vector2i(iy, 0), []), iy < NROWS)
	for ix in NCOLS + 1:
		var xc: float = node_pos(ix, 0).x
		for by in NROWS:
			var y0: float = node_pos(ix, by).y + ST / 2.0
			var y1: float = node_pos(ix, by + 1).y - ST / 2.0
			_kerb_v(y0, y1, xc - PARK_OFF, ix > 0)
			_kerb_v(y0, y1, xc + PARK_OFF, ix < NCOLS)
	# the city edge: a wall beyond the outer sidewalks
	for r in [Rect2(0, 0, W, 0.3), Rect2(0, H - 0.3, W, 0.3), Rect2(0, 0, 0.3, H), Rect2(W - 0.3, 0, 0.3, H)]:
		walls.append(geom.add(r, Geom.WALL, 3.0, "perimeter"))


func _kerb_h(x0: float, x1: float, y: float, gates: Array, used: bool) -> void:
	if not used:
		return
	var x := x0 + 9.0
	while x + 4.4 < x1 - 9.0:
		var clear := true
		for gx in gates:
			if gx > x - 3.5 and gx < x + 7.9:
				clear = false
				break
		if not clear:
			x += 2.0
			continue
		var r := rng.randf()
		if r < 0.55:
			var key := "yard/car" if rng.randf() < 0.85 else "yard/van"
			var L := 4.4 if key == "yard/car" else 5.0
			var wd := 1.9 if key == "yard/car" else 2.0
			var rr := Rect2(x, y - wd / 2.0, L, wd)
			geom.add(rr, Geom.COVER, 1.45 if key == "yard/car" else 1.9, "parked car")
			props.append({"key": key, "r": rr, "rot": 0.0 if rng.randf() < 0.5 else 180.0, "under": false, "lot": -1})
			parked.append(rr)
			x += L + rng.randf_range(1.2, 4.0)
		elif r < 0.7:
			_street_tree(Vector2(x + 2.0, y))
			x += 6.0
		else:
			x += rng.randf_range(4.0, 9.0)


func _kerb_v(y0: float, y1: float, x: float, used: bool) -> void:
	if not used:
		return
	var y := y0 + 9.0
	while y + 4.4 < y1 - 9.0:
		var r := rng.randf()
		if r < 0.45:
			var rr := Rect2(x - 0.95, y, 1.9, 4.4)
			geom.add(rr, Geom.COVER, 1.45, "parked car")
			props.append({"key": "yard/car", "r": rr, "rot": 90.0 if rng.randf() < 0.5 else 270.0, "under": false, "lot": -1})
			parked.append(rr)
			y += 4.4 + rng.randf_range(1.2, 4.0)
		elif r < 0.65:
			_street_tree(Vector2(x, y + 2.0))
			y += 6.0
		else:
			y += rng.randf_range(4.0, 9.0)


func _street_tree(c: Vector2) -> void:
	geom.add(Rect2(c - Vector2(0.22, 0.22), Vector2(0.44, 0.44)), Geom.WALL, 6.0, "tree trunk")
	props.append({"key": "yard/tree", "r": Rect2(c - Vector2(1.7, 1.7), Vector2(3.4, 3.4)), "rot": 0.0, "under": true, "lot": -1})
	parked.append(Rect2(c - Vector2(0.22, 0.22), Vector2(0.44, 0.44)))


func _stage_index() -> void:
	geom.build_index()
	_index()
	_annotate()
	progress = 1.0


# ================================================================== queries
func lot_at(p: Vector2) -> int:
	var lst = _lot_grid.get(Vector2i(int(p.x / 10.0), int(p.y / 10.0)), null)
	if lst == null:
		return -1
	for li in lst:
		if (lots[li]["rect"] as Rect2).has_point(p):
			return li
	return -1


func bldg_at(p: Vector2) -> int:
	var rm := room_at(p)
	return room_bldg.get(rm, -1)


func building_doors(bi: int) -> Array:
	return bldgs[bi]["doors"]


func building_rooms(bi: int) -> Array:
	return bldgs[bi]["rooms"]


## Which street a point is on: [iy of the horizontal street or -1, ix of the vertical or -1].
func street_at(p: Vector2) -> Vector2i:
	var iy := -1
	var ix := -1
	var fy := fposmod(p.y, BH + ST)
	if fy < ST and p.y >= 0.0 and p.y <= H:
		iy = int(p.y / (BH + ST))
	var fx := fposmod(p.x, BW + ST)
	if fx < ST and p.x >= 0.0 and p.x <= W:
		ix = int(p.x / (BW + ST))
	return Vector2i(iy, ix)


func in_street(p: Vector2) -> bool:
	var s := street_at(p)
	return s.x >= 0 or s.y >= 0


func block_of(p: Vector2) -> Vector2i:
	var bx := clampi(int((p.x - ST) / (BW + ST)), 0, NCOLS - 1)
	var by := clampi(int((p.y - ST) / (BH + ST)), 0, NROWS - 1)
	return Vector2i(bx, by)


func hood_at(p: Vector2) -> int:
	return blocks[block_of(p)]["hood"]


func precinct_at(p: Vector2) -> int:
	return blocks[block_of(p)]["precinct"]


## A readable place for the ledger: room and address, or the street, with the neighbourhood.
func place_name(p: Vector2) -> String:
	var hood: String = hoods[hood_at(p)]["name"]
	var li := lot_at(p)
	if li >= 0:
		var lot: Dictionary = lots[li]
		var rm := room_at(p)
		var what: String = lot["tpl"]["name"]
		if rooms.has(rm) and not rooms[rm]["exterior"] and rooms[rm]["title"] != "":
			var rt: String = rooms[rm]["title"].capitalize()
			if rt.to_lower() == what.to_lower():
				return "%s %s (%s)" % [what, lot["address"], hood]
			return "%s, %s %s (%s)" % [rt, what.to_lower(), lot["address"], hood]
		return "outside the %s, %s (%s)" % [what.to_lower(), lot["address"], hood]
	var s := street_at(p)
	if s.x >= 0 and s.y >= 0:
		return "%s and %s (%s)" % [STREETS_H[s.x], STREETS_V[s.y], hood]
	if s.x >= 0:
		return "%s (%s)" % [STREETS_H[s.x], hood]
	if s.y >= 0:
		return "%s (%s)" % [STREETS_V[s.y], hood]
	return hood
