extends SceneTree
## v0.5 gate: persistent officers. A department is founded, saved and loaded back
## unchanged; an operation's experience, wounds and file entries are written back and
## survive a save; an injured officer is not available until healed; and an operation
## run from a reloaded save replays exactly.
##   godot --headless --path . -s res://tests/dept_test.gd
const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Department = preload("res://scripts/campaign/department.gd")
const Operation = preload("res://scripts/campaign/operation.gd")

const PATH := "user://dept_test.json"
var problems := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		problems += 1


func _suspects(lv, n: int) -> Array:
	var out: Array = []
	for slot in 20:
		var id := "B%d" % (slot + 1)
		var e: String = ["untrained", "militia", "untrained", "regular"][slot % 4]
		var good := {}
		for g in Habits.preset_good(e):
			good[g] = true
		var bad := {}
		for b in Habits.stress_bad_ids():
			bad[b] = true
		out.append({"id": id, "team": 1, "slot": slot, "echelon": e, "good": good, "bad": bad, "traits": {}, "exp": 1,
			"plates": 0, "pos": lv.spawns[id]["p"], "face": lv.spawns[id]["face"], "enabled": slot < n, "alert": 0})
	return out


func _run(dep, lv, nav, seed_val: int):
	var team: Array = dep.available().slice(0, 6)
	var cfgs: Array = Operation.build(_suspects(lv, 4), lv, nav, {"officers": team, "civilians": 6, "seed": seed_val}, dep)
	var w = World.new()
	w.keep_events = false
	w.setup(lv, nav, cfgs, ["assault", "hold"], seed_val, [1, 0], {"police_rules": true})
	while not w.over:
		w.step()
	return w


func _fingerprint(w) -> String:
	var parts: Array = ["%.3f" % w.t, str(w.winner), str(w.stat)]
	for o in w.ops:
		parts.append("%s %s %.3f,%.3f %d %d %d" % [o.id, o.state, o.pos.x, o.pos.y, o.shots, o.hits, o.wounds])
	return "|".join(parts)


func _init() -> void:
	var lv = Maps.get_level(5)
	var nav = Nav.new()
	nav.build(lv)
	print("department test (map %s)" % lv.map_name)
	# founding, save and load
	var dep = Department.new()
	dep.found(77)
	_check(dep.officers.size() == 12, "founded with 12 officers")
	var a: Dictionary = dep.officers[2]
	_check(a["ech"].has("form") and a["echelon"] == "patrol", "stats rolled at hire (Patrol echelon, form %+.0f%%)" % ((1.0 - float(a["ech"]["form"])) * 100.0))
	_check(dep.save(PATH), "saved")
	var dep2 = Department.load_from(PATH)
	_check(dep2 != null, "loaded")
	_check(JSON.stringify(dep2.to_data()) == JSON.stringify(Department.load_from(PATH).to_data()), "load is stable")
	_check(JSON.stringify(dep2.officers[2]["ech"]) == JSON.stringify(JSON.parse_string(JSON.stringify(a["ech"]))), "an officer's roll survives a save")
	# the roll travels into the operation
	var cfg: Dictionary = dep2.to_cfg(dep2.officers[2], 0, lv)
	var w0 = World.new()
	w0.setup(lv, nav, [cfg], ["assault", "hold"], 5, [1, 0], {"police_rules": true})
	var o0 = w0.ops[0]
	_check(is_equal_approx(float(o0.ech["t_rec0"]), float(dep2.officers[2]["ech"]["t_rec0"])), "the operation uses the record's roll, not a new one")
	_check(o0.judges and o0.vest and o0.officer_id == dep2.officers[2]["id"], "officer judges, wears a vest, knows their record")
	w0.dispose()
	# operation 1, written back
	var before := {}
	for r in dep2.officers:
		before[r["id"]] = [int(r["xp"]), r["status"], r["file"].size()]
	var w1 = _run(dep2, lv, nav, 4101)
	var lines: Array = dep2.apply_result(w1, lv.map_name)
	for ln in lines:
		print("      ", ln)
	var gained := 0
	var hurt := 0
	var filed := 0
	for r in dep2.officers:
		var b: Array = before[r["id"]]
		if int(r["xp"]) > b[0]:
			gained += 1
		if r["status"] != "active":
			hurt += 1
		if r["file"].size() > b[2]:
			filed += 1
	_check(filed == 6, "all six officers sent have a new file entry (%d)" % filed)
	_check(gained > 0, "experience gained by %d officer(s)" % gained)
	print("      %d officer(s) injured or killed" % hurt)
	w1.dispose()
	_check(dep2.save(PATH), "saved after the operation")
	var dep3 = Department.load_from(PATH)
	var same := true
	for i in dep2.officers.size():
		var r2: Dictionary = dep2.officers[i]
		var r3: Dictionary = dep3.officers[i]
		if int(r2["xp"]) != int(r3["xp"]) or r2["status"] != r3["status"] or int(r2["out_until"]) != int(r3["out_until"]) \
				or r2["file"].size() != r3["file"].size() or int(r2["exp"]) != int(r3["exp"]):
			same = false
	_check(same, "experience, wounds and files survive the save")
	var injured: Array = dep3.officers.filter(func(r): return r["status"] == "injured")
	if not injured.is_empty():
		var who: Dictionary = injured[0]
		_check(not dep3.available().has(who), "an injured officer is not available")
		var guard := 0
		while who["status"] == "injured" and guard < 30:
			dep3.next_week()
			guard += 1
		_check(who["status"] == "active", "healed after %d week(s)" % guard)
		dep3 = Department.load_from(PATH)
	# replay: operation 2 from the saved department, twice, from two fresh loads
	var da = Department.load_from(PATH)
	var db = Department.load_from(PATH)
	var wa = _run(da, lv, nav, 4202)
	var wb = _run(db, lv, nav, 4202)
	_check(_fingerprint(wa) == _fingerprint(wb), "an operation from a reloaded save replays exactly (%.1f s, %s)" % [wa.t, ["A", "B", "draw"][wa.winner]])
	_check(JSON.stringify(wa.incident.summary()) == JSON.stringify(wb.incident.summary()), "and so does its incident record")
	da.apply_result(wa, lv.map_name)
	db.apply_result(wb, lv.map_name)
	_check(JSON.stringify(da.to_data()) == JSON.stringify(db.to_data()), "and the department after it")
	wa.dispose()
	wb.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("problems: %d" % problems)
	quit()
