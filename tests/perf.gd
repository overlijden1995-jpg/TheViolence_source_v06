extends SceneTree
## Profile: where the time goes in a big fight.
##   godot --headless --path . -s res://tests/perf.gd -- --map=10 --na=20 --nb=20 --t=60 --pa=hunt --pb=hunt
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Teams = preload("res://tests/teams.gd")


func _init() -> void:
	var opt := {"map": "10", "na": "20", "nb": "20", "t": "60", "pa": "assault", "pb": "hold", "a": "sof", "b": "militia", "seed": "77"}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		if kv.size() == 2:
			opt[kv[0]] = kv[1]
	var lv = Maps.get_level(Maps.index_of(opt["map"]))
	var nav = Nav.new()
	nav.build(lv)
	var w = World.new()
	w.keep_events = false
	w.profiling = true
	var cfgs: Array = Teams.team(lv, 0, {"n": int(opt["na"]), "ech": opt["a"]}) + Teams.team(lv, 1, {"n": int(opt["nb"]), "ech": opt["b"]})
	w.setup(lv, nav, cfgs, [opt["pa"], opt["pb"]], int(opt["seed"]))
	var t0 := Time.get_ticks_usec()
	var ticks := 0
	var sc0: int = w.geom.sight_calls
	var pc0: int = nav.path_calls
	while not w.over and w.t < float(opt["t"]):
		w.step()
		ticks += 1
	var us := Time.get_ticks_usec() - t0
	print("%d ticks, %.2f ms/tick, sim %.1f s, realtime factor %.1fx" % [ticks, us / 1000.0 / ticks, w.t, w.t / (us / 1e6)])
	for k in w.prof:
		print("  %-10s %6.2f ms/tick" % [k, w.prof[k] / 1000.0 / ticks])
	print("  sight checks/tick %.0f, path calls/tick %.2f (%.2f ms/tick)" % [float(w.geom.sight_calls - sc0) / ticks, float(nav.path_calls - pc0) / ticks, nav.path_us / 1000.0 / ticks])
	var alive := [0, 0]
	for o in w.ops:
		if o.alive():
			alive[o.team] += 1
	print("  alive %d/%d at %.1f s" % [alive[0], alive[1], w.t])
	quit()
