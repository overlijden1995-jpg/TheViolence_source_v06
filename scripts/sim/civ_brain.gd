extends RefCounted
## Civilians (v0.6): a parallel population with a brain much cheaper than the CQB brain.
## Nobody targets a civilian on purpose (the paramedic rule), but every bullet can hit
## them, and an officer who has not yet judged a recognized civilian covers them.
##
## States:
##   unaware   at their spot; now and then a few steps within the room
##   alarmed   just heard a shot, saw a gun or had a round go past; decides at once
##   flee      runs to the reachable point that puts most distance and walls between them
##             and the threat, then crouches there
##   hide      the nearest spot the threat cannot see, ducked
##   freeze    stays put, crouched, for a few seconds, then decides again
##   comply    hands up, kneeling: an officer told them to, or pointed a gun at them
##   film      holds up a phone with a line of sight to the shooting: video evidence, and a
##             hand holding something that an officer may take for a gun
## Personality (persona): panic, curiosity, defiance, mobility (speed), phone (has one).

const Op = preload("res://scripts/sim/op.gd")
const Geom = preload("res://scripts/sim/geom.gd")

const SEE_R := 18.0           # a drawn gun is noticed within this distance
const FILM_MIN := 7.0         # a filmer keeps at least this far from the shooting
const FILM_MAX := 26.0
const COMPLY_R := 12.0        # an officer this close, aiming at them, makes them comply

var w


func _init(world) -> void:
	w = world


## A random personality, drawn from the world's generator (deterministic per seed).
static func roll_persona(rng: RandomNumberGenerator) -> Dictionary:
	return {"panic": snappedf(rng.randf(), 0.01), "curiosity": snappedf(rng.randf(), 0.01),
		"defiance": snappedf(rng.randf() * rng.randf(), 0.01), "mobility": snappedf(rng.randf_range(0.55, 1.0), 0.01),
		"phone": rng.randf() < 0.85}


func think(o) -> void:
	if o.mounted != null:
		return
	var t: float = w.t
	o.dbg = o.cstate
	match o.cstate:
		"unaware":
			_unaware(o, t)
		"alarmed":
			_decide(o, true)
		"flee":
			_flee(o, t)
		"hide":
			_hide(o, t)
		"freeze":
			if t >= o.ticker.get("plan_t", 0.0):
				_decide(o, false)
			else:
				w.stop(o)
				o.stance_goal = Op.CROUCH
		"comply":
			_comply(o, t)
		"film":
			_film(o, t)
	if o.cstate != "comply" and o.cstate != "unaware" and t >= o.ticker.get("comply_check", 0.0):
		o.ticker["comply_check"] = t + 0.5
		_check_comply(o)


# ------------------------------------------------------------------ alarm
## Something frightening at p: gunfire heard, a gun seen, a near miss, someone falling.
func alarm(o, p: Vector2, why: String) -> void:
	if not o.alive() or not o.civ:
		return
	var old: Vector2 = o.ticker.get("threat_p", Vector2.INF)
	o.ticker["threat_p"] = p
	o.ticker["alarm_t"] = w.t
	o.last_stress_t = w.t
	o.stress = minf(1.0, o.stress + (0.3 if why == "near miss" else 0.12))
	if o.cstate == "unaware":
		o.cstate = "alarmed"
		w.say("%s (civilian) %s" % [o.id, {"gunfire": "hears gunfire", "gun": "sees a gun", "near miss": "has a round go past",
			"fall": "sees someone fall", "hit": "is hit"}.get(why, why)], "civ")
		return
	# a new threat much closer than the old one changes the plan
	if o.cstate in ["film", "freeze", "hide"] and (old == Vector2.INF or o.pos.distance_to(p) < o.pos.distance_to(old) - 4.0):
		if why == "near miss" or why == "hit" or o.pos.distance_to(p) < FILM_MIN:
			_start_flee(o)
	elif o.cstate == "flee" and why == "near miss":
		o.ticker.erase("dest")


func _decide(o, first: bool) -> void:
	var pr: Dictionary = o.persona
	var tp: Vector2 = o.ticker.get("threat_p", o.pos)
	var d: float = o.pos.distance_to(tp)
	var panic: float = pr.get("panic", 0.5)
	var wts := {"flee": 0.6 + panic, "hide": 0.5 + (1.0 - pr.get("mobility", 0.8)) * 0.8,
		"freeze": (0.15 + panic * 0.5) if first else 0.0,
		"film": pr.get("curiosity", 0.3) * 0.9 if pr.get("phone", false) and d > FILM_MIN else 0.0}
	if o.wounds > 0 or o.leg_hit:
		wts["film"] = 0.0
		wts["hide"] += 0.6
	var total := 0.0
	for k in wts:
		total += wts[k]
	var r: float = w.rng.randf() * total
	var pick := "flee"
	for k2 in ["flee", "hide", "freeze", "film"]:
		r -= wts[k2]
		if r <= 0.0:
			pick = k2
			break
	match pick:
		"flee":
			_start_flee(o)
		"hide":
			_start_hide(o)
		"freeze":
			o.cstate = "freeze"
			o.ticker["plan_t"] = w.t + w.rng.randf_range(2.0, 6.0)
			w.stop(o)
			o.stance_goal = Op.CROUCH
		"film":
			o.cstate = "film"
			o.ticker["film_since"] = w.t
			w.say("%s (civilian) starts filming" % o.id, "civ")


# ------------------------------------------------------------------ unaware
func _unaware(o, t: float) -> void:
	o.stance_goal = Op.STAND
	if t < o.ticker.get("look_t", 0.0):
		_idle_move(o, t)
		return
	o.ticker["look_t"] = t + 0.5
	# a drawn gun in plain view
	for x in w._near_fast(o.pos, SEE_R):
		if x.civ or not x.alive() or x.mounted != null:
			continue
		if not (x.weapon_up or not x.aim.is_empty() or x.alert >= Op.YELLOW):
			continue
		if not x.shows_weapon():
			continue
		var dv: Vector2 = x.pos - o.pos
		if absf(angle_difference(o.look_dir, dv.angle())) > deg_to_rad(75.0):
			continue
		if w.geom.sight_clear(o.pos, o.eye(), x.pos, 1.3):
			alarm(o, x.pos, "gun")
			return
	_idle_move(o, t)


## A few steps now and then, inside the room they are in.
func _idle_move(o, t: float) -> void:
	if o.moving:
		if w.at(o, o.goal, 0.3):
			w.stop(o)
		return
	if t < o.ticker.get("wander_t", -1.0):
		return
	if not o.ticker.has("wander_t"):
		o.ticker["wander_t"] = t + w.rng.randf_range(4.0, 30.0)
		return
	o.ticker["wander_t"] = t + w.rng.randf_range(15.0, 45.0)
	var home: Vector2 = o.spawn
	for k in 6:
		var q: Vector2 = home + Vector2(w.rng.randf_range(-2.5, 2.5), w.rng.randf_range(-2.5, 2.5))
		if w.nav.reachable(q) and w.level.room_at(q) == w.level.room_at(home):
			w.move_to(o, q, "walk", 0)
			o.look_goal = (q - o.pos).angle()
			return


# ------------------------------------------------------------------ flee and hide
func _start_flee(o) -> void:
	o.cstate = "flee"
	o.ticker.erase("dest")
	o.ticker["flee_since"] = w.t
	o.stance_goal = Op.STAND


func _flee(o, t: float) -> void:
	o.stance_goal = Op.STAND
	var tp: Vector2 = o.ticker.get("threat_p", o.pos)
	if not o.ticker.has("dest"):
		var dest = _flee_point(o, tp)
		if dest == null:
			_start_hide(o)
			return
		o.ticker["dest"] = dest
	var dp: Vector2 = o.ticker["dest"]
	if w.at(o, dp, 0.6) or (t - o.ticker.get("flee_since", t) > 25.0):
		# arrived (or gave up running): get down out of sight
		w.stop(o)
		o.cstate = "hide"
		o.ticker["hide_p"] = o.pos
		o.stance_goal = Op.DUCK
		return
	w.move_to(o, dp, "run", 0)
	if o.path.is_empty() and t < o.ticker.get("path_fail_until", -1.0):
		o.ticker.erase("dest")
		_start_hide(o)
		return
	o.look_goal = o.vel.angle() if o.vel.length() > 0.2 else (dp - o.pos).angle()


## Sample reachable points around; the best is far from the threat, out of its sight,
## and not much further from here than it needs to be.
func _flee_point(o, tp: Vector2):
	var best = null
	var best_s := -INF
	var W: float = w.level.W
	var H: float = w.level.H
	for k in 18:
		var q := Vector2(clampf(o.pos.x + w.rng.randf_range(-30.0, 30.0), 1.0, W - 1.0),
			clampf(o.pos.y + w.rng.randf_range(-30.0, 30.0), 1.0, H - 1.0))
		if not w.nav.reachable(q):
			continue
		var s: float = q.distance_to(tp) - 0.35 * q.distance_to(o.pos)
		if not w.geom.sight_clear(tp, 1.6, q, 1.0):
			s += 10.0
		if q.distance_to(tp) < 8.0:
			s -= 20.0
		if s > best_s:
			best_s = s
			best = q
	return best


func _start_hide(o) -> void:
	o.cstate = "hide"
	var tp: Vector2 = o.ticker.get("threat_p", o.pos)
	var best = null
	var bd := INF
	var n := 0
	for item in w.nav.spots_near(o.pos, 10.0):
		n += 1
		if n > 40:
			break
		var c: Dictionary = item[1]
		var p: Vector2 = c["p"]
		var d := sqrt(float(item[0]))
		if d >= bd:
			break
		if w.geom.sight_clear(tp, 1.6, p, 0.8):
			continue
		bd = d
		best = p
	o.ticker["hide_p"] = best if best != null else o.pos


func _hide(o, t: float) -> void:
	var hp: Vector2 = o.ticker.get("hide_p", o.pos)
	if not w.at(o, hp, 0.4):
		w.move_to(o, hp, "run", 0)
		o.stance_goal = Op.STAND
		return
	w.stop(o)
	o.stance_goal = Op.DUCK
	var tp: Vector2 = o.ticker.get("threat_p", o.pos)
	o.look_goal = (tp - o.pos).angle()
	# a long quiet: some peek out and start filming
	if t - o.ticker.get("alarm_t", t) > 40.0 and o.persona.get("phone", false) and o.persona.get("curiosity", 0.0) > 0.6:
		o.cstate = "film"
		o.ticker["film_since"] = t


# ------------------------------------------------------------------ filming
func _film(o, t: float) -> void:
	var tp: Vector2 = o.ticker.get("threat_p", o.pos)
	var d: float = o.pos.distance_to(tp)
	o.stance_goal = Op.STAND
	if d < FILM_MIN:
		# too close: back off along the line from the shooting
		var away: Vector2 = o.pos + (o.pos - tp).normalized() * 4.0
		if w.nav.is_free(away):
			w.move_to(o, away, "walk", 0)
		else:
			_start_flee(o)
		return
	var los: bool = w.geom.sight_clear(o.pos, o.eye(), tp, 1.2)
	if not los and d > 6.0 and t >= o.ticker.get("film_move_t", 0.0):
		o.ticker["film_move_t"] = t + 2.0
		var step: Vector2 = o.pos + (tp - o.pos).normalized() * minf(4.0, d - FILM_MIN)
		if w.nav.is_free(step):
			w.move_to(o, step, "walk", 0)
			o.look_goal = (tp - o.pos).angle()
			return
	if d > FILM_MAX:
		w.move_to(o, o.pos + (tp - o.pos).normalized() * 3.0, "walk", 0)
	else:
		w.stop(o)
	o.look_goal = (tp - o.pos).angle()
	o.ticker["filming"] = t


# ------------------------------------------------------------------ complying
## An officer close by, aiming at them or shouting at them: most put their hands up.
func _check_comply(o) -> void:
	for x in w._near_fast(o.pos, COMPLY_R):
		if not x.judges or not x.alive():
			continue
		var aimed: bool = x.aim.get("tid", "") == o.id
		var shouted: bool = x.ticker.get("chal_t", -99.0) > w.t - 1.0 and x.pos.distance_to(o.pos) < 10.0
		if not aimed and not shouted:
			continue
		if not w.geom.sight_clear(o.pos, o.eye(), x.pos, 1.5):
			continue
		if w.rng.randf() < 1.0 - 0.75 * float(o.persona.get("defiance", 0.2)):
			comply(o, x)
		return


func comply(o, by) -> void:
	if o.cstate == "comply":
		return
	o.cstate = "comply"
	o.ticker["comply_since"] = w.t
	o.ticker["hands"] = w.t
	w.stop(o)
	o.stance_goal = Op.CROUCH
	o.look_goal = (by.pos - o.pos).angle()
	w.say("%s (civilian) puts their hands up for %s" % [o.id, by.id], "civ")
	w.emit({"type": "float", "p": o.pos, "text": "HANDS UP"})
	# an officer who had judged them a threat may see the hands in time
	for x in w.ops:
		if x.misjudged.has(o.id) and w.rng.randf() < 0.6:
			x.misjudged.erase(o.id)
			x.judged.erase(o.id)
			x.cleared[o.id] = w.t
			if x.aim.get("tid", "") == o.id:
				x.aim = {}


func _comply(o, t: float) -> void:
	w.stop(o)
	o.stance_goal = Op.CROUCH
	o.ticker["hands"] = t
	# no officer near for a while: they get up and get away
	if t >= o.ticker.get("comply_look", 0.0):
		o.ticker["comply_look"] = t + 1.0
		var near := false
		for x in w._near_fast(o.pos, 15.0):
			if x.judges and x.alive():
				near = true
				break
		if near:
			o.ticker["comply_since"] = t
		elif t - o.ticker.get("comply_since", t) > 12.0:
			o.ticker.erase("hands")
			_start_flee(o)
