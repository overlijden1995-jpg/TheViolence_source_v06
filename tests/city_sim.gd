extends SceneTree
## Endless battle headless: build the city, run the director and the fight for a while,
## print what happens and where the time goes.
##   godot --headless --path . -s res://tests/city_sim.gd -- --seed=3 --min=6
const CityLevel = preload("res://scripts/city/city_level.gd")
const CityNav = preload("res://scripts/city/city_nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Director = preload("res://scripts/city/director.gd")


func _init() -> void:
	var sd := 3
	var mins := 6.0
	var quiet := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.trim_prefix("--seed="))
		elif a.begins_with("--min="):
			mins = float(a.trim_prefix("--min="))
		elif a == "--quiet":
			quiet = true
	var t0 := Time.get_ticks_msec()
	var lv = CityLevel.new(sd)
	lv.build()
	var nav = CityNav.new()
	nav.build(lv)
	var w = World.new()
	w.setup_empty(lv, nav, sd, Director.faction_list())
	w.keep_events = false
	w.log_kinds = {"city": true}
	var d = Director.new(w, lv, nav, sd)
	w.director = d
	d.setup()
	print("ready in %d ms: %d ops, %d units" % [Time.get_ticks_msec() - t0, w.ops.size(), w.teams.size()])
	var shown := 0
	var steps := int(mins * 60.0 * 30.0)
	var tw := Time.get_ticks_usec()
	var worst := 0
	var chunk_t := Time.get_ticks_usec()
	w.profiling = true
	w.brain.fine = OS.get_cmdline_user_args().has("--fine")
	for i in steps:
		var ts := Time.get_ticks_usec()
		w.step()
		worst = maxi(worst, Time.get_ticks_usec() - ts)
		if not quiet:
			while shown < w.log_base + w.log_lines.size():
				if shown >= w.log_base:
					print(w.log_lines[shown - w.log_base]["text"])
				shown += 1
		if i % 1800 == 1799:
			var now := Time.get_ticks_usec()
			var counts := {}
			var dormant := 0
			for o in w.ops:
				if o.alive():
					counts[o.faction] = counts.get(o.faction, 0) + 1
					if o.dormant:
						dormant += 1
			var owned := {}
			for bs in d.bstate:
				owned[bs["owner"]] = owned.get(bs["owner"], 0) + 1
			print("--- %s  %.2f ms/tick (worst %.1f)  alive %s  dormant %d  owned %s  deaths %d  queue %d" % [w.clock(w.t),
				(now - chunk_t) / 1800.0 / 1000.0, worst / 1000.0, str(counts), dormant, str(owned), w.deaths.size() + w.deaths_base, d.queue.size()])
			var pf := []
			var keys: Array = w.prof.keys()
			keys.sort_custom(func(a, b): return w.prof[a] > w.prof[b])
			for k in keys:
				if w.prof[k] / 1800.0 / 1000.0 >= 0.05:
					pf.append("%s %.2f" % [k, w.prof[k] / 1800.0 / 1000.0])
			print("    ", ", ".join(pf), "   paths %d (%.1f ms)" % [nav.path_calls, nav.path_us / 1000.0])
			if not w.prof_n.is_empty():
				print("    path calls: ", w.prof_n)
			w.prof_n = {}
			w.prof = {}
			nav.path_calls = 0
			nav.path_us = 0
			worst = 0
			chunk_t = now
	print("ran %.0f s of battle in %.1f s; stats %s" % [w.t, (Time.get_ticks_usec() - tw) / 1e6, str(d.stats)])
	var causes := {}
	for d0 in w.deaths:
		var k0: String = d0["cause"] + "/" + d0["where"] + " " + w.factions[d0["faction"]]["tag"]
		causes[k0] = causes.get(k0, 0) + 1
	print("deaths by cause: ", causes)
	var alerts := [0, 0, 0]
	for o0 in w.ops:
		if o0.alive() and not o0.medic:
			alerts[o0.alert] += 1
	print("alert states now (green, yellow, red): ", alerts)
	for dd in w.deaths.slice(maxi(0, w.deaths.size() - 12)):
		print("  KIA %s %s (%s) %s, by %s (%s), %s, %s" % [w.clock(dd["t"]), dd["name"], dd["rank"], dd["fac_name"], dd["by_name"], dd["by_fac_name"], dd["where"], dd["place"]])
	quit()
