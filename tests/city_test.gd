extends SceneTree
## City build check: timings, counts, every building's rooms reachable from its gate,
## sample cross-city paths.
##   godot --headless --path . -s res://tests/city_test.gd -- --seed=3
const CityLevel = preload("res://scripts/city/city_level.gd")
const CityNav = preload("res://scripts/city/city_nav.gd")


func _init() -> void:
	var sd := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sd = int(a.trim_prefix("--seed="))
	var lv = CityLevel.new(sd)
	var t_all := Time.get_ticks_msec()
	for st in lv.build_steps():
		var t0 := Time.get_ticks_msec()
		st[1].call()
		print("  %-36s %6d ms" % [st[0], Time.get_ticks_msec() - t0])
	var t1 := Time.get_ticks_msec()
	var nav = CityNav.new()
	nav.build(lv)
	print("  %-36s %6d ms" % ["street graph", Time.get_ticks_msec() - t1])
	print("city %dx%d m, %d lots, %d buildings, %d rooms, %d doors, %d windows, %d obstacles, %d props, total %d ms" % [
		int(lv.W), int(lv.H), lv.lots.size(), lv.bldgs.size(), lv.rooms.size(), lv.doors.size(), lv.windows.size(),
		lv.geom.obs.size(), lv.props.size(), Time.get_ticks_msec() - t_all])
	var kinds := {}
	for b in lv.bldgs:
		kinds[b["kind"]] = kinds.get(b["kind"], 0) + 1
	print("kinds: ", kinds)
	for h in lv.hoods:
		print("  hood %-14s blocks %d buildings %d" % [h["name"], h["blocks"].size(), h["bldgs"].size()])
	var bad := 0
	var t2 := Time.get_ticks_msec()
	var n_paths := 0
	for b in lv.bldgs:
		var lot: Dictionary = lv.lots[b["lot"]]
		if not nav.reachable(lot["gate_in"]):
			print("  ! gate of lot %d (%s) not reachable" % [lot["i"], lot["tpl"]["name"]])
			bad += 1
			continue
		for rn in b["rooms"]:
			var rm: Dictionary = lv.rooms[rn]
			var p: Vector2 = nav.snap(rm["rects"][0].get_center())
			if lv.room_at(p) != rn:
				continue
			var pth: PackedVector2Array = nav.find_path(0, lot["gate_in"], p)
			n_paths += 1
			if pth.is_empty():
				print("  ! %s: no path from the gate to %s" % [b["name"], rn])
				bad += 1
	print("room paths %d in %d ms" % [n_paths, Time.get_ticks_msec() - t2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t3 := Time.get_ticks_msec()
	var lens := []
	for k in 60:
		var ba: Dictionary = lv.bldgs[rng.randi() % lv.bldgs.size()]
		var bb: Dictionary = lv.bldgs[rng.randi() % lv.bldgs.size()]
		var pa: Vector2 = nav.snap(lv.rooms[ba["rooms"][0]]["rects"][0].get_center())
		var pb: Vector2 = nav.snap(lv.rooms[bb["rooms"][0]]["rects"][0].get_center())
		var pth2: PackedVector2Array = nav.find_path(3, pa, pb)
		if pth2.is_empty():
			print("  ! no path %s -> %s" % [ba["name"], bb["name"]])
			bad += 1
		else:
			lens.append(int(nav.path_length(pth2)))
	print("60 cross-city paths in %d ms, lengths %s" % [Time.get_ticks_msec() - t3, str(lens.slice(0, 12))])
	# street points
	for k2 in 30:
		var sp := Vector2(rng.randf_range(5, lv.W - 5), lv.node_pos(0, rng.randi() % 6).y + rng.randf_range(-8, 8))
		if not nav.is_free(sp):
			continue
		var bb2: Dictionary = lv.bldgs[rng.randi() % lv.bldgs.size()]
		var pth3: PackedVector2Array = nav.find_path(0, sp, nav.snap(lv.rooms[bb2["rooms"][0]]["rects"][0].get_center()))
		if pth3.is_empty():
			print("  ! no path from street %s" % str(sp))
			bad += 1
	print("problems: %d" % bad)
	quit()
