extends RefCounted
## The endless battle's director: runs the city around the simulation.
##
## Gangs hold buildings. A building changes hands after a minute of domination: only one
## gang's members alive inside, nobody else there. Neighbourhood dominance (the share of
## its buildings held by the gang with the most) times neighbourhood size sets each gang's
## recruiting rate; recruits appear at the hospitals and schools it holds. Every two
## minutes a gang pushes its reserves from those spawn points out to the buildings on the
## edge of its territory, one squad of up to five per room. When that edge is full, its
## soldiers and militia form an assault team and go after a nearby building.
##
## Gang gunfire is reported. A report within 500 m of an original report from the last
## five minutes is a duplicate of that incident; otherwise it opens a new incident, queued
## first come first served for the nearest free QRF (ten special-operations officers in
## two vans) to search the three buildings nearest the report, then return to base.
## Two patrol convoys (two cars, four officers) drive each precinct and get out when they
## hear shooting. Police paramedics go straight to downed officers; hospital ambulances go
## in for everyone else once a QRF has reported all clear. A downed casualty has five
## minutes to reach an ambulance.

const Op = preload("res://scripts/sim/op.gd")
const Habits = preload("res://scripts/data/habits.gd")
const Names = preload("res://scripts/data/names.gd")
const Roads = preload("res://scripts/city/roads.gd")

const POLICE := 0
const MEDICS := 5
const GANG_DEFS := [
	{"name": "Kilbride Crew", "tag": "KC", "ranks": ["Lad", "Hard Man", "Veteran"]},
	{"name": "Corvino Family", "tag": "CF", "ranks": ["Associate", "Soldier", "Made Man"]},
	{"name": "Los Halcones", "tag": "LH", "ranks": ["Prospecto", "Soldado", "Veterano"]},
	{"name": "Zarya Bratva", "tag": "ZB", "ranks": ["Shestyorka", "Boyevik", "Brigadir"]},
]
const ECH_MIX := [["untrained", 0.7], ["militia", 0.2], ["regular", 0.1]]
const CAPTURE_TIME := 60.0
const PUSH_EVERY := 120.0
const REPORT_RADIUS := 500.0
const REPORT_WINDOW := 300.0
const HIRE_DELAY := 120.0
const RECOVER_DELAY := 120.0
const AMB_RADIUS := 120.0
const BODY_TIME := 900.0
const BODY_CAP := 70

var w
var lv
var nav
var roads
var rng := RandomNumberGenerator.new()
var names
var cfg := {"gang_cap": 60, "police_cap": 108, "gang_start": 34, "spawn_k": 0.15}
var gangs: Array = []        # [{fi, gi, name, tag, push_t, spawn_acc, rate, expansion: ti or -1, ...}]
var bstate: Array = []       # per building: {owner, cap_fac, cap, squads: {room: ti}, hold_rooms}
var stations: Array = []     # per precinct: {bldg, lot, stop, qrf: ti, state, vans: [v], convoys: [...], pamb: v, ...}
var hospitals: Array = []    # [{bldg, lot, stop, ambs: [v]}]
var incidents: Array = []    # [{id, p, t, points, search: [bldg], state, qrf, dups}]
var queue: Array = []        # incident ids waiting for a QRF
var reports: Array = []      # recent reports for the panel [{t, p, kind, inc}]
var hires: Array = []        # [{t, station, unit_kind}]
var returning: Array = []    # officers recovering in hospital [{t, op, station}]
var police_down: Array = []  # downed officers waiting for police paramedics (op ids)
var stats := {"captures": 0, "expansions": 0, "reports": 0, "incidents": 0, "saved": 0, "evacuated_dead": 0,
	"hired": 0, "returned": 0, "bled_out": 0}
var feed: Array = []         # director events for the panel [{t, text, kind}]
var serial := {}
var _tick := 0
var _last_report_p: Array = []
var hotspots: Array = []     # recent gunfire for the camera: [{p, t, n}]


func _init(world, level, city_nav, seed_val: int, opts := {}) -> void:
	w = world
	lv = level
	nav = city_nav
	rng.seed = seed_val * 31 + 7
	names = Names.new(seed_val)
	for k in opts:
		cfg[k] = opts[k]
	roads = Roads.new()
	roads.build(lv)


static func faction_list() -> Array:
	var out: Array = [{"id": POLICE, "name": "Port Carrick PD", "tag": "PD", "gang": false, "police": true, "medic": false}]
	for gi in GANG_DEFS.size():
		var g: Dictionary = GANG_DEFS[gi]
		out.append({"id": gi + 1, "name": g["name"], "tag": g["tag"], "gang": true, "police": false, "medic": false, "gi": gi})
	out.append({"id": MEDICS, "name": "Ambulance Service", "tag": "EMS", "gang": false, "police": false, "medic": true})
	return out


func say(text: String, kind := "city") -> void:
	w.say(text, kind)
	feed.append({"t": w.t, "text": text, "kind": kind})
	if feed.size() > 200:
		feed = feed.slice(50)


# ================================================================== setup
func setup() -> void:
	for b in lv.bldgs:
		bstate.append({"owner": -1, "cap_fac": -1, "cap": 0.0, "squads": {}, "hold": _hold_rooms(b), "target_of": -1, "last_cap": -999.0})
	for gi in GANG_DEFS.size():
		gangs.append({"fi": gi + 1, "gi": gi, "name": GANG_DEFS[gi]["name"], "tag": GANG_DEFS[gi]["tag"],
			"push_t": 40.0 + gi * 20.0, "spawn_acc": 0.0, "rate": 0.0, "expansion": -1, "spawn_i": 0,
			"home": [], "kills": 0, "lost": 0, "captured": 0})
	_claim_territory()
	for p in lv.precincts:
		_setup_station(p)
	for b in lv.bldgs:
		if b["kind"] == "hospital":
			_setup_hospital(b)
	for g in gangs:
		_initial_gang(g)
	_update_dominance()
	say("The battle for %s begins: %s." % [lv.CITY_NAME.capitalize(), ", ".join(gangs.map(func(g): return "%s %d" % [g["name"], _gang_count(g["fi"])]))])


## The rooms a gang garrisons in a building: one for a house, up to three for the
## biggest; big, deep rooms with few windows first.
func _hold_rooms(b: Dictionary) -> Array:
	var n := 1 if b["area"] < 260.0 else (2 if b["area"] < 650.0 else 3)
	var cands: Array = []
	for rn in b["rooms"]:
		var rm: Dictionary = lv.rooms[rn]
		if rm["hall"] or rm["area"] < 9.0:
			continue
		var s: float = minf(rm["area"], 50.0)
		s -= 3.0 * lv.windows_by_room.get(rn, []).size()
		s -= 5.0 if lv.adj.get(rn, []).size() > 3 else 0.0
		cands.append([s, rn])
	if cands.is_empty():
		for rn2 in b["rooms"]:
			cands.append([lv.rooms[rn2]["area"], rn2])
	cands.sort_custom(func(a, c): return a[0] > c[0])
	var out: Array = []
	for c in cands:
		if out.size() >= n:
			break
		# spread the squads: not two rooms side by side if it can be helped
		var touching := false
		for o in out:
			if _rooms_touch(o, c[1]):
				touching = true
		if touching and cands.size() > n + 1:
			continue
		out.append(c[1])
	if out.is_empty() and not cands.is_empty():
		out.append(cands[0][1])
	return out


func _rooms_touch(a: String, b: String) -> bool:
	for ra in lv.rooms[a]["rects"]:
		for rb in lv.rooms[b]["rects"]:
			if (ra as Rect2).grow(0.2).intersects(rb):
				return true
	return false


## Each gang starts with a home neighbourhood holding a school and one neighbourhood next
## to it; the four homes are spread across the city. The rest starts unclaimed.
func _claim_territory() -> void:
	var school_hoods: Array = []
	for b in lv.bldgs:
		if b["kind"] == "school" and not school_hoods.has(b["hood"]):
			school_hoods.append(b["hood"])
	var homes: Array = []
	if not school_hoods.is_empty():
		homes.append(school_hoods[rng.randi() % school_hoods.size()])
	while homes.size() < gangs.size():
		var best := -1
		var bd := -1.0
		var pool: Array = school_hoods if school_hoods.size() > homes.size() else range(lv.hoods.size())
		for h in pool:
			if homes.has(h):
				continue
			var dmin := INF
			for hh in homes:
				dmin = minf(dmin, (lv.hoods[h]["centre"] as Vector2).distance_to(lv.hoods[hh]["centre"]))
			if dmin > bd:
				bd = dmin
				best = h
		homes.append(best)
	var taken: Dictionary = {}
	for gi in gangs.size():
		gangs[gi]["home"] = [homes[gi]]
		taken[homes[gi]] = true
	for gi2 in gangs.size():
		var h0: int = homes[gi2]
		var best2 := -1
		var bd2 := INF
		for h2 in lv.hoods.size():
			if taken.has(h2):
				continue
			var d: float = (lv.hoods[h2]["centre"] as Vector2).distance_to(lv.hoods[h0]["centre"])
			if d < bd2:
				bd2 = d
				best2 = h2
		if best2 >= 0:
			taken[best2] = true
			gangs[gi2]["home"].append(best2)
	for g in gangs:
		for h3 in g["home"]:
			for bi in lv.hoods[h3]["bldgs"]:
				bstate[bi]["owner"] = g["fi"]


func _initial_gang(g: Dictionary) -> void:
	var fi: int = g["fi"]
	# enough to hold every spawn point and every room on the edge, plus a reserve squad
	var budget := 5
	for bi0 in _owned(fi):
		if lv.bldgs[bi0]["spawn"]:
			budget += 5
	for bi1 in _perimeter(fi):
		if not lv.bldgs[bi1]["spawn"]:
			budget += 5 * bstate[bi1]["hold"].size()
	budget = mini(budget, int(cfg["gang_cap"]) - 6)
	g["start"] = budget
	# a squad at every spawn point it holds
	for bi in _owned(fi):
		if lv.bldgs[bi]["spawn"] and budget > 0:
			var n := mini(5, budget)
			_new_squad(fi, bi, bstate[bi]["hold"][0], n, true)
			budget -= n
	# then a squad in each held room of the buildings on the edge, nearest the enemy first
	var edge := _perimeter(fi)
	edge.sort_custom(func(a, b): return _threat_dist(fi, a) < _threat_dist(fi, b))
	for bi2 in edge:
		if lv.bldgs[bi2]["spawn"]:
			continue
		for rn in bstate[bi2]["hold"]:
			if budget <= 0:
				break
			var n2 := mini(5, budget)
			_new_squad(fi, bi2, rn, n2, true)
			budget -= n2
	while budget > 0:
		var sp := _spawn_points(fi)
		if sp.is_empty():
			break
		var n3 := mini(5, budget)
		if not _add_reserve(fi, sp[rng.randi() % sp.size()], n3):
			break
		budget -= n3


# ================================================================== operators and units
func _next_id(prefix: String) -> String:
	serial[prefix] = serial.get(prefix, 0) + 1
	return "%s%d" % [prefix, serial[prefix]]


func _gang_echelon() -> String:
	var r := rng.randf()
	for e in ECH_MIX:
		r -= e[1]
		if r < 0.0:
			return e[0]
	return "untrained"


## A new operator, configured from an echelon preset with a sprinkling of personality.
func _make_op(fi: int, ti: int, ech: String, pos: Vector2, face: float, opts := {}) -> Object:
	var good := {}
	for gid in Habits.preset_good(ech):
		good[gid] = true
	var bad := {}
	for b in Habits.stress_bad_ids():
		bad[b] = true
	for b2 in Habits.BAD:
		if b2["kind"] == "trait" and rng.randf() < 0.05:
			bad[b2["id"]] = true
	var traits := {}
	if rng.randf() < 0.06:
		traits["TR01"] = true
	elif rng.randf() < 0.06:
		traits["TR02"] = true
	var fac: Dictionary = w.factions[fi]
	var nm := ""
	var rank := ""
	var oid := ""
	if fac.get("gang", false):
		nm = names.gang_name(fac["gi"])
		var ri: int = {"untrained": 0, "militia": 1, "regular": 2}.get(ech, 0)
		rank = GANG_DEFS[fac["gi"]]["ranks"][ri]
		oid = _next_id(fac["tag"])
	elif fac.get("medic", false) or opts.get("medic", false):
		nm = names.diverse_name(0.4)
		rank = "Police Paramedic" if fi == POLICE else "Paramedic"
		oid = _next_id("M")
	else:
		nm = names.diverse_name(0.25)
		rank = opts.get("rank", "Officer")
		oid = _next_id("P")
	var c := {"id": oid, "team": ti, "slot": w.teams[ti]["members"].size(), "echelon": ech, "good": good, "bad": bad,
		"plates": Habits.PRESET_PLATES[ech], "exp": Habits.PRESET_EXP[ech], "traits": traits, "pos": pos, "face": face,
		"faction": fi, "name": nm, "rank": rank, "medic": opts.get("medic", false), "alert": opts.get("alert", 0)}
	var o = Op.new()
	o.configure(c)
	o.reset()
	o.pos = pos
	w.add_op(o)
	return o


func _unit(fi: int, kind: String, tag: String, posture: String, extra := {}) -> int:
	var opts := {"kind": kind, "stay": true, "base_alert": extra.get("base_alert", 0)}
	for k in extra:
		opts[k] = extra[k]
	return w.new_unit(fi, posture, tag, opts)


## A garrison or reserve squad of n new recruits in one room of a building.
func _new_squad(fi: int, bi: int, room: String, n: int, initial := false) -> int:
	var g: Dictionary = gangs[fi - 1]
	var b: Dictionary = lv.bldgs[bi]
	var ti := _unit(fi, "garrison", "%s %s" % [g["tag"], _short(b)], "hold", {"bldg": bi, "fixed_room": room})
	var c: Vector2 = nav.snap(lv.rooms[room]["label"])
	for i in n:
		var p: Vector2 = nav.snap(c + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
		if lv.room_at(p) != room:
			p = c
		_make_op(fi, ti, _gang_echelon(), p, rng.randf() * TAU)
	w.brain.init_team(w.teams[ti])
	bstate[bi]["squads"][room] = ti
	return ti


func _short(b: Dictionary) -> String:
	return "%s %s" % [b["name"], b["address"].split(" ")[0]]


## Move an operator into another unit (re-forms that unit's elements).
func _transfer(o, ti: int) -> void:
	var old: int = o.team
	if old == ti:
		return
	if old >= 0 and old < w.teams.size():
		var tm: Dictionary = w.teams[old]
		tm["members"].erase(o)
		w.team_ops[old].erase(o)
		for el in tm["elements"]:
			el["members"].erase(o)
			el["sectors"].erase(o.id)
			el["entry"].erase(o.id)
	o.team = ti
	o.el = -1
	w.teams[ti]["members"].append(o)
	w.team_ops[ti].append(o)


func _alive_members(ti: int) -> Array:
	var out: Array = []
	for m in w.teams[ti]["members"]:
		if m.alive():
			out.append(m)
	return out


func _gang_count(fi: int) -> int:
	var n := 0
	for o in w.ops:
		if o.faction == fi and o.alive():
			n += 1
	return n


func _owned(fi: int) -> Array:
	var out: Array = []
	for bi in bstate.size():
		if bstate[bi]["owner"] == fi:
			out.append(bi)
	return out


func _spawn_points(fi: int) -> Array:
	var out: Array = []
	for bi in _owned(fi):
		if lv.bldgs[bi]["spawn"]:
			out.append(bi)
	return out


## Distance from a building to the nearest building the gang doesn't hold (police aside).
func _threat_dist(fi: int, bi: int) -> float:
	var c: Vector2 = lv.bldgs[bi]["centre"]
	var best := INF
	for bj in bstate.size():
		if bstate[bj]["owner"] == fi or lv.bldgs[bj]["police"]:
			continue
		best = minf(best, c.distance_to(lv.bldgs[bj]["centre"]))
	return best


## Buildings on the edge of a gang's territory: within 90 m of one it doesn't hold.
func _perimeter(fi: int) -> Array:
	var out: Array = []
	for bi in _owned(fi):
		if _threat_dist(fi, bi) < 90.0:
			out.append(bi)
	return out


# ================================================================== police and hospitals
func _setup_station(p: Dictionary) -> void:
	var bi: int = p["station"]
	if bi < 0:
		return
	var b: Dictionary = lv.bldgs[bi]
	var lot: Dictionary = lv.lots[b["lot"]]
	var stop: Vector2 = roads.lot_stop(lot)
	var st := {"i": stations.size(), "precinct": p["i"], "bldg": bi, "lot": b["lot"], "stop": stop, "qrf": -1,
		"state": "base", "inc": -1, "vans": [], "convoys": [], "pamb": null, "medics": [], "search_i": 0, "state_t": 0.0}
	stations.append(st)
	bstate[bi]["owner"] = POLICE
	# QRF: ten special-operations officers in two elements, based in the station
	var ti := _unit(POLICE, "qrf", "QRF %d" % (st["i"] + 1), "hold", {"bldg": bi, "base_alert": 0})
	st["qrf"] = ti
	w.teams[ti]["station"] = st["i"]
	for i in 10:
		_make_op(POLICE, ti, "sof", _station_spot(st), PI / 2.0, {"rank": "Sergeant" if i % 5 == 0 else "Officer"})
	w.brain.init_team(w.teams[ti])
	var dir := 0.0 if lot["side"] == 0 else PI
	for k in 2:
		st["vans"].append(roads.add_vehicle("van", stop + Vector2(-10.0 - 7.0 * k, 0).rotated(dir), dir, {"station": st["i"]}))
	st["pamb"] = roads.add_vehicle("pamb", stop + Vector2(12.0, 0).rotated(dir), dir, {"station": st["i"], "job": "idle"})
	for k2 in 2:
		var m = _make_op(POLICE, _medic_unit(), "regular", _station_spot(st), 0.0, {"medic": true})
		_mount(m, st["pamb"])
		st["medics"].append(m)
	# two patrol convoys, two cars each, two officers per car
	for c in 2:
		var cti := _unit(POLICE, "convoy", "Patrol %d-%d" % [st["i"] + 1, c + 1], "wait", {"base_alert": 0})
		w.teams[cti]["station"] = st["i"]
		var cars: Array = []
		for k3 in 2:
			var car: Dictionary = roads.add_vehicle("car", stop + Vector2(24.0 + 7.0 * k3 + 16.0 * c, 0).rotated(dir), dir, {"station": st["i"]})
			cars.append(car)
			for s in 2:
				var o = _make_op(POLICE, cti, "police", car["pos"], dir, {"rank": "Senior Officer" if s == 0 and k3 == 0 else "Officer"})
				_mount(o, car)
		w.brain.init_team(w.teams[cti])
		var cv := {"unit": cti, "cars": cars, "state": "patrol", "node": -1, "prev": -1, "until": 0.0, "station": st["i"]}
		st["convoys"].append(cv)
		_patrol_next(cv)


var _medic_ti := -1
var _ems_ti := -1


## Paramedics share one unit per service (they never take part in the fighting).
func _medic_unit() -> int:
	if _medic_ti < 0:
		_medic_ti = _unit(POLICE, "medics", "Police paramedics", "wait")
	return _medic_ti


func _ems_unit() -> int:
	if _ems_ti < 0:
		_ems_ti = _unit(MEDICS, "medics", "Ambulance crews", "wait")
	return _ems_ti


func _station_spot(st: Dictionary) -> Vector2:
	var b: Dictionary = lv.bldgs[st["bldg"]]
	var rn: String = b["rooms"][rng.randi() % b["rooms"].size()]
	return nav.snap(lv.rooms[rn]["label"] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))


func _setup_hospital(b: Dictionary) -> void:
	var lot: Dictionary = lv.lots[b["lot"]]
	var stop: Vector2 = roads.lot_stop(lot)
	var dir := 0.0 if lot["side"] == 0 else PI
	var h := {"i": hospitals.size(), "bldg": b["i"], "lot": b["lot"], "stop": stop, "ambs": []}
	hospitals.append(h)
	for k in 2:
		var v: Dictionary = roads.add_vehicle("amb", stop + Vector2(-8.0 + 16.0 * k, 0).rotated(dir), dir, {"hospital": h["i"], "job": "idle"})
		v["medics"] = []
		for k2 in 2:
			var m = _make_op(MEDICS, _ems_unit(), "regular", stop, 0.0, {"medic": true})
			_mount(m, v)
			v["medics"].append(m)
		h["ambs"].append(v)


func _mount(o, v: Dictionary) -> void:
	o.mounted = v
	o.pos = v["pos"]
	o.moving = false
	o.path = PackedVector2Array()
	o.aim = {}
	if not v["seats"].has(o):
		v["seats"].append(o)


func _dismount(o, p: Vector2) -> void:
	var v = o.mounted
	if v != null:
		v["seats"].erase(o)
	o.mounted = null
	o.pos = nav.snap(p)
	o.spawn = o.pos
	o.vel = Vector2.ZERO
	o.room = lv.room_at(o.pos)
	o.hot = true
	o.hot_next = w.t


# ================================================================== the tick
func _pt(k: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	if w.brain.fine:
		w.prof[k] = w.prof.get(k, 0) + t1 - t0
	return t1


func tick() -> void:
	_tick += 1
	var t0 := Time.get_ticks_usec()
	roads.step(w.DT)
	_sync_mounted()
	_carry_step()
	t0 = _pt("d_roads", t0)
	if _tick % 15 == 0:
		_medic_jobs()
		t0 = _pt("d_medic", t0)
		_qrf_jobs()
		t0 = _pt("d_qrf", t0)
		_convoy_jobs()
		t0 = _pt("d_convoy", t0)
	if _tick % 30 == 0:
		_captures()
		t0 = _pt("d_capture", t0)
		_hires_and_returns()
		_retire_bodies()
		t0 = _pt("d_hire_bodies", t0)
	if _tick % 150 == 0:
		_update_dominance()
		_tidy_units()
		t0 = _pt("d_tidy", t0)
	if _tick % 30 == 5:
		_spawns(1.0)
		t0 = _pt("d_spawn", t0)
		for g in gangs:
			if w.t >= g["push_t"]:
				g["push_t"] = w.t + PUSH_EVERY
				_push(g)
		t0 = _pt("d_push", t0)
		_expansion_jobs()
		t0 = _pt("d_expansion", t0)


func _sync_mounted() -> void:
	for v in roads.vehicles:
		for o in v["seats"]:
			o.pos = v["pos"]
		for o2 in v["cargo"]:
			o2.pos = v["pos"]


func dispose() -> void:
	w = null


# ================================================================== captures and dominance
func _captures() -> void:
	var inside := {}   # building -> {faction: count}
	for o in w.ops:
		if not o.alive() or o.medic or o.mounted != null:
			continue
		var bi: int = lv.room_bldg.get(o.room, -1)
		if bi < 0:
			continue
		if not inside.has(bi):
			inside[bi] = {}
		inside[bi][o.faction] = inside[bi].get(o.faction, 0) + 1
	for bi2 in bstate.size():
		var bs: Dictionary = bstate[bi2]
		if lv.bldgs[bi2]["police"]:
			continue
		var occ: Dictionary = inside.get(bi2, {})
		var gang_in: Array = []
		for f in occ:
			if w.factions[f]["gang"]:
				gang_in.append(f)
		var capper := -1
		if gang_in.size() == 1 and gang_in[0] != bs["owner"] and not occ.has(POLICE):
			capper = gang_in[0]
		if capper >= 0:
			if bs["cap_fac"] != capper:
				bs["cap_fac"] = capper
				bs["cap"] = 0.0
			bs["cap"] += 1.0
			if bs["cap"] >= CAPTURE_TIME:
				_capture(bi2, capper)
		elif bs["cap"] > 0.0:
			if gang_in.is_empty() and not occ.has(POLICE):
				bs["cap"] = maxf(0.0, bs["cap"] - 1.0)
			if bs["cap"] <= 0.0:
				bs["cap_fac"] = -1


func _capture(bi: int, fi: int) -> void:
	var bs: Dictionary = bstate[bi]
	var old: int = bs["owner"]
	bs["owner"] = fi
	bs["cap"] = 0.0
	bs["cap_fac"] = -1
	bs["last_cap"] = w.t
	stats["captures"] += 1
	gangs[fi - 1]["captured"] += 1
	var b: Dictionary = lv.bldgs[bi]
	say("%s take the %s at %s (%s)%s" % [w.factions[fi]["name"], b["name"].to_lower(), b["address"], lv.hoods[b["hood"]]["name"],
		"" if old < 0 else " from the " + w.factions[old]["name"]], "city")
	w.emit({"type": "capture", "bldg": bi, "faction": fi, "old": old})
	# the old owner's squads there are now strays; the director re-tasks them
	for rn in bs["squads"].keys():
		var ti: int = bs["squads"][rn]
		if ti >= 0 and ti < w.teams.size() and w.teams[ti]["faction"] != fi:
			bs["squads"].erase(rn)
	# an assault team that took it becomes its garrison
	var g: Dictionary = gangs[fi - 1]
	var ex: int = g["expansion"]
	if ex >= 0 and w.teams[ex].get("target", -1) == bi:
		_settle_assault(g, ex, bi)
	_update_dominance()


## Dominance: the gang holding the most of a neighbourhood's buildings dominates it by its
## share of them. Recruiting rate = sum of dominance x neighbourhood size.
func _update_dominance() -> void:
	for g in gangs:
		g["rate"] = 0.0
		g["hoods"] = []
	for h in lv.hoods:
		var counts := {}
		for bi in h["bldgs"]:
			var ow: int = bstate[bi]["owner"]
			if ow > 0:
				counts[ow] = counts.get(ow, 0) + 1
		var best := -1
		var bc := 0
		var tie := false
		for f in counts:
			if counts[f] > bc:
				bc = counts[f]
				best = f
				tie = false
			elif counts[f] == bc:
				tie = true
		h["owner"] = -1 if tie else best
		h["dominance"] = 0.0 if (tie or best < 0) else float(bc) / maxf(1.0, h["bldgs"].size())
		if best > 0 and not tie:
			var g2: Dictionary = gangs[best - 1]
			g2["rate"] += h["dominance"] * h["bldgs"].size() * cfg["spawn_k"]
			g2["hoods"].append(h["i"])


# ================================================================== recruiting and pushes
func _spawns(dt: float) -> void:
	for g in gangs:
		var fi: int = g["fi"]
		var sp := _spawn_points(fi)
		if sp.is_empty() or g["rate"] <= 0.0:
			continue
		g["spawn_acc"] += g["rate"] / 60.0 * dt
		while g["spawn_acc"] >= 1.0:
			g["spawn_acc"] -= 1.0
			if _gang_count(fi) >= cfg["gang_cap"]:
				g["spawn_acc"] = 0.0
				break
			g["spawn_i"] += 1
			_add_reserve(fi, sp[g["spawn_i"] % sp.size()], 1)


## Add n recruits to a spawn building: into a squad there with room, else a new squad in
## the next free room.
func _add_reserve(fi: int, bi: int, n: int) -> bool:
	var bs: Dictionary = bstate[bi]
	for rn in bs["squads"]:
		var ti: int = bs["squads"][rn]
		if _alive_members(ti).size() + n <= 5:
			var c: Vector2 = nav.snap(lv.rooms[rn]["label"])
			for i in n:
				_make_op(fi, ti, _gang_echelon(), c, rng.randf() * TAU)
			w.brain.init_team(w.teams[ti])
			return true
	for rn2 in _free_rooms(bi):
		_new_squad(fi, bi, rn2, n)
		return true
	return false


## Rooms of a building with no squad in them, big enough for one.
func _free_rooms(bi: int) -> Array:
	var bs: Dictionary = bstate[bi]
	var out: Array = []
	for rn in bs["hold"]:
		if not bs["squads"].has(rn):
			out.append(rn)
	for rn2 in lv.bldgs[bi]["rooms"]:
		if out.has(rn2) or bs["squads"].has(rn2) or not lv.bldgs[bi]["spawn"]:
			continue
		var rm: Dictionary = lv.rooms[rn2]
		if not rm["hall"] and rm["area"] >= 12.0:
			out.append(rn2)
	return out


## Every two minutes: reserves at the spawn points (beyond one squad kept at each) go
## out to fill the edge of the territory, five to a room. A full edge sends out an
## assault team.
func _push(g: Dictionary) -> void:
	var fi: int = g["fi"]
	var sp := _spawn_points(fi)
	# what the edge needs: for each held room, squads short of five
	var need: Array = []   # [bldg, room, missing, squad ti or -1]
	for bi in _perimeter(fi):
		if lv.bldgs[bi]["spawn"]:
			continue
		var bs: Dictionary = bstate[bi]
		for rn in bs["hold"]:
			var ti: int = bs["squads"].get(rn, -1)
			var have := 0 if ti < 0 else _alive_members(ti).size()
			if have < 5:
				need.append([bi, rn, 5 - have, ti])
	need.sort_custom(func(a, b): return _threat_dist(fi, a[0]) < _threat_dist(fi, b[0]))
	# who can go: everyone at a spawn point beyond the five kept there
	var pool: Array = []
	for bi2 in sp:
		var bs2: Dictionary = bstate[bi2]
		var keys: Array = bs2["squads"].keys()
		keys.sort()
		var kept := 0
		for rk in keys:
			var ti2: int = bs2["squads"][rk]
			if w.teams[ti2].get("kind", "") != "garrison":
				continue
			for m in _alive_members(ti2):
				if kept < 5:
					kept += 1
					continue
				if not m.assault and m.ticker.get("retreat", {}).is_empty():
					pool.append(m)
	var sent := 0
	for nd in need:
		if pool.is_empty():
			break
		var take: Array = []
		while take.size() < nd[2] and not pool.is_empty():
			take.append(pool.pop_back())
		_send_squad(fi, take, nd[0], nd[1], nd[3])
		sent += take.size()
	var vacancies := 0
	for nd2 in need:
		vacancies += nd2[2]
	vacancies -= sent
	if sent > 0:
		say("%s push %d from their spawn points to the edge of their territory" % [g["name"], sent], "city")
	# a full edge (or a gang at strength) attacks
	var full := vacancies <= 0 or _gang_count(fi) >= int(cfg["gang_cap"] * 0.9)
	if full and g["expansion"] < 0:
		_start_expansion(g)


## Send people to a room of a building: they travel as a squad and join (or become) the
## squad holding it.
func _send_squad(fi: int, ms: Array, bi: int, room: String, into: int) -> void:
	if ms.is_empty():
		return
	var g: Dictionary = gangs[fi - 1]
	var b: Dictionary = lv.bldgs[bi]
	var ti := _unit(fi, "push", "%s push" % g["tag"], "transit", {"dest_bldg": bi, "dest_room": room, "join": into})
	for m in ms:
		_transfer(m, ti)
	var tm: Dictionary = w.teams[ti]
	w.brain.init_team(tm)
	var dest: Vector2 = nav.snap(lv.rooms[room]["label"])
	tm["dest"] = dest
	tm["pace"] = "run"
	for el in tm["elements"]:
		el["mode"] = "transit"
		el["dest"] = dest
		el["pace"] = "run"
	for m2 in tm["members"]:
		w.wake(m2)
	tm["t0"] = w.t
	# reserve the room so the next push doesn't double up
	if into < 0:
		bstate[bi]["squads"][room] = ti


# ================================================================== expansion
## The gang's best soldiers and militia (up to ten, at least three) go after the nearest
## building it doesn't hold, unclaimed ones first.
func _start_expansion(g: Dictionary) -> void:
	var fi: int = g["fi"]
	var owned := _owned(fi)
	if owned.is_empty():
		return
	var best := -1
	var bs_score := INF
	for bj in bstate.size():
		var bsj: Dictionary = bstate[bj]
		if bsj["owner"] == fi or lv.bldgs[bj]["police"] or bsj["target_of"] >= 0:
			continue
		var c: Vector2 = lv.bldgs[bj]["centre"]
		var dmin := INF
		for bi in owned:
			dmin = minf(dmin, c.distance_to(lv.bldgs[bi]["centre"]))
		if dmin > 260.0:
			continue
		var s := dmin * (0.7 if bsj["owner"] < 0 else 1.0)
		var defenders := 0
		for rn in bsj["squads"]:
			defenders += _alive_members(bsj["squads"][rn]).size()
		s += defenders * 6.0
		if lv.bldgs[bj]["spawn"]:
			s -= 25.0
		if s < bs_score:
			bs_score = s
			best = bj
	if best < 0:
		return
	var target_c: Vector2 = lv.bldgs[best]["centre"]
	var cands: Array = []
	for o in w.ops:
		if o.faction != fi or not o.alive() or o.assault or o.echelon == "untrained" or o.mounted != null:
			continue
		var tm: Dictionary = w.teams[o.team]
		if tm.get("kind", "") == "push":
			continue
		if w.t - tm.get("police_t", -999.0) < 60.0:
			continue
		var score: float = (0.0 if o.echelon == "regular" else 40.0) + o.pos.distance_to(target_c) * 0.25
		cands.append([score, o])
	if cands.size() < 3:
		return
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var n := mini(10, cands.size())
	var ti := _unit(fi, "assault", "%s assault" % g["tag"], "transit", {"target": best, "base_alert": 1})
	for i in n:
		var o2 = cands[i][1]
		var old: int = o2.team
		_transfer(o2, ti)
		o2.assault = true
		o2.alert_floor = Op.YELLOW
		w.raise_alert(o2, Op.YELLOW)
		_refresh_unit(old)
	var tm2: Dictionary = w.teams[ti]
	w.brain.init_team(tm2)
	var lot: Dictionary = lv.lots[lv.bldgs[best]["lot"]]
	var stage: Vector2 = lot["gate_out"]
	tm2["dest"] = stage
	tm2["pace"] = "run"
	for el in tm2["elements"]:
		el["mode"] = "transit"
		el["dest"] = stage
		el["pace"] = "run"
	for m3 in tm2["members"]:
		w.wake(m3)
	tm2["t0"] = w.t
	tm2["phase"] = "move"
	g["expansion"] = ti
	bstate[best]["target_of"] = ti
	stats["expansions"] += 1
	var b: Dictionary = lv.bldgs[best]
	var held: String = "unclaimed" if bstate[best]["owner"] < 0 else "held by the " + w.factions[bstate[best]["owner"]]["name"]
	say("%s send %d against the %s at %s (%s, %s)" % [g["name"], n, b["name"].to_lower(), b["address"], lv.hoods[b["hood"]]["name"], held], "city")


## A unit that lost members re-forms its elements (or is freed when empty).
func _refresh_unit(ti: int) -> void:
	if ti < 0 or ti >= w.teams.size():
		return
	var tm: Dictionary = w.teams[ti]
	if _alive_members(ti).is_empty():
		_drop_unit(ti)
		return
	var keep_modes := {}
	for el in tm["elements"]:
		keep_modes[el["i"]] = el["mode"]
	if tm.get("kind", "") in ["garrison", "qrf"]:
		w.brain.init_team(tm)


func _drop_unit(ti: int) -> void:
	var tm: Dictionary = w.teams[ti]
	for bs in bstate:
		for rn in bs["squads"].keys():
			if bs["squads"][rn] == ti:
				bs["squads"].erase(rn)
	# dead and downed members stay in the world until collected; the record is freed
	# only once nobody refers to it
	var anyone := false
	for m in tm["members"]:
		if w.by_id.has(m.id):
			anyone = true
	if not anyone:
		w.free_unit(ti)


func _expansion_jobs() -> void:
	for g in gangs:
		var ti: int = g["expansion"]
		if ti < 0:
			continue
		var tm: Dictionary = w.teams[ti]
		var al := _alive_members(ti)
		var target: int = tm.get("target", -1)
		if al.is_empty() or w.t - tm["t0"] > 480.0:
			if target >= 0:
				bstate[target]["target_of"] = -1
			if not al.is_empty():
				say("%s call off the attack on %s" % [g["name"], lv.bldgs[target]["address"]], "city")
				_disband_to_reserve(g, ti)
			else:
				say("%s assault team on %s is wiped out" % [g["name"], lv.bldgs[target]["address"]], "city")
				_drop_unit(ti)
			g["expansion"] = -1
			continue
		if target >= 0 and bstate[target]["owner"] == g["fi"]:
			_settle_assault(g, ti, target)
			continue
		match tm.get("phase", "move"):
			"move":
				var arrived := false
				for el in tm["elements"]:
					if el.has("arrived_t") or el["mode"] != "transit":
						arrived = true
				var lead_d := INF
				var gate: Vector2 = lv.lots[lv.bldgs[target]["lot"]]["gate_out"]
				for m in al:
					lead_d = minf(lead_d, m.pos.distance_to(gate))
				if arrived or lead_d < 6.0 or w.t - tm["t0"] > 240.0:
					tm["phase"] = "assault"
					tm["bldg"] = target
					tm["cleared"] = {}
					tm["skipped"] = {}
					tm["claimed"] = {}
					tm["clear_said"] = false
					w.brain._set_posture(tm, "assault")
					say("%s storm the %s at %s" % [g["name"], lv.bldgs[target]["name"].to_lower(), lv.bldgs[target]["address"]], "city")
			"assault":
				var done := true
				for el in tm["elements"]:
					if not _alive_el(el).is_empty() and el["mode"] != "done":
						done = false
				if done:
					tm["phase"] = "hold"
					tm["posture"] = "hold"
					tm["held"] = {}
					for el2 in tm["elements"]:
						if not _alive_el(el2).is_empty():
							w.brain._set_mode(tm, el2, "hold")


func _alive_el(el: Dictionary) -> Array:
	var out: Array = []
	for m in el["members"]:
		if m.alive():
			out.append(m)
	return out


## The assault team now holds the building: they become its garrison, one squad per room.
func _settle_assault(g: Dictionary, ti: int, bi: int) -> void:
	var tm: Dictionary = w.teams[ti]
	var al := _alive_members(ti)
	g["expansion"] = -1
	bstate[bi]["target_of"] = -1
	if al.is_empty():
		_drop_unit(ti)
		return
	var rooms_free: Array = bstate[bi]["hold"].duplicate()
	var groups: Array = []
	var i := 0
	while i < al.size():
		groups.append(al.slice(i, mini(i + 5, al.size())))
		i += 5
	for k in groups.size():
		var room: String = rooms_free[k] if k < rooms_free.size() else _free_rooms(bi)[0] if not _free_rooms(bi).is_empty() else rooms_free[0]
		var sq := _unit(g["fi"], "garrison", "%s %s" % [g["tag"], _short(lv.bldgs[bi])], "hold", {"bldg": bi, "fixed_room": room})
		for m in groups[k]:
			_transfer(m, sq)
			m.assault = false
			m.alert_floor = Op.GREEN
		w.brain.init_team(w.teams[sq])
		bstate[bi]["squads"][room] = sq
	_drop_unit(ti)


## An attack called off: survivors walk back to the nearest spawn point as reserves.
func _disband_to_reserve(g: Dictionary, ti: int) -> void:
	var fi: int = g["fi"]
	var sp := _spawn_points(fi)
	var al := _alive_members(ti)
	for m in al:
		m.assault = false
		m.alert_floor = Op.GREEN
	if sp.is_empty():
		var owned := _owned(fi)
		if owned.is_empty():
			return
		sp = [owned[0]]
	var c := Vector2.ZERO
	for m2 in al:
		c += m2.pos
	c /= maxf(1.0, al.size())
	var best: int = sp[0]
	for bi in sp:
		if (lv.bldgs[bi]["centre"] as Vector2).distance_to(c) < (lv.bldgs[best]["centre"] as Vector2).distance_to(c):
			best = bi
	var rooms: Array = _free_rooms(best)
	var room: String = rooms[0] if not rooms.is_empty() else bstate[best]["hold"][0]
	_send_squad(fi, al, best, room, bstate[best]["squads"].get(room, -1))
	_drop_unit(ti)


## Every five seconds: pushes that arrived join their room's squad; squads in buildings
## their gang has lost become reserves; empty units are released.
func _tidy_units() -> void:
	for ti in w.teams.size():
		var tm: Dictionary = w.teams[ti]
		if tm["free"]:
			continue
		var kind: String = tm.get("kind", "")
		var al := _alive_members(ti)
		if al.is_empty():
			if kind in ["garrison", "push", "assault"]:
				_drop_unit(ti)
			continue
		if kind == "push":
			var arrived: bool = w.t - tm.get("t0", w.t) > 300.0
			for el in tm["elements"]:
				if el.has("arrived_t"):
					arrived = true
			if arrived:
				_land_push(ti)
		elif kind == "garrison":
			var bi: int = tm.get("bldg", -1)
			if bi >= 0 and bstate[bi]["owner"] != tm["faction"]:
				var g: Dictionary = gangs[tm["faction"] - 1]
				var room: String = tm.get("fixed_room", "")
				if bstate[bi]["squads"].get(room, -1) == ti:
					bstate[bi]["squads"].erase(room)
				_disband_to_reserve(g, ti)


func _land_push(ti: int) -> void:
	var tm: Dictionary = w.teams[ti]
	var bi: int = tm["dest_bldg"]
	var room: String = tm["dest_room"]
	var fi: int = tm["faction"]
	if bstate[bi]["owner"] != fi:
		# lost on the way: go home instead
		_disband_to_reserve(gangs[fi - 1], ti)
		return
	var into: int = tm.get("join", -1)
	if into >= 0 and into < w.teams.size() and not w.teams[into]["free"] and w.teams[into]["faction"] == fi \
			and bstate[bi]["squads"].get(room, -1) == into:
		for m in _alive_members(ti):
			_transfer(m, into)
		w.brain.init_team(w.teams[into])
		_drop_unit(ti)
		return
	tm["kind"] = "garrison"
	tm["bldg"] = bi
	tm["fixed_room"] = room
	tm["posture"] = "hold"
	tm["tag"] = "%s %s" % [gangs[fi - 1]["tag"], _short(lv.bldgs[bi])]
	bstate[bi]["squads"][room] = ti
	w.brain.init_team(tm)


# ================================================================== reports and the QRF
## Gang gunfire is called in. A caller near a report made in the last 20 s adds nothing;
## otherwise the report is a duplicate of an incident within 500 m opened in the last
## five minutes, or opens a new one.
func on_gunshot(src) -> void:
	_hotspot(src.pos)
	if src.faction == POLICE or src.medic:
		return
	var p: Vector2 = src.pos
	_convoys_hear(p)
	for r in _last_report_p:
		if w.t - r[1] < 20.0 and p.distance_to(r[0]) < 40.0:
			return
	_last_report_p.append([p, w.t])
	if _last_report_p.size() > 40:
		_last_report_p = _last_report_p.slice(20)
	stats["reports"] += 1
	for inc in incidents:
		if w.t - inc["t"] <= REPORT_WINDOW and p.distance_to(inc["p"]) <= REPORT_RADIUS:
			inc["dups"] += 1
			inc["points"].append(p)
			reports.append({"t": w.t, "p": p, "kind": "duplicate", "inc": inc["id"]})
			_trim_reports()
			return
	var inc2 := {"id": incidents.size() + 1, "p": p, "t": w.t, "points": [p], "dups": 0, "search": _nearest_bldgs(p, 3),
		"state": "queued", "qrf": -1, "place": lv.place_name(p)}
	incidents.append(inc2)
	queue.append(inc2["id"])
	stats["incidents"] += 1
	reports.append({"t": w.t, "p": p, "kind": "original", "inc": inc2["id"]})
	_trim_reports()
	say("Shots fired: incident %d, %s" % [inc2["id"], inc2["place"]], "city")
	w.emit({"type": "report", "p": p, "inc": inc2["id"]})


## Gunfire anywhere (police too), merged within 40 m, for the follow camera.
func _hotspot(p: Vector2) -> void:
	for h in hotspots:
		if (h["p"] as Vector2).distance_to(p) < 40.0 and w.t - h["t"] < 30.0:
			h["t"] = w.t
			h["n"] += 1
			return
	hotspots.append({"p": p, "t": w.t, "n": 1, "t0": w.t})
	if hotspots.size() > 30:
		hotspots = hotspots.slice(10)


## The busiest fight of the last 20 seconds, or null.
func hottest():
	var best = null
	var bs := 0.0
	for h in hotspots:
		var age: float = w.t - h["t"]
		if age > 20.0:
			continue
		var s: float = h["n"] / (1.0 + age * 0.3)
		if s > bs:
			bs = s
			best = h
	return best


func _trim_reports() -> void:
	if reports.size() > 60:
		reports = reports.slice(30)


func _nearest_bldgs(p: Vector2, n: int) -> Array:
	var cands: Array = []
	for b in lv.bldgs:
		if b["police"]:
			continue
		cands.append([(b["centre"] as Vector2).distance_to(p), b["i"]])
	cands.sort_custom(func(a, c): return a[0] < c[0])
	var out: Array = []
	for k in mini(n, cands.size()):
		out.append(cands[k][1])
	return out


func _incident(id: int) -> Dictionary:
	return incidents[id - 1]


func _qrf_jobs() -> void:
	# dispatch: oldest queued incident to the nearest free QRF
	while not queue.is_empty():
		var inc: Dictionary = _incident(queue[0])
		var best = null
		var bd := INF
		for st in stations:
			if st["state"] != "base" or _alive_members(st["qrf"]).size() < 4:
				continue
			var d: float = (st["stop"] as Vector2).distance_to(inc["p"])
			if d < bd:
				bd = d
				best = st
		if best == null:
			break
		queue.pop_front()
		_dispatch(best, inc)
	for st2 in stations:
		_qrf_step(st2)


func _dispatch(st: Dictionary, inc: Dictionary) -> void:
	inc["state"] = "assigned"
	inc["qrf"] = st["i"]
	st["inc"] = inc["id"]
	st["state"] = "outbound"
	st["state_t"] = w.t
	st["search_i"] = 0
	var tm: Dictionary = w.teams[st["qrf"]]
	tm["base_alert"] = Op.YELLOW
	for m in _alive_members(st["qrf"]):
		m.alert_floor = Op.YELLOW
		w.raise_alert(m, Op.YELLOW)
	_unit_transit(st["qrf"], st["stop"] + Vector2(0, 0), "run")
	say("QRF %d rolls to incident %d (%s)" % [st["i"] + 1, inc["id"], inc["place"]], "city")


func _unit_transit(ti: int, dest: Vector2, pace: String) -> void:
	var tm: Dictionary = w.teams[ti]
	tm["posture"] = "transit"
	tm["dest"] = nav.snap(dest)
	tm["pace"] = pace
	tm.erase("bldg")
	for el in tm["elements"]:
		if el["mode"] == "hold":
			w.brain._release_hold(tm, el)
		el["mode"] = "transit"
		el["dest"] = nav.snap(dest)
		el["pace"] = pace
		el.erase("arrived_t")
	for m in tm["members"]:
		w.wake(m)


func _unit_arrived(ti: int, dest: Vector2, r: float) -> bool:
	var al := _alive_members(ti)
	if al.is_empty():
		return true
	var n_close := 0
	for m in al:
		if m.pos.distance_to(dest) < r or m.mounted != null:
			n_close += 1
	return n_close >= al.size()


func _qrf_step(st: Dictionary) -> void:
	var ti: int = st["qrf"]
	var al := _alive_members(ti)
	var tm: Dictionary = w.teams[ti]
	match st["state"]:
		"outbound":
			# walk out to the vans and climb in
			for m in al:
				if m.mounted == null and m.pos.distance_to(st["stop"]) < 6.0:
					var van = _van_with_room(st)
					if van != null:
						_mount(m, van)
			if _all_mounted(al) or w.t - st["state_t"] > 60.0:
				for m2 in al:
					if m2.mounted == null:
						var van2 = _van_with_room(st)
						if van2 != null:
							_mount(m2, van2)
				var inc: Dictionary = _incident(st["inc"])
				var b0: Dictionary = lv.bldgs[inc["search"][0]]
				var stop: Vector2 = roads.lot_stop(lv.lots[b0["lot"]])
				var k := 0
				for v in st["vans"]:
					v["lights"] = true
					roads.drive(v, stop, 0.0 if k == 0 else 9.0)
					k += 1
				st["state"] = "driving"
				st["state_t"] = w.t
		"driving":
			var all_arrived := true
			for v in st["vans"]:
				if not v["arrived"]:
					all_arrived = false
			if all_arrived or w.t - st["state_t"] > 240.0:
				_unload(st["vans"])
				for m3 in _alive_members(ti):
					m3.clearing = true
				st["state"] = "search"
				st["state_t"] = w.t
				st["search_i"] = 0
				_start_search(st)
		"search":
			var inc2: Dictionary = _incident(st["inc"])
			if al.is_empty():
				st["state"] = "lost"
				inc2["state"] = "clear"
				say("QRF %d is down: incident %d unresolved" % [st["i"] + 1, inc2["id"]], "city")
				return
			var phase: String = tm.get("phase", "move")
			if phase == "move":
				var b: Dictionary = lv.bldgs[inc2["search"][st["search_i"]]]
				var gate: Vector2 = lv.lots[b["lot"]]["gate_in"]
				if _unit_arrived(ti, gate, 12.0) or w.t - st["state_t"] > 120.0:
					tm["phase"] = "clear"
					tm["bldg"] = b["i"]
					tm["cleared"] = {}
					tm["skipped"] = {}
					tm["claimed"] = {}
					tm["clear_said"] = false
					st["state_t"] = w.t
					w.brain._set_posture(tm, "assault")
					say("QRF %d searches the %s at %s" % [st["i"] + 1, b["name"].to_lower(), b["address"]], "city")
			else:
				var done := true
				for el in tm["elements"]:
					if not _alive_el(el).is_empty() and el["mode"] != "done" and el["mode"] != "lost" and el["mode"] != "merged":
						done = false
				if done or w.t - st["state_t"] > 360.0:
					st["search_i"] += 1
					if st["search_i"] >= inc2["search"].size():
						_all_clear(st, inc2)
					else:
						_start_search(st)
		"return":
			# back to the vans, climb in, drive home
			var vp: Vector2 = st["vans"][0]["pos"]
			for m4 in al:
				if m4.mounted == null and m4.pos.distance_to(vp) < 8.0:
					var van3 = _van_with_room(st)
					if van3 != null:
						_mount(m4, van3)
			if _all_mounted(al) or w.t - st["state_t"] > 150.0:
				for m5 in al:
					if m5.mounted == null:
						var van4 = _van_with_room(st)
						if van4 != null:
							_mount(m5, van4)
				var k2 := 0
				for v2 in st["vans"]:
					v2["lights"] = false
					roads.drive(v2, st["stop"] + Vector2(-10.0 - 7.0 * k2, 0).rotated(0.0 if lv.lots[st["lot"]]["side"] == 0 else PI), 0.0)
					k2 += 1
				st["state"] = "homebound"
				st["state_t"] = w.t
		"homebound":
			var home := true
			for v3 in st["vans"]:
				if not v3["arrived"]:
					home = false
			if home or w.t - st["state_t"] > 240.0:
				_unload(st["vans"])
				tm["base_alert"] = Op.GREEN
				for m6 in _alive_members(ti):
					m6.alert_floor = Op.GREEN
				tm["bldg"] = st["bldg"]
				tm["posture"] = "hold"
				tm["held"] = {}
				w.brain.init_team(tm)
				st["state"] = "base"
				st["inc"] = -1
				say("QRF %d back at the station" % (st["i"] + 1), "city")
		"lost":
			if not _alive_members(ti).is_empty():
				# survivors (or new hires) regroup at the station
				st["state"] = "homebound"
				st["state_t"] = w.t - 300.0


func _start_search(st: Dictionary) -> void:
	var inc: Dictionary = _incident(st["inc"])
	inc["state"] = "searching"
	var ti: int = st["qrf"]
	var tm: Dictionary = w.teams[ti]
	var b: Dictionary = lv.bldgs[inc["search"][st["search_i"]]]
	tm["phase"] = "move"
	st["state_t"] = w.t
	_unit_transit(ti, lv.lots[b["lot"]]["gate_in"], "run")


func _all_clear(st: Dictionary, inc: Dictionary) -> void:
	inc["state"] = "clear"
	inc["clear_t"] = w.t
	say("QRF %d: all clear at incident %d. Ambulances called" % [st["i"] + 1, inc["id"]], "city")
	w.emit({"type": "all_clear", "inc": inc["id"], "p": inc["p"]})
	for m in _alive_members(st["qrf"]):
		m.clearing = false
	st["state"] = "return"
	st["state_t"] = w.t
	_unit_transit(st["qrf"], st["vans"][0]["pos"], "walk")
	w.teams[st["qrf"]]["phase"] = ""
	_call_ambulances(inc)


func _van_with_room(st: Dictionary):
	for v in st["vans"]:
		if v["seats"].size() < v["cap"]:
			return v
	return null


func _all_mounted(al: Array) -> bool:
	for m in al:
		if m.mounted == null:
			return false
	return true


func _unload(vs: Array) -> void:
	for v in vs:
		var seats: Array = v["seats"].duplicate()
		var spots: Array = roads.doors_of(v, seats.size())
		for i in seats.size():
			_dismount(seats[i], spots[i])


# ================================================================== patrol convoys
func _patrol_next(cv: Dictionary) -> void:
	var cars: Array = cv["cars"]
	var lead: Dictionary = cars[0]
	var here: int = cv["node"]
	if here < 0:
		here = _nearest_node(lead["pos"])
	var st: Dictionary = stations[cv["station"]]
	var rect: Rect2 = lv.precincts[st["precinct"]]["rect"].grow(2.0)
	var nb: Array = []
	for nid in roads.astar.get_point_connections(here):
		if nid == cv["prev"]:
			continue
		if rect.has_point(roads.astar.get_point_position(nid)):
			nb.append(nid)
	if nb.is_empty():
		nb = Array(roads.astar.get_point_connections(here))
	var nxt: int = nb[rng.randi() % nb.size()]
	cv["prev"] = here
	cv["node"] = nxt
	var dest: Vector2 = roads.astar.get_point_position(nxt)
	roads.drive(lead, dest)
	for k in range(1, cars.size()):
		roads.follow(cars[k], lead, 0.0)
		cars[k]["s"] = -9.0 * k


func _nearest_node(p: Vector2) -> int:
	return roads.astar.get_closest_point(p)


func _convoy_jobs() -> void:
	for st in stations:
		for cv in st["convoys"]:
			var ti: int = cv["unit"]
			var al := _alive_members(ti)
			match cv["state"]:
				"patrol":
					if al.is_empty():
						continue
					if cv["cars"][0]["arrived"]:
						_patrol_next(cv)
				"respond":
					var tm: Dictionary = w.teams[ti]
					var quiet: bool = w.t > cv["until"] and w.t - tm.get("last_contact", -99.0) > 30.0
					if al.is_empty():
						cv["state"] = "down"
					elif quiet:
						cv["state"] = "remount"
						cv["until"] = w.t + 120.0
						tm["base_alert"] = Op.GREEN
						_unit_transit(ti, cv["cars"][0]["pos"], "walk")
				"remount":
					var vp: Vector2 = cv["cars"][0]["pos"]
					for m in al:
						if m.mounted == null and m.pos.distance_to(vp) < 7.0:
							_board_convoy(cv, m)
					if _all_mounted(al) or w.t > cv["until"]:
						for m2 in al:
							if m2.mounted == null:
								_board_convoy(cv, m2)
						for m3 in al:
							m3.alert_floor = Op.GREEN
						for car in cv["cars"]:
							car["lights"] = false
						cv["state"] = "patrol"
						cv["node"] = -1
						_patrol_next(cv)
				"down":
					if not al.is_empty():
						cv["state"] = "remount"
						cv["until"] = w.t + 120.0
						_unit_transit(ti, cv["cars"][0]["pos"], "walk")


func _board_convoy(cv: Dictionary, m) -> void:
	for car in cv["cars"]:
		if car["seats"].size() < car["cap"]:
			_mount(m, car)
			return


## A convoy within earshot of gang gunfire stops and gets out to hunt the shooter.
func _convoys_hear(p: Vector2) -> void:
	for st in stations:
		for cv in st["convoys"]:
			if cv["state"] == "respond":
				if (cv["cars"][0]["pos"] as Vector2).distance_to(p) < 160.0:
					cv["until"] = w.t + 90.0
					w.teams[cv["unit"]]["sound"] = {"p": p, "t": w.t, "kind": "rifle"}
				continue
			if cv["state"] != "patrol" or (cv["cars"][0]["pos"] as Vector2).distance_to(p) > 140.0:
				continue
			var al := _alive_members(cv["unit"])
			if al.is_empty():
				continue
			for car in cv["cars"]:
				roads.stop(car)
				car["lights"] = true
			_unload(cv["cars"])
			cv["state"] = "respond"
			cv["until"] = w.t + 90.0
			var tm: Dictionary = w.teams[cv["unit"]]
			tm["base_alert"] = Op.YELLOW
			tm["sound"] = {"p": p, "t": w.t, "kind": "rifle"}
			tm["last_contact"] = w.t
			tm["posture"] = "hunt"
			for el in tm["elements"]:
				w.brain._set_mode(tm, el, "hunt")
			say("%s hear shooting and get out (%s)" % [tm["tag"], lv.place_name(p)], "city")


# ================================================================== casualties and ambulances
func on_down(a, shooter, killed: bool) -> void:
	if a.faction == POLICE and not killed and not a.medic:
		police_down.append(a.id)
	if a.faction == POLICE and killed:
		_schedule_hire(a)
	if w.factions[shooter.faction].get("gang", false) and shooter.faction != a.faction:
		gangs[shooter.faction - 1]["kills"] += 1
	if w.factions[a.faction].get("gang", false):
		gangs[a.faction - 1]["lost"] += 1
	if a.assault:
		_refresh_unit(a.team)


func on_bled_out(o) -> void:
	stats["bled_out"] += 1
	if o.faction == POLICE and not o.medic:
		_schedule_hire(o)
		police_down.erase(o.id)


func on_recognized(_o, _e) -> void:
	pass


func on_flagged(o, e) -> void:
	if w.t - e.ticker.get("flag_said", -99.0) > 30.0:
		e.ticker["flag_said"] = w.t
		w.say("%s sees %s (%s) shooting: cleared to engage" % [o.id, e.id, w.factions[e.faction]["tag"]], "city")


## A gang member in a fight who sees tactical police or the QRF may break and run.
func on_sees_police(o, e) -> void:
	var key: String = "seen_" + e.id
	if w.t - o.ticker.get(key, -99.0) < 15.0 or not o.ticker.get("retreat", {}).is_empty():
		return
	o.ticker[key] = w.t
	var qrf: bool = w.teams[e.team].get("kind", "") == "qrf"
	var base: float = {"untrained": 0.55, "militia": 0.35, "regular": 0.15}.get(o.echelon, 0.3)
	if qrf:
		base += 0.15
	var p := clampf(base + 0.5 * o.stress * (1.0 - o.ech["resist"]) - 0.4 * o.ech["resist"], 0.03, 0.92)
	w.add_stress(o, 0.1, "police")
	if rng.randf() >= p:
		return
	var away: Vector2 = (o.pos - e.pos).normalized()
	var dest := _refuge(o, away)
	o.ticker["retreat"] = {"p": dest, "until": w.t + 25.0}
	o.aim = {}
	w.say("%s breaks and runs from the %s" % [o.id, "QRF" if qrf else "police"], "city")
	w.emit({"type": "retreat", "id": o.id})


## Somewhere to run: the nearest building the gang holds that lies away from the threat,
## or 40 m straight away from it.
func _refuge(o, away: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for bi in _owned(o.faction):
		var c: Vector2 = lv.bldgs[bi]["centre"]
		var d: Vector2 = c - o.pos
		if d.length() < 8.0 or d.length() > 160.0 or d.normalized().dot(away) < 0.2:
			continue
		if d.length() < bd:
			bd = d.length()
			best = lv.rooms[bstate[bi]["hold"][0]]["label"]
	if best == Vector2.INF:
		best = o.pos + away * 40.0
	return nav.snap(best)


func _schedule_hire(o) -> void:
	var st_i: int = w.teams[o.team].get("station", -1)
	if st_i < 0:
		st_i = _nearest_station(o.pos)
	hires.append({"t": w.t + HIRE_DELAY, "station": st_i, "unit": o.team, "ech": o.echelon, "rank": o.rank,
		"medic": o.medic, "replaces": o.name})


func _nearest_station(p: Vector2) -> int:
	var best := 0
	for st in stations:
		if (st["stop"] as Vector2).distance_to(p) < (stations[best]["stop"] as Vector2).distance_to(p):
			best = st["i"]
	return best


func _police_count() -> int:
	var n := 0
	for o in w.ops:
		if o.faction == POLICE and not o.medic and (o.alive() or o.state == "down"):
			n += 1
	return n + returning.size()


func _hires_and_returns() -> void:
	var keep: Array = []
	for h in hires:
		if w.t < h["t"]:
			keep.append(h)
			continue
		if _police_count() + 0 >= cfg["police_cap"]:
			# over strength: the post stays empty
			continue
		var st: Dictionary = stations[h["station"]]
		var ti: int = h["unit"]
		if ti < 0 or ti >= w.teams.size() or w.teams[ti]["free"]:
			ti = st["qrf"]
		var o = _make_op(POLICE, ti, h["ech"], _station_spot(st), 0.0, {"rank": h["rank"], "medic": h["medic"]})
		stats["hired"] += 1
		say("%s %s joins %s, replacing %s" % [o.rank, o.name, w.teams[ti]["tag"], h["replaces"]], "city")
		_home_member(o, st)
	hires = keep
	var keep2: Array = []
	for r in returning:
		if w.t < r["t"]:
			keep2.append(r)
			continue
		var o2 = r["op"]
		var st2: Dictionary = stations[r["station"]]
		o2.state = "ok"
		o2.wounds = 0
		o2.arm_hit = false
		o2.leg_hit = false
		o2.carried = false
		o2.saved = false
		o2.ticker = {}
		o2.spawn = _station_spot(st2)
		o2.spawn_face = 0.0
		o2.reset()
		o2.stance = Op.STAND
		o2.stance_goal = Op.STAND
		o2.mounted = null
		o2.dormant = false
		w.add_op(o2)
		stats["returned"] += 1
		say("%s %s is back on duty from the hospital" % [o2.rank, o2.name], "city")
		_home_member(o2, st2)
	returning = keep2


## A hire or a returning officer reports to the station and rejoins their unit when it's
## home (a convoy picks them up on the next remount; otherwise they wait inside).
func _home_member(o, st: Dictionary) -> void:
	var tm: Dictionary = w.teams[o.team]
	if o.medic:
		if st["pamb"] != null and st["pamb"]["job"] == "idle" and (st["pamb"]["pos"] as Vector2).distance_to(st["stop"]) < 30.0:
			_mount(o, st["pamb"])
			st["medics"].append(o)
		return
	if tm.get("kind", "") == "qrf" and st["state"] == "base":
		w.brain.init_team(tm)
		return
	if tm.get("kind", "") == "convoy":
		for cv in st["convoys"]:
			if cv["unit"] == o.team and cv["state"] == "patrol":
				# the convoy swings by the station: put them straight in a car
				for car in cv["cars"]:
					if car["seats"].size() < car["cap"]:
						_mount(o, car)
						w.brain.init_team(tm)
						return
	w.brain.init_team(tm)


func _medic_jobs() -> void:
	# police paramedics: straight to downed officers
	var waiting: Array = []
	for oid in police_down:
		var o = w.op_by_id(oid)
		if o != null and o.state == "down" and not o.carried and o.mounted == null:
			waiting.append(o)
	police_down = []
	for o2 in waiting:
		police_down.append(o2.id)
	for st in stations:
		var v = st["pamb"]
		if v == null:
			continue
		_amb_step(v, st["stop"], st["i"], true)
	for h in hospitals:
		for v2 in h["ambs"]:
			_amb_step(v2, h["stop"], -1, false)


## Hospital ambulances answer an all-clear: every casualty within 120 m of the incident's
## report points, the living first.
func _call_ambulances(inc: Dictionary) -> void:
	var cas: Array = []
	for o in w.ops:
		if o.alive() or o.carried or o.mounted != null or o.ticker.get("claimed_by", -1) >= 0:
			continue
		var near := false
		for p in inc["points"]:
			if o.pos.distance_to(p) < AMB_RADIUS:
				near = true
				break
		if near:
			cas.append(o)
	if cas.is_empty():
		return
	cas.sort_custom(func(a, b): return (0 if a.state == "down" else 1) < (0 if b.state == "down" else 1))
	inc["pickups"] = cas.map(func(o2): return o2.id)
	say("Ambulances sent for %d casualt%s at incident %d" % [cas.size(), "y" if cas.size() == 1 else "ies", inc["id"]], "city")


func _amb_step(v: Dictionary, home: Vector2, st_i: int, police: bool) -> void:
	var medics: Array = []
	for m in v.get("medics", []):
		if m.alive():
			medics.append(m)
	if police:
		medics = []
		for m2 in stations[st_i]["medics"]:
			if m2.alive():
				medics.append(m2)
	match v["job"]:
		"idle":
			var pick = _next_casualty(v, police)
			if pick == null or medics.is_empty():
				return
			for m3 in medics:
				if m3.mounted == null:
					return  # crew not aboard yet
			pick.ticker["claimed_by"] = v["id"]
			v["patient"] = pick.id
			v["job"] = "out"
			v["lights"] = true
			v["t0"] = w.t
			roads.drive(v, _stop_near(pick.pos))
		"out":
			var pat = w.op_by_id(v["patient"])
			if pat == null or pat.carried:
				_amb_abort(v)
				return
			if v["arrived"] or w.t - v["t0"] > 200.0:
				roads.stop(v)
				var spots: Array = roads.doors_of(v, medics.size())
				for i in medics.size():
					if medics[i].mounted != null:
						_dismount(medics[i], spots[i])
				v["job"] = "fetch"
				v["t0"] = w.t
		"fetch":
			var pat2 = w.op_by_id(v["patient"])
			if pat2 == null or medics.is_empty():
				_amb_abort(v)
				return
			var reached := false
			for m4 in medics:
				w.move_to(m4, pat2.pos + (m4.pos - pat2.pos).normalized() * 0.6, "run", 0)
				if m4.pos.distance_to(pat2.pos) < 1.3:
					reached = true
			if reached:
				v["job"] = "treat"
				v["t0"] = w.t
				for m5 in medics:
					w.stop(m5)
			elif w.t - v["t0"] > 120.0:
				_amb_abort(v)
		"treat":
			var pat3 = w.op_by_id(v["patient"])
			if pat3 == null:
				_amb_abort(v)
				return
			if w.t - v["t0"] > 4.0:
				pat3.carried = true
				v["job"] = "carry"
				v["t0"] = w.t
				v["carrying"] = pat3.id
		"carry":
			var pat4 = w.op_by_id(v["patient"])
			if pat4 == null:
				_amb_abort(v)
				return
			if medics.is_empty():
				pat4.carried = false
				_amb_abort(v)
				return
			var at_van := true
			for m6 in medics:
				w.move_to(m6, v["pos"], "walk", 0)
				if m6.pos.distance_to(v["pos"]) > 3.2:
					at_van = false
			if at_van or w.t - v["t0"] > 150.0:
				_load(v, pat4)
				for m7 in medics:
					_mount(m7, v)
				v.erase("carrying")
				# room for another casualty close by?
				var nxt = null
				if v["cargo"].size() < v["cap"]:
					nxt = _next_casualty(v, police, 60.0)
				if nxt != null:
					nxt.ticker["claimed_by"] = v["id"]
					v["patient"] = nxt.id
					v["job"] = "out"
					v["t0"] = w.t
					roads.drive(v, _stop_near(nxt.pos))
				else:
					v["job"] = "hospital"
					v["t0"] = w.t
					var hp := _nearest_hospital(v["pos"])
					roads.drive(v, hospitals[hp]["stop"] if hp >= 0 else home)
					v["dest_h"] = hp
		"hospital":
			if v["arrived"] or w.t - v["t0"] > 240.0:
				_deliver(v, police, st_i)
				v["job"] = "home"
				v["t0"] = w.t
				v["lights"] = false
				roads.drive(v, home + Vector2(12.0, 0) if police else home)
		"home":
			if v["arrived"] or w.t - v["t0"] > 240.0:
				v["job"] = "idle"


func _amb_abort(v: Dictionary) -> void:
	var pat = w.op_by_id(v.get("patient", ""))
	if pat != null:
		pat.ticker.erase("claimed_by")
	v.erase("patient")
	v.erase("carrying")
	# crew back aboard, then either deliver what it has or go home
	var crew: Array = v.get("medics", [])
	if v.get("kind", "") == "pamb":
		crew = stations[v["station"]]["medics"]
	for m in crew:
		if m.alive() and m.mounted == null:
			_mount(m, v)
	v["job"] = "hospital" if not v["cargo"].is_empty() else "home"
	v["t0"] = w.t
	var hp := _nearest_hospital(v["pos"])
	if v["job"] == "hospital":
		v["dest_h"] = hp
		roads.drive(v, hospitals[hp]["stop"])
	else:
		roads.drive(v, v["home"])


func _load(v: Dictionary, pat) -> void:
	pat.carried = true
	if pat.state == "down":
		pat.saved = true
	pat.mounted = v
	v["cargo"].append(pat)
	pat.ticker.erase("claimed_by")


## Unload at the hospital: the living are saved (officers come back in two minutes), the
## dead go to the morgue.
func _deliver(v: Dictionary, _police: bool, _st_i: int) -> void:
	for pat in v["cargo"]:
		if pat.state == "down":
			stats["saved"] += 1
			if pat.faction == POLICE and not pat.medic:
				returning.append({"t": w.t + RECOVER_DELAY, "op": pat, "station": _station_of(pat)})
				say("%s %s reaches the hospital alive" % [pat.rank, pat.name], "city")
		else:
			stats["evacuated_dead"] += 1
		police_down.erase(pat.id)
		w.remove_op(pat)
	v["cargo"] = []


func _station_of(o) -> int:
	var st_i: int = w.teams[o.team].get("station", -1)
	return st_i if st_i >= 0 else _nearest_station(o.pos)


func _nearest_hospital(p: Vector2) -> int:
	var best := -1
	var bd := INF
	for h in hospitals:
		var d: float = (h["stop"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = h["i"]
	return best


## The kerbside lane point nearest a casualty (in front of their lot, or the street they're in).
func _stop_near(p: Vector2) -> Vector2:
	var li: int = lv.lot_at(p)
	if li >= 0:
		return roads.lot_stop(lv.lots[li])
	return p


func _next_casualty(v: Dictionary, police: bool, within := INF):
	var best = null
	var bd := INF
	if police:
		for oid in police_down:
			var o = w.op_by_id(oid)
			if o == null or o.carried or o.mounted != null or o.ticker.get("claimed_by", -1) >= 0:
				continue
			var d: float = o.pos.distance_to(v["pos"])
			if d < bd and d < within:
				bd = d
				best = o
		return best
	for inc in incidents:
		if not inc.has("pickups"):
			continue
		for oid2 in inc["pickups"]:
			var o2 = w.op_by_id(oid2)
			if o2 == null or o2.carried or o2.mounted != null or o2.ticker.get("claimed_by", -1) >= 0:
				continue
			var d2: float = o2.pos.distance_to(v["pos"]) + (0.0 if o2.state == "down" else 2000.0)
			if d2 < bd and o2.pos.distance_to(v["pos"]) < within:
				bd = d2
				best = o2
	return best


## Stretchers: a casualty being carried rides between the two medics.
func _carry_step() -> void:
	for v in roads.vehicles:
		if not v.has("carrying"):
			continue
		var pat = w.op_by_id(v["carrying"])
		if pat == null:
			continue
		var crew: Array = []
		var src: Array = stations[v["station"]]["medics"] if v["kind"] == "pamb" else v.get("medics", [])
		for m in src:
			if m.alive() and m.mounted == null:
				crew.append(m)
		if crew.is_empty():
			continue
		var c := Vector2.ZERO
		for m2 in crew:
			c += m2.pos
		pat.pos = c / crew.size()


## Bodies nobody collected are cleared after a quarter of an hour; past the cap, the
## oldest go first.
func _retire_bodies() -> void:
	var dead: Array = []
	for o in w.ops:
		if o.state == "dead" and not o.carried and o.mounted == null:
			dead.append(o)
	dead.sort_custom(func(a, b): return a.ticker.get("down_t", 0.0) < b.ticker.get("down_t", 0.0))
	var over := dead.size() - BODY_CAP
	for o2 in dead:
		if over > 0 or w.t - o2.ticker.get("down_t", w.t) > BODY_TIME:
			over -= 1
			w.emit({"type": "body_gone", "id": o2.id})
			var ti: int = o2.team
			w.remove_op(o2)
			if ti >= 0 and ti < w.teams.size() and _alive_members(ti).is_empty() and w.teams[ti].get("kind", "") in ["garrison", "push", "assault"]:
				_drop_unit(ti)


func place_name(p: Vector2) -> String:
	return lv.place_name(p)
