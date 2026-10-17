extends SceneTree
## Stall hunt: every map, several sizes and matchups; flags matches that run to the time
## limit and prints what the survivors were doing.
##   godot --headless --path . -s res://tests/stall_test.gd -- [--map=4] [--seed=1]
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Teams = preload("res://tests/teams.gd")

const CASES := [
	[5, 5, "regular", "regular", "assault", "hold"],
	[12, 12, "police", "militia", "assault", "hold"],
	[20, 20, "regular", "regular", "assault", "hold"],
	[8, 16, "sof", "militia", "assault", "hold"],
	[10, 10, "regular", "militia", "hunt", "hunt"],
	[16, 8, "militia", "sof", "assault", "hold"],
]


func _init() -> void:
	var only := -1
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			only = Maps.index_of(a.trim_prefix("--map="))
		elif a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
	var stalls := 0
	var t_all := Time.get_ticks_msec()
	for i in Maps.count():
		if only >= 0 and i != only:
			continue
		var lv = Maps.get_level(i)
		var nav = Nav.new()
		nav.build(lv)
		for c in CASES:
			var cfgs: Array = Teams.team(lv, 0, {"n": c[0], "ech": c[2]}) + Teams.team(lv, 1, {"n": c[1], "ech": c[3]})
			var w = World.new()
			w.keep_events = false
			w.setup(lv, nav, cfgs, [c[4], c[5]], 100 * i + seed_v)
			var t0 := Time.get_ticks_usec()
			var ticks := 0
			while not w.over:
				w.step()
				ticks += 1
			var alive := [0, 0]
			for o in w.ops:
				if o.alive():
					alive[o.team] += 1
			var flag := ""
			if w.t >= w.time_limit:
				flag = "  <<< TIME LIMIT"
				stalls += 1
			print("map %02d %2dv%-2d %-8s %-8s %-7s/%-5s -> %-6s %5.1f s  alive %2d/%-2d  cleared %2d  %.2f ms/tick%s" % [i, c[0], c[1],
				c[2], c[3], c[4], c[5], ["A", "B", "draw"][w.winner], w.t, alive[0], alive[1], w.teams[0]["cleared"].size(),
				(Time.get_ticks_usec() - t0) / 1000.0 / ticks, flag])
			if flag != "":
				for o in w.ops:
					if o.alive():
						print("      %s el %d %s %s: %s" % [o.id, o.el, str(o.pos.snapped(Vector2(0.1, 0.1))), o.room, o.dbg])
				for el in w.teams[0]["elements"]:
					print("      A-%d mode %s task %s phase %s" % [el["i"] + 1, el["mode"], str(el["task"]), el["phase"]])
			w.dispose()
	print("stalls: %d   (%d s)" % [stalls, (Time.get_ticks_msec() - t_all) / 1000])
	quit()
