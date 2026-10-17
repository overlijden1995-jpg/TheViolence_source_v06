extends RefCounted
## Decisions (bible section 4). Root priorities, re-evaluated every tick:
##   P1 Rule 1 (closest visible enemy within 10 m: fire until dry or eliminated)
##   P2 Rule 2 (primary dry -> sidearm; both dry -> break line of sight, then reload)
##   P3 stoppage  P4 engage beyond 10 m  P5 react  P6 maintain  P7 team task  P8 scan
## Good habits change how each branch runs; active bad habits suspend the good habits
## they override (op.has() is false for a suspended habit) and add their own behaviour.

const Op = preload("res://scripts/sim/op.gd")
const Geom = preload("res://scripts/sim/geom.gd")
const Habits = preload("res://scripts/data/habits.gd")
const DT := 1.0 / 30.0

var w
var tick := 0


func _init(world) -> void:
	w = world


# ================================================================== team level
## Teams of more than five split into elements (fire teams) of up to five: balanced,
## contiguous blocks of slots (6 = 3+3, 7 = 4+3, 11 = 4+4+3, 20 = 5x4). Each element
## picks its own room, stacks, enters, holds its own sectors and bounds on its own; the
## team shares what is cleared, which rooms are claimed, and every callout. A team of
## five or fewer is a single element and behaves exactly as before.
func init_teams() -> void:
	for tm in w.teams:
		if tm.get("civ", false):
			continue
		init_team(tm)


## Form a unit's elements and start it on its posture (also for units created mid-match).
func init_team(tm: Dictionary) -> void:
	_form_elements(tm)
	if tm["posture"] == "hold":
		# squads already gathered in one room claim it first
		var order: Array = tm["elements"].duplicate()
		order.sort_custom(func(a, b): return _concentration(a) > _concentration(b))
		for el in order:
			_set_mode(tm, el, "hold")
	else:
		_set_posture(tm, tm["posture"])


func _concentration(el: Dictionary) -> int:
	var counts := {}
	var best := 0
	for m in el["members"]:
		var rm: String = w.level.room_at(m.pos)
		if w.level.is_exterior(rm):
			continue
		counts[rm] = counts.get(rm, 0) + 1
		best = maxi(best, counts[rm])
	return best


func _form_elements(tm: Dictionary) -> void:
	var ms: Array = tm["members"].duplicate()
	ms.sort_custom(func(a, b): return a.slot < b.slot)
	var n := ms.size()
	var n_el := maxi(1, int(ceil(n / 5.0)))
	tm["elements"] = []
	var k := 0
	var sizes: Array = []
	for i in n_el:
		var size := n / n_el + (1 if i < n % n_el else 0)
		var el := _new_element(i)
		for j in size:
			var m = ms[k]
			k += 1
			m.el = i
			m.eslot = j
			el["members"].append(m)
		tm["elements"].append(el)
		sizes.append(str(size))
	if n_el > 1:
		w.say("%s forms %d elements (%s)" % [tm["tag"], n_el, " + ".join(sizes)], "info")


func _new_element(i: int) -> Dictionary:
	return {"i": i, "members": [], "mode": "", "task": {}, "phase": "", "phase_t": 0.0, "entry": {}, "ctl": {},
		"geo": {}, "sectors": {}, "sector_half": deg_to_rad(80.0), "sector_pending": {}, "bound": -1,
		"bound_from": Vector2.ZERO, "bound_t": 0.0, "hunt_i": 0, "hunt_done_t": -1.0, "sweep": [],
		"sweep_target": null, "last_room": "", "retask_t": 0.0}


func _set_posture(tm: Dictionary, p: String) -> void:
	tm["posture"] = p
	for el in tm["elements"]:
		if not _alive(el).is_empty():
			_set_mode(tm, el, p)


func _set_mode(tm: Dictionary, el: Dictionary, mode: String) -> void:
	if el["mode"] == "hold" and mode != "hold":
		_release_hold(tm, el)
	el["mode"] = mode
	for m0 in el["members"]:
		w.wake(m0)
	# taskings that go looking for the enemy keep weapons drawn
	var floor_lvl: int = Op.YELLOW if mode in ["assault", "hunt", "support"] else int(tm.get("base_alert", -1))
	if floor_lvl >= 0:
		for m in el["members"]:
			m.alert_floor = floor_lvl
			if m.alert < floor_lvl and m.alive():
				w.raise_alert(m, floor_lvl)
	if mode == "assault":
		_next_task(tm, el)
	elif mode == "hold":
		_consolidate(tm, el)
	elif mode == "hunt":
		_release(tm, el)
		el["task"] = {}
		var n_el: int = tm["elements"].size()
		el["hunt_i"] = int(el["i"] * tm.get("patrol", w.level.patrol).size() / maxi(1, n_el))
		el["hunt_done_t"] = -1.0


func alive_members(tm: Dictionary) -> Array:
	var out: Array = []
	for m in tm["members"]:
		if m.alive():
			out.append(m)
	return out


func _alive(el: Dictionary) -> Array:
	var out: Array = []
	for m in el["members"]:
		if m.alive():
			out.append(m)
	return out


func _el(o) -> Dictionary:
	return w.teams[o.team]["elements"][o.el]


func _el_mates(o) -> Array:
	var out: Array = []
	for m in _el(o)["members"]:
		if m != o and m.alive():
			out.append(m)
	return out


func _tag(tm: Dictionary, el: Dictionary) -> String:
	if tm["elements"].size() <= 1:
		return tm["tag"]
	return "%s-%d" % [tm["tag"], el["i"] + 1]


func _any_has(tm: Dictionary, gid: String) -> bool:
	for m in alive_members(tm):
		if m.has(gid):
			return true
	return false


func _release(tm: Dictionary, el: Dictionary) -> void:
	var into: String = el["task"].get("into", "")
	if into != "" and tm["claimed"].get(into, -1) == el["i"]:
		tm["claimed"].erase(into)


## Pick the element's next room: any uncleared interior room reachable through a door
## from outside or from a cleared room, not claimed by another element. Nearest by
## path wins; a small room off the room just cleared goes first (no open door left
## behind). Small rooms (PF10 check rooms) are looked into by someone with PF10, or
## skipped if nobody on the team has it.
func _next_task(tm: Dictionary, el: Dictionary) -> void:
	_release(tm, el)
	el["task"] = {}
	var al := _alive(el)
	if al.is_empty():
		return
	var lv = w.level
	var c := _centre(al)
	var pf10_team := _any_has(tm, "PF10")
	var pf10_el := false
	for m in al:
		if m.has("PF10"):
			pf10_el = true
	var cands: Array = []
	var bi: int = tm.get("bldg", -1)
	var door_ids: Array = lv.building_doors(bi) if bi >= 0 else lv.doors.keys()
	for did in door_ids:
		var D: Dictionary = lv.doors[did]
		for into in [D["a"], D["b"]]:
			if lv.is_exterior(into) or tm["cleared"].has(into) or tm["skipped"].has(into):
				continue
			if tm["claimed"].has(into) and tm["claimed"][into] != el["i"]:
				continue
			var frm: String = lv.from_room(did, into)
			if not (lv.is_exterior(frm) or tm["cleared"].has(frm) or tm["skipped"].has(frm) or _held_hall(tm, frm)):
				continue
			var check: bool = lv.is_check_room(into)
			if check and not pf10_team:
				tm["skipped"][into] = true
				continue
			if check and not pf10_el:
				continue
			var bonus := -4.0 if (check and frm == el["last_room"]) else 0.0
			cands.append([c.distance_to(D["c"]) + bonus, did, into, check, bonus])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var best = null
	var best_s := INF
	var start: Vector2 = w.nav.snap(c)
	for k in mini(4, cands.size()):
		var cd: Array = cands[k]
		var D2: Dictionary = lv.doors[cd[1]]
		var app: Vector2 = D2["c"] - lv.inward(cd[1], cd[2]) * 1.2
		var pth: PackedVector2Array = w.nav.find_path(0, start, app)
		var L: float = w.nav.path_length(pth) if not pth.is_empty() else 999.0
		var sc: float = L + cd[4]
		if sc < best_s:
			best_s = sc
			best = cd
	if best != null:
		el["task"] = {"door": best[1], "into": best[2], "check": best[3]}
		tm["claimed"][best[2]] = el["i"]
		el["mode"] = "assault"
		_begin_task(tm, el)
		return
	# nothing open to this element: wait behind another element, or hunt if all clear
	var remaining := false
	for name in (lv.building_rooms(bi) if bi >= 0 else lv.rooms.keys()):
		if lv.is_exterior(name) or tm["cleared"].has(name) or tm["skipped"].has(name):
			continue
		if lv.adj.get(name, []).is_empty():
			continue
		remaining = true
	var others_busy := false
	for other in tm["elements"]:
		if other != el and not other["task"].is_empty() and not _alive(other).is_empty():
			others_busy = true
	if remaining and others_busy:
		if el["mode"] != "support":
			w.say("%s waits on the next room" % _tag(tm, el), "info")
		el["mode"] = "support"
		el["retask_t"] = w.t + 1.0
		return
	if bi >= 0:
		# a building search: report done and wait for the next tasking
		if not tm["clear_said"]:
			tm["clear_said"] = true
			tm["done_t"] = w.t
			w.say("%s: building %s" % [tm["tag"], "clear" if not remaining else "searched (rooms out of reach)"], "info")
		el["mode"] = "done"
		return
	if not tm["clear_said"]:
		tm["clear_said"] = true
		if remaining:
			w.say("%s: no room left it can reach, hunting" % tm["tag"], "info")
		else:
			w.say("%s: building clear, hunting" % tm["tag"], "info")
	tm["posture"] = "hunt"
	for other in tm["elements"]:
		if other == el or other["mode"] == "support" or (other["mode"] == "assault" and other["task"].is_empty()):
			_set_mode(tm, other, "hunt")


## A corridor or stair hall that an element has entered and is clearing or sweeping is
## held: other elements may peel off it into the rooms along it.
func _held_hall(tm: Dictionary, name: String) -> bool:
	if not w.level.rooms.has(name) or not w.level.rooms[name]["hall"]:
		return false
	var ei: int = tm["claimed"].get(name, -1)
	if ei < 0:
		return false
	var el: Dictionary = tm["elements"][ei]
	return el["phase"] == "clear" or el["phase"] == "sweep"


func _begin_task(tm: Dictionary, el: Dictionary) -> void:
	var st: Dictionary = el["task"]
	var lv = w.level
	var D: Dictionary = lv.doors[st["door"]]
	var n_in: Vector2 = lv.inward(st["door"], st["into"])
	var c: Vector2 = D["c"]
	var tdir: Vector2 = D["t"]
	el["phase"] = "check" if st.get("check", false) else "approach"
	el["phase_t"] = w.t
	el["entry"] = {}
	el["ctl"] = {}
	el["sweep"] = []
	el["sweep_target"] = null
	var al := _alive(el)
	al.sort_custom(func(a, b): return a.pos.distance_to(c) < b.pos.distance_to(c))
	for i in range(al.size()):
		if al[i].hb("BH11") and i > 0:
			var r = al[i]
			al.remove_at(i)
			al.insert(0, r)
			break
	# stack side: the wall side with more walkable room on the near side of the door
	var from_room: String = lv.from_room(st["door"], st["into"])
	var side := tdir
	var free_pos := 0
	var free_neg := 0
	for k in 3:
		if _near_side_ok(c - n_in * 0.55 + tdir * (D["half"] + 0.5 + 0.8 * k), from_room):
			free_pos += 1
		if _near_side_ok(c - n_in * 0.55 - tdir * (D["half"] + 0.5 + 0.8 * k), from_room):
			free_neg += 1
	if free_neg > free_pos:
		side = -tdir
	# entry geometry inside the room (runs are capped at 4.5 m in big rooms)
	var inside := c + n_in * 0.7
	var ext_p: float = minf(lv.extent_along(inside, tdir), 4.5)
	var ext_n: float = minf(lv.extent_along(inside, -tdir), 4.5)
	var s1 := tdir if ext_p >= ext_n else -tdir
	el["geo"] = {"c": c, "n_in": n_in, "tdir": tdir, "side": side, "from": from_room, "inside": inside,
		"s1": s1, "e1": maxf(ext_p, ext_n), "e2": minf(ext_p, ext_n),
		"depth": minf(lv.extent_along(inside, n_in), 4.5), "cap": lv.room_capacity(st["into"]),
		"slots": _stack_slots(c, n_in, side, D["half"], from_room)}
	for k in range(al.size()):
		el["entry"][al[k].id] = _entry_record(el, al[k], k, true)
	if el["phase"] == "approach":
		var cap: int = el["geo"]["cap"]
		var held: int = al.size() - cap
		w.say("%s moves on the %s%s" % [_tag(tm, el), lv.rooms[st["into"]]["title"].to_lower(),
			(" (%d enter, %d hold rear security)" % [cap, held]) if held > 0 else ""], "info")


## One member's part in an entry: wait point (stack, or a loose clump without GD01),
## optional pie-slicing arc (PF03), point of domination and corner to clear.
func _entry_record(el: Dictionary, m, k: int, may_enter: bool) -> Dictionary:
	var g: Dictionary = el["geo"]
	var c: Vector2 = g["c"]
	var n_in: Vector2 = g["n_in"]
	var tdir: Vector2 = g["tdir"]
	var side: Vector2 = g["side"]
	var from_room: String = g["from"]
	var slots: Array = g["slots"]
	var enters: bool = may_enter and k < g["cap"]
	var d := {"order": k, "wi": 0, "at_stack": false, "ready": false, "looked": 0.0,
		"checked": not m.has("WD04"), "arrived": false, "paused": false, "swept": false, "enters": enters}
	var stack: Vector2
	if m.has("GD01"):
		stack = slots[k] if k < slots.size() else _cluster_point(c, n_in, tdir, k, from_room)
	else:
		stack = _cluster_point(c, n_in, tdir, k, from_room)
	var wps: Array = []
	if m.has("PF03"):
		for arc_side in [-side, side]:
			var arc: Array = []
			for a_deg in [70.0, 45.0, 20.0]:
				var a := deg_to_rad(a_deg)
				var q: Vector2 = c - n_in * 2.0 * cos(a) + arc_side * 2.0 * sin(a)
				if _near_side_ok(q, from_room) and w.geom.sight_clear(q, 1.6, c + n_in * 0.6, 1.6):
					arc.append(q)
			if arc.size() >= 2:
				wps = arc
				break
	wps.append(stack)
	d["wps"] = wps
	d["stack"] = stack
	var tgt: Array = _entry_target(m, k, c, n_in, g["inside"], g["s1"], g["e1"], g["e2"], g["depth"])
	var my_side: Vector2 = tgt[1]
	d["target"] = _inside_room(w.nav.snap(tgt[0]), el["task"]["into"], c, n_in)
	var ext: float = g["e1"] if my_side == g["s1"] else g["e2"]
	d["corner"] = c + n_in * 0.25 + my_side * maxf(ext - 0.25, 0.3)
	return d


## A member who joins mid-task (from a merged element) enters if the stack has not gone
## yet and there is room; otherwise holds rear security.
func _add_to_entry(el: Dictionary, m) -> void:
	if el["geo"].is_empty():
		return
	var k: int = el["entry"].size()
	el["entry"][m.id] = _entry_record(el, m, k, el["phase"] == "approach" or el["phase"] == "check")


## Stack positions along the wall beside the door: up to five on the near wall, then a
## split stack on the far side of the door, then a second row.
func _stack_slots(c: Vector2, n_in: Vector2, side: Vector2, half: float, from_room: String) -> Array:
	var out: Array = []
	for k in 5:
		var q: Vector2 = c - n_in * 0.55 + side * (half + 0.5 + 0.8 * k)
		if not _near_side_ok(q, from_room):
			break
		out.append(q)
	for k in 3:
		var q2: Vector2 = c - n_in * 0.55 - side * (half + 0.5 + 0.8 * k)
		if not _near_side_ok(q2, from_room):
			break
		out.append(q2)
	for k in 4:
		var q3: Vector2 = c - n_in * 1.4 + side * (half + 0.5 + 0.8 * k)
		if not _near_side_ok(q3, from_room):
			break
		out.append(q3)
	return out


## Where an operator without stack discipline waits: a loose clump behind the door,
## kept on the near side so nobody waits in the room being cleared.
func _cluster_point(c: Vector2, n_in: Vector2, tdir: Vector2, k: int, from_room: String) -> Vector2:
	for dep in [1.8 + 0.7 * k, 1.8 + 0.4 * k, 1.4, 1.0]:
		for lat in [0.35 * k, -0.35 * k, 0.8, -0.8, 0.0]:
			var q: Vector2 = c - n_in * dep + tdir * lat
			if _near_side_ok(q, from_room):
				return q
	return w.nav.snap(c - n_in * 1.2)


## Point of domination for entry order k. Returns [target, side used].
## PF04: #1 and #2 run the entry wall to the corners (#2 opposite with GD06); #3 and #4
## step into the room behind them, alternating sides with GD06. Without PF04 everyone
## stops just inside the door, bunched in the funnel.
func _entry_target(m, k: int, c: Vector2, n_in: Vector2, inside: Vector2, s1: Vector2, e1: float, e2: float, depth: float) -> Array:
	if not m.has("PF04"):
		if k == 0:
			return [c + n_in * 1.0, s1]
		var sd := s1 if k % 2 == 1 else -s1
		return [c + n_in * (1.0 + 0.5 * int((k - 1) / 2)) + sd * 0.7, sd]
	var gd6: bool = m.has("GD06")
	if k == 0:
		return [inside + s1 * maxf(e1 - 0.6, 0.6), s1]
	if k == 1:
		if gd6:
			return [inside - s1 * maxf(e2 - 0.6, 0.6), -s1]
		return [inside + s1 * maxf(e1 - 1.6, 0.5), s1]
	if not gd6:
		return [inside + s1 * maxf(e1 - 0.6 - 1.0 * k, 0.4), s1]
	var sd2 := s1 if k % 2 == 0 else -s1
	var ext := e1 if sd2 == s1 else e2
	var d2: float = clampf(depth - 1.2, 0.8, 2.2)
	return [c + n_in * (0.7 + d2) + sd2 * clampf(ext - 0.9, 0.3, 1.3), sd2]


func _inside_room(p: Vector2, into: String, c: Vector2, n_in: Vector2) -> Vector2:
	if w.level.room_at(p) == into and w.nav.is_free(p):
		return p
	var aim := c + n_in * 1.5
	for k in range(1, 9):
		var q := p.lerp(aim, k / 8.0)
		if w.level.room_at(q) == into and w.nav.is_free(q):
			return q
	return w.nav.snap(aim)


func _near_side_ok(q: Vector2, from_room: String) -> bool:
	if not w.nav.is_free(q):
		return false
	var rm: String = w.level.room_at(q)
	if w.level.is_exterior(from_room):
		return w.level.is_exterior(rm)
	return rm == from_room


func update_teams() -> void:
	tick += 1
	for tm in w.teams:
		if tm["free"] or tm["sleep"] or tm.get("civ", false):
			continue
		if w.dormancy and not tm.get("hot", true) and (tick + tm["id"]) % 4 != 0:
			continue
		var al := alive_members(tm)
		if al.is_empty():
			continue
		_merge_elements(tm)
		for el in tm["elements"]:
			var eal := _alive(el)
			if eal.is_empty():
				continue
			_sectors(el, eal)
			_bounding(el, eal)
			match el["mode"]:
				"assault":
					_assault_tick(tm, el, eal)
				"support":
					if w.t >= el["retask_t"]:
						el["retask_t"] = w.t + 1.0
						_next_task(tm, el)
		if tm["posture"] == "hold" and not tm.get("stay", false):
			var quiet: float = w.t - maxf(tm["last_contact"], 0.0)
			if quiet > 60.0:
				w.say("%s: no contact for a minute, hunting" % tm["tag"], "info")
				_set_posture(tm, "hunt")


## An element cut down to one joins the nearest element that still has people; an
## element wiped out releases the room it had claimed.
func _merge_elements(tm: Dictionary) -> void:
	var els: Array = tm["elements"]
	if els.size() < 2:
		return
	for el in els:
		var al := _alive(el)
		if al.is_empty():
			if el["mode"] == "lost":
				continue
			if not el["task"].is_empty():
				_release(tm, el)
				el["task"] = {}
			_release_hold(tm, el)
			el["mode"] = "lost"
			continue
		if al.size() != 1:
			continue
		var lone = al[0]
		var best = null
		var bd := INF
		for other in els:
			if other == el:
				continue
			var oal := _alive(other)
			if oal.is_empty():
				continue
			var d: float = _centre(oal).distance_to(lone.pos) + (25.0 if oal.size() >= 5 else 0.0)
			if d < bd:
				bd = d
				best = other
		if best == null:
			continue
		_release(tm, el)
		_release_hold(tm, el)
		el["task"] = {}
		el["mode"] = "merged"
		el["members"].erase(lone)
		var top := -1
		for m in best["members"]:
			top = maxi(top, m.eslot)
		lone.el = best["i"]
		lone.eslot = top + 1
		best["members"].append(lone)
		best["sector_key"] = "?"
		w.say("%s, last of %s, joins %s" % [lone.id, _tag(tm, el), _tag(tm, best)], "comms")
		if best["mode"] == "assault" and not best["task"].is_empty():
			_add_to_entry(best, lone)
		elif best["mode"] == "hold" and best.get("hold_room", "") != "":
			_post_member(best, lone, {})


## GD02 sector ownership for any element size. Moving elements split the arc around
## their direction of advance (110 deg each for two or three, 360/N for four or five),
## left to right by position. Holders own the arc they were placed facing. After a
## casualty, GD09 members re-sector within 1 s; anyone without GD09 keeps the old arcs,
## so the casualty's arc stays dark.
func _sectors(el: Dictionary, al: Array) -> void:
	var gd2: Array = []
	for m in al:
		if m.has("GD02"):
			gd2.append(m)
	var key := ""
	for m in gd2:
		key += m.id
	var fwd := _team_forward(el, al)
	var holding: bool = el["mode"] == "hold"
	var first: bool = not el.has("sector_key") or el.get("sector_posture", "") != el["mode"]
	if not holding and not first and absf(angle_difference(fwd, el["sector_fwd"])) > 0.3:
		first = true
	if key == el.get("sector_key", "") and not first:
		_adopt_sectors(el)
		return
	var layout := _sector_layout(el, gd2, fwd)
	if first:
		el["sectors"] = layout
		el["sector_pending"] = {}
	else:
		var pend := {}
		if holding:
			for x in el["members"]:
				if x.alive() or not el["sectors"].has(x.id):
					continue
				var best = null
				for m in al:
					if m.has("GD09") and m.pos.distance_to(x.pos) < 10.0:
						if best == null or m.pos.distance_to(x.pos) < best.pos.distance_to(x.pos):
							best = m
				if best != null:
					var own: float = el["sectors"].get(best.id, best.spawn_face)
					pend[best.id] = {"dir": lerp_angle(own, el["sectors"][x.id], 0.5), "at": w.t + 1.0}
		else:
			for m in al:
				if m.has("GD09"):
					pend[m.id] = {"dir": layout.get(m.id, null), "at": w.t + 1.0}
		el["sector_pending"] = pend
	for oid in el["sectors"].keys():
		var x = w.op_by_id(oid)
		if x == null or not x.alive():
			el["sectors"].erase(oid)
	el["sector_key"] = key
	el["sector_fwd"] = fwd
	el["sector_posture"] = el["mode"]


func _sector_layout(el: Dictionary, members: Array, fwd: float) -> Dictionary:
	var out := {}
	var n := members.size()
	if el["mode"] == "hold":
		for m in members:
			out[m.id] = m.spawn_face
		el["sector_half"] = deg_to_rad(80.0)
		return out
	if n < 2:
		return out
	var c := Vector2.ZERO
	for m in members:
		c += m.pos
	c /= n
	var f := Vector2.from_angle(fwd)
	var sorted := members.duplicate()
	sorted.sort_custom(func(a, b): return f.cross(a.pos - c) < f.cross(b.pos - c))
	var spacing := minf(deg_to_rad(110.0), TAU / n)
	el["sector_half"] = clampf(spacing / 2.0 + deg_to_rad(15.0), deg_to_rad(50.0), deg_to_rad(80.0))
	for i in n:
		out[sorted[i].id] = fwd + (i - (n - 1) / 2.0) * spacing
	return out


func _adopt_sectors(el: Dictionary) -> void:
	var pend: Dictionary = el["sector_pending"]
	for oid in pend.keys():
		var p: Dictionary = pend[oid]
		if w.t < p["at"]:
			continue
		pend.erase(oid)
		var x = w.op_by_id(oid)
		if x == null or not x.alive():
			continue
		if p["dir"] == null:
			el["sectors"].erase(oid)
		else:
			el["sectors"][oid] = p["dir"]
		w.say("%s re-sectors after the casualty" % oid, "comms")


func _team_forward(el: Dictionary, al: Array) -> float:
	if el["mode"] == "assault" and not el["task"].is_empty():
		return w.level.inward(el["task"]["door"], el["task"]["into"]).angle()
	var v := Vector2.ZERO
	for m in al:
		v += Vector2.from_angle(m.spawn_face if el["mode"] == "hold" else m.body_dir)
	return v.angle()


## GD05 bounding overwatch inside each element: odd slots (1, 3, 5) and even slots (2, 4)
## alternate. One half moves while the other is static and covering.
func _bounding(el: Dictionary, al: Array) -> void:
	var movers: Array = [[], []]
	for m in al:
		if m.has("GD05") and w.level.is_exterior(w.level.room_at(m.pos)):
			movers[m.eslot % 2].append(m)
	var phase_ok: bool = el["mode"] == "hunt" or el["mode"] == "support" or (el["mode"] == "assault" and el["phase"] == "approach")
	if movers[0].is_empty() or movers[1].is_empty() or not phase_ok:
		el["bound"] = -1
		return
	var cur: int = el["bound"]
	if cur < 0:
		el["bound"] = 0
		el["bound_from"] = _centre(movers[0])
		el["bound_t"] = w.t
		return
	var grp: Array = movers[cur]
	var any_moving := false
	for m in grp:
		if m.moving:
			any_moving = true
	var done: bool = _centre(grp).distance_to(el["bound_from"]) > 4.5 or w.t - el["bound_t"] > 4.0
	if w.t - el["bound_t"] > 0.8 and not any_moving:
		done = true
	if done:
		var nxt := 1 - cur
		el["bound"] = nxt
		el["bound_from"] = _centre(movers[nxt])
		el["bound_t"] = w.t


func _centre(ms: Array) -> Vector2:
	var c := Vector2.ZERO
	for m in ms:
		c += m.pos
	return c / maxf(1.0, ms.size())


func _room_done(tm: Dictionary, el: Dictionary, what: String) -> void:
	var into: String = el["task"]["into"]
	tm["cleared"][into] = true
	w.say("%s: %s %s" % [_tag(tm, el), w.level.rooms[into]["title"].to_lower(), what], "info")
	el["last_room"] = into
	_next_task(tm, el)


func _assault_tick(tm: Dictionary, el: Dictionary, al: Array) -> void:
	if el["task"].is_empty():
		if w.t >= el["retask_t"]:
			el["retask_t"] = w.t + 1.0
			_next_task(tm, el)
		return
	var st: Dictionary = el["task"]
	var entry: Dictionary = el["entry"]
	var ctl: Dictionary = el["ctl"]
	for m in al:
		if not entry.has(m.id):
			_add_to_entry(el, m)
	match el["phase"]:
		"check":
			if ctl.has("check_done_t") and w.t >= ctl["check_done_t"]:
				_room_done(tm, el, "checked")
			elif w.t - el["phase_t"] > 12.0:
				el["last_room"] = st["into"]
				tm["skipped"][st["into"]] = true
				_next_task(tm, el)
		"approach":
			var all_ready := true
			var any_ready := false
			var rusher := false
			var all_gd01 := true
			for m in al:
				var d: Dictionary = entry[m.id]
				if d["ready"]:
					any_ready = true
				else:
					all_ready = false
				if m.hb("BH11") and d["at_stack"]:
					rusher = true
				if not m.has("GD01"):
					all_gd01 = false
			var go := false
			if rusher:
				go = true
			elif all_gd01 and al.size() > 1:
				go = all_ready or (any_ready and w.t - ctl.get("first_ready_t", w.t) > 6.0)
			else:
				go = any_ready
			if w.t - el["phase_t"] > 45.0:
				go = true
			if go:
				el["phase"] = "entry"
				el["phase_t"] = w.t
				w.say("%s enters the %s" % [_tag(tm, el), w.level.rooms[st["into"]]["title"].to_lower()], "info")
		"entry":
			var done := true
			for m in al:
				if entry[m.id]["enters"] and not entry[m.id]["arrived"]:
					done = false
			if done or w.t - el["phase_t"] > 9.0:
				el["phase"] = "clear"
				el["phase_t"] = w.t
		"clear":
			var quiet := true
			for m in al:
				if not w.visible_enemies(m).is_empty():
					quiet = false
			if quiet and w.t - el["phase_t"] > 1.2:
				if w.level.needs_sweep(st["into"]):
					el["phase"] = "sweep"
					el["phase_t"] = w.t
					el["sweep"] = _sweep_points(st["into"])
					w.say("%s sweeps the %s" % [_tag(tm, el), w.level.rooms[st["into"]]["title"].to_lower()], "info")
				else:
					_room_done(tm, el, "clear")
		"sweep":
			if tick % 15 == 0:
				_prune_sweep(el, al)
			if el["sweep"].is_empty() or w.t - el["phase_t"] > 120.0:
				_room_done(tm, el, "clear")


## Big rooms are swept: a lattice of points about 5 m apart that each must be seen from
## within 12 m by someone in the element before the room counts as clear.
func _sweep_points(into: String) -> Array:
	var pts: Array = []
	for rv in w.level.rooms[into]["rects"]:
		var r: Rect2 = rv
		var nx := maxi(1, int(round(r.size.x / 5.0)))
		var ny := maxi(1, int(round(r.size.y / 5.0)))
		for i in nx:
			for j in ny:
				var p := r.position + Vector2((i + 0.5) * r.size.x / nx, (j + 0.5) * r.size.y / ny)
				var q: Vector2 = w.nav.snap(p)
				if w.level.room_at(q) == into:
					pts.append(q)
	return pts


func _prune_sweep(el: Dictionary, al: Array) -> void:
	var keep: Array = []
	for p in el["sweep"]:
		var seen := false
		for m in al:
			if m.pos.distance_to(p) < 12.0 and w.geom.sight_clear(m.pos, m.eye(), p, 1.0):
				seen = true
				break
		if not seen:
			keep.append(p)
	el["sweep"] = keep
	var tg = el["sweep_target"]
	if tg != null and not keep.has(tg):
		el["sweep_target"] = null

# ================================================================== individual
var fine := false   # fine-grained profiling into w.prof


func think(o) -> void:
	if not fine:
		_think(o)
		return
	var t0 := Time.get_ticks_usec()
	var tm0: Dictionary = w.teams[o.team]
	var md: String = tm0["elements"][o.el]["mode"] if o.el >= 0 and o.el < tm0["elements"].size() else "?"
	_think(o)
	var k: String = "th_" + md + ("_" + o.dbg.split(" ")[0] if o.dbg != "" else "")
	w.prof[k] = w.prof.get(k, 0) + Time.get_ticks_usec() - t0


func _think(o) -> void:
	o.dbg = ""
	o.stance_goal = Op.STAND if not o.leg_hit or o.stance_goal != Op.CROUCH else Op.CROUCH
	var tm: Dictionary = w.teams[o.team]
	var el: Dictionary = tm["elements"][o.el]
	# PF09: keep a fallback cover point cached while threats are known
	if o.has("PF09") and w.t >= o.ticker.get("cover_next", 0.0):
		o.ticker["cover_next"] = w.t + 0.5
		var th := _threats(o)
		if not th.is_empty():
			var sig: Vector2 = o.pos.snapped(Vector2(1, 1))
			for tp in th:
				sig += (tp as Vector2).snapped(Vector2(1, 1)) * 0.001
			var cache: Dictionary = o.ticker.get("cover_cache", {})
			if cache.is_empty() or cache.get("sig", Vector2.INF) != sig or w.t - cache["t"] > 2.0:
				o.ticker["cover_cache"] = {"p": _find_cover(o, th, true), "t": w.t, "sig": sig}
			else:
				cache["t"] = w.t
	# blocking reactions
	if o.ticker.get("flinch_until", -1.0) > w.t:
		o.dbg = "flinch"
		o.stance_goal = Op.DUCK
		return
	if o.hb("BH07") and o.ticker.get("near_t", -9.0) > o.ticker.get("last_flinch", -9.0) + 0.9:
		o.ticker["last_flinch"] = w.t
		o.ticker["flinch_until"] = w.t + 0.8
		o.look_goal = o.look_dir + PI * 0.6
		o.aim = {}
		w.stop(o)
		o.stance_goal = Op.DUCK
		w.say("%s flinches and turtles" % o.id, "bad")
		return
	if not o.action.is_empty() and o.ticker.get("duck_action", false):
		o.stance_goal = Op.DUCK
	if o.action.is_empty():
		o.ticker["duck_action"] = false
	if o.ticker.get("freeze_until", -1.0) > w.t:
		o.dbg = "FROZEN"
	# BH09: shoots at half-recognized movement, and sometimes at friends
	if o.hb("BH09") and _jumpy(o):
		return
	# P1: Rule 1
	var close = _close_threat(o)
	if close != null:
		_rule1(o, close)
		return
	# retreat (city): a gang member who broke on seeing the police runs for safety
	var rt: Dictionary = o.ticker.get("retreat", {})
	if not rt.is_empty():
		if w.t > rt["until"] or w.at(o, rt["p"], 1.5):
			o.ticker.erase("retreat")
		else:
			o.dbg = "RETREATING"
			o.aim = {}
			w.move_to(o, rt["p"], "sprint")
			_finish_look(o)
			return
	# P2: Rule 2
	var s: Dictionary = o.ws()
	if s["mag"] <= 0 or s["lost"]:
		_rule2(o)
		return
	# P3: stoppage
	if s["jam"]:
		_stoppage(o)
		return
	# BH05: panic reload whenever firing stops
	if o.hb("BH05") and o.action.is_empty() and s["mag"] < o.wpn()["mag"] and s["spare"] > 0:
		var since: float = w.t - o.last_shot_t
		if since >= 0.5 and since < 6.0:
			_reload(o, o.active, false)
			w.say("%s panic-reloads in the open" % o.id, "bad")
			return
	# P4: engage beyond 10 m
	var far = _far_target(o)
	if far == null and o.ticker.has("far_dest") and _to_far_dest(o):
		return
	if far != null:
		_engage_far(o, far)
		return
	# police rules: cuff anyone close by who has given up (v0.6)
	if o.judges and _arrest(o):
		_finish_look(o)
		return
	# fixation on a body (no ED05)
	if o.ticker.get("fixate_until", -1.0) > w.t:
		o.dbg = "staring at body"
		w.stop(o)
		o.look_goal = (o.ticker["fixate_p"] - o.pos).angle()
		return
	# P5 react
	if _react(o, tm):
		_finish_look(o)
		return
	# P6 maintain
	if _maintain(o):
		_finish_look(o)
		return
	# P7 task
	match el["mode"]:
		"assault":
			_task_assault(o, tm, el)
		"hold":
			_task_hold(o)
		"hunt":
			_task_hunt(o, tm, el)
		"support":
			_task_support(o, tm, el)
		"transit":
			_task_transit(o, el)
		_:
			w.stop(o)
			o.dbg = "waiting"
	_finish_look(o)


# ------------------------------------------------------------------ Rule 1
func _close_threat(o):
	var best = null
	var best_d := 10.0001
	var cur: String = o.aim.get("tid", "")
	var cur_d := INF
	for e in w.visible_tracked(o):
		if not e.alive():
			var until: float = o.ticker.get("confirm_" + e.id, -1.0)
			if until < 0.0 and cur == e.id:
				until = e.ticker.get("down_t", w.t) + (0.15 if o.has("ED05") else 0.6) + (1.0 if o.hb("BH03") else 0.0)
				o.ticker["confirm_" + e.id] = until
			if w.t > until:
				if until > 0.0 and not o.ticker.has("assessed_" + e.id):
					o.ticker["assessed_" + e.id] = true
					if not o.has("ED05"):
						o.ticker["fixate_until"] = w.t + w.rng.randf_range(1.0, 2.0)
						o.ticker["fixate_p"] = e.pos
				continue
		var d: float = o.pos.distance_to(e.pos)
		if d > 10.0:
			continue
		if e.id == cur:
			cur_d = d
		if d < best_d:
			best_d = d
			best = e
	if best != null and cur != "" and cur_d <= 10.0 and best.id != cur and best_d > cur_d - 0.5:
		return w.op_by_id(cur)
	return best


func _rule1(o, e) -> void:
	var tm: Dictionary = w.teams[o.team]
	tm["last_contact"] = w.t
	o.last_contact_t = w.t
	o.dbg = "RULE 1 > " + e.id
	o.look_goal = (e.pos - o.pos).angle()
	if not o.action.is_empty() and o.action["type"] in ["check", "stall"]:
		o.action = {}
	if not o.action.is_empty():
		return
	var s: Dictionary = o.ws()
	if s["mag"] <= 0 or s["lost"]:
		if o.usable(o.other()):
			_transition(o)
		else:
			_rule2(o)
		return
	if s["jam"]:
		if o.active == "rifle" and o.has("WD06") and o.usable("pistol"):
			w.say("%s: stoppage inside 10 m, transitions to pistol" % o.id, "rule")
			_transition(o)
		else:
			_clear(o)
		return
	if o.has("PF07") and o.sidestep.is_empty() and not o.ticker.has("pf07_" + e.id) and e.alive():
		o.ticker["pf07_" + e.id] = true
		var b: float = (e.pos - o.pos).angle()
		var best_dir := Vector2.ZERO
		var best_s := INF
		for sgn in [1.0, -1.0]:
			var dv := Vector2.from_angle(b + PI / 2.0 * sgn)
			if not w.nav.is_free(o.pos + dv * 1.2):
				continue
			if not w.geom.sight_clear(o.pos + dv * 1.2, o.eye(), e.pos, e.zone_centre("chest")):
				continue
			var sc: float = w.geom.dist_to_kinds(o.pos + dv * 1.2, [Geom.COVER, Geom.WALL], 3.0)
			if sc < best_s:
				best_s = sc
				best_dir = dv
		if best_dir != Vector2.ZERO:
			o.sidestep = {"dir": best_dir, "left": 1.0}
	if o.sidestep.is_empty():
		w.stop(o)
	w.engage(o, e, _aim_zone(o, e), true)


func _aim_zone(o, e) -> String:
	if not e.alive():
		return "chest"
	if o.hb("BH19"):
		return "chest"
	if o.has("WD08") and o.aim.get("plate_seen", false) and o.aim.get("tid", "") == e.id:
		var d: float = maxf(o.pos.distance_to(e.pos), 0.5)
		var w_head := 2.0 * atan(0.11 / d) * 1000.0
		if w.sigma_shooter(o, 0.3) <= 0.5 * w_head:
			return "head"
		return "abd"
	return "chest"


# ------------------------------------------------------------------ Rule 2 and weapon handling
func _transition(o) -> void:
	if not o.action.is_empty():
		return
	var other: String = o.other()
	if not o.usable(other):
		return
	if o.ws()["mag"] <= 0 and not o.has("WD01") and not o.ticker.get("clicked", false):
		w.start_action(o, "click", 0.4)
		return
	o.ticker["clicked"] = false
	w.start_action(o, "transition", o.ech["transition"], {"to": other})
	w.say("%s transitions to %s (Rule 2)" % [o.id, other], "rule")


func _rule2(o) -> void:
	o.dbg = "RULE 2"
	if not o.action.is_empty():
		return
	if o.usable(o.other()):
		_transition(o)
		return
	var threats := _threats(o)
	var which := _reload_choice(o)
	if which == "":
		o.dbg = "out of ammo"
		_seek_cover(o, threats)
		return
	if threats.is_empty() or _hidden(o.pos, threats, 0.82):
		w.stop(o)
		if not threats.is_empty():
			o.stance_goal = Op.DUCK
			o.ticker["duck_action"] = true
		o.ticker.erase("cover_wait")
		_reload(o, which, true)
		return
	_seek_cover(o, threats)


func _seek_cover(o, threats: Array) -> void:
	if threats.is_empty():
		return
	var dest = _cover_point(o, threats)
	if dest == null:
		o.dbg += " (finding cover)"
		w.stop(o)
		return
	o.dbg += " > cover"
	var prof := 0 if o.hb("BH10") else -1
	if not w.at(o, dest, 0.3):
		w.move_to(o, dest, "run", prof)
	else:
		w.stop(o)
		o.stance_goal = Op.DUCK
	var lk = _latest_lkp(o)
	if lk != null:
		o.look_goal = (lk["p"] - o.pos).angle()


func _reload_choice(o) -> String:
	if not o.weapons["rifle"]["lost"] and o.weapons["rifle"]["spare"] > 0:
		return "rifle"
	if o.weapons["pistol"]["spare"] > 0:
		return "pistol"
	return ""


func _reload(o, which: String, from_rule2: bool) -> void:
	var dur: float = Habits.WEAPONS[which]["reload"] * o.ech["reload"]
	if which != o.active:
		dur += o.ech["transition"]
	w.start_action(o, "reload", dur, {"w": which})
	if from_rule2:
		w.say("%s reloads %s behind cover" % [o.id, which], "rule")


func _clear(o) -> void:
	if not o.action.is_empty():
		return
	var dur := 0.0
	var p_ok := 0.8
	if o.hb("BH19"):
		dur = 3.0
		p_ok = 0.95
	elif o.has("WD05"):
		dur = 1.2
		p_ok = 0.95
	else:
		dur = w.rng.randf_range(2.5, 4.0)
	w.start_action(o, "clear", dur, {"p_ok": p_ok})


func _stoppage(o) -> void:
	o.dbg = "stoppage"
	if not o.action.is_empty():
		return
	var threats := _threats(o)
	if o.has("WD03") and not threats.is_empty() and not _hidden(o.pos, threats, 0.82):
		_seek_cover(o, threats)
		return
	w.stop(o)
	if not threats.is_empty():
		o.stance_goal = Op.DUCK
		o.ticker["duck_action"] = true
	_clear(o)


## Positions of the threats an operator knows about: seen now, or last seen within 15 s.
## Only the nearest five within 40 m count (cover is chosen against what matters).
func _threats(o) -> Array:
	var out: Array = []
	for eid in o.lkp:
		var e = w.by_id.get(eid, null)
		if e == null or not e.alive():
			continue
		if w.visible(o, e):
			out.append(e.pos)
		elif w.t - o.lkp[eid]["t"] < 15.0:
			out.append(o.lkp[eid]["p"])
	if out.size() > 1:
		out = out.filter(func(p): return o.pos.distance_to(p) <= 40.0)
		if out.size() > 5:
			out.sort_custom(func(a, b): return o.pos.distance_squared_to(a) < o.pos.distance_squared_to(b))
			out.resize(5)
	return out


func _hidden(p: Vector2, threats: Array, head_z: float) -> bool:
	for tp in threats:
		if w.geom.sight_clear(tp, 1.65, p, head_z):
			return false
	return true


func _cover_point(o, threats: Array):
	if o.has("PF09"):
		var cache: Dictionary = o.ticker.get("cover_cache", {})
		if not cache.is_empty() and cache["p"] != null and w.t - cache["t"] < 0.8:
			return cache["p"]
		return _find_cover(o, threats, true)
	if o.ticker.has("cover_dest") and w.t - o.ticker["cover_dest_t"] < 3.0:
		return o.ticker["cover_dest"]
	if not o.ticker.has("cover_wait"):
		o.ticker["cover_wait"] = w.t + 0.4
		return null
	if w.t < o.ticker["cover_wait"]:
		return null
	var p = _find_cover(o, threats, false)
	o.ticker["cover_dest"] = p
	o.ticker["cover_dest_t"] = w.t
	return p


func _find_cover(o, threats: Array, smart: bool):
	var cands: Array = w.nav.spots_near(o.pos, 12.0)
	var best = null
	var best_s := INF
	var n := 0
	for item in cands:
		n += 1
		var d := sqrt(item[0])
		if n > 60 or d >= best_s:
			break
		var c: Dictionary = item[1]
		var p: Vector2 = c["p"]
		if not _hidden(p, threats, 0.82):
			continue
		var sc := d
		if smart:
			sc += 2.5 * _route_exposure(o.pos, p, threats)
			if o.has("PF05"):
				sc += 2.0 * absf(c["gap"] - 1.0)
		else:
			sc += 0.3 * c["gap"]
		if sc < best_s:
			best_s = sc
			best = p
	return best


func _route_exposure(a: Vector2, b: Vector2, threats: Array) -> float:
	var n := 0.0
	for k in range(1, 5):
		var p := a.lerp(b, k / 5.0)
		for tp in threats:
			if w.geom.sight_clear(tp, 1.65, p, 1.3):
				n += 1.0
				break
	return n


# ------------------------------------------------------------------ arrests (v0.6)
## The nearest person who has given up and is not yet cuffed, within 20 m and in sight,
## that no other officer is already cuffing: walk up and cuff them (3 s).
func _arrest(o) -> bool:
	if not o.action.is_empty():
		return o.action.get("type", "") == "cuff"
	var best = null
	var bd := 20.0
	for e in w.ops:
		if not e.complying or e.arrested or not e.alive():
			continue
		var by: String = e.ticker.get("cuff_by", "")
		if by != "" and by != o.id:
			var other = w.by_id.get(by, null)
			if other != null and other.alive() and w.t - e.ticker.get("cuff_t", -99.0) < 30.0:
				continue
		var d: float = o.pos.distance_to(e.pos)
		if d < bd and (d < 3.0 or w.geom.sight_clear(o.pos, o.eye(), e.pos, 0.8)):
			bd = d
			best = e
	if best == null:
		return false
	if best.ticker.get("cuff_by", "") != o.id:
		w.say("%s moves in to cuff %s" % [o.id, best.id], "comms")
	best.ticker["cuff_by"] = o.id
	best.ticker["cuff_t"] = w.t
	o.dbg = "ARREST > " + best.id
	o.look_goal = (best.pos - o.pos).angle()
	if bd > 0.95:
		var side: Vector2 = (o.pos - best.pos).normalized()
		var spot: Vector2 = best.pos + side * 0.75
		w.move_to(o, spot if w.nav.is_free(spot) else best.pos, "walk")
		return true
	w.stop(o)
	w.start_action(o, "cuff", 3.0, {"tid": best.id})
	return true


# ------------------------------------------------------------------ BH09
func _jumpy(o) -> bool:
	if not o.usable(o.active) or not o.action.is_empty():
		return false
	for eid in o.vis:
		var e = w.by_id.get(eid, null)
		if e == null or not e.alive() or w.visible(o, e) or not w.attends(o, e):
			continue
		var p: float = o.rec.get(e.id, 0.0)
		if p >= 0.5 and o.vis.get(e.id, {}).get("los", false) and o.pos.distance_to(e.pos) <= 10.0 and e.vel.length() > 0.3:
			o.dbg = "jumpy trigger > " + e.id
			o.look_goal = (e.pos - o.pos).angle()
			w.stop(o)
			# fires before knowing who it is: friend, foe or a civilian running
			w.engage(o, e, "chest", true, true)
			return true
	for m in w.mates_near(o, 4.0):
		var d: Vector2 = m.pos - o.pos
		if d.length() < 4.0 and m.vel.length() > 0.5 and absf(angle_difference(o.look_dir, d.angle())) < deg_to_rad(40.0):
			if w.rng.randf() < 0.05 * DT and o.ws()["mag"] > 0:
				w.say("%s startles and fires at %s" % [o.id, m.id], "bad")
				w._fire(o, d.angle(), 1.3, d.length(), 0.0)
	return false


# ------------------------------------------------------------------ P4
func _far_target(o):
	var vis: Array = w.visible_enemies(o)
	if vis.is_empty():
		return null
	var cur: String = o.aim.get("tid", "")
	if o.has("ED04"):
		var team_pos: Array = [o.pos]
		for m in w.mates_of(o):
			team_pos.append(m.pos)
		for e in vis:
			for tp in team_pos:
				if absf(angle_difference(e.muzzle_dir, (tp - e.pos).angle())) < deg_to_rad(20.0):
					return e
	elif o.hb("BH16"):
		var best = null
		var best_s := INF
		for e in vis:
			var sc: float = o.pos.distance_to(e.pos) + (20.0 if o.vis[e.id].get("head_only", false) else 0.0)
			if sc < best_s:
				best_s = sc
				best = e
		return best
	for e in vis:
		if e.id == cur:
			return e
	var first = vis[0]
	for e in vis:
		if o.first_rec.get(e.id, 0.0) < o.first_rec.get(first.id, 0.0):
			first = e
	return first


func _engage_far(o, e) -> void:
	var tm: Dictionary = w.teams[o.team]
	tm["last_contact"] = w.t
	o.last_contact_t = w.t
	o.dbg = "engage > " + e.id
	o.look_goal = (e.pos - o.pos).angle()
	if not o.action.is_empty():
		return
	if o.hb("BH13") and o.hide_until > w.t:
		o.dbg = "hiding"
		o.stance_goal = Op.DUCK
		w.stop(o)
		return
	# under fire at range, trained shooters move to a fighting position: hidden when
	# ducked, able to shoot over the cover when crouched
	var key: String = "farcover_" + e.id
	var under_fire: bool = w.t - o.last_stress_t < 1.5
	if (o.has("PF05") or o.has("PF09")) and under_fire and not o.ticker.has(key):
		o.ticker[key] = true
		if not _hidden(o.pos, [e.pos], 0.82):
			var dest = _fighting_position(o, e)
			if dest != null:
				o.ticker["far_dest"] = dest
				o.ticker["far_until"] = w.t + 3.0
	if o.ticker.has("far_dest") and _to_far_dest(o):
		return
	# PF08: come up somewhere new after reloading or clearing behind cover
	if o.ticker.get("reengage", false):
		o.ticker["reengage"] = false
		if o.has("PF08") and o.last_exposure != Vector2.INF:
			var spot = _new_spot(o, e)
			if spot != null:
				o.ticker["far_dest"] = spot
				return
	if o.hb("BH15") and o.pos.distance_to(e.pos) > 6.0:
		w.move_to(o, e.pos, "walk")
	else:
		w.stop(o)
	# fire over half cover from a crouch
	if o.ticker.get("stance_t", -1.0) < w.t:
		o.ticker["stance_t"] = w.t + 0.5
		var hidden_ducked: bool = not w.geom.sight_clear(e.pos, e.eye(), o.pos, 0.82)
		var seen_crouched: bool = w.geom.sight_clear(e.pos, e.eye(), o.pos, 1.125)
		o.ticker["crouch"] = hidden_ducked and seen_crouched
	if o.ticker.get("crouch", false):
		o.stance_goal = Op.CROUCH
	o.last_exposure = o.pos
	if o.hb("BH13"):
		o.hide_until = maxf(o.hide_until, o.last_stress_t + 3.0) if w.t - o.last_stress_t < 0.2 else o.hide_until
	w.engage(o, e, _aim_zone(o, e), true)


func _fighting_position(o, e):
	var best = null
	var best_s := INF
	for item in w.nav.spots_near(o.pos, 4.0):
		var c: Dictionary = item[1]
		var p: Vector2 = c["p"]
		var d: float = sqrt(item[0])
		if d >= best_s:
			break
		if w.geom.sight_clear(e.pos, e.eye(), p, 0.82):
			continue
		if not w.geom.sight_clear(e.pos, e.eye(), p, 1.125):
			continue
		var sc: float = d + (2.0 * absf(c["gap"] - 1.0) if o.has("PF05") else 0.5 * c["gap"])
		if sc < best_s:
			best_s = sc
			best = p
	return best


## Keep moving to a chosen fighting position for up to 3 s, even if sight is lost on
## the way; on arrival, hold it for a moment instead of drifting back to the task.
func _to_far_dest(o) -> bool:
	var dest: Vector2 = o.ticker["far_dest"]
	if w.at(o, dest, 0.3) or w.t > o.ticker.get("far_until", 0.0):
		o.ticker.erase("far_dest")
		o.ticker["hold_pos_until"] = w.t + 2.5
		return false
	w.move_to(o, dest, "run")
	o.dbg = "to fighting position"
	var lk = _latest_lkp(o)
	if lk != null:
		o.look_goal = (lk["p"] - o.pos).angle()
	return true


func _new_spot(o, e):
	for item in w.nav.spots_near(o.pos, 4.0):
		var c: Dictionary = item[1]
		var p: Vector2 = c["p"]
		var d: float = sqrt(item[0])
		if d < 1.5 or p.distance_to(o.last_exposure) < 1.5:
			continue
		if w.geom.sight_clear(e.pos, e.eye(), p, 1.3):
			return p
	return null


# ------------------------------------------------------------------ P5 react
func _react(o, tm: Dictionary) -> bool:
	var lk = _latest_lkp(o)
	if o.ticker.get("hold_pos_until", -1.0) > w.t and lk != null:
		o.dbg = "holding fighting position"
		w.stop(o)
		o.stance_goal = Op.CROUCH
		o.look_goal = (lk["p"] - o.pos).angle()
		return true
	if o.hb("BH13") and w.t - o.last_contact_t < 3.0:
		o.dbg = "hiding"
		o.stance_goal = Op.DUCK
		w.stop(o)
		return true
	if o.hb("BH12") and lk != null and w.t - lk["t"] > 0.3 and w.t - lk["t"] < 15.0 and o.pos.distance_to(lk["p"]) > 1.2:
		o.dbg = "chasing contact"
		w.move_to(o, lk["p"], "sprint")
		o.look_goal = (lk["p"] - o.pos).angle()
		_task_look(o, o.look_goal)
		return true
	if o.has("ED08") and lk != null and w.t - lk["t"] < 3.0 and w.t - lk["t"] > 0.05:
		o.dbg = "holding last-known position"
		w.stop(o)
		var dir: float = (lk["p"] - o.pos).angle()
		_task_look(o, dir)
		o.muzzle_dir = rotate_toward(o.muzzle_dir, dir, deg_to_rad(o.ech["turn"]) * DT)
		return true
	if o.hb("BH15"):
		var tl = _team_lkp(tm, 15.0, o.pos)
		if tl != null and o.pos.distance_to(tl) > 1.5 and not _stuck_on(o, tl):
			o.dbg = "lone wolf push"
			w.move_to(o, tl, "walk")
			return true
	return false


func _latest_lkp(o):
	var best = null
	for eid in o.lkp:
		var e2 = w.by_id.get(eid, null)
		if e2 == null or not e2.alive():
			continue
		var l: Dictionary = o.lkp[eid]
		if best == null or l["t"] > best["t"]:
			best = l
	return best


func _team_lkp(tm: Dictionary, within: float, from: Vector2):
	var best = null
	var bt := -INF
	for eid in tm["lkps"]:
		var e = w.op_by_id(eid)
		if e == null or not e.alive():
			continue
		var l: Dictionary = tm["lkps"][eid]
		if l["t"] > bt and from.distance_to(l["p"]) <= within:
			bt = l["t"]
			best = l["p"]
	return best


# ------------------------------------------------------------------ P6 maintain
func _maintain(o) -> bool:
	if not o.action.is_empty():
		o.dbg = o.action["type"]
		return true
	var lull: float = w.t - o.last_enemy_seen_t
	var s: Dictionary = o.ws()
	var cap: int = o.wpn()["mag"]
	var want := ""
	if o.active == "pistol" and lull > 3.0:
		if o.weapons["rifle"]["mag"] > 0 and not o.weapons["rifle"]["lost"] and not o.weapons["rifle"]["jam"]:
			if o.has("WD02") and s["mag"] < cap and s["spare"] > 0:
				want = "pistol"
			else:
				w.start_action(o, "transition", o.ech["transition"], {"to": "rifle"})
				return true
		elif not o.weapons["rifle"]["lost"] and o.weapons["rifle"]["spare"] > 0:
			want = "rifle"
	elif o.has("WD02") and lull > 2.0 and s["mag"] < int(cap * 0.4) and s["spare"] > 0:
		want = o.active
	if want == "":
		return false
	var threats := _threats(o)
	if o.has("WD03") and not threats.is_empty() and not _hidden(o.pos, threats, 0.82):
		o.dbg = "to cover to reload"
		_seek_cover(o, threats)
		return true
	w.stop(o)
	_reload(o, want, false)
	return true


# ------------------------------------------------------------------ P7 tasks
func _go(o, p: Vector2, mode: String, group := true) -> void:
	var el := _el(o)
	var mates: Array = _el_mates(o)
	var outside: bool = w.level.is_exterior(o.room)
	if group and not mates.is_empty():
		var near = mates[0]
		for m in mates:
			if m.pos.distance_to(o.pos) < near.pos.distance_to(o.pos):
				near = m
		if o.has("GD10") and o.pos.distance_to(near.pos) > 8.0 and (p - o.pos).dot(near.pos - o.pos) < 0.0:
			o.dbg = "waiting (tether)"
			w.stop(o)
			return
		if el["bound"] >= 0 and o.eslot % 2 != el["bound"] and outside and o.has("GD05"):
			o.dbg = "overwatch"
			w.stop(o)
			_task_look(o, (p - o.pos).angle())
			return
		if o.hb("BH14") and o.pos.distance_to(near.pos) > 1.0 and near.pos.distance_to(p) > 2.0:
			p = near.pos + (o.pos - near.pos).limit_length(0.8)
		elif o.has("GD07"):
			var ahead: Vector2 = near.pos - o.pos
			if ahead.length() < 1.5 and ahead.dot(p - o.pos) > 0.0 and near.vel.length() > 0.2:
				o.dbg = "keeping spacing"
				w.stop(o)
				return
		if o.has("GD03") and _in_line_of_fire(o, w.mates_near(o, 7.0)):
			if o.ticker.get("gd03_wait", -1.0) < 0.0:
				o.ticker["gd03_wait"] = w.t
			if w.t - o.ticker["gd03_wait"] < 1.0:
				o.dbg = "not crossing line of fire"
				w.stop(o)
				return
		else:
			o.ticker["gd03_wait"] = -1.0
	var m2 := mode
	if outside and (mode == "walk" or mode == "clear"):
		m2 = "walk"
		if o.has("PF06") and _open_ground(o):
			var sp: float = o.ticker.get("sprint_s", 0.0)
			if sp < 3.0:
				m2 = "sprint"
				o.ticker["sprint_s"] = sp + DT
			elif sp < 3.4:
				o.ticker["sprint_s"] = sp + DT
				w.stop(o)
				o.dbg = "between rushes"
				return
			else:
				o.ticker["sprint_s"] = 0.0
		if o.has("PF02") and _near_window(o.pos):
			m2 = "creep"
			o.stance_goal = Op.DUCK
	w.move_to(o, p, m2)


## A teammate's muzzle line is live while they are aiming or have fired in the last
## 1.5 s; an overwatcher who is only scanning keeps the muzzle off friends.
func _in_line_of_fire(o, mates: Array) -> bool:
	for m in mates:
		if m.aim.is_empty() and w.t - m.last_shot_t > 1.5:
			continue
		var u := Vector2.from_angle(m.muzzle_dir)
		var rel: Vector2 = (o.pos + o.vel.normalized() * 0.4) - m.pos
		var s := rel.dot(u)
		if s > 0.3 and s < 6.0 and absf(rel.cross(u)) < 0.45:
			return true
	return false


func _open_ground(o) -> bool:
	if o.ticker.get("open_t", -1.0) < w.t:
		o.ticker["open_t"] = w.t + 0.25
		o.ticker["open"] = w.geom.dist_to_kinds(o.pos, [Geom.COVER, Geom.WALL], 3.0) >= 2.9
	return o.ticker["open"]


func _near_window(p: Vector2) -> bool:
	for i in w.level.openings_near(p, 1.4):
		if w.level.openings[i]["kind"] == "window" and not w.level.is_inside(p):
			return true
	return false


func _task_look(o, dir: float) -> void:
	o.ticker["task_look"] = dir
	o.ticker["task_look_tick"] = tick


func _task_assault(o, tm: Dictionary, el: Dictionary) -> void:
	if el["task"].is_empty():
		w.stop(o)
		return
	var st: Dictionary = el["task"]
	var D: Dictionary = w.level.doors[st["door"]]
	var c: Vector2 = D["c"]
	var n_in: Vector2 = w.level.inward(st["door"], st["into"])
	var entry: Dictionary = el["entry"]
	var ctl: Dictionary = el["ctl"]
	if not entry.has(o.id):
		return
	var d: Dictionary = entry[o.id]
	match el["phase"]:
		"check":
			if not ctl.has("checker"):
				var best = null
				for m in _alive(el):
					if m.has("PF10") and (best == null or m.pos.distance_to(c) < best.pos.distance_to(c)):
						best = m
				ctl["checker"] = best.id if best != null else ""
			if ctl["checker"] == o.id:
				var cp: Vector2 = w.nav.snap(c - n_in * 1.1 + D["t"] * 0.35)
				o.dbg = "checking the " + w.level.rooms[st["into"]]["title"].to_lower()
				if not w.at(o, cp, 0.3):
					_go(o, cp, "clear", false)
					_task_look(o, (c - o.pos).angle())
				else:
					w.stop(o)
					_task_look(o, (c + n_in * 1.6 - o.pos).angle())
					if not ctl.has("check_done_t"):
						ctl["check_done_t"] = w.t + 1.0
			else:
				o.dbg = "covering the check"
				w.stop(o)
		"approach":
			var wps: Array = d["wps"]
			if d["wi"] < wps.size():
				var target: Vector2 = wps[d["wi"]]
				var slicing: bool = d["wi"] < wps.size() - 1
				var mode := "walk"
				if slicing and o.pos.distance_to(c) < 3.2:
					mode = "slice"
				if not w.level.is_inside(o.pos) and not slicing:
					mode = "walk"
				elif w.level.is_inside(o.pos):
					mode = "clear"
				if o.hb("BH11"):
					mode = "sprint"
				_go(o, target, mode)
				if slicing:
					o.dbg = "slicing the pie"
					_task_look(o, (c + n_in * 2.5 - o.pos).angle())
				if w.at(o, target, 0.35):
					d["wi"] += 1
			else:
				w.stop(o)
				d["at_stack"] = true
				if not d["checked"] and o.action.is_empty():
					d["checked"] = true
					w.start_action(o, "check", 1.0)
					w.say("%s function check" % o.id, "info")
				var look_in: float = (c + n_in * 2.5 - o.pos).angle()
				if o.has("ED10"):
					_task_look(o, look_in)
					if absf(angle_difference(o.look_dir, look_in)) < 0.3:
						d["looked"] += DT
				d["ready"] = d["checked"] and o.action.is_empty() and (not o.has("ED10") or d["looked"] >= 0.5)
				if d["ready"] and not ctl.has("first_ready_t"):
					ctl["first_ready_t"] = w.t
				o.dbg = "stacked" if o.has("GD01") else "waiting at the door"
		"sweep":
			_task_sweep(o, el)
		"entry", "clear":
			if not d["enters"]:
				var sp: Vector2 = d["stack"]
				if not w.at(o, sp, 0.35):
					_go(o, sp, "walk", false)
				else:
					w.stop(o)
				o.dbg = "rear security"
				if o.has("ED09"):
					_task_look(o, (-n_in).angle() + sin(w.t * 0.7 + o.slot) * 0.8)
				else:
					_task_look(o, (c + n_in * 2.0 - o.pos).angle())
				return
			if d["order"] > 0:
				var lead = null
				var lead_order := -1
				for m in _alive(el):
					if entry.has(m.id) and entry[m.id]["enters"] and entry[m.id]["order"] < d["order"] and entry[m.id]["order"] > lead_order:
						lead = m
						lead_order = entry[m.id]["order"]
				if lead != null:
					var depth: float = (lead.pos - c).dot(n_in)
					var ok := depth >= 0.0
					if o.has("GD07"):
						ok = lead.pos.distance_to(c) >= 1.4 or entry[lead.id]["arrived"]
					if not ok:
						w.stop(o)
						_task_look(o, (c + n_in * 2.0 - o.pos).angle())
						o.dbg = "waiting for #%d" % (lead_order + 1)
						return
			var depth_me: float = (o.pos - c).dot(n_in)
			var lateral: float = absf((o.pos - c).dot(D["t"]))
			var in_door := absf(depth_me) < 0.45 and lateral < 0.7
			if in_door and not d["paused"] and (not o.has("PF01") or o.hb("BH06")):
				d["paused"] = true
				var dur: float = 1.0 if o.hb("BH06") else w.rng.randf_range(1.0, 2.0)
				w.start_action(o, "stall", dur)
				w.say("%s stops in the doorway (%.1f s)%s" % [o.id, dur, " - BH06" if o.hb("BH06") else ""], "bad" if o.hb("BH06") else "info")
				_task_look(o, (w.level.rooms[st["into"]]["label"] - o.pos).angle())
				return
			var target: Vector2 = d["target"]
			if not w.at(o, target, 0.3):
				_go(o, target, "sprint" if o.hb("BH11") else "entry", false)
			else:
				w.stop(o)
				if not d["arrived"]:
					d["arrived"] = true
			if depth_me > -0.7:
				if not d.has("look_t0"):
					d["look_t0"] = w.t
				var since: float = w.t - d["look_t0"]
				if o.hb("BH20"):
					if not d["swept"]:
						d["swept"] = true
						o.ticker["sweep_until"] = w.t + 2.0
						o.ticker["sweep_from"] = n_in.angle() - PI / 2.0
						o.ticker["sweep_t0"] = w.t
						w.say("%s sweeps left to right (BH20)" % o.id, "bad")
				elif o.has("ED03") and since < 0.9:
					_task_look(o, (d["corner"] - o.pos).angle())
					o.dbg = "hard corner"
				elif since < 2.5 and el["phase"] == "entry":
					_task_look(o, (w.level.rooms[st["into"]]["label"] - o.pos).angle())


func _task_hold(o) -> void:
	var inv: Dictionary = o.ticker.get("investigate", {})
	if not inv.is_empty():
		if w.t > inv["until"] or w.at(o, inv["p"], 1.5):
			o.ticker.erase("investigate")
		else:
			o.dbg = "going after a sound"
			_go(o, inv["p"], "walk", false)
			_task_look(o, (inv["p"] - o.pos).angle())
			return
	if not w.at(o, o.spawn, 0.6):
		_go(o, o.spawn, "walk", false)
		o.dbg = "returning to post"
	else:
		w.stop(o)
		o.dbg = "holding"


## Progress watchdog for operators who should be closing on a point: true once they have
## gained less than 0.4 m on it for 8 s (blocked, unreachable, or circling), so the
## caller can give the point up.
func _stuck_on(o, p: Vector2) -> bool:
	var key := p.snapped(Vector2(0.5, 0.5))
	var d: float = o.pos.distance_to(p)
	var g: Dictionary = o.ticker.get("prog", {})
	if g.get("key", Vector2.INF) != key:
		o.ticker["prog"] = {"key": key, "best": d, "t": w.t}
		return false
	if d < g["best"] - 0.4:
		g["best"] = d
		g["t"] = w.t
		return false
	return w.t - g["t"] > 8.0


func _task_hunt(o, tm: Dictionary, el: Dictionary) -> void:
	var target = null
	var best_t: float = el["hunt_done_t"]
	var lk = _latest_lkp(o)
	if lk != null and lk["t"] > best_t:
		target = lk["p"]
		best_t = lk["t"]
	for eid in tm["lkps"]:
		var l: Dictionary = tm["lkps"][eid]
		var e = w.op_by_id(eid)
		if e != null and e.alive() and l["t"] > best_t:
			target = l["p"]
			best_t = l["t"]
	var snd: Dictionary = tm["sound"]
	if not snd.is_empty() and snd["t"] > best_t and w.t - snd["t"] < 40.0:
		target = snd["p"]
	var al := _alive(el)
	al.sort_custom(func(a, b): return a.eslot < b.eslot)
	var k := al.find(o)
	if target == null:
		var pts: Array = tm.get("patrol", w.level.patrol)
		if pts.is_empty():
			w.stop(o)
			return
		target = pts[el["hunt_i"] % pts.size()]
		if k == 0 and (w.at(o, target, 1.2) or _stuck_on(o, target)):
			el["hunt_i"] += 1
	elif k == 0 and (w.at(o, target, 1.5) or _stuck_on(o, target)):
		el["hunt_done_t"] = w.t
	o.dbg = "hunting"
	if k > 0:
		# followers take wedge slots behind the leader's objective: 1.5 m apart with GD07,
		# bunched at 0.6 m without it; recomputed only when the objective moves
		var key := str((target as Vector2).snapped(Vector2(1, 1)))
		if o.ticker.get("form_key", "") != key:
			o.ticker["form_key"] = key
			var lead = al[0]
			var to_t: Vector2 = target - lead.pos
			var dir: Vector2 = to_t.normalized() if to_t.length() > 0.5 else Vector2.from_angle(lead.body_dir)
			var sp := 1.5 if o.has("GD07") else 0.6
			var row := int((k + 1) / 2)
			var lat := 1.0 if k % 2 == 1 else -1.0
			o.ticker["form_p"] = w.nav.snap(target - dir * sp * row + dir.orthogonal() * sp * 0.8 * lat)
		target = o.ticker["form_p"]
	_go(o, target, "clear" if w.level.is_inside(o.pos) else "walk")


# ------------------------------------------------------------------ P8 eyes
func _finish_look(o) -> void:
	if fine:
		var t0 := Time.get_ticks_usec()
		_finish_look2(o)
		w.prof["look"] = w.prof.get("look", 0) + Time.get_ticks_usec() - t0
		return
	_finish_look2(o)


func _finish_look2(o) -> void:
	var tm: Dictionary = w.teams[o.team]
	if o.hb("BH04"):
		var lk = _latest_lkp(o)
		if lk != null:
			o.look_goal = (lk["p"] - o.pos).angle()
			return
	if o.ticker.get("sweep_until", -1.0) > w.t:
		o.look_goal = o.ticker["sweep_from"] + deg_to_rad(90.0) * (w.t - o.ticker["sweep_t0"])
		return
	var h: Dictionary = o.look_hint
	if not h.is_empty() and w.t >= h["start"] and w.t <= h["until"]:
		o.look_goal = h["dir"]
		return
	if o.ticker.get("task_look_tick", -1) == tick:
		o.look_goal = o.ticker["task_look"]
		return
	if o.has("ED09") and o.moving and _is_rear(o):
		if fmod(w.t + o.slot * 1.7, 4.0) < 1.0:
			o.look_goal = o.vel.angle() + PI
			return
	if o.has("ED02"):
		_scan(o, tm)
		return
	if o.moving and o.vel.length() > 0.3:
		o.look_goal = o.vel.angle()
		return
	if w.t >= o.ticker.get("salient_next", 0.0):
		o.ticker["salient_next"] = w.t + 2.0
		var best = null
		var bd := INF
		for oi in w.level.openings_near(o.pos, 15.0):
			var p: Vector2 = w.level.openings[oi]["c"]
			var d: float = o.pos.distance_to(p)
			if d > 0.8 and d < bd and w.geom.sight_clear(o.pos, o.eye(), p, 1.2):
				bd = d
				best = p
		o.ticker["salient"] = best
	var sal = o.ticker.get("salient", null)
	if sal != null:
		o.look_goal = (sal - o.pos).angle()
	else:
		o.look_goal = o.spawn_face if _el(o)["mode"] == "hold" else o.look_goal


func _is_rear(o) -> bool:
	var mates: Array = _el_mates(o)
	if mates.is_empty():
		return false
	var dir: Vector2 = o.vel.normalized()
	for m in mates:
		if (m.pos - o.pos).dot(dir) < 0.0:
			return false
	return true


func _scan(o, tm: Dictionary) -> void:
	var el := _el(o)
	var sector = el["sectors"].get(o.id, null)
	var half: float = el["sector_half"]
	if w.t < o.ticker.get("scan_next", 0.0):
		if sector != null and absf(angle_difference(o.look_goal, sector)) > half:
			o.look_goal = sector
		return
	o.ticker["scan_next"] = w.t + w.rng.randf_range(0.9, 1.5)
	var cands: Array = []
	for i in w.level.openings_near(o.pos, 24.0):
		var op: Dictionary = w.level.openings[i]
		var wt := 2.5
		if op["kind"] == "door":
			var D: Dictionary = w.level.doors[op["id"]]
			if el["mode"] == "assault" and _cleared_side(tm, D["a"]) and _cleared_side(tm, D["b"]):
				wt = 1.0
			else:
				wt = 3.0
		cands.append({"p": op["c"], "w": wt, "k": "o%d" % i})
	for cp in w.level.corners_by_room.get(o.room, []):
		cands.append({"p": cp, "w": 2.0, "k": "c%s" % str(cp)})
	for eid in o.lkp:
		var l: Dictionary = o.lkp[eid]
		if w.t - l["t"] < 30.0:
			cands.append({"p": l["p"], "w": 4.0, "k": "l" + eid})
	var best = null
	var best_s := -1.0
	for c in cands:
		var p: Vector2 = c["p"]
		var d: float = o.pos.distance_to(p)
		if d < 0.8 or d > 30.0:
			continue
		var dir: float = (p - o.pos).angle()
		if sector != null and absf(angle_difference(dir, sector)) > half:
			continue
		if not w.geom.sight_clear(o.pos, o.eye(), p, 1.2):
			continue
		var last: float = o.ticker.get("ll_" + c["k"], -99.0)
		var sc: float = c["w"] * minf(3.0, (w.t - last) / 2.0 + 0.3) * w.rng.randf_range(0.8, 1.2)
		if sc > best_s:
			best_s = sc
			best = c
	if best != null:
		o.look_goal = (best["p"] - o.pos).angle()
		o.ticker["ll_" + best["k"]] = w.t
	elif sector != null:
		o.look_goal = sector
	elif o.moving and o.vel.length() > 0.3:
		o.look_goal = o.vel.angle()


## A door side counts as cleared for scanning when the team has cleared that room.
func _cleared_side(tm: Dictionary, rm: String) -> bool:
	return tm["cleared"].has(rm)


## Sweeping a big room: the element's lead walks to the nearest unseen sweep point, the
## rest follow in a wedge (1.5 m apart with GD07, bunched without it).
func _task_sweep(o, el: Dictionary) -> void:
	var al := _alive(el)
	al.sort_custom(func(a, b): return a.eslot < b.eslot)
	var k := al.find(o)
	var lead = al[0]
	var tg = el["sweep_target"]
	if tg == null:
		var bd := INF
		for p in el["sweep"]:
			var dd: float = lead.pos.distance_to(p)
			if dd < bd:
				bd = dd
				tg = p
		el["sweep_target"] = tg
	if tg == null:
		w.stop(o)
		return
	o.dbg = "sweeping"
	var target: Vector2 = tg
	if k > 0:
		var key := str(target.snapped(Vector2(1, 1)))
		if o.ticker.get("form_key", "") != key:
			o.ticker["form_key"] = key
			var to_t: Vector2 = target - lead.pos
			var dir: Vector2 = to_t.normalized() if to_t.length() > 0.5 else Vector2.from_angle(lead.body_dir)
			var sp := 1.5 if o.has("GD07") else 0.6
			var row := int((k + 1) / 2)
			var lat := 1.0 if k % 2 == 1 else -1.0
			o.ticker["form_p"] = w.nav.snap(target - dir * sp * row + dir.orthogonal() * sp * 0.8 * lat)
		target = o.ticker["form_p"]
	if w.at(o, target, 0.5):
		w.stop(o)
	else:
		_go(o, target, "clear")


## An element with no room of its own waits a few metres behind the nearest element that
## is working a door, watching that door.
func _task_support(o, tm: Dictionary, el: Dictionary) -> void:
	var best = null
	var bd := INF
	for other in tm["elements"]:
		if other == el or other["task"].is_empty() or _alive(other).is_empty():
			continue
		var dc: Vector2 = w.level.doors[other["task"]["door"]]["c"]
		var dd: float = o.pos.distance_to(dc)
		if dd < bd:
			bd = dd
			best = other
	if best == null:
		w.stop(o)
		o.dbg = "waiting"
		return
	var st: Dictionary = best["task"]
	var D: Dictionary = w.level.doors[st["door"]]
	var n_in: Vector2 = w.level.inward(st["door"], st["into"])
	var key: String = st["door"] + str(o.eslot)
	if o.ticker.get("support_key", "") != key:
		o.ticker["support_key"] = key
		var lat: float = (o.eslot - 2) * 1.2
		var q: Vector2 = D["c"] - n_in * (4.5 + 0.6 * (o.eslot % 2)) + D["t"] * lat
		o.ticker["support_p"] = w.nav.snap(q)
	var sp: Vector2 = o.ticker["support_p"]
	o.dbg = "supporting " + _tag(tm, best)
	if w.at(o, sp, 0.5):
		w.stop(o)
		_task_look(o, (D["c"] - o.pos).angle())
	else:
		_go(o, sp, "walk")


# ================================================================== defence and sound
## Defensive squads consolidate: one squad per room. A squad takes the free room where
## most of its members already are (ties: the nearest, then the bigger), big enough for
## all of it; members already inside keep their posts, the rest move in to posts covering
## the room's doors and windows. A squad with no room left holds where it stands.
func _consolidate(tm: Dictionary, el: Dictionary) -> void:
	var al := _alive(el)
	if al.is_empty():
		return
	var lv = w.level
	var held: Dictionary = tm["held"]
	var counts := {}
	for m in al:
		var rm: String = lv.room_at(m.pos)
		if not lv.is_exterior(rm):
			counts[rm] = counts.get(rm, 0) + 1
	var c := _centre(al)
	var best := ""
	var best_s := -INF
	var fixed: String = el.get("fixed_room", tm.get("fixed_room", ""))
	var bi: int = tm.get("bldg", -1)
	for name in ([fixed] if fixed != "" else (lv.building_rooms(bi) if bi >= 0 else lv.rooms.keys())):
		if lv.is_exterior(name) or (held.has(name) and fixed == ""):
			continue
		var n_in: int = counts.get(name, 0)
		if lv.room_area(name) < 3.5 * al.size() and n_in < al.size() and fixed == "":
			continue
		var sc: float = n_in * 100.0 - c.distance_to(lv.rooms[name]["label"]) + minf(lv.room_area(name), 40.0) * 0.1
		if lv.rooms[name]["hall"]:
			sc -= 8.0
		if sc > best_s:
			best_s = sc
			best = name
	el["hold_room"] = best
	el["cover_open"] = -1
	if best == "":
		return
	held[best] = el["i"]
	var moved: Array = []
	for m in al:
		if lv.room_at(m.spawn) != best:
			moved.append(m)
	for m in moved:
		_post_member(el, m, {})
	if not moved.is_empty() or tm["elements"].size() > 1:
		w.say("%s consolidates in the %s" % [_tag(tm, el), lv.rooms[best]["title"].to_lower()], "info")
	el["sector_posture"] = ""


func _release_hold(tm: Dictionary, el: Dictionary) -> void:
	var hr: String = el.get("hold_room", "")
	if hr != "" and tm["held"].get(hr, -1) == el["i"]:
		tm["held"].erase(hr)
	el["hold_room"] = ""


## Give one member a post in the squad's room covering an opening (or the given one).
func _post_member(el: Dictionary, m, only: Dictionary) -> void:
	var taken: Array = []
	for x in _alive(el):
		if x != m:
			taken.append(x.spawn)
	var ops: Array = w.level.room_openings(el["hold_room"])
	var op: Dictionary = only
	if op.is_empty() and not ops.is_empty():
		op = ops[m.eslot % ops.size()]
	var posts: Array = w.level.cover_posts(el["hold_room"], 1, taken, w.nav, op)
	if posts.is_empty():
		return
	m.spawn = posts[0]["p"]
	m.spawn_face = posts[0]["face"]


## Somebody heard an enemy. Aggressive operators (a hunting team, or the Aggression
## personality) go after the sound; a defensive squad re-posts to cover the opening of
## its room closest to the sound.
func on_heard(o, p: Vector2, kind: String) -> void:
	var tm: Dictionary = w.teams[o.team]
	if o.el < 0 or o.el >= tm["elements"].size():
		return
	var el: Dictionary = tm["elements"][o.el]
	if el["mode"] != "hold":
		return
	if o.hb("BH11") or o.hb("BH12"):
		var inv: Dictionary = o.ticker.get("investigate", {})
		if inv.is_empty():
			w.say("%s hears %s and goes after it (aggression)" % [o.id, _sound_name(kind)], "bad")
		o.ticker["investigate"] = {"p": p, "until": w.t + 25.0}
		return
	_cover_sound(tm, el, p, kind)


func _sound_name(kind: String) -> String:
	match kind:
		"rifle", "pistol":
			return "gunfire"
		"reload":
			return "a reload"
	return "footsteps"


func _cover_sound(tm: Dictionary, el: Dictionary, p: Vector2, kind: String) -> void:
	var al := _alive(el)
	var hr: String = el.get("hold_room", "")
	if hr == "":
		# no room: face the sound where they stand
		for m in al:
			if w.visible_enemies(m).is_empty():
				m.spawn_face = (p - m.spawn).angle()
		el["sector_posture"] = ""
		return
	var ops: Array = w.level.room_openings(hr)
	if ops.is_empty():
		return
	var bi := 0
	for i in ops.size():
		if (ops[i]["c"] as Vector2).distance_to(p) < (ops[bi]["c"] as Vector2).distance_to(p):
			bi = i
	if el.get("cover_open", -1) == bi and w.t - el.get("cover_t", -99.0) < 8.0:
		return
	el["cover_open"] = bi
	el["cover_t"] = w.t
	var op: Dictionary = ops[bi]
	# everyone covers that opening, except one rear watcher (ED09 first) in squads of 3+
	var watcher = null
	if al.size() >= 3:
		for m in al:
			if m.has("ED09"):
				watcher = m
				break
		if watcher == null:
			watcher = al[-1]
	var taken: Array = []
	if watcher != null:
		taken.append(watcher.spawn)
	for m in al:
		if m == watcher or not w.visible_enemies(m).is_empty():
			continue
		var posts: Array = w.level.cover_posts(hr, 1, taken, w.nav, op)
		if posts.is_empty():
			continue
		m.spawn = posts[0]["p"]
		m.spawn_face = posts[0]["face"]
		taken.append(m.spawn)
	el["sector_posture"] = ""
	var what: String = "door" if op["kind"] == "door" else "window"
	var where: String = ""
	if op["kind"] == "door":
		where = " to outside" if w.level.is_exterior(op["other"]) else " to the " + w.level.rooms[op["other"]]["title"].to_lower()
	w.say("%s hears %s: covers the %s %s%s" % [_tag(tm, el), _sound_name(kind), w.level.rooms[hr]["title"].to_lower(), what, where], "comms")


## Travelling across the city as a squad: the leader heads for the destination, the rest
## follow in a loose file behind. The director watches for arrival.
func _task_transit(o, el: Dictionary) -> void:
	var al := _alive(el)
	al.sort_custom(func(a, b): return a.eslot < b.eslot)
	var k := al.find(o)
	var dv = el.get("dest", w.teams[o.team].get("dest", null))
	if dv == null:
		w.stop(o)
		return
	var dest: Vector2 = dv
	o.dbg = "moving"
	if k <= 0:
		if w.at(o, dest, 2.0):
			w.stop(o)
			if not el.has("arrived_t"):
				el["arrived_t"] = w.t
			return
		_go(o, dest, el.get("pace", w.teams[o.team].get("pace", "run")), false)
		return
	var lead = al[0]
	var gap := 1.6 * k
	if lead.pos.distance_to(o.pos) < gap and lead.pos.distance_to(dest) > 2.5:
		w.stop(o)
		return
	var key := str(dest.snapped(Vector2(1, 1)))
	if o.ticker.get("form_key", "") != key:
		o.ticker["form_key"] = key
		var off := Vector2.from_angle(TAU * k / maxf(1.0, al.size())) * 1.3
		o.ticker["form_p"] = w.nav.snap(dest + off)
	var fp: Vector2 = o.ticker["form_p"]
	if w.at(o, fp, 0.8):
		w.stop(o)
	else:
		_go(o, fp, el.get("pace", "run"), false)
