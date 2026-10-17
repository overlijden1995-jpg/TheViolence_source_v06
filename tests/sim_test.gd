extends SceneTree
## Headless batch test: runs seeded matches for several matchups and prints outcomes.
##   godot --headless --path . -s res://tests/sim_test.gd
const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")

func cfg(id: String, team: int, slot: int, ech: String, lv, extra_bad := []) -> Dictionary:
	var good := {}
	for g in Habits.preset_good(ech):
		good[g] = true
	var bad := {}
	for b in Habits.stress_bad_ids():
		bad[b] = true
	for b in extra_bad:
		bad[b] = true
	return {"id": id, "team": team, "slot": slot, "echelon": ech, "good": good, "bad": bad,
		"plates": Habits.PRESET_PLATES[ech], "pos": lv.spawns[id]["p"], "face": lv.spawns[id]["face"], "enabled": true}

func run(lv, nav, a: String, b: String, n: int, verbose := false, extra_a := [], extra_b := []) -> void:
	var wins := [0, 0, 0]
	var dur := 0.0
	var t0 := Time.get_ticks_msec()
	for s in n:
		var w = World.new()
		w.keep_events = false
		var cfgs := [cfg("A1", 0, 0, a, lv, extra_a), cfg("A2", 0, 1, a, lv, extra_a), cfg("B1", 1, 0, b, lv, extra_b), cfg("B2", 1, 1, b, lv, extra_b)]
		w.setup(lv, nav, cfgs, ["assault", "hold"], 1000 + s)
		while not w.over:
			w.step()
		wins[w.winner] += 1
		dur += w.t
		if verbose and s == 0:
			for l in w.log_lines:
				print(l["text"])
		w.dispose()
	print("%-10s (assault) vs %-10s (hold): A %d  B %d  draw %d   mean %.1f s   [%d ms]" % [a, b, wins[0], wins[1], wins[2], dur / n, Time.get_ticks_msec() - t0])

func _init() -> void:
	var map_i := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_i = Maps.index_of(a.trim_prefix("--map="))
	var lv = Maps.get_level(map_i)
	var nav = Nav.new()
	nav.build(lv)
	var args := OS.get_cmdline_user_args()
	var n := 20
	for a in args:
		if a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
	if "--ablation" in args:
		_ablation(lv, nav, n)
		quit()
		return
	if "--verbose" in args:
		run(lv, nav, "sof", "untrained", 1, true)
		quit()
		return
	run(lv, nav, "sof", "untrained", n)
	run(lv, nav, "untrained", "sof", n)
	run(lv, nav, "regular", "militia", n)
	run(lv, nav, "militia", "regular", n)
	run(lv, nav, "regular", "regular", n)
	quit()


## The bible's thesis check: identical special-operations reflexes, 40 habits vs none.
func _ablation(lv, nav, n: int) -> void:
	for roles in [["assault", "hold"], ["hold", "assault"]]:
		for bonus in [true, false]:
			var wins := [0, 0, 0]
			for s in n:
				var w = World.new()
				w.keep_events = false
				var cfgs: Array = []
				for id in ["A1", "A2", "B1", "B2"]:
					var c := cfg(id, 0 if id.begins_with("A") else 1, int(id[1]) - 1, "sof", lv)
					if id.begins_with("B"):
						c["good"] = {}
					cfgs.append(c)
				w.setup(lv, nav, cfgs, roles, 3000 + s)
				if not bonus:
					for o in w.ops:
						o.ticker["no_bonus"] = true
				while not w.over:
					if not bonus:
						for o in w.ops:
							o.m_h = 1.0
					w.step()
				wins[w.winner] += 1
				w.dispose()
			print("40 habits (A, %s) vs 0 habits (B, %s), speed bonus %s: A %d  B %d  draw %d" % [roles[0], roles[1], "on" if bonus else "OFF", wins[0], wins[1], wins[2]])
