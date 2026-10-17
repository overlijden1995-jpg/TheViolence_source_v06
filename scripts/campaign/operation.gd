extends RefCounted
## Operation spec (v0.5/v0.6): what goes into one run of the simulation.
##   {map, seed, civilians: n, night, police_rules, roe_strict,
##    officers: [department records] (team A) or none (team A from the setup),
##    team_b: [configurations] }
## build() turns team A's department officers and the civilians into world
## configurations; civilians are placed from the seed, mostly indoors.

const CivBrain = preload("res://scripts/sim/civ_brain.gd")


## n civilians on the map: about two in three inside buildings, the rest in the yard,
## at least 1.2 m apart and 5 m from team A's posts. Deterministic for a seed.
static func civilians(level, nav, n: int, seed_val: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 31 + 17
	var out: Array = []
	var taken: Array = []
	var a_posts: Array = []
	for k in 20:
		a_posts.append(level.spawns["A%d" % (k + 1)]["p"])
	var tries := 0
	while out.size() < n and tries < n * 400:
		tries += 1
		var p := Vector2(rng.randf_range(1.0, level.W - 1.0), rng.randf_range(1.0, level.H - 1.0))
		if not nav.reachable(p):
			continue
		var inside: bool = not level.is_exterior(level.room_at(p))
		var want_inside: bool = out.size() % 3 != 2
		if inside != want_inside and tries < n * 200:
			continue
		var ok := true
		for q in taken:
			if p.distance_to(q) < 1.2:
				ok = false
				break
		for q2 in a_posts:
			if p.distance_to(q2) < 5.0:
				ok = false
				break
		if not ok:
			continue
		taken.append(p)
		var i := out.size()
		out.append({"id": "C%d" % (i + 1), "team": 2, "faction": 2, "slot": i, "echelon": "untrained", "good": {}, "bad": {},
			"plates": 0, "exp": 1, "traits": {}, "pos": p, "face": rng.randf() * TAU, "enabled": true, "civ": true,
			"alert": 0, "persona": CivBrain.roll_persona(rng)})
	return out


## The configurations for a run: team A from the department when officers are given
## (in their order, up to twenty), the rest of the setup's configurations as they are,
## and the civilians.
static func build(base_cfgs: Array, level, nav, spec: Dictionary, dept = null) -> Array:
	var out: Array = []
	var officers: Array = spec.get("officers", [])
	var alert_a: int = int(spec.get("alert_a", 1))
	if dept != null and not officers.is_empty():
		for k in mini(officers.size(), 20):
			out.append(dept.to_cfg(officers[k], k, level, alert_a))
		for c in base_cfgs:
			if c["team"] != 0:
				out.append(c)
	else:
		out = base_cfgs.duplicate()
	var n_civ: int = int(spec.get("civilians", 0))
	if n_civ > 0:
		out.append_array(civilians(level, nav, n_civ, int(spec.get("seed", 1))))
	return out
