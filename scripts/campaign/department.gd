extends RefCounted
## The department (v0.5): persistent officers and their files, saved as versioned JSON.
##
## Every officer is rolled once, at hire: stats (form, jitter and quirks of the Patrol
## echelon), habits, personality, Judgment, Temper and Integrity. The roll travels with
## the record into every operation, and what happens there comes back: experience,
## wounds and weeks out, trauma, rounds fired, and a line in their file for every
## finding the incident record ties to them.
##
## One save slot (ironman): the department is saved after every operation and every week.

const Habits = preload("res://scripts/data/habits.gd")
const Names = preload("res://scripts/data/names.gd")

const VERSION := 1
const SAVE_PATH := "user://department.json"
## Experience points needed for tiers 1-5 (Green, Blooded, Seasoned, Veteran, Exceptional).
const XP_TIERS := [0, 6, 18, 40, 80]
const RANKS := ["Officer", "Corporal", "Sergeant", "Lieutenant", "Captain"]
## Personality traits and the bad habits each brings (habits.gd, trait habits).
const PERSONALITY := {"Aggression": ["BH11", "BH12"], "Anxiety": ["BH13", "BH14"], "Ego": ["BH15", "BH16"],
	"Complacency": ["BH17", "BH18"], "Rigidity": ["BH19", "BH20"]}

var seed_val := 1
var week := 1
var serial := 0
var officers: Array = []      # records (see _new_record)
var history: Array = []       # [{week, op, map, summary, lines}] one per operation
var notes: Array = []         # [{week, text}] department log
var ops_run := 0
var bodycams := false
var rng := RandomNumberGenerator.new()
var names


# ================================================================== founding and hiring
## A new department: a sergeant, a corporal and ten officers, all rolled from the seed.
func found(seed_v: int, n := 12) -> void:
	seed_val = seed_v
	rng.seed = seed_v
	names = Names.new(seed_v * 7 + 3)
	week = 1
	serial = 0
	officers = []
	history = []
	notes = []
	ops_run = 0
	for k in n:
		var rank := "Officer"
		var xp := 0
		if k == 0:
			rank = "Sergeant"
			xp = 20
		elif k == 1:
			rank = "Corporal"
			xp = 8
		elif rng.randf() < 0.25:
			xp = 6
		hire(rank, xp)
	note("Department founded: %d officers." % officers.size())


## Hire one officer of the Patrol echelon. A lateral hire arrives with experience.
func hire(rank := "Officer", xp := 0, lateral := false) -> Dictionary:
	if names == null:
		names = Names.new(seed_val * 7 + 3 + serial)
	serial += 1
	var r := {"id": "PC-%04d" % serial, "badge": 1000 + serial * 7 + rng.randi_range(0, 6), "name": names.diverse_name(0.3),
		"rank": rank, "echelon": "patrol", "hired_week": week, "status": "active", "out_until": 0,
		"ech": Habits.vary(Habits.ECHELONS["patrol"], rng), "good": [], "bad_traits": [], "traits": [],
		"personality": "", "judgment": _trait(50.0, 12.0), "temper": _trait(40.0, 15.0), "integrity": _trait(65.0, 15.0),
		"exp": 1, "xp": 0, "trauma": 0.0, "ops": 0, "shots": 0, "hits": 0, "kills": 0, "civ_hits": 0,
		"wounded": 0, "arrests": 0, "file": [], "lateral": lateral}
	# habits: the academy's twelve, sometimes one swapped for another Regular habit
	var good: Array = Habits.preset_good("patrol")
	if rng.randf() < 0.5:
		var extra: Array = Habits.preset_good("regular").filter(func(g): return not good.has(g))
		if not extra.is_empty():
			good.remove_at(rng.randi() % good.size())
			good.append(extra[rng.randi() % extra.size()])
	if rank == "Sergeant" or rank == "Corporal" or lateral:
		var more: Array = Habits.preset_good("regular").filter(func(g): return not good.has(g))
		for k in (4 if rank == "Sergeant" else 2):
			if more.is_empty():
				break
			good.append(more.pop_at(rng.randi() % more.size()))
	good.sort()
	r["good"] = good
	# personality: some recruits bring a trait and the bad habits that come with it
	if rng.randf() < 0.4:
		var keys: Array = PERSONALITY.keys()
		var pk: String = keys[rng.randi() % keys.size()]
		r["personality"] = pk
		var bh: Array = PERSONALITY[pk]
		r["bad_traits"] = bh.duplicate() if rng.randf() < 0.3 else [bh[rng.randi() % 2]]
	if rng.randf() < 0.06:
		r["traits"].append("TR01")
	elif rng.randf() < 0.05:
		r["traits"].append("TR02")
	r["xp"] = xp
	r["exp"] = tier_for(xp)
	r["file"].append({"week": week, "text": "Hired as %s%s." % [rank.to_lower(), " (lateral)" if lateral else ""]})
	officers.append(r)
	return r


func _trait(mean: float, sd: float) -> int:
	return clampi(int(round(rng.randfn(mean, sd))), 10, 95)


static func tier_for(xp: int) -> int:
	var tier := 1
	for k in range(1, XP_TIERS.size()):
		if xp >= XP_TIERS[k]:
			tier = k + 1
	return tier


func get_officer(oid: String) -> Dictionary:
	for r in officers:
		if r["id"] == oid:
			return r
	return {}


func available() -> Array:
	return officers.filter(func(r): return r["status"] == "active")


func note(text: String) -> void:
	notes.append({"week": week, "text": text})


# ================================================================== into an operation
## The configuration for one officer in team A's slot `slot` (spawn from the map).
func to_cfg(r: Dictionary, slot: int, level, alert := 1) -> Dictionary:
	var id := "A%d" % (slot + 1)
	var good := {}
	for g in r["good"]:
		good[g] = true
	var bad := {}
	for b in Habits.stress_bad_ids():
		bad[b] = true
	for b2 in r["bad_traits"]:
		bad[b2] = true
	var traits := {}
	for tr in r["traits"]:
		traits[tr] = true
	var ech: Dictionary = (r["ech"] as Dictionary).duplicate(true)
	# trauma raises the stress an officer brings into every operation
	ech["stress0"] = minf(0.3, float(r["trauma"]) * 0.015)
	return {"id": id, "team": 0, "slot": slot, "echelon": r["echelon"], "good": good, "bad": bad,
		"plates": 0, "exp": int(r["exp"]), "traits": traits, "pos": level.spawns[id]["p"], "face": level.spawns[id]["face"],
		"enabled": true, "alert": alert, "ech": ech, "officer_id": r["id"], "name": r["name"], "rank": r["rank"],
		"vest": true, "bodycam": bodycams, "judgment": int(r["judgment"]), "temper": int(r["temper"]),
		"integrity": int(r["integrity"])}


# ================================================================== back from an operation
## Write what happened to each department officer back into their record, file the
## incident summary, and save. Returns readable lines for the debrief.
func apply_result(w, map_name: String) -> Array:
	ops_run += 1
	var lines: Array = []
	var inc = w.incident
	var data: Dictionary = inc.to_data() if inc != null else {}
	var per_op: Dictionary = data.get("per_op", {})
	var officers_dead := 0
	for o in w.ops:
		if o.officer_id != "" and o.state == "dead":
			officers_dead += 1
	for o in w.ops:
		if o.officer_id == "":
			continue
		var r := get_officer(o.officer_id)
		if r.is_empty():
			continue
		var po: Dictionary = per_op.get(o.id, {})
		r["ops"] += 1
		r["shots"] += o.shots
		r["hits"] += int(po.get("hits_threat", o.hits))
		r["kills"] += o.kills
		r["civ_hits"] += int(po.get("hits_civ", 0))
		var arrests := 0
		for a in data.get("arrests", []):
			if a["by"] == o.id:
				arrests += 1
		r["arrests"] += arrests
		# experience: contact, being under fire, hits on a threat, arrests, coming back hurt
		var gain := 0
		var contact := false
		for pid in o.first_rec:
			var p = w.by_id.get(pid, null)
			if p != null and not p.civ:
				contact = true
				break
		if contact:
			gain += 2
		if o.last_stress_t > 0.0:
			gain += 2
		gain += mini(3, int(po.get("hits_threat", 0)))
		gain += arrests
		var hurt: bool = o.wounds > 0 or o.arm_hit or o.leg_hit or o.state == "down"
		if hurt and o.state != "dead":
			gain += 1
		var old_tier: int = r["exp"]
		r["xp"] += gain
		r["exp"] = tier_for(r["xp"])
		var who: String = "%s %s" % [r["rank"], r["name"]]
		var opline := "Operation %d (%s): %d rounds, %d hit a threat%s." % [ops_run, map_name, o.shots, int(po.get("hits_threat", 0)),
			(", %d arrest%s" % [arrests, "" if arrests == 1 else "s"]) if arrests > 0 else ""]
		r["file"].append({"week": week, "text": opline})
		if r["exp"] > old_tier:
			r["file"].append({"week": week, "text": "Now %s (experience tier %d)." % [Habits.EXP_NAMES[r["exp"]], r["exp"]]})
			lines.append("%s is now %s (tier %d)." % [who, Habits.EXP_NAMES[r["exp"]], r["exp"]])
		# trauma: taking a life, being hit, losing a partner, hitting a civilian
		var tr := 0.0
		if o.kills > 0:
			tr += 2.0
		if hurt:
			tr += 2.0
		if officers_dead > (1 if o.state == "dead" else 0):
			tr += 1.0
		if int(po.get("hits_civ", 0)) > 0:
			tr += 3.0
		r["trauma"] = float(r["trauma"]) + tr
		# injuries and deaths
		if o.state == "dead":
			r["status"] = "dead"
			r["file"].append({"week": week, "text": "Killed in operation %d, %s." % [ops_run, map_name]})
			lines.append("%s was killed." % who)
			note("%s killed in operation %d." % [who, ops_run])
		elif o.state == "down":
			r["status"] = "injured"
			r["out_until"] = week + 8 + rng.randi_range(0, 6)
			r["wounded"] += 1
			r["file"].append({"week": week, "text": "Seriously wounded; out until week %d." % r["out_until"]})
			lines.append("%s is seriously wounded: out until week %d." % [who, r["out_until"]])
		elif hurt:
			r["status"] = "injured"
			r["out_until"] = week + 2 + rng.randi_range(0, 3)
			r["wounded"] += 1
			r["file"].append({"week": week, "text": "Wounded; out until week %d." % r["out_until"]})
			lines.append("%s is wounded: out until week %d." % [who, r["out_until"]])
		# findings that name this officer go into their file
		for f in data.get("findings", []):
			if f["by"] == o.id and f["kind"] in ["civilian_hit_by_police", "excessive_force", "misjudgment", "friendly_fire", "jumpy_fire"]:
				r["file"].append({"week": week, "text": "Finding: %s (%s; evidence: %s)." % [f["text"], f["place"], f["strength"]]})
	var s: Dictionary = data.get("summary", {})
	history.append({"week": week, "op": ops_run, "map": map_name, "seed": w.seed_used, "summary": s.duplicate(true)})
	if history.size() > 200:
		history = history.slice(history.size() - 200)
	note("Operation %d at %s: %d civilians hit, %d suspects down, %d arrested, %d findings." % [ops_run, map_name,
		int(s.get("civ_hit", 0)), int(s.get("suspects_down", 0)), int(s.get("arrested", 0)), int(s.get("findings", 0))])
	return lines


## A week passes: wounds heal, trauma eases a little.
func next_week() -> Array:
	week += 1
	var lines: Array = []
	for r in officers:
		if r["status"] == "injured" and int(r["out_until"]) <= week:
			r["status"] = "active"
			r["file"].append({"week": week, "text": "Back on duty."})
			lines.append("%s %s is back on duty." % [r["rank"], r["name"]])
		if r["status"] != "dead":
			r["trauma"] = maxf(0.0, float(r["trauma"]) - 0.5)
	note("Week %d." % week)
	return lines


# ================================================================== saving
func to_data() -> Dictionary:
	return {"version": VERSION, "seed": seed_val, "week": week, "serial": serial, "ops_run": ops_run,
		"bodycams": bodycams, "rng_state": str(rng.state), "officers": officers.duplicate(true),
		"history": history.duplicate(true), "notes": notes.duplicate(true)}


func from_data(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION:
		return false
	seed_val = int(d["seed"])
	week = int(d["week"])
	serial = int(d["serial"])
	ops_run = int(d["ops_run"])
	bodycams = bool(d.get("bodycams", false))
	rng.seed = seed_val
	rng.state = String(d["rng_state"]).to_int()
	names = Names.new(seed_val * 7 + 3 + serial)
	officers = []
	for r0 in d["officers"]:
		var r: Dictionary = r0
		# JSON has no integers: restore them
		for k in ["badge", "hired_week", "out_until", "judgment", "temper", "integrity", "exp", "xp", "ops", "shots",
				"hits", "kills", "civ_hits", "wounded", "arrests"]:
			r[k] = int(r.get(k, 0))
		r["trauma"] = float(r.get("trauma", 0.0))
		for fe in r["file"]:
			fe["week"] = int(fe["week"])
		officers.append(r)
	history = d.get("history", [])
	notes = d.get("notes", [])
	for n in notes:
		n["week"] = int(n["week"])
	return true


func save(path := SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_data(), "\t"))
	f.close()
	return true


static func load_from(path := SAVE_PATH):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var dep = load("res://scripts/campaign/department.gd").new()
	if not dep.from_data(d):
		return null
	return dep
