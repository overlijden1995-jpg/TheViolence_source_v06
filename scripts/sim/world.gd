extends RefCounted
## The simulation (bible sections 1-5). Fixed 30 Hz ticks, seeded RNG, no rendering.
## The view reads `ops`, `events` and `log_lines`; the brain makes the decisions.

const Habits = preload("res://scripts/data/habits.gd")
const Geom = preload("res://scripts/sim/geom.gd")
const Op = preload("res://scripts/sim/op.gd")
const Brain = preload("res://scripts/sim/brain.gd")
const Names = preload("res://scripts/data/names.gd")
const CivBrain = preload("res://scripts/sim/civ_brain.gd")
const Incident = preload("res://scripts/sim/incident.gd")

const DT := 1.0 / 30.0
const SPEEDS := {"walk": 1.6, "entry": 2.0, "clear": 1.2, "slice": 1.0, "creep": 0.8, "run": 3.0, "sprint": 4.0, "step": 1.2}

var level
var geom: Geom
var nav
var brain
var ops: Array = []
var teams: Array = []          # units: a team record per squad (two in a normal match)
var factions: Array = []       # [{id, name, tag, gang, police}]
var t := 0.0
var rng := RandomNumberGenerator.new()
var seed_used := 0
var events: Array = []
var keep_events := true
var log_lines: Array = []
var log_base := 0              # lines dropped from the front of log_lines
var log_kinds := {}            # when not empty, only these kinds are logged
var over := false
var winner := -1        # 0 = team A, 1 = team B, 2 = draw
var stat := {"shots": 0, "hits": 0, "friendly": 0, "stray": 0}
var time_limit := 300.0
var by_id := {}
var team_ops: Array = [[], []]   # per-unit operator lists (alive or not)
var endless := false           # the endless city battle: no end, no time limit
var city := false              # city rules for hostility (gangs, police, medics)
var dormancy := false          # skip the work for operators with no possible enemy near
var director = null            # city director: told about gunshots, casualties and sightings
var deaths: Array = []         # the ledger of the dead: [{t, name, rank, faction, ...}]
var deaths_base := 0
var serial := 0
var civ_brain                  # civilians' decisions (v0.6)
var incident = null            # the incident record of an operation (v0.6; none in the city)
var night := false             # darkness: slower recognition and judgment, more mistakes
var roe_strict := false        # armed but not attacking: challenge before firing (v0.7 Weapons tight)
var _end_wait := -1.0

## Judgment (v0.6). A recognized person is judged before an officer under police rules
## may fire: JUDGE_BASE seconds at Judgment 50, longer under stress and in the dark,
## much shorter when the person is already pointing a gun at them.
const JUDGE_BASE := 0.30
const CLEAR_TIME := 10.0       # a person judged harmless is not judged again for this long
const CHALLENGE_EVERY := 2.5   # "Police! Show me your hands!" at most this often per officer
const CHALLENGE_R := 14.0      # and heard this far
## How readily each echelon gives up when cornered by police (1 = most readily).
const SURRENDER := {"untrained": 1.0, "militia": 0.6, "patrol": 0.4, "regular": 0.3, "police": 0.15, "sof": 0.05}
## Walls and rounds (v0.6). Partitions and timber walls let rifle rounds through and
## sometimes pistol rounds; [chance a pistol round goes through, energy kept].
const PEN := {
	"drywall": {"rifle": [1.0, 0.85], "pistol": [0.75, 0.65]},
	"frame": {"rifle": [1.0, 0.6], "pistol": [0.25, 0.45]},
	"fence": {"rifle": [1.0, 0.9], "pistol": [0.85, 0.75]},
}

const LOG_MAX := 2500
const DEATHS_MAX := 400
const BLEED_OUT := 300.0       # a downed casualty dies unless aboard an ambulance within 5 min
const FLAG_TIME := 90.0        # police treat a gang member seen targeting someone as hostile this long
const ENGAGED_TIME := 45.0     # a holding gang squad engaged by police fires back this long
const GRID := 12.0             # spatial hash cell, metres


## A match or an operation. opts (v0.6): police_rules (team A judges before firing,
## challenges and arrests), night, roe_strict. Configurations with "civ": true are
## civilians (team 2).
func setup(lv, nv, cfgs: Array, postures: Array, seed_val: int, alerts := [1, 1], opts := {}) -> void:
	_base(lv, nv, seed_val)
	time_limit = lv.time_limit
	var pol: bool = opts.get("police_rules", false)
	night = opts.get("night", false)
	roe_strict = opts.get("roe_strict", false)
	factions = [{"id": 0, "name": "Police" if pol else "Team A", "tag": "A", "gang": false, "police": pol, "judges": pol},
		{"id": 1, "name": "Suspects" if pol else "Team B", "tag": "B", "gang": false, "police": false},
		{"id": 2, "name": "Civilians", "tag": "C", "gang": false, "police": false, "civ": true}]
	for k in 2:
		new_unit(k, postures[k], "Team " + "AB"[k], {"base_alert": int(alerts[k])})
	new_unit(2, "civ", "Civilians", {"civ": true, "sleep": true})
	incident = Incident.new(self)
	# names: team A from every culture, team B mostly from one (it reads as a local crew)
	var names = Names.new(seed_val)
	var crew := seed_val % 4
	for c in cfgs:
		if not c.get("enabled", true):
			continue
		var o = Op.new()
		o.configure(c)
		o.reset()
		if o.name == "":
			if o.civ:
				o.name = names.diverse_name(0.5)
			else:
				o.name = names.diverse_name(0.2) if o.team == 0 else names.gang_name(crew)
		if o.rank == "":
			o.rank = "Civilian" if o.civ else Habits.ECHELONS[o.echelon]["name"]
		_attach(o)
	for o in ops:
		if not o.civ:
			_update_bad(o, true)
	brain.init_teams()
	var n_civ: int = teams[2]["members"].size()
	say("Seed %d. Team A: %d, %s. Team B: %d, %s.%s%s%s" % [seed_val, teams[0]["members"].size(), postures[0],
		teams[1]["members"].size(), postures[1], (" %d civilians." % n_civ) if n_civ > 0 else "",
		" Police rules." if pol else "", " Night." if night else ""], "info")


## An empty world for the city: the director adds units and operators as it goes.
func setup_empty(lv, nv, seed_val: int, facs: Array) -> void:
	_base(lv, nv, seed_val)
	factions = facs
	time_limit = INF
	endless = true
	city = true
	dormancy = true


func _base(lv, nv, seed_val: int) -> void:
	level = lv
	geom = lv.geom
	nav = nv
	seed_used = seed_val
	rng.seed = seed_val
	ops.clear()
	by_id.clear()
	teams = []
	team_ops = []
	brain = Brain.new(self)
	civ_brain = CivBrain.new(self)
	_grid_init()


## A new unit (team record) of a faction. Reuses the record of a unit that has emptied.
func new_unit(faction: int, posture: String, tag: String, opts := {}) -> int:
	var rec := {"id": 0, "faction": faction, "posture": posture, "members": [], "elements": [],
		"cleared": {}, "skipped": {}, "claimed": {}, "held": {}, "lkps": {}, "sound": {},
		"last_contact": -99.0, "orig_posture": posture, "lost": {}, "clear_said": false, "tag": tag,
		"free": false, "sleep": false, "police_t": -999.0}
	for k in opts:
		rec[k] = opts[k]
	for i in teams.size():
		if teams[i]["free"]:
			rec["id"] = i
			teams[i] = rec
			team_ops[i] = []
			return i
	rec["id"] = teams.size()
	teams.append(rec)
	team_ops.append([])
	return rec["id"]


## Mark an emptied unit's record for reuse.
func free_unit(ti: int) -> void:
	var tm: Dictionary = teams[ti]
	for m in tm["members"]:
		if by_id.has(m.id):
			return
	tm["free"] = true
	tm["members"] = []
	tm["elements"] = []


func _attach(o) -> void:
	serial += 1
	o.gid = serial
	if city and o.faction < factions.size():
		o.gang = factions[o.faction].get("gang", false)
		o.police = factions[o.faction].get("police", false)
	if o.faction < factions.size():
		o.judges = factions[o.faction].get("judges", false)
	if not o.ech.has("form") and not o.civ:
		o.ech = Habits.vary(o.ech, rng)
	if o.civ and o.persona.is_empty():
		o.persona = CivBrain.roll_persona(rng)
	o.room = level.room_at(o.pos)
	o.perc_phase = rng.randf() * 0.1
	o.hot_next = t + rng.randf() * 0.5
	ops.append(o)
	by_id[o.id] = o
	team_ops[o.team].append(o)
	teams[o.team]["members"].append(o)


## Add an operator to a unit mid-match (the unit's elements are re-formed by the caller).
func add_op(o) -> void:
	# someone returning to the world (from hospital) remembers nobody
	o.rec = {}
	o.vis = {}
	o.lkp = {}
	o.tracked = {}
	o.first_rec = {}
	o.cue = {}
	o.heard = {}
	o.aim = {}
	_attach(o)
	_update_bad(o, true)


## Take an operator out of the world for good (a body collected, a casualty evacuated)
## and forget every reference to them.
func remove_op(o) -> void:
	if not by_id.has(o.id):
		return
	ops.erase(o)
	by_id.erase(o.id)
	if o.team >= 0 and o.team < teams.size():
		team_ops[o.team].erase(o)
		var tm: Dictionary = teams[o.team]
		tm["members"].erase(o)
		for el in tm["elements"]:
			el["members"].erase(o)
			el["sectors"].erase(o.id)
			el["entry"].erase(o.id)
	var oid: String = o.id
	for x in ops:
		x.rec.erase(oid)
		x.vis.erase(oid)
		x.lkp.erase(oid)
		x.tracked.erase(oid)
		x.first_rec.erase(oid)
		x.cue.erase(oid)
		if x.aim.get("tid", "") == oid:
			x.aim = {}
		for pre in ["confirm_", "tot_", "froze_", "assessed_", "pf07_", "farcover_", "callout_"]:
			x.ticker.erase(pre + oid)
	for tm2 in teams:
		tm2["lkps"].erase(oid)
	o.mounted = null


# ================================================================== main loop
var profiling := false
var prof := {}
var prof_n := {}


func _pf(key: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	prof[key] = prof.get(key, 0) + t1 - t0
	return t1


func step() -> void:
	if over:
		return
	t += DT
	var t0 := Time.get_ticks_usec() if profiling else 0
	_grid_build()
	if profiling:
		t0 = _pf("grid", t0)
	if dormancy:
		_update_dormancy()
	if profiling:
		t0 = _pf("dormancy", t0)
	var bad_tick: bool = not city or int(round(t / DT)) % 3 == 0
	for o in ops:
		if o.fighting() and not o.dormant and not o.medic and o.mounted == null:
			if bad_tick:
				_update_bad(o, false)
	if profiling:
		t0 = _pf("bad", t0)
	for o in ops:
		if o.fighting() and o.hot and not o.dormant and not o.medic and o.mounted == null:
			_perceive(o)
	if profiling:
		t0 = _pf("perceive", t0)
	for o in ops:
		if o.fighting() and o.hot and not o.dormant and not o.medic and o.mounted == null:
			_recognize(o)
	if profiling:
		t0 = _pf("recognize", t0)
	brain.update_teams()
	if profiling:
		t0 = _pf("teams", t0)
	var tick_n := int(round(t / DT))
	for o in ops:
		if o.fighting() and not o.dormant and not o.medic and o.mounted == null:
			# away from any possible enemy, people walking or standing post think every
			# third tick (they keep moving every tick)
			if dormancy and not o.hot and (tick_n + o.gid) % 3 != 0 and o.action.is_empty() and _calm_mode(o):
				continue
			brain.think(o)
		elif o.civ and o.alive() and not o.dormant:
			civ_brain.think(o)
		elif o.complying and o.alive():
			_hold_complying(o)
	if profiling:
		t0 = _pf("think", t0)
	if incident != null and tick_n % 30 == 7:
		_surrender_checks()
	for o in ops:
		if o.alive() and not o.dormant and o.mounted == null:
			_integrate(o)
	if profiling:
		t0 = _pf("integrate", t0)
	_melee()
	if profiling:
		t0 = _pf("melee", t0)
	for o in ops:
		_passive(o)
	if profiling:
		t0 = _pf("passive", t0)
	if director != null:
		director.tick()
		if profiling:
			t0 = _pf("director", t0)
	if not endless:
		_check_end()


## Break reference cycles so a finished match frees its memory.
func dispose() -> void:
	if brain != null:
		brain.w = null
	brain = null
	if civ_brain != null:
		civ_brain.w = null
	civ_brain = null
	if incident != null:
		incident.w = null
	incident = null
	if director != null and director.has_method("dispose"):
		director.dispose()
	director = null
	ops.clear()
	teams.clear()
	by_id.clear()
	team_ops = []


func say(text: String, kind := "info") -> void:
	if not log_kinds.is_empty() and not log_kinds.has(kind):
		return
	log_lines.append({"t": t, "text": "%s  %s" % [clock(t), text], "kind": kind})
	if log_lines.size() > LOG_MAX:
		log_lines = log_lines.slice(500)
		log_base += 500


static func clock(tt: float) -> String:
	var tenths := int(round(tt * 10.0))
	var h := tenths / 36000
	var mm := (tenths / 600) % 60
	var ss := (tenths % 600) / 10.0
	if h > 0:
		return "%d:%02d:%04.1f" % [h, mm, ss]
	return "%02d:%04.1f" % [mm, ss]


# ================================================================== alert states
## GREEN: relaxed, rifle at low carry (pistol holstered); YELLOW: weapon drawn and ready;
## RED: engaging. Sounds, sightings, callouts and incoming fire raise it to yellow; aiming
## at someone makes it red. Red relaxes to yellow after 5 s without engaging, yellow to
## green after a quiet minute, never below the operator's floor (taskings set it).
const RED_HOLD := 5.0
const YELLOW_HOLD := 60.0


func raise_alert(o, lvl: int) -> void:
	if lvl > o.alert:
		o.alert = lvl
		if lvl == Op.YELLOW and o.alert_t < t - 1.0:
			emit({"type": "alert", "id": o.id, "lvl": lvl})
	if lvl >= o.alert:
		o.alert_t = t


func _relax(o) -> void:
	if o.alert == Op.RED and t - o.armed_t > RED_HOLD:
		o.alert = Op.YELLOW
		o.alert_t = t
	elif o.alert == Op.YELLOW and o.alert_floor < Op.YELLOW and t - o.alert_t > YELLOW_HOLD \
			and t - o.last_stress_t > YELLOW_HOLD and t - o.last_enemy_seen_t > YELLOW_HOLD:
		o.alert = Op.GREEN
	if o.alert < o.alert_floor:
		o.alert = o.alert_floor


## Seconds to bring the weapon to bear from the current carry: a rifle at low carry comes
## up in 0.45 s; a holstered pistol is drawn in 0.9 s (slower for the untrained).
func carry_time(o) -> float:
	if o.alert != Op.GREEN or o.weapon_up:
		return 0.0
	if o.active == "pistol":
		return 0.9 * (1.3 if o.echelon == "untrained" else 1.0)
	return 0.45


func emit(ev: Dictionary) -> void:
	if keep_events:
		events.append(ev)


func op_by_id(oid: String):
	return by_id.get(oid, null)


## May a target b? In a normal match: anyone on the other team. In the city:
##   - paramedics are never targets and never target anyone;
##   - rival gangs fight only when one side is an assault (expansion) team;
##   - police engage a gang member only once police have seen him targeting someone,
##     or while their own QRF is clearing its search buildings;
##   - gang members on assault or out hunting fire on police at will; holding gang members
##     only when police have engaged their squad.
func hostile(a, b) -> bool:
	if a == b or a.medic or b.medic or a.faction == b.faction:
		return false
	# civilians and people who have given up are nobody's targets, unless an officer has
	# judged them a threat by mistake, or has not yet let go of the trigger (v0.6)
	if a.civ or a.complying:
		return false
	if b.civ or b.complying:
		return a.misjudged.has(b.id) or a.ticker.get("late_" + b.id, -1.0) >= t
	if not city:
		return true
	var ga: bool = a.gang
	var gb: bool = b.gang
	if ga and gb:
		return a.assault or b.assault
	if gb:
		return a.clearing or t - b.flag_t < FLAG_TIME
	if ga:
		if a.assault or _hunting(a):
			return true
		return t - teams[a.team].get("police_t", -999.0) < ENGAGED_TIME
	return true


## Pairs worth perceiving: anyone who may become hostile soon. Police watch gang members
## who are shooting (to flag them), flagged, or inside their search; gang members watch
## police when hostile to them or in a fight (for the retreat check); holding gangs ignore
## each other.
func potential(a, b) -> bool:
	if a == b or a.medic or b.medic or a.faction == b.faction:
		return false
	if a.civ or a.complying:
		return false
	# officers under police rules watch everyone, to judge them
	if b.civ or b.complying:
		return a.judges or hostile(a, b)
	if not city:
		return true
	var ga: bool = a.gang
	var gb: bool = b.gang
	if ga and gb:
		return a.assault or b.assault
	if gb:
		# police watch gang members who are shooting, flagged, or in their search
		return a.clearing or t - b.flag_t < FLAG_TIME or t - b.armed_t < 2.0
	if ga:
		return hostile(a, b) or in_combat(a)
	return true


## In combat: engaging, under fire in the last 5 s, or (a gang squad) engaged by police.
func in_combat(o) -> bool:
	if o.alert == Op.RED or t - o.last_stress_t < 5.0:
		return true
	return city and t - teams[o.team].get("police_t", -999.0) < ENGAGED_TIME


## Someone worth attention: an enemy, or (police rules) any person not yet judged
## harmless. Attention is limited by Experience, so civilians use it up too.
func attends(a, b) -> bool:
	if hostile(a, b):
		return true
	if not a.judges or not b.alive() or a.faction == b.faction or b.medic:
		return false
	if b.civ or (b.complying and not b.arrested):
		return t - a.cleared.get(b.id, -999.0) > CLEAR_TIME
	return false


## Is e attacking o's side right now: aiming at one of them, or firing at all?
func attacking(e, o) -> bool:
	if e.civ or e.complying or not e.alive():
		return false
	if t - e.last_shot_t < 1.0:
		return true
	if e.aim.is_empty() or t - e.armed_t > 1.0:
		return false
	var tgt = by_id.get(e.aim.get("tid", ""), null)
	return tgt != null and tgt.faction == o.faction


## Are police rules in force for anyone (someone judges before firing)?
func police_rules() -> bool:
	for f in factions:
		if f.get("judges", false):
			return true
	return false


## A place name for the record: the room, or outside.
func place_of(p: Vector2) -> String:
	if director != null and director.has_method("place_name"):
		return director.place_name(p)
	var rm: String = level.room_at(p)
	if level.rooms.has(rm) and not level.is_exterior(rm):
		return "in the " + String(level.rooms[rm]["title"]).to_lower()
	return "outside"


func _hunting(a) -> bool:
	if a.ticker.has("investigate"):
		return true
	var tm: Dictionary = teams[a.team]
	if a.el < 0 or a.el >= tm["elements"].size():
		return false
	return tm["elements"][a.el]["mode"] == "hunt"


## Every operator who could be hostile to o (alive or not), within 60 m in the city.
func enemies_of(o) -> Array:
	var out: Array = []
	for e in near(o.pos, 60.0) if city else ops:
		if potential(o, e):
			out.append(e)
	return out


## Living members of o's own unit.
func mates_of(o) -> Array:
	var out: Array = []
	for m in team_ops[o.team]:
		if m != o and m.alive():
			out.append(m)
	return out


## Living members of o's faction within r metres (paramedics excluded).
func mates_near(o, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for m in _near_fast(o.pos, r):
		if m != o and m.faction == o.faction and m.alive() and not m.medic and m.pos.distance_squared_to(o.pos) <= r2:
			out.append(m)
	return out


# ================================================================== spatial hash
var _gw := 1
var _gh := 1
var _ghead := PackedInt32Array()
var _gnext := PackedInt32Array()
var _gops: Array = []


func _grid_init() -> void:
	_gw = maxi(1, int(ceil(level.W / GRID)))
	_gh = maxi(1, int(ceil(level.H / GRID)))
	_ghead.resize(_gw * _gh)
	_ghead.fill(-1)


func _cell(p: Vector2) -> int:
	return clampi(int(p.y / GRID), 0, _gh - 1) * _gw + clampi(int(p.x / GRID), 0, _gw - 1)


## Rebuilt every tick: everyone on foot, alive or not (bodies stop bullets too).
func _grid_build() -> void:
	_ghead.fill(-1)
	_gops.clear()
	_gnext.resize(ops.size())
	for o in ops:
		if o.mounted != null:
			continue
		var i := _gops.size()
		_gops.append(o)
		var c := _cell(o.pos)
		_gnext[i] = _ghead[c]
		_ghead[c] = i


## Operators on foot in the grid cells touching the square of half-side r around p
## (callers filter by exact distance).
func near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := clampi(int((p.x - r) / GRID), 0, _gw - 1)
	var x1 := clampi(int((p.x + r) / GRID), 0, _gw - 1)
	var y0 := clampi(int((p.y - r) / GRID), 0, _gh - 1)
	var y1 := clampi(int((p.y + r) / GRID), 0, _gh - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i: int = _ghead[cy * _gw + cx]
			while i >= 0:
				out.append(_gops[i])
				i = _gnext[i]
	return out


## Like near(), but already filtered to the circle of radius r, into a reused array
## (valid until the next call).
var _nf: Array = []


func _near_fast(p: Vector2, r: float) -> Array:
	_nf.clear()
	var r2 := r * r
	var x0 := clampi(int((p.x - r) / GRID), 0, _gw - 1)
	var x1 := clampi(int((p.x + r) / GRID), 0, _gw - 1)
	var y0 := clampi(int((p.y - r) / GRID), 0, _gh - 1)
	var y1 := clampi(int((p.y + r) / GRID), 0, _gh - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i: int = _ghead[cy * _gw + cx]
			while i >= 0:
				var e = _gops[i]
				if e.pos.distance_squared_to(p) <= r2:
					_nf.append(e)
				i = _gnext[i]
	return _nf


## Operators on foot in the cells overlapping a rectangle.
func near_rect(r: Rect2) -> Array:
	var out: Array = []
	var x0 := clampi(int(r.position.x / GRID), 0, _gw - 1)
	var x1 := clampi(int(r.end.x / GRID), 0, _gw - 1)
	var y0 := clampi(int(r.position.y / GRID), 0, _gh - 1)
	var y1 := clampi(int(r.end.y / GRID), 0, _gh - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i: int = _ghead[cy * _gw + cx]
			while i >= 0:
				out.append(_gops[i])
				i = _gnext[i]
	return out


func _calm_mode(o) -> bool:
	var tm: Dictionary = teams[o.team]
	if o.el < 0 or o.el >= tm["elements"].size():
		return true
	var md: String = tm["elements"][o.el]["mode"]
	return md == "transit" or md == "hold" or md == "wait" or md == "done"


## Dormancy (city): an operator with no possible enemy within 55 m, no recent stress and
## nothing to do skips perception, decisions and integration until one comes near.
func _update_dormancy() -> void:
	var tick_n := int(round(t / DT))
	var team_pass := tick_n % 8 == 0
	# a quarter of everyone each tick (the flags lag by at most 0.13 s)
	var n := ops.size()
	var i0 := tick_n % 4
	for i in range(i0, n, 4):
		var o = ops[i]
		if not o.alive() or o.medic or o.mounted != null:
			o.dormant = false
			continue
		if t >= o.hot_next:
			o.hot_next = t + 0.5
			var was: bool = o.hot
			o.hot = t - o.last_stress_t < 6.0 or t - o.last_enemy_seen_t < 6.0
			if not o.hot:
				for e in _near_fast(o.pos, 55.0):
					if e.alive() and potential(o, e):
						o.hot = true
						break
			if was and not o.hot:
				o.vis = {}
				o.tracked = {}
				o.n_los = 0
		if o.hot:
			o.dormant = false
			continue
		if t < o.idle_next:
			continue
		o.idle_next = t + 0.25
		var idle: bool = not o.moving and o.action.is_empty() and o.aim.is_empty() and o.sidestep.is_empty() \
			and not o.ticker.has("retreat")
		if idle:
			var tm: Dictionary = teams[o.team]
			var md: String = tm["elements"][o.el]["mode"] if o.el >= 0 and o.el < tm["elements"].size() else ""
			idle = (md == "hold" or md == "done" or md == "wait") and o.pos.distance_squared_to(o.spawn) < 0.49
		o.dormant = idle
	if not team_pass:
		return
	for tm in teams:
		if tm["free"]:
			continue
		var sl := true
		var ht := false
		for m in tm["members"]:
			if m.alive():
				if not m.dormant:
					sl = false
				if m.hot:
					ht = true
		tm["sleep"] = sl
		tm["hot"] = ht


## Wake someone the director has just given something to do.
func wake(o) -> void:
	o.dormant = false
	o.idle_next = t + 0.25


# ================================================================== bad habits
func _update_bad(o, first: bool) -> void:
	var eff: float = o.stress * (1.0 - o.ech["resist"])
	# stress habits switch on at their threshold and off 0.1 below it: nothing can change
	# while effective stress stays inside the band between the nearest two such points
	if not first and eff >= o.bad_lo and eff < o.bad_hi:
		return
	var anx := 70.0 if (o.bad.get("BH13", false) or o.bad.get("BH14", false)) else 40.0
	var changed := false
	var quiet: bool = not log_kinds.is_empty() and not log_kinds.has("bad")
	var lo := -INF
	var hi := INF
	for b in Habits.BAD:
		var bid: String = b["id"]
		var present: bool = o.bad.get(bid, false)
		var on: bool = o.active_bad.has(bid)
		if not present:
			if on:
				o.active_bad.erase(bid)
				changed = true
			continue
		if b["kind"] == "trait":
			if not on:
				o.active_bad[bid] = true
				changed = true
				if first and not quiet:
					say("%s %s %s (%s): %s suspended" % [o.id, bid, b["name"], b["trait"], _list_owned(o, b["over"])], "bad")
			continue
		var thr: float = b["t"] - 0.3 * anx / 100.0
		if on and eff < thr - 0.1:
			o.active_bad.erase(bid)
			on = false
			changed = true
			if not quiet:
				say("%s %s %s eases" % [o.id, bid, b["name"]], "bad")
		elif not on and eff >= thr:
			o.active_bad[bid] = true
			on = true
			changed = true
			if not quiet:
				say("%s %s %s: %s suspended" % [o.id, bid, b["name"], _list_owned(o, b["over"])], "bad")
			emit({"type": "bad_on", "id": o.id, "bad": bid, "name": b["name"]})
		if on:
			lo = maxf(lo, thr - 0.1)
		else:
			hi = minf(hi, thr)
	o.bad_lo = lo
	o.bad_hi = hi
	if changed or first:
		o.suspended.clear()
		for bid in o.active_bad:
			for gid in Habits.bad_info(bid)["over"]:
				if o.good.get(gid, false):
					o.suspended[gid] = true
		var n := 0
		for gid in o.good:
			if o.has(gid):
				n += 1
		o.m_h = 1.0 - 0.005 * n


func _list_owned(o, ids: Array) -> String:
	var owned: Array = []
	for gid in ids:
		if o.good.get(gid, false):
			owned.append(gid)
	return ", ".join(owned) if not owned.is_empty() else "nothing it owns"


# ================================================================== perception
func cone_half(o) -> float:
	if o.hb("BH04"):
		return deg_to_rad(25.0)
	var k := 0.5 if o.has("ED06") else 1.0
	return deg_to_rad(60.0 * (1.0 - 0.4 * o.stress * (1.0 - o.ech["resist"]) * k))


func _perceive(o) -> void:
	o.perc_phase -= DT
	if o.perc_phase > 0.0:
		return
	o.perc_phase += 0.1
	var ez: float = o.eye()
	var half := cone_half(o)
	var police: bool = o.police
	var gang: bool = o.gang
	if brain.fine:
		prof_n["perc_calls"] = prof_n.get("perc_calls", 0) + 1
	var prev_vis: Dictionary = o.vis
	var nv := {}
	var n := 0
	for e in (_near_fast(o.pos, 45.0) if city else ops):
		if brain.fine:
			prof_n["perc_cands"] = prof_n.get("perc_cands", 0) + 1
		if not potential(o, e):
			continue
		if brain.fine:
			prof_n["perc_pot"] = prof_n.get("perc_pot", 0) + 1
		if not e.alive() and t - e.ticker.get("down_t", t) > 4.0:
			continue
		var d: Vector2 = e.pos - o.pos
		var dist := d.length()
		var ecc := absf(angle_difference(o.look_dir, d.angle()))
		if ecc > half + 0.05 or dist > 45.0:
			if not city:
				nv[e.id] = {"los": false, "head_only": false, "dist": dist}
			continue
		# far pairs are re-traced less often (every 0.2 s past 15 m, 0.4 s past 30 m)
		if dist > 15.0:
			var prev: Dictionary = prev_vis.get(e.id, {})
			if prev.has("next") and t < prev["next"] and prev.get("ecc_ok", false):
				prev["dist"] = dist
				nv[e.id] = prev
				if prev["los"] and e.alive() and attends(o, e):
					n += 1
				continue
		if brain.fine:
			prof_n["perc_traces"] = prof_n.get("perc_traces", 0) + 1
		var m2: int = geom.sight_mask(o.pos, ez, e.pos, e.zone_centre("head"), e.zone_centre("chest"))
		var hv := (m2 & 1) != 0
		var cv := (m2 & 2) != 0
		var nxt := t + (0.0 if dist <= 15.0 else (0.19 if dist <= 30.0 else 0.39))
		var los := hv or cv
		nv[e.id] = {"los": los, "head_only": hv and not cv, "dist": dist, "next": nxt, "ecc_ok": true}
		if los and e.alive():
			if ecc <= half and not e.civ and not e.complying:
				raise_alert(o, Op.YELLOW)
			if attends(o, e):
				n += 1
			if police and e.gang and t - e.armed_t < 0.6 and ecc <= half:
				if t - e.flag_t > 2.0 and director != null:
					director.on_flagged(o, e)
				e.flag_t = t
			elif gang and e.police and ecc <= half and director != null and in_combat(o):
				director.on_sees_police(o, e)
	o.vis = nv
	o.n_los = n


func t_rec(o, e, ecc: float, head_only: bool) -> float:
	var ed := rad_to_deg(ecc) / 60.0
	var E := 1.0 + 2.5 * ed * ed
	var X := 1.5 if head_only else 1.0
	if e.ticker.get("in_cover_t", -9.0) > t - 0.3 and e.has("PF05"):
		X = maxf(X, 1.5)
	if e.vel.length() > 0.3:
		X *= 0.8
	var S: float = 1.0 + 0.5 * o.stress * (1.0 - o.ech["resist"])
	var C := 0.6 if o.cue.get(e.id, -1.0) > t else 1.0
	var G := 1.3 if o.alert == Op.GREEN else 1.0
	var N := 1.25 if night else 1.0
	return o.ech["t_rec0"] * o.m_h * E * X * S * C * G * N


## Experience: an operator holds up to `exp` enemies in attention. A tracked enemy is
## dropped when eliminated (after the confirm pause) or when sight of it has been broken
## for 0.3 s; free slots go to the closest enemies in the cone with a line of sight.
func _update_tracking(o, half: float) -> void:
	for eid in o.tracked.keys():
		var e = by_id.get(eid, null)
		if e == null:
			o.tracked.erase(eid)
			continue
		var tr: Dictionary = o.tracked[eid]
		if not e.alive():
			var until: float = o.ticker.get("confirm_" + eid, e.ticker.get("down_t", t) + 0.15)
			if t > until:
				o.tracked.erase(eid)
			continue
		var v: Dictionary = o.vis.get(eid, {})
		var in_view: bool = v.get("los", false) and absf(angle_difference(o.look_dir, (e.pos - o.pos).angle())) <= half
		if not attends(o, e):
			o.tracked.erase(eid)
			continue
		if in_view:
			tr["lost_t"] = -1.0
		elif tr["lost_t"] < 0.0:
			tr["lost_t"] = t
		elif t - tr["lost_t"] > 0.3:
			o.tracked.erase(eid)
	if o.tracked.size() >= o.exp or o.n_los == 0:
		return
	var cands: Array = []
	for eid2 in o.vis:
		var v2: Dictionary = o.vis[eid2]
		if not v2.get("los", false) or o.tracked.has(eid2):
			continue
		var e = by_id.get(eid2, null)
		if e == null or not e.alive() or not attends(o, e):
			continue
		var d: Vector2 = e.pos - o.pos
		if absf(angle_difference(o.look_dir, d.angle())) > half:
			continue
		# a person showing a weapon draws the eye before one who is not
		var pri: float = 0.25 if (o.judges and e.shows_weapon()) else 1.0
		cands.append([d.length_squared() * pri, e.id])
	if cands.is_empty():
		return
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for c in cands:
		if o.tracked.size() >= o.exp:
			break
		o.tracked[c[1]] = {"lost_t": -1.0, "ready_t": INF}


func _recognize(o) -> void:
	var half := cone_half(o)
	_update_tracking(o, half)
	# untracked enemies are not attended to: their recognition fades
	for eid in o.rec.keys():
		if o.tracked.has(eid):
			continue
		var q: float = o.rec[eid] - 0.5 * DT
		if q <= 0.0:
			o.rec.erase(eid)
		else:
			o.rec[eid] = q
	for eid in o.tracked.keys():
		var e = by_id.get(eid, null)
		if e == null:
			continue
		var p: float = o.rec.get(e.id, 0.0)
		var was := p >= 1.0
		var v: Dictionary = o.vis.get(e.id, {})
		var seen := false
		if v.get("los", false):
			var d: Vector2 = e.pos - o.pos
			var ecc := absf(angle_difference(o.look_dir, d.angle()))
			if ecc <= half:
				seen = true
				p += DT / t_rec(o, e, ecc, v.get("head_only", false))
		if not seen:
			p = maxf(0.0, p - 0.5 * DT)
		p = minf(p, 1.0)
		o.rec[e.id] = p
		if seen and p >= 1.0:
			var foe: bool = hostile(o, e)
			if foe or not (e.civ or e.complying):
				o.lkp[e.id] = {"p": e.pos, "t": t}
			if e.alive():
				if foe:
					o.last_enemy_seen_t = t
				# aim set up in parallel from the moment of recognition
				var tr: Dictionary = o.tracked[e.id]
				if tr["ready_t"] == INF:
					tr["ready_t"] = t + _acquire_time(o, e, "chest", false)
			if not was and (foe or not (e.civ or e.complying)):
				_on_recognized(o, e)
			if o.judges and e.alive():
				_judge(o, e)
				if not o.tracked.has(e.id):
					continue


func visible(o, e) -> bool:
	return o.rec.get(e.id, 0.0) >= 1.0 and o.vis.get(e.id, {}).get("los", false)


## Recognized enemies in sight (only tracked enemies can be recognized).
func visible_enemies(o) -> Array:
	var out: Array = []
	for eid in o.tracked:
		var e = by_id.get(eid, null)
		if e != null and e.alive() and visible(o, e):
			out.append(e)
	return out


## Tracked enemies in sight, including ones just downed (for the confirm pause).
func visible_tracked(o) -> Array:
	var out: Array = []
	for eid in o.tracked:
		var e = by_id.get(eid, null)
		if e != null and visible(o, e):
			out.append(e)
	return out


func _on_recognized(o, e) -> void:
	if not e.alive():
		return
	var dist: float = o.pos.distance_to(e.pos)
	var ecc := rad_to_deg(absf(angle_difference(o.look_dir, (e.pos - o.pos).angle())))
	if not o.first_rec.has(e.id):
		o.first_rec[e.id] = t
		say("%s recognizes %s: %.1f m, %d deg off eye line" % [o.id, e.id, dist, int(ecc)], "info")
	emit({"type": "recognized", "id": o.id, "target": e.id})
	if director != null:
		director.on_recognized(o, e)
	teams[o.team]["last_contact"] = t
	if o.hb("BH01") and not o.ticker.has("froze_" + e.id):
		o.ticker["froze_" + e.id] = true
		o.freeze_add = rng.randf_range(0.4, 1.0)
		o.ticker["freeze_until"] = t + o.freeze_add
		say("%s freezes for %.1f s" % [o.id, o.freeze_add], "bad")
	if o.has("GD04") and t - o.ticker.get("callout_" + e.id, -99.0) > 5.0:
		o.ticker["callout_" + e.id] = t
		for m in mates_near(o, 30.0):
			raise_alert(m, Op.YELLOW)
			if m.has("GD04"):
				m.cue[e.id] = t + 3.0
				if m.pos.distance_to(e.pos) < 25.0 and visible_enemies(m).is_empty() and in_sector(m, (e.pos - m.pos).angle()):
					m.look_hint = {"dir": (e.pos - m.pos).angle(), "start": t + 0.5, "until": t + 2.0, "why": "callout"}
		teams[o.team]["lkps"][e.id] = {"p": e.pos, "t": t}
		var clock := int(round(fposmod(rad_to_deg((e.pos - o.pos).angle() - o.body_dir), 360.0) / 30.0)) % 12
		say("%s calls: contact, %d o'clock, %d m" % [o.id, 12 if clock == 0 else clock, int(dist)], "comms")


# ================================================================== judgment (v0.6)
## Police rules: a recognized person is judged before an officer may fire. The verdict:
##   threat     showing a weapon, or attacking: fire is allowed
##   unknown    no weapon in sight: the officer covers them and shouts a challenge
##   civilian   (or someone who has given up) let go of; not judged again for 10 s
## A civilian can be judged a threat by mistake: more often under stress, in the dark,
## with something in their hand (a phone), running, or with poor Judgment.
func _judge(o, e) -> void:
	var j: Dictionary = o.judged.get(e.id, {})
	if j.is_empty():
		o.judged[e.id] = {"until": t + judge_time(o, e), "v": ""}
		return
	var v: String = j["v"]
	if v == "":
		if t < j["until"]:
			return
		if e.civ or e.complying:
			if rng.randf() < misjudge_p(o, e):
				j["v"] = "threat"
				o.misjudged[e.id] = true
				say("%s judges %s (%s) a threat" % [o.id, e.id, "a civilian" if e.civ else "giving up"], "bad")
				emit({"type": "float", "p": o.pos, "text": "MISJUDGED"})
				if incident != null:
					incident.on_misjudge(o, e)
				return
			o.judged.erase(e.id)
			o.cleared[e.id] = t
			o.tracked.erase(e.id)
			if o.aim.get("tid", "") == e.id:
				o.aim = {}
			return
		if e.shows_weapon() or attacking(e, o):
			j["v"] = "threat"
		else:
			j["v"] = "unknown"
			say("%s: %s shows no weapon" % [o.id, e.id], "info")
	elif v == "unknown" and (e.shows_weapon() or attacking(e, o)):
		j["v"] = "threat"


func judge_time(o, e) -> float:
	var jt: float = JUDGE_BASE * (1.5 - o.judgment / 100.0)
	jt *= 1.0 + 0.5 * o.stress * (1.0 - o.ech["resist"])
	if night:
		jt *= 1.3
	if o.has("ED04"):
		jt *= 0.8
	if attacking(e, o):
		jt *= 0.4
	if e.ticker.get("hands", -99.0) > t - 1.0:
		jt *= 0.6
	return maxf(0.05, jt * o.m_h)


## Chance that judging a civilian (or someone giving up) ends in "threat".
func misjudge_p(o, e) -> float:
	var eff: float = o.stress * (1.0 - o.ech["resist"])
	var p: float = 0.003 + 0.12 * eff + 0.002 * (50.0 - o.judgment)
	if e.civ and e.cstate == "film":
		p += 0.04
	if e.vel.length() > 2.0:
		p += 0.03
	if night:
		p += 0.03
	if e.pos.distance_to(o.pos) < 4.0:
		p += 0.02
	if e.ticker.get("hands", -99.0) > t - 1.0:
		p *= 0.15
	if o.has("ED04"):
		p *= 0.5
	if o.has("WD09"):
		p *= 0.7
	p *= o.ech["t_rec0"] / 0.39
	return clampf(p, 0.0, 0.5)


## May o fire at e now? (Only asked under police rules.)
func cleared_to_fire(o, e) -> bool:
	if not e.alive():
		return true
	if e.civ or e.complying:
		return o.misjudged.has(e.id) or o.ticker.get("late_" + e.id, -1.0) >= t
	if attacking(e, o):
		return true
	var j: Dictionary = o.judged.get(e.id, {})
	if j.get("v", "") == "unknown" and e.shows_weapon():
		j["v"] = "threat"
	if j.get("v", "") != "threat":
		return false
	return not roe_strict


## "Police! Show me your hands!" Heard by the suspect (who may give up) and by any
## civilian close by (who usually complies).
func _challenge(o, e) -> void:
	if t - o.ticker.get("chal_t", -99.0) < CHALLENGE_EVERY:
		return
	o.ticker["chal_t"] = t
	say("%s: Police! Show me your hands! (%s)" % [o.id, e.id], "comms")
	emit({"type": "float", "p": o.pos, "text": "SHOW ME YOUR HANDS"})
	if e.pos.distance_to(o.pos) <= CHALLENGE_R:
		_surrender_roll(e, o, true)


## Every second: a suspect covered by police may give up, more readily when cornered,
## hurt, out of ammunition or untrained, less readily with friends close by.
func _surrender_checks() -> void:
	if not police_rules():
		return
	for o in ops:
		if not o.fighting() or o.judges or o.civ:
			continue
		var by = null
		for x in _near_fast(o.pos, 15.0):
			if x.judges and x.alive() and x.aim.get("tid", "") == o.id and x.aim.get("on", false):
				by = x
				break
		if by == null and o.any_loaded():
			continue
		if by == null:
			for x2 in _near_fast(o.pos, 15.0):
				if x2.judges and x2.alive() and visible(x2, o):
					by = x2
					break
		if by != null:
			_surrender_roll(o, by, false)


func _surrender_roll(e, by, challenged: bool) -> void:
	if e.complying or e.civ or not e.alive() or e.judges:
		return
	var prop: float = SURRENDER.get(e.echelon, 0.3)
	var p := 0.35 * prop if challenged else 0.0
	var aimed := 0
	for x in _near_fast(e.pos, 20.0):
		if x.judges and x.alive() and x.aim.get("tid", "") == e.id:
			aimed += 1
	p += 0.12 * mini(aimed, 3) * prop
	if e.wounds > 0 or e.arm_hit or e.leg_hit:
		p += 0.25 * prop
	if not e.any_loaded():
		p += 0.5
	p += 0.2 * e.stress * (1.0 - e.ech["resist"]) * prop
	if attacking(e, by):
		p *= 0.3
	var mates := 0
	for m in mates_near(e, 10.0):
		if m.fighting():
			mates += 1
	p /= 1.0 + 0.5 * mates
	if rng.randf() < p:
		surrender(e, by)


## Hands up, weapon dropped, kneeling. Whoever was firing at them takes a moment to stop.
func surrender(e, by) -> void:
	e.complying = true
	e.aim = {}
	e.action = {}
	e.sidestep = {}
	stop(e)
	for wn in ["rifle", "pistol"]:
		e.weapons[wn]["lost"] = true
		e.weapons[wn]["mag"] = 0
	e.alert = Op.GREEN
	e.alert_floor = Op.GREEN
	e.weapon_up = false
	e.stance_goal = Op.CROUCH
	e.ticker["hands"] = INF
	e.ticker.erase("retreat")
	for x in ops:
		if x.judges and x.alive() and x.aim.get("tid", "") == e.id:
			x.ticker["late_" + e.id] = t + late_stop(x)
	say("%s gives up: hands up, weapon down (%s)" % [e.id, by.id if by != null else "nobody"], "kill")
	emit({"type": "float", "p": e.pos, "text": "HANDS UP"})
	emit({"type": "surrender", "id": e.id})
	if incident != null:
		incident.on_surrender(e, by)


## How long an officer keeps firing at someone who has just given up: reaction time,
## plus temper and stress, plus a second for anyone with Overkill active.
func late_stop(x) -> float:
	var eff: float = x.stress * (1.0 - x.ech["resist"])
	var d: float = 0.12 + rng.randf() * 0.2 + 0.3 * x.temper / 100.0 + 0.4 * eff
	if x.hb("BH03"):
		d += 0.5
	if x.has("WD09"):
		d *= 0.6
	return d


## Someone who has given up stays put, kneeling with their hands up (seated once cuffed).
func _hold_complying(o) -> void:
	stop(o)
	o.stance_goal = Op.DUCK if o.arrested else Op.CROUCH
	o.aim = {}


# ================================================================== actions
func start_action(o, type: String, dur: float, extra := {}) -> void:
	o.action = {"type": type, "left": dur, "total": dur}
	for k in extra:
		o.action[k] = extra[k]
	o.aim = {}
	if type == "reload" or type == "clear":
		emit_sound(o, "reload")
	if (type == "reload" or type == "clear") and o.has("GD08"):
		var cover = null
		for m in mates_near(o, 12.0):
			if m.has("GD08") and m.action.is_empty() and visible_enemies(m).is_empty():
				if cover == null or m.pos.distance_to(o.pos) < cover.pos.distance_to(o.pos):
					cover = m
		if cover != null:
			cover.look_hint = {"dir": o.look_dir, "start": t + 0.5, "until": t + dur + 0.5, "why": "covering " + o.id}
			say("%s: %s, cover me. %s covers" % [o.id, "reloading" if type == "reload" else "stoppage", cover.id], "comms")
		else:
			say("%s: %s, nobody free to cover" % [o.id, "reloading" if type == "reload" else "stoppage"], "comms")


func _finish_action(o) -> void:
	var a: Dictionary = o.action
	o.action = {}
	match a["type"]:
		"transition":
			o.active = a["to"]
			say("%s on %s" % [o.id, "pistol" if o.active == "pistol" else "rifle"], "rule")
		"reload":
			var wn: String = a["w"]
			var s: Dictionary = o.weapons[wn]
			s["mag"] = Habits.WEAPONS[wn]["mag"]
			s["spare"] -= 1
			o.active = wn
			o.ticker["reengage"] = true
			say("%s reloaded %s (%d spare)" % [o.id, wn, s["spare"]], "info")
		"clear":
			if rng.randf() < a["p_ok"]:
				o.ws()["jam"] = false
				o.ticker["reengage"] = true
				say("%s cleared the stoppage" % o.id, "info")
			else:
				say("%s: stoppage still there, again" % o.id, "info")
				start_action(o, "clear", a["total"], {"p_ok": a["p_ok"]})
		"click":
			o.ticker["clicked"] = true
		"cuff":
			var e = by_id.get(a.get("tid", ""), null)
			if e != null and e.alive() and e.complying and not e.arrested:
				e.arrested = true
				e.stance_goal = Op.DUCK
				say("%s cuffs %s" % [o.id, e.id], "kill")
				emit({"type": "float", "p": e.pos, "text": "CUFFED"})
				if incident != null:
					incident.on_arrest(e, o)


func blocks_move(o) -> bool:
	if o.ticker.get("freeze_until", -1.0) > t or o.ticker.get("flinch_until", -1.0) > t:
		return true
	if o.action.is_empty():
		return false
	return o.action["type"] in ["reload", "clear", "check", "stall", "click", "melee", "cuff"]


# ================================================================== movement
func move_to(o, p: Vector2, mode: String, prof := -1) -> void:
	if prof < 0:
		prof = (1 if o.has("PF01") else 0) | (2 if o.has("PF02") else 0)
	o.goal_mode = mode
	var spd: float = SPEEDS.get(mode, 1.6)
	spd *= 1.0 - 0.04 * o.plates_max
	if o.civ:
		spd *= float(o.persona.get("mobility", 1.0))
	if o.wounds > 0:
		spd *= 0.7
	if o.leg_hit:
		spd *= 0.4
	o.speed = spd
	var stuck := false
	if t > o.repath_t:
		stuck = o.moving and o.pos.distance_to(o.ticker.get("prog_p", Vector2.INF)) < 0.1 and not blocks_move(o)
		o.ticker["prog_p"] = o.pos
		o.repath_t = t + 1.5
	var need: bool = o.path.is_empty() or o.goal.distance_to(p) > 0.4 or stuck or o.ticker.get("prof", -1) != prof
	if need and o.path.is_empty() and o.goal.distance_to(p) <= 0.4 and t < o.ticker.get("path_fail_until", -1.0):
		need = false
	if need:
		var why := ""
		if brain.fine:
			why = "pth_empty" if o.path.is_empty() else ("pth_goal" if o.goal.distance_to(p) > 0.4 else ("pth_stuck" if stuck else "pth_prof"))
		var tp0 := Time.get_ticks_usec()
		o.goal = p
		o.path = nav.find_path(prof, o.pos, p)
		if brain.fine:
			if o.path.is_empty():
				why += "_FAIL"
			prof_n[why] = prof_n.get(why, 0) + 1
			self.prof[why] = self.prof.get(why, 0) + Time.get_ticks_usec() - tp0
		if o.path.is_empty():
			o.ticker["path_fail_until"] = t + 1.0
		o.path_i = 1
		o.ticker["prof"] = prof
	o.moving = true


## Pause movement but keep the path, so resuming toward the same goal costs nothing.
func stop(o) -> void:
	o.moving = false


func at(o, p: Vector2, tol := 0.35) -> bool:
	return o.pos.distance_to(p) <= tol


func _move(o) -> void:
	if brain.fine:
		var t0 := Time.get_ticks_usec()
		_move2(o)
		prof["int_move"] = prof.get("int_move", 0) + Time.get_ticks_usec() - t0
		return
	_move2(o)


func _move2(o) -> void:
	var newp: Vector2 = o.pos
	if blocks_move(o):
		o.vel = Vector2.ZERO
		return
	if not o.sidestep.is_empty():
		var sd: Dictionary = o.sidestep
		sd["left"] -= DT
		var q: Vector2 = o.pos + sd["dir"] * SPEEDS["step"] * DT
		if sd["left"] <= 0.0 or not nav.is_free(q):
			o.sidestep = {}
		else:
			newp = q
	elif o.moving and o.path.size() > 0:
		while o.path_i < o.path.size() and o.pos.distance_to(o.path[o.path_i]) < 0.08:
			o.path_i += 1
		if o.path_i >= o.path.size():
			o.moving = false
		else:
			var target: Vector2 = o.path[o.path_i]
			var d: Vector2 = target - o.pos
			newp = o.pos + d.limit_length(o.speed * DT)
	# separation from other bodies (suspended briefly when two are jammed in a doorway)
	var ghost: bool = o.ticker.get("ghost_until", -1.0) > t
	for m in ([] if ghost else _near_fast(newp, 0.72)):
		if m == o:
			continue
		if absf(newp.x - m.pos.x) >= 0.5 or absf(newp.y - m.pos.y) >= 0.5 or not m.alive():
			continue
		var sep: Vector2 = newp - m.pos
		var dd := sep.length()
		if dd < 0.5 and dd > 0.001:
			var q2: Vector2 = newp + sep / dd * (0.5 - dd) * 0.5
			if nav.is_free(q2):
				newp = q2
	var moved: float = newp.distance_to(o.pos)
	if moved > 0.0005 and o.sidestep.is_empty() and o.moving:
		o.ticker["step_d"] = o.ticker.get("step_d", 0.0) + moved
		if o.ticker["step_d"] >= 1.2:
			o.ticker["step_d"] = 0.0
			emit_sound(o, o.goal_mode)
	if o.moving and o.sidestep.is_empty() and moved < 0.005:
		o.ticker["jam_t"] = o.ticker.get("jam_t", 0.0) + DT
		if o.ticker["jam_t"] > 1.0:
			o.ticker["ghost_until"] = t + 0.8
			o.ticker["jam_t"] = 0.0
	else:
		o.ticker["jam_t"] = 0.0
	o.vel = (newp - o.pos) / DT
	o.pos = newp
	o.room = level.room_at(o.pos)
	if o.wounds > 0 or o.arm_hit or o.leg_hit:
		o.ticker["drip_d"] = o.ticker.get("drip_d", 0.0) + moved
		if o.ticker["drip_d"] > 0.45:
			o.ticker["drip_d"] = 0.0
			emit({"type": "drip", "p": o.pos + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))})


# ================================================================== aiming and firing
func sigma_shooter(o, settle: float) -> float:
	return o.ech["s_min"] + (o.ech["s_snap"] - o.ech["s_min"]) * exp(-settle / o.ech["tau"])


## Aim at e, and fire when ready. Under police rules fire waits for the officer's
## judgment (force: BH09 fires at half-recognized movement and skips it).
func engage(o, e, zone: String, fire := true, force := false) -> void:
	if fire and o.judges and not force and not cleared_to_fire(o, e):
		fire = false
		if e.alive() and not e.civ and not e.complying:
			_challenge(o, e)
	if o.aim.get("tid", "") != e.id or o.aim.get("zone", "") != zone or o.aim.get("weapon", "") != o.active:
		_start_acquire(o, e, zone)
	if fire and e.alive():
		o.armed_t = t
		raise_alert(o, Op.RED)
		if city and factions[o.faction]["police"] and factions[e.faction]["gang"]:
			teams[e.team]["police_t"] = t
	o.aim["want_t"] = t
	o.aim["fire"] = fire


## Fitts-law time on target from the current muzzle direction (bible section 2.3).
func _acquire_time(o, e, zone: String, arm := true) -> float:
	var to: Vector2 = e.pos - o.pos
	var d := maxf(to.length(), 0.5)
	var dth := absf(angle_difference(o.muzzle_dir, to.angle()))
	var W := 2.0 * atan(e.zone_radius(zone) / d)
	var w: Dictionary = o.wpn()
	var t_ready := 0.0 if (o.has("ED01") or o.weapon_up) else 0.25
	t_ready += carry_time(o)
	var a: float = o.ech["a"] + w["a_w"]
	var b: float = o.ech["b"] * w["b_w"]
	var tt: float = o.m_h * (t_ready + a + b * log(1.0 + dth / W) / log(2.0))
	tt = maxf(tt, dth / deg_to_rad(o.ech["turn"]))
	if arm and o.arm_hit:
		tt += 0.2
	return tt


func _start_acquire(o, e, zone: String) -> void:
	var to: Vector2 = e.pos - o.pos
	var bearing := to.angle()
	var dth := absf(angle_difference(o.muzzle_dir, bearing))
	var tt: float = _acquire_time(o, e, zone, false)
	# Experience: a target already acquired in parallel is switched to almost at once
	# (weapon and plates make a few milliseconds of difference)
	var tr = o.tracked.get(e.id, null)
	if tr != null and tr["ready_t"] != INF and (o.aim.get("tid", "") != e.id or o.aim.get("weapon", "") != o.active):
		var sw: float = o.wpn()["switch"] + Habits.SWITCH_PER_PLATE * o.plates_max
		tt = maxf(tr["ready_t"] - t, sw)
	if o.arm_hit:
		tt += 0.2
	if o.freeze_add > 0.0:
		tt += o.freeze_add
		o.freeze_add = 0.0
	var plate_seen: bool = o.aim.get("plate_seen", false) and o.aim.get("tid", "") == e.id
	o.aim = {"tid": e.id, "zone": zone, "weapon": o.active, "acq_left": tt, "acq_total": tt,
		"from": o.muzzle_dir, "on": false, "settle": 0.0, "pair": 0, "pause": 0.0, "hold": 0.0,
		"want_t": t, "fire": true, "plate_seen": plate_seen, "dth": dth}


func _aim_update(o) -> void:
	if o.aim.is_empty():
		return
	if o.aim["want_t"] < t - 0.05:
		o.aim = {}
		return
	var e = op_by_id(o.aim["tid"])
	if e == null:
		o.aim = {}
		return
	o.weapon_up = true
	o.last_aim_t = t
	var bearing: float = (e.pos - o.pos).angle()
	if not o.aim["on"]:
		o.aim["acq_left"] -= DT
		var k: float = clampf(1.0 - o.aim["acq_left"] / maxf(o.aim["acq_total"], 0.001), 0.0, 1.0)
		o.muzzle_dir = lerp_angle(o.aim["from"], bearing, k)
		if o.aim["acq_left"] <= 0.0:
			o.aim["on"] = true
			o.aim["settle"] = 0.0
			if not o.ticker.has("tot_" + e.id) and e.alive():
				o.ticker["tot_" + e.id] = true
				say("%s on target %s after %.2f s (%.0f deg traverse)" % [o.id, e.id, o.aim["acq_total"], rad_to_deg(o.aim["dth"])], "info")
		return
	o.muzzle_dir = bearing
	o.aim["settle"] += DT
	if o.aim["pause"] > 0.0:
		o.aim["pause"] -= DT
		return
	if not o.aim["fire"] or not o.action.is_empty():
		return
	if o.ticker.get("flinch_until", -1.0) > t or o.ticker.get("stagger_until", -1.0) > t:
		return
	var s: Dictionary = o.ws()
	if s["mag"] <= 0 or s["jam"] or s["lost"]:
		return
	var w: Dictionary = o.wpn()
	var since: float = t - o.last_shot_t
	var split: float = w["snap"]
	var release := true
	if o.hb("BH02"):
		split = w["cadence"]
	elif o.hb("BH19"):
		split = 0.25
	elif o.has("WD07"):
		split = 0.25
		var dist: float = maxf(o.pos.distance_to(e.pos), 0.5)
		var W: float = 2.0 * atan(e.zone_radius(o.aim["zone"]) / dist) * 1000.0
		var cap := 0.5 if o.aim["zone"] == "head" else 0.15
		release = sigma_shooter(o, o.aim["settle"]) <= 0.35 * W or o.aim["settle"] >= cap
	if since < split or not release:
		return
	if o.has("WD10") and friend_in_line(o, e.pos):
		o.aim["hold"] += DT
		if o.aim["hold"] > 0.3 and o.sidestep.is_empty() and o.action.is_empty():
			var side := Vector2.from_angle(bearing + PI / 2.0)
			if not nav.is_free(o.pos + side * 0.5):
				side = -side
			o.sidestep = {"dir": side, "left": 0.45}
			o.aim["hold"] = 0.0
		return
	o.aim["hold"] = 0.0
	fire_at(o, e, o.aim["zone"], o.aim["settle"])
	o.aim["pair"] += 1
	o.aim["settle"] = 0.0
	if o.hb("BH19"):
		if o.aim["pair"] >= 2:
			o.aim["pause"] = 0.6
			o.aim["pair"] = 0
	elif o.has("WD07") and not o.hb("BH02"):
		if o.aim["pair"] >= 2:
			o.aim["pause"] = 0.3
			o.aim["pair"] = 0


func friend_in_line(o, target: Vector2) -> bool:
	var u: Vector2 = (target - o.pos)
	var L := u.length()
	if L < 0.01:
		return false
	u /= L
	for m in mates_near(o, L + 0.5):
		var rel: Vector2 = m.pos - o.pos
		var s := rel.dot(u)
		if s > 0.2 and s < L and absf(rel.cross(u)) < 0.5:
			return true
	return false


func fire_at(o, e, zone: String, settle: float) -> void:
	var to: Vector2 = e.pos - o.pos
	_fire(o, to.angle(), e.zone_centre(zone), maxf(to.length(), 0.3), settle, e)


## Does a round of this weapon go through this wall, and with how much energy left?
## Returns the energy kept (0 = stopped).
func _penetrate(idx: int, weapon: String, energy: float) -> float:
	var mat: String = geom.material(idx)
	if not PEN.has(mat):
		return 0.0
	var spec: Array = PEN[mat][weapon]
	if spec[0] < 1.0 and rng.randf() >= spec[0]:
		return 0.0
	var left: float = energy * float(spec[1])
	return left if left >= 0.3 else 0.0


func _fire(o, bearing: float, aim_z: float, dist: float, settle: float, tgt = null) -> void:
	var w: Dictionary = o.wpn()
	var s: Dictionary = o.ws()
	if s["mag"] <= 0:
		return
	s["mag"] -= 1
	o.shots += 1
	stat["shots"] += 1
	o.last_shot_t = t
	o.weapon_up = true
	var sig := sqrt(pow(sigma_shooter(o, settle), 2.0) + pow(w["s_w"], 2.0))
	var sp: float = o.vel.length()
	if sp > 0.2:
		sig *= o.ech["move_s"] * (1.5 if sp > 2.5 else 1.0)
	sig *= 1.0 + o.stress * (1.0 - o.ech["resist"])
	if o.wounds > 0:
		sig *= 1.5
	if o.arm_hit:
		sig *= 1.4
	var yaw := bearing + rng.randfn(0.0, sig) / 1000.0
	var mz: float = o.eye() - 0.05
	var pitch: float = atan2(aim_z - mz, dist) + (rng.randfn(0.0, sig) - o.ech["flinch"] + o.recoil) / 1000.0
	o.recoil += w["kappa"]
	o.armed_t = t
	var u := Vector2.from_angle(yaw)
	var reach := 60.0
	var slope := tan(clampf(pitch, -1.2, 1.2))
	# walk the round through the walls it can go through (v0.6): partitions and timber
	# let rifle rounds through, and pistol rounds sometimes; masonry stops everything
	var s0 := 0.0
	var energy := 1.0
	var passes: Array = []          # [[s_in, s_out, energy after], ...]
	var mh: Dictionary = {}
	var stop_d := reach
	for guard in 4:
		var a0: Vector2 = o.pos + u * s0
		mh = geom.trace_shot(a0, mz + slope * s0, o.pos + u * reach, mz + slope * reach)
		if not mh["hit"]:
			stop_d = reach
			break
		var s_in: float = s0 + mh["t"] * (reach - s0)
		stop_d = s_in
		if mh["kind"] != Geom.WALL or guard == 3:
			break
		var left := _penetrate(mh["idx"], o.active, energy)
		if left <= 0.0:
			break
		var tt := Geom.seg_rect(a0, u * (reach - s0), geom.obs[mh["idx"]]["r"])
		var s_out: float = s0 + maxf(tt.y, mh["t"]) * (reach - s0) + 0.02
		emit({"type": "impact", "p": mh["p"], "n": mh["n"], "kind": mh["kind"]})
		energy = left
		passes.append([s_in, s_out, energy])
		s0 = s_out
		mh = {}
		stop_d = reach
	var hit_op = null
	var hit_zone: Array = []
	var hit_lat := 0.0
	var best := stop_d
	var lane := Rect2(o.pos, Vector2.ZERO).expand(o.pos + u * (stop_d + 1.2)).grow(1.2)
	var cands: Array = near_rect(lane) if city else ops
	for a in cands:
		if a == o or a.mounted != null:
			continue
		var rel: Vector2 = a.pos - o.pos
		var sa := rel.dot(u)
		if sa <= 0.15 or sa >= best:
			continue
		var lat := absf(rel.cross(u))
		var zn: Array = a.zone_at(mz + slope * sa)
		if not zn.is_empty() and lat <= zn[3]:
			best = sa
			hit_op = a
			hit_zone = zn
			hit_lat = lat
	# the walls the round went through before it reached where it stopped
	var walls := 0
	var e_at := 1.0
	for ps in passes:
		if ps[1] <= best:
			walls += 1
			e_at = ps[2]
	var endp: Vector2 = o.pos + u * best
	emit({"type": "shot", "from": o.pos + u * 0.55, "to": endp, "team": o.team, "id": o.id})
	emit({"type": "casing", "p": o.pos, "dir": o.body_dir})
	emit_sound(o, o.active)
	for a in cands:
		if a == o or a == hit_op or not a.alive() or a.mounted != null:
			continue
		var rel2: Vector2 = a.pos - o.pos
		var sa2 := rel2.dot(u)
		if sa2 > 0.3 and sa2 < best + 1.0 and absf(rel2.cross(u)) < 1.0:
			add_stress(a, 0.15, "near miss")
			a.ticker["near_t"] = t
			if a.civ:
				civ_brain.alarm(a, o.pos, "near miss")
	if incident != null:
		incident.on_shot(o, tgt, hit_op, walls)
	if hit_op != null:
		_hit(hit_op, hit_zone, hit_lat, u, o, e_at, walls)
	elif not mh.is_empty() and mh["hit"]:
		emit({"type": "impact", "p": mh["p"], "n": mh["n"], "kind": mh["kind"]})
	var pj: float = w["stop"] * (0.5 if o.has("WD04") else 1.0)
	if rng.randf() < pj:
		s["jam"] = true
		say("%s stoppage (%s)" % [o.id, o.active], "rule")


## Sound: every source makes a noise of fixed loudness (Habits.SOUND). A living enemy
## hears it within loudness x their hearing (a static attribute; Tinnitus and Elephant
## Ears change it), or half that if walls stand between them, unless they can already
## see the source. Hearing gives a rough position, off by up to 8% of the distance.
func emit_sound(src, kind: String) -> void:
	var loud: float = Habits.SOUND.get(kind, 0.0)
	if loud <= 0.0 or src.civ or src.complying:
		return
	var gun: bool = kind == "rifle" or kind == "pistol"
	if gun and director != null:
		director.on_gunshot(src)
	# civilians who hear a shot are alarmed (v0.6)
	if gun and incident != null:
		for c in (team_ops[2] if team_ops.size() > 2 else []):
			if not c.alive() or c.cstate == "comply":
				continue
			var dc: float = c.pos.distance_to(src.pos)
			if dc > loud or (dc > loud * 0.5 and not geom.sight_clear(src.pos, 1.6, c.pos, 1.6)):
				continue
			civ_brain.alarm(c, src.pos, "gunfire")
	for o in (near(src.pos, loud * 1.5) if city else (team_ops[1 - src.team] if src.team < 2 else [])):
		if not o.alive() or o.medic or o.mounted != null or not potential(o, src):
			continue
		var d: float = o.pos.distance_to(src.pos)
		var r: float = loud * o.hear
		if d > r:
			continue
		if d > r * 0.5 and not geom.sight_clear(src.pos, 1.6, o.pos, 1.6):
			continue
		if visible(o, src):
			continue
		var err := d * 0.08
		var p: Vector2 = src.pos + Vector2(rng.randf_range(-err, err), rng.randf_range(-err, err))
		var first: bool = o.heard.is_empty() or t - o.heard["t"] > 3.0
		o.heard = {"p": p, "t": t, "kind": kind}
		teams[o.team]["sound"] = {"p": p, "t": t, "kind": kind}
		raise_alert(o, Op.YELLOW)
		if o.dormant or not o.hot:
			o.hot = true
			o.dormant = false
			o.hot_next = t + 0.5
		if first:
			emit({"type": "heard", "id": o.id, "kind": kind, "p": p})
		_look_to_sound(o, p, gun)
		brain.on_heard(o, p, kind)


## ED07 turns the eyes to any sound within 0.3 s; without it, only gunfire, after 1 s.
func _look_to_sound(o, p: Vector2, gun: bool) -> void:
	if o.ticker.get("sweep_until", -1.0) > t:
		return
	var engaged := not visible_enemies(o).is_empty()
	var dir: float = (p - o.pos).angle()
	if o.has("ED07"):
		if not engaged:
			o.look_hint = {"dir": dir, "start": t + 0.3, "until": t + 1.8, "why": "gunfire" if gun else "sound"}
	elif gun and not engaged and o.look_hint.get("why", "") != "gunfire":
		o.look_hint = {"dir": dir, "start": t + 1.0, "until": t + 2.4, "why": "gunfire"}


## Is a bearing inside this operator's assigned sector (or has it none)?
func in_sector(m, dir: float) -> bool:
	var els: Array = teams[m.team]["elements"]
	if m.el < 0 or m.el >= els.size():
		return true
	var el: Dictionary = els[m.el]
	var sec = el["sectors"].get(m.id, null)
	if sec == null:
		return true
	return absf(angle_difference(dir, sec)) <= el["sector_half"] + deg_to_rad(20.0)


func add_stress(a, amt: float, _why: String) -> void:
	a.stress = minf(1.0, a.stress + amt)
	a.last_stress_t = t
	if a.alive():
		raise_alert(a, Op.YELLOW)
	if amt >= 0.15 and a.alive() and not a.has("WD09") and a.stress > 0.6 and rng.randf() < 0.02:
		if a.ws()["mag"] > 0 and a.action.is_empty():
			say("%s fires a stray shot" % a.id, "bad")
			stat["stray"] += 1
			_fire(a, a.muzzle_dir, 1.0, 8.0, 0.0)


# ================================================================== damage
func _hit(a, zn: Array, lat: float, u: Vector2, shooter, energy := 1.0, walls := 0) -> void:
	var zone: String = zn[0]
	if (zone == "chest" or zone == "abd") and lat > 0.7 * zn[3] and rng.randf() < 0.5:
		zone = "arm"
	var side := signf(u.cross(a.pos - shooter.pos))
	if a.alive() and (a.faction == shooter.faction or a.medic):
		stat["friendly"] += 1
		say("%s hit by friendly fire from %s" % [a.id, shooter.id], "bad")
	if a.alive() and a.civ:
		stat["civ"] = stat.get("civ", 0) + 1
		say("%s (civilian) hit by %s%s" % [a.id, shooter.id, " through %d wall%s" % [walls, "" if walls == 1 else "s"] if walls > 0 else ""], "bad")
	if not a.alive():
		emit({"type": "blood", "p": a.pos, "dir": u, "power": 0.5, "zone": "body", "id": a.id, "side": side})
		return
	if incident != null:
		incident.on_hit(a, shooter, zone, walls)
	if a.civ:
		civ_brain.alarm(a, shooter.pos, "hit")
	var from_dir: float = (shooter.pos - a.pos).angle()
	var front := absf(angle_difference(a.body_dir, from_dir)) <= deg_to_rad(60.0)
	add_stress(a, 0.25, "hit")
	# soft armour stops a pistol round to the chest from any side (v0.6)
	if zone == "chest" and a.vest and shooter.active == "pistol" and a.plates <= 0:
		a.ticker["flinch_until"] = maxf(a.ticker.get("flinch_until", -1.0), t + 0.25)
		emit({"type": "plate", "p": a.pos, "id": a.id, "dir": u})
		say("%s: vest stops %s's pistol round" % [a.id, shooter.id], "hit")
		return
	if zone == "chest" and a.plates > 0 and front:
		a.plates -= 1
		a.ticker["flinch_until"] = maxf(a.ticker.get("flinch_until", -1.0), t + 0.15)
		a.muzzle_dir += deg_to_rad(5.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		if not a.aim.is_empty():
			a.aim["settle"] = 0.0
		if shooter.aim.get("tid", "") == a.id:
			shooter.aim["plate_seen"] = true
		emit({"type": "plate", "p": a.pos, "id": a.id, "dir": u})
		say("%s: plate stops %s's round (%d left)" % [a.id, shooter.id, a.plates], "hit")
		return
	shooter.hits += 1
	stat["hits"] += 1
	var power := 1.0
	match zone:
		"head":
			power = 1.6
			_down(a, shooter, true, "head")
		"chest":
			# a chest hit no plate stopped is fatal outright one time in five (less often
			# for a round slowed by walls)
			if rng.randf() < 0.2 * energy:
				power = 1.3
				_down(a, shooter, true, "chest")
			elif rng.randf() < 0.65 * energy or a.wounds > 0:
				_down(a, shooter, false, "chest")
			else:
				_wound(a, "chest")
		"abd":
			power = 0.9
			if rng.randf() < 0.35 * energy or a.wounds > 0:
				_down(a, shooter, false, "abdomen")
			else:
				_wound(a, "abdomen")
		"arm":
			power = 0.6
			a.arm_hit = true
			say("%s hit in the arm" % a.id, "hit")
			if a.active == "rifle" and rng.randf() < 0.25 and not a.weapons["rifle"]["lost"]:
				a.weapons["rifle"]["lost"] = true
				say("%s drops the rifle" % a.id, "hit")
		"legs":
			power = 0.6
			a.leg_hit = true
			say("%s hit in the leg" % a.id, "hit")
			if rng.randf() < 0.2:
				a.stance_goal = Op.CROUCH
	a.ticker["stagger_until"] = t + 0.3
	if not a.aim.is_empty():
		a.aim["settle"] = 0.0
	emit({"type": "blood", "p": a.pos, "dir": u, "power": power, "zone": zone, "id": a.id, "side": side})


func _wound(a, where: String) -> void:
	a.wounds += 1
	say("%s wounded (%s)" % [a.id, where], "hit")


func _down(a, shooter, killed: bool, where: String) -> void:
	a.state = "dead" if killed else "down"
	a.stance = Op.DOWN
	a.stance_goal = Op.DOWN
	a.vel = Vector2.ZERO
	a.action = {}
	a.aim = {}
	a.sidestep = {}
	a.dormant = false
	stop(a)
	a.ticker["down_t"] = t
	a.ticker["down_where"] = where
	a.ticker["down_by"] = shooter.id
	a.ticker["down_by_name"] = shooter.name
	a.ticker["down_by_fac"] = shooter.faction
	shooter.kills += 1
	say("%s %s (%s, by %s)" % [a.id, "KILLED" if killed else "DOWN", where, shooter.id], "kill")
	emit({"type": "down", "id": a.id, "killed": killed, "p": a.pos})
	if killed:
		_record_death(a, "killed")
	if incident != null:
		incident.on_down(a, shooter, killed)
	if not a.civ:
		for m in mates_near(a, 25.0):
			if geom.sight_clear(m.pos, m.eye(), a.pos, 0.3):
				add_stress(m, 0.10, "friend down")
	# civilians who see someone fall
	if incident != null:
		for c in _near_fast(a.pos, 15.0).duplicate():
			if c.civ and c.alive() and c != a and geom.sight_clear(c.pos, c.eye(), a.pos, 0.5):
				civ_brain.alarm(c, shooter.pos, "fall")
	if director != null:
		director.on_down(a, shooter, killed)


## A line in the ledger of the dead.
func _record_death(a, cause: String) -> void:
	var fac: Dictionary = factions[a.faction] if a.faction < factions.size() else {}
	var kf: int = a.ticker.get("down_by_fac", -1)
	var place: String = ""
	if director != null and director.has_method("place_name"):
		place = director.place_name(a.pos)
	else:
		var rm: String = level.room_at(a.pos)
		place = level.rooms[rm]["title"].capitalize() if level.rooms.has(rm) and not level.is_exterior(rm) else "Outside"
	deaths.append({"t": t, "id": a.id, "name": a.name, "rank": a.rank, "faction": a.faction,
		"fac_name": fac.get("name", "?"), "medic": a.medic, "cause": cause,
		"where": a.ticker.get("down_where", ""), "by": a.ticker.get("down_by", ""),
		"by_name": a.ticker.get("down_by_name", ""), "by_fac": kf,
		"by_fac_name": factions[kf]["name"] if kf >= 0 and kf < factions.size() else "", "place": place,
		"after": t - a.ticker.get("down_t", t)})
	if deaths.size() > DEATHS_MAX:
		deaths = deaths.slice(100)
		deaths_base += 100


# ================================================================== melee
## Two hostiles in body contact: whoever reacts first kills the other. Reaction comes
## from the echelon's recognition speed, habits and stress; it is half again slower
## against someone not yet recognized, and slower still in green.
const MELEE_D := 0.8


func _melee() -> void:
	for o in ops:
		if not o.alive() or o.medic or o.mounted != null or (dormancy and not o.hot):
			continue
		var pair: Array = _near_fast(o.pos, MELEE_D).duplicate() if _melee_any(o) else []
		for e in pair:
			if e == o or not e.alive() or e.medic:
				continue
			if e.gid < o.gid and (e.hot or not dormancy):
				continue
			if e.pos.distance_squared_to(o.pos) > MELEE_D * MELEE_D:
				continue
			var ho: bool = hostile(o, e)
			var he: bool = hostile(e, o)
			if not ho and not he:
				continue
			if o.ticker.get("melee_until", -1.0) > t or e.ticker.get("melee_until", -1.0) > t:
				continue
			var ro: float = _react(o, e) if ho else INF
			var re: float = _react(e, o) if he else INF
			var win = o if ro <= re else e
			var lose = e if win == o else o
			win.ticker["melee_until"] = t + 0.8
			lose.ticker["melee_until"] = t + 0.8
			start_action(win, "melee", 0.6)
			win.armed_t = t
			raise_alert(win, Op.RED)
			say("%s kills %s hand to hand (%.2f s against %.2f s)" % [win.id, lose.id, minf(ro, re), maxf(ro, re) if maxf(ro, re) < INF else 0.0], "kill")
			emit({"type": "blood", "p": lose.pos, "dir": (lose.pos - win.pos).normalized(), "power": 0.8, "zone": "chest", "id": lose.id, "side": 1.0})
			_down(lose, win, true, "melee")
			if not o.alive():
				break


## Anyone at all within contact distance (cheap test before the real one).
func _melee_any(o) -> bool:
	var c := _cell(o.pos)
	var i: int = _ghead[c]
	var n := 0
	while i >= 0:
		n += 1
		if n > 1:
			return true
		i = _gnext[i]
	# alone in the cell: only a neighbour cell can hold someone within reach
	var fx := fposmod(o.pos.x, GRID)
	var fy := fposmod(o.pos.y, GRID)
	return fx < MELEE_D or fy < MELEE_D or fx > GRID - MELEE_D or fy > GRID - MELEE_D


func _react(a, b) -> float:
	var r: float = a.ech["t_rec0"] * a.m_h * (1.0 + 0.5 * a.stress * (1.0 - a.ech["resist"]))
	if a.rec.get(b.id, 0.0) < 1.0:
		r *= 1.5
	if a.alert == Op.GREEN:
		r *= 1.3
	if not a.action.is_empty():
		r += 0.25
	return maxf(0.05, r + rng.randfn(0.0, 0.06))


# ================================================================== per-tick integration
func _integrate(o) -> void:
	if brain.fine:
		var t0 := Time.get_ticks_usec()
		_integrate2(o)
		prof["int_all"] = prof.get("int_all", 0) + Time.get_ticks_usec() - t0
		return
	_integrate2(o)


func _integrate2(o) -> void:
	_relax(o)
	if not o.action.is_empty():
		o.action["left"] -= DT
		if o.action["left"] <= 0.0:
			_finish_action(o)
	o.stance = o.stance_goal
	var eye_rate := deg_to_rad(400.0) * DT
	var body_rate: float = deg_to_rad(o.ech["turn"]) * DT
	o.look_dir = rotate_toward(o.look_dir, o.look_goal, eye_rate)
	_move(o)
	if not o.aim.is_empty():
		o.body_dir = rotate_toward(o.body_dir, o.muzzle_dir, body_rate)
	elif o.vel.length() > 0.2:
		o.body_dir = rotate_toward(o.body_dir, o.vel.angle(), body_rate)
	elif absf(angle_difference(o.body_dir, o.look_dir)) > deg_to_rad(50.0):
		o.body_dir = rotate_toward(o.body_dir, o.look_dir, body_rate)
	if o.aim.is_empty():
		var target_dir: float = o.look_dir if o.has("ED01") else o.body_dir
		o.muzzle_dir = rotate_toward(o.muzzle_dir, target_dir, body_rate)
		if t - o.last_aim_t > 2.0:
			o.weapon_up = false
	_aim_update(o)
	if o.ticker.get("in_cover_check", -1.0) < t:
		o.ticker["in_cover_check"] = t + 0.25
		if geom.dist_to_kinds(o.pos, [Geom.COVER, Geom.WALL], 1.3) < 1.25:
			o.ticker["in_cover_t"] = t


func _passive(o) -> void:
	if o.recoil > 0.01:
		o.recoil *= exp(-DT / o.ech["tr"])
	if o.dormant and o.stress <= 0.0:
		return
	if not o.alive():
		if o.state == "down" and not o.carried and t - o.ticker.get("down_t", t) >= BLEED_OUT:
			o.state = "dead"
			say("%s dies of wounds" % o.id, "kill")
			emit({"type": "bled_out", "id": o.id, "p": o.pos})
			_record_death(o, "died of wounds")
			if incident != null:
				incident.on_bled_out(o)
			if director != null:
				director.on_bled_out(o)
		return
	if t - o.last_stress_t > 1.0 and t - o.last_enemy_seen_t > 1.0:
		# never below the baseline an officer brings in (trauma, fatigue)
		o.stress = maxf(minf(o.stress, float(o.ech.get("stress0", 0.0))), o.stress - 0.1 * DT)


func _check_end() -> void:
	var alive := [0, 0]
	for o in ops:
		if o.team < 2 and o.fighting():
			alive[o.team] += 1
	# under police rules the operation goes on until the people who gave up are cuffed
	if alive[1] == 0 and alive[0] > 0 and t < time_limit and police_rules():
		var waiting := false
		for o2 in ops:
			if o2.complying and o2.alive() and not o2.arrested:
				waiting = true
				break
		if waiting:
			if _end_wait < 0.0:
				_end_wait = t + 60.0
			if t < _end_wait:
				return
	if alive[0] == 0 or alive[1] == 0 or t >= time_limit:
		over = true
		if alive[0] == 0 and alive[1] == 0:
			winner = 2
		elif alive[0] == 0:
			winner = 1
		elif alive[1] == 0:
			winner = 0
		else:
			winner = 2
		var names := ["TEAM A WINS", "TEAM B WINS", "DRAW"]
		say("%s at %.1f s. %d shots, %d hits." % [names[winner], t, stat["shots"], stat["hits"]], "end")
		for o in ops:
			if o.civ:
				continue
			say("  %s %s: %d shots, %d hits, %d down; %s" % [o.id, o.ech["name"], o.shots, o.hits, o.kills,
				("ARRESTED" if o.arrested else ("GAVE UP" if o.complying else o.state.to_upper()))], "end")
