extends SceneTree
## Map validation: every room reachable, every door passable from both sides, every
## post for 20 a side free and reachable, door graph connected. Optional matches.
##   godot --headless --path . -s res://tests/maps_test.gd                  # all maps
##   godot --headless --path . -s res://tests/maps_test.gd -- --map=4 --run=1
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Teams = preload("res://tests/teams.gd")


func _init() -> void:
	var only := -1
	var runs := 0
	var sizes := [[5, 5], [20, 20]]
	var ech := ["sof", "militia"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			only = Maps.index_of(a.trim_prefix("--map="))
		elif a.begins_with("--run="):
			runs = int(a.trim_prefix("--run="))
		elif a.begins_with("--sizes="):
			sizes = []
			for part in a.trim_prefix("--sizes=").split(";"):
				var ab := part.split("v")
				sizes.append([int(ab[0]), int(ab[1])])
		elif a.begins_with("--ech="):
			ech = a.trim_prefix("--ech=").split("v")
	var problems := 0
	for i in Maps.count():
		if only >= 0 and i != only:
			continue
		var t0 := Time.get_ticks_msec()
		var lv = Maps.get_level(i)
		var t1 := Time.get_ticks_msec()
		var nav = Nav.new()
		nav.build(lv)
		var t2 := Time.get_ticks_msec()
		var n_int := 0
		for name in lv.rooms:
			if not lv.is_exterior(name):
				n_int += 1
		print("map %02d %-40s %dx%d m  rooms %d  doors %d  windows %d  obstacles %d  build %d ms  nav %d ms" % [
			i, lv.map_name, int(lv.W), int(lv.H), n_int, lv.doors.size(), lv.windows.size(), lv.geom.obs.size(), t1 - t0, t2 - t1])
		problems += _check(lv, nav)
		for r in runs:
			for sz in sizes:
				_match(lv, nav, sz[0], sz[1], ech, 9100 + r)
	print("problems: %d" % problems)
	quit()


func _reach_ok(nav, p: Vector2) -> bool:
	var c: Vector2i = nav.cell_of(p)
	return nav.reach[c.y * nav.nx + c.x] == 1


func _check(lv, nav) -> int:
	var bad := 0
	# rooms: some reachable floor, at least one door, connected to the outside
	for name in lv.rooms:
		var rm: Dictionary = lv.rooms[name]
		var ok := false
		for rv in rm["rects"]:
			var r: Rect2 = rv
			var y := r.position.y + 0.25
			while y < r.end.y and not ok:
				var x := r.position.x + 0.25
				while x < r.end.x:
					if lv.room_at(Vector2(x, y)) == name and _reach_ok(nav, Vector2(x, y)):
						ok = true
						break
					x += 0.5
				y += 0.5
		if not ok:
			print("  ! room %s has no reachable floor" % name)
			bad += 1
		if not rm["exterior"] and lv.adj.get(name, []).is_empty():
			print("  ! room %s has no door" % name)
			bad += 1
	var seen := {"OUT": true}
	var stack := ["OUT"]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for did in lv.adj.get(cur, []):
			var d: Dictionary = lv.doors[did]
			for nb in [d["a"], d["b"]]:
				if not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
	for name in lv.rooms:
		if not lv.is_exterior(name) and not seen.has(name):
			print("  ! room %s is not connected to the outside by doors" % name)
			bad += 1
	# doors: both sides reachable and joined by a path through the opening
	for did in lv.doors:
		var d: Dictionary = lv.doors[did]
		var a: Vector2 = d["c"] - d["n"] * 0.7
		var b: Vector2 = d["c"] + d["n"] * 0.7
		if d["a"] == d["b"] and d["a"] != "OUT":
			print("  ! door %s has the same room (%s) on both sides" % [did, d["a"]])
			bad += 1
		if not _reach_ok(nav, a) or not _reach_ok(nav, b):
			print("  ! door %s at %s: side %s%s not reachable (%s | %s)" % [did, str(d["c"]), "A" if not _reach_ok(nav, a) else "",
				"B" if not _reach_ok(nav, b) else "", d["a"], d["b"]])
			bad += 1
			continue
		var pth: PackedVector2Array = nav.find_path(0, a, b)
		if pth.is_empty() or nav.path_length(pth) > 4.0:
			print("  ! door %s at %s: no short path through (%.1f m)" % [did, str(d["c"]), nav.path_length(pth) if not pth.is_empty() else -1.0])
			bad += 1
	# posts
	for side in ["A", "B"]:
		for k in range(1, 21):
			var sid := "%s%d" % [side, k]
			if not lv.spawns.has(sid):
				print("  ! no post %s" % sid)
				bad += 1
				continue
			var p: Vector2 = lv.spawns[sid]["p"]
			if not nav.is_free(p) or not _reach_ok(nav, p):
				print("  ! post %s at %s is blocked or unreachable" % [sid, str(p)])
				bad += 1
	return bad


func _match(lv, nav, na: int, nb: int, ech: Array, seed_val: int) -> void:
	var cfgs: Array = Teams.team(lv, 0, {"n": na, "ech": ech[0]}) + Teams.team(lv, 1, {"n": nb, "ech": ech[1]})
	var w = World.new()
	w.keep_events = false
	w.setup(lv, nav, cfgs, ["assault", "hold"], seed_val)
	var t0 := Time.get_ticks_usec()
	var ticks := 0
	while not w.over:
		w.step()
		ticks += 1
	var us := Time.get_ticks_usec() - t0
	var alive := [0, 0]
	for o in w.ops:
		if o.alive():
			alive[o.team] += 1
	var cleared: int = w.teams[0]["cleared"].size()
	print("    %2dv%-2d %s v %s seed %d: %s at %5.1f s, alive %d/%d, A cleared %d rooms, %d shots, ff %d, %.2f ms/tick" % [
		na, nb, ech[0], ech[1], seed_val, ["A WINS", "B WINS", "DRAW"][w.winner], w.t, alive[0], alive[1], cleared,
		w.stat["shots"], w.stat["friendly"], us / 1000.0 / ticks])
	w.dispose()
