extends SceneTree
## Fuzz: random maps, team sizes (1-20 each), echelons, good/bad habit subsets, traits,
## Experience tiers, placements and postures. Any script error shows up in the output;
## the summary checks that every habit was exercised and every match ended.
##   godot --headless --path . -s res://tests/fuzz_test.gd -- --n=60 [--map=3] [--max=20] [--seed=4242]
const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Operation = preload("res://scripts/campaign/operation.gd")


func _init() -> void:
	var n := 60
	var only := -1
	var max_n := 20
	var seed_v := 4242
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--map="):
			only = Maps.index_of(a.trim_prefix("--map="))
		elif a.begins_with("--max="):
			max_n = int(a.trim_prefix("--max="))
		elif a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
	var navs := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var bad_seen := {}
	var ends := [0, 0, 0]
	var timeouts := 0
	var t0 := Time.get_ticks_msec()
	var sim_t := 0.0
	for k in n:
		var mi: int = only if only >= 0 else rng.randi_range(0, Maps.count() - 1)
		var lv = Maps.get_level(mi)
		if not navs.has(mi):
			var nv = Nav.new()
			nv.build(lv)
			navs[mi] = nv
		var nav = navs[mi]
		var cfgs: Array = []
		var sizes := [rng.randi_range(1, max_n), rng.randi_range(1, max_n)]
		for team in 2:
			for slot in 20:
				var id := "%s%d" % ["AB"[team], slot + 1]
				var ech: String = Habits.ECHELON_ORDER[rng.randi_range(0, Habits.ECHELON_ORDER.size() - 1)]
				var good := {}
				for g in Habits.good_ids():
					good[g] = rng.randf() < 0.55
				var bad := {}
				for b in Habits.bad_ids():
					bad[b] = rng.randf() < 0.45
				var traits := {}
				for tr in Habits.trait_ids():
					traits[tr] = rng.randf() < 0.2
				var p: Vector2 = lv.spawns[id]["p"]
				if rng.randf() < 0.3:
					for tries in 50:
						var q := Vector2(rng.randf_range(1, lv.W - 1), rng.randf_range(1, lv.H - 1))
						if nav.is_free(q):
							p = q
							break
				cfgs.append({"id": id, "team": team, "slot": slot, "echelon": ech, "good": good, "bad": bad,
					"traits": traits, "exp": rng.randi_range(1, 5), "plates": rng.randi_range(0, 4), "pos": p,
					"face": rng.randf() * TAU, "enabled": slot < sizes[team]})
		var post: Array = [["assault", "hold", "hunt"][rng.randi_range(0, 2)], ["assault", "hold", "hunt"][rng.randi_range(0, 2)]]
		# v0.6: about half the matches add civilians; police rules, night and strict rules
		# of engagement at random
		var n_civ := rng.randi_range(0, 14) if rng.randf() < 0.5 else 0
		var opts := {"police_rules": rng.randf() < 0.5, "night": rng.randf() < 0.25, "roe_strict": rng.randf() < 0.15}
		if n_civ > 0:
			cfgs = Operation.build(cfgs, lv, nav, {"civilians": n_civ, "seed": 5000 + k})
		var w = World.new()
		w.keep_events = rng.randf() < 0.3
		w.setup(lv, nav, cfgs, post, 5000 + k, [1, 1], opts)
		while not w.over:
			w.step()
			for o in w.ops:
				for b in o.active_bad:
					bad_seen[b] = true
			if w.keep_events:
				w.events.clear()
		ends[w.winner] += 1
		if w.t >= w.time_limit:
			timeouts += 1
			if "--dump" in OS.get_cmdline_user_args():
				for ln in w.log_lines.slice(maxi(0, w.log_lines.size() - 60)):
					print("      ", ln["text"])
				for o in w.ops:
					if o.alive():
						print("      %s el %d %s room %s dbg %s" % [o.id, o.el, str(o.pos.snapped(Vector2(0.1, 0.1))), o.room, o.dbg])
		sim_t += w.t
		print("  %3d map %02d %2dv%-2d %-7s/%-7s civ %2d%s -> %s at %5.1f s" % [k, mi, sizes[0], sizes[1], post[0], post[1],
			n_civ, " police" if opts["police_rules"] else "", ["A", "B", "draw"][w.winner], w.t])
		w.dispose()
	print("fuzz matches %d: A %d  B %d  draw %d (time limit %d)   sim %.0f s in %d ms" % [n, ends[0], ends[1], ends[2],
		timeouts, sim_t, Time.get_ticks_msec() - t0])
	var missing: Array = []
	for b in Habits.bad_ids():
		if not bad_seen.has(b):
			missing.append(b)
	print("bad habits activated: %d/20  missing: %s" % [bad_seen.size(), str(missing)])
	quit()
