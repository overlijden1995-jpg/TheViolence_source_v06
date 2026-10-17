extends SceneTree
## v0.6 gate: operations with civilians under police rules run clean, and a better
## trained team hurts fewer civilians. The same maps, seeds, suspects and civilians are
## run twice, once with team A as Patrol officers and once as Police tactical.
##   godot --headless --path . -s res://tests/civ_test.gd -- --n=40 [--civ=8] [--map=5] [--night] [--only=patrol]
const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Operation = preload("res://scripts/campaign/operation.gd")


func _init() -> void:
	var n := 40
	var n_civ := 8
	var only_map := -1
	var night := false
	var only := ""
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--civ="):
			n_civ = int(a.trim_prefix("--civ="))
		elif a.begins_with("--map="):
			only_map = Maps.index_of(a.trim_prefix("--map="))
		elif a == "--night":
			night = true
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a == "--v":
			verbose = true
	var navs := {}
	var totals := {}
	var t0 := Time.get_ticks_msec()
	var echs: Array = ["patrol", "police"] if only == "" else [only]
	for ech in echs:
		totals[ech] = {"ops": 0, "civ_hit": 0, "civ_hit_police": 0, "civ_killed": 0, "misjudged": 0, "excessive": 0,
			"surrendered": 0, "arrested": 0, "officers_down": 0, "suspects_down": 0, "timeouts": 0, "walls": 0,
			"findings": 0, "video": 0, "won": 0, "sim": 0.0, "ff": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060
	var plans: Array = []
	for k in n:
		# maps 0 (the test range) has no building worth raiding
		var mi: int = only_map if only_map >= 0 else rng.randi_range(1, Maps.count() - 1)
		plans.append({"map": mi, "na": rng.randi_range(4, 8), "nb": rng.randi_range(2, 6), "seed": 8000 + k * 13,
			"bmix": [rng.randf(), rng.randf(), rng.randf(), rng.randf(), rng.randf(), rng.randf()]})
	for ech in echs:
		for k in n:
			var pl: Dictionary = plans[k]
			var mi: int = pl["map"]
			var lv = Maps.get_level(mi)
			if not navs.has(mi):
				var nv = Nav.new()
				nv.build(lv)
				navs[mi] = nv
			var nav = navs[mi]
			var cfgs: Array = []
			for team in 2:
				for slot in 20:
					var id := "%s%d" % ["AB"[team], slot + 1]
					var e: String = ech
					if team == 1:
						var r: float = pl["bmix"][slot % 6]
						e = "untrained" if r < 0.5 else ("militia" if r < 0.9 else "regular")
					var good := {}
					for g in Habits.preset_good(e):
						good[g] = true
					var bad := {}
					for b in Habits.stress_bad_ids():
						bad[b] = true
					cfgs.append({"id": id, "team": team, "slot": slot, "echelon": e, "good": good, "bad": bad,
						"traits": {}, "exp": Habits.PRESET_EXP[e], "plates": Habits.PRESET_PLATES[e],
						"pos": lv.spawns[id]["p"], "face": lv.spawns[id]["face"],
						"enabled": slot < (pl["na"] if team == 0 else pl["nb"]), "alert": 1 if team == 0 else 0})
			var spec := {"civilians": n_civ, "seed": pl["seed"]}
			var all: Array = Operation.build(cfgs, lv, nav, spec)
			var w = World.new()
			w.keep_events = false
			w.setup(lv, nav, all, ["assault", "hold"], pl["seed"], [1, 0], {"police_rules": true, "night": night})
			while not w.over:
				w.step()
			var s: Dictionary = w.incident.summary()
			var tt: Dictionary = totals[ech]
			tt["ops"] += 1
			for key in ["civ_hit", "civ_hit_police", "civ_killed", "misjudged", "excessive", "surrendered", "arrested",
					"officers_down", "suspects_down", "findings"]:
				tt[key] += int(s[key])
			tt["walls"] += int(s["through_walls"])
			for pid in w.incident.per_op:
				var po: Dictionary = w.incident.per_op[pid]
				if po["role"] == "officer":
					tt["ff"] += int(po["hits_friend"])
			tt["video"] += int(s["strength"].get("video", 0))
			tt["won"] += 1 if w.winner == 0 else 0
			tt["timeouts"] += 1 if w.t >= w.time_limit else 0
			tt["sim"] += w.t
			print("  %-7s %2d map %02d %dv%d  %5.1f s  %s  civ hit %d (police %d) killed %d  misjudged %d  excessive %d  gave up %d  cuffed %d  officers down %d" % [
				ech, k, mi, pl["na"], pl["nb"], w.t, ["A", "B", "draw"][w.winner], s["civ_hit"], s["civ_hit_police"], s["civ_killed"],
				s["misjudged"], s["excessive"], s["surrendered"], s["arrested"], s["officers_down"]])
			if verbose:
				for ln in s["lines"]:
					print("        ", ln["text"])
			w.dispose()
	print("civ test: %d operations per echelon, %d civilians each%s, %d ms" % [n, n_civ, " (night)" if night else "", Time.get_ticks_msec() - t0])
	for ech in echs:
		var tt: Dictionary = totals[ech]
		print("  %-7s won %d/%d  civilians hit %d (by police %d) killed %d  misjudged %d  excessive %d  gave up %d  cuffed %d  officers down %d  suspects down %d  rounds through walls %d  findings %d (video %d)  friendly hits %d  timeouts %d" % [
			ech, tt["won"], tt["ops"], tt["civ_hit"], tt["civ_hit_police"], tt["civ_killed"], tt["misjudged"], tt["excessive"],
			tt["surrendered"], tt["arrested"], tt["officers_down"], tt["suspects_down"], tt["walls"], tt["findings"], tt["video"], tt["ff"], tt["timeouts"]])
	if echs.size() == 2:
		var a: int = totals["patrol"]["civ_hit_police"]
		var b: int = totals["police"]["civ_hit_police"]
		print("GATE civilians hit by police: patrol %d vs police tactical %d -> %s" % [a, b, "PASS" if b < a else "FAIL"])
	quit()
