extends RefCounted
## The incident record (v0.6): what an operation leaves behind for the department.
## Built from the simulation as it runs, not from a summary afterwards: every round
## fired, what the shooter had judged the target to be, who it hit and through how many
## walls, every person who went down, surrenders and arrests, and for each event that
## matters the evidence there is for it: body cameras, phone video, eyewitnesses, or
## only people who heard it.
##
## Findings are the events that become consequences in the campaign (v0.9): a civilian
## shot, a shot at someone who had given up, a misjudgment, an officer killed. The
## evidence attached to each sets how hard and how fast the consequence lands.

const Geom = preload("res://scripts/sim/geom.gd")

const WITNESS_R := 35.0     # a civilian sees an event within this distance, with a line of sight
const HEARD_R := 60.0       # and hears the shots within this one
const CAM_R := 30.0         # a body camera records what is within this distance
const CAM_HALF := 1.2       # radians either side of the wearer's body direction (about 140 deg)
const SHOTS_MAX := 4000

var w
var shots: Array = []        # [{t, by, tgt, tkind, verdict, hit, hkind, walls}]
var findings: Array = []     # [{t, kind, by, target, text, place, evidence, strength}]
var per_op := {}             # id -> {shots, hits_threat, hits_civ, hits_friend, walls, misjudged, excessive, kills}
var surrenders: Array = []   # [{t, id, by}]
var arrests: Array = []      # [{t, id, by}]
var _keys := {}              # finding dedupe keys
var dropped := 0


func _init(world) -> void:
	w = world


## What kind of person this is, as the record names them.
func role(o) -> String:
	if o == null:
		return "nobody"
	if o.civ:
		return "civilian"
	if o.judges:
		return "officer"
	if w.police_rules():
		return "suspect"
	return "team " + "ABC"[clampi(o.team, 0, 2)]


func _who(o) -> String:
	if o == null:
		return "?"
	var nm: String = o.name if o.name != "" else o.id
	return "%s %s (%s)" % [role(o).capitalize(), nm, o.id]


func _po(o) -> Dictionary:
	if not per_op.has(o.id):
		per_op[o.id] = {"shots": 0, "hits_threat": 0, "hits_civ": 0, "hits_friend": 0, "walls": 0,
			"misjudged": 0, "excessive": 0, "kills": 0, "name": o.name, "role": role(o), "officer_id": o.officer_id}
	return per_op[o.id]


## One round fired. tgt is the person aimed at (null for a stray), hit the person struck
## (null for a miss), walls how many walls the round went through before it stopped.
func on_shot(o, tgt, hit, walls: int) -> void:
	var verdict := verdict_for(o, tgt)
	var rec := {"t": w.t, "by": o.id, "pol": o.judges, "tgt": tgt.id if tgt != null else "", "tkind": role(tgt) if tgt != null else "",
		"verdict": verdict, "hit": hit.id if hit != null else "", "hkind": role(hit) if hit != null else "", "walls": walls}
	if shots.size() < SHOTS_MAX:
		shots.append(rec)
	else:
		dropped += 1
	var po := _po(o)
	po["shots"] += 1
	po["walls"] += 1 if walls > 0 else 0
	if not o.judges:
		return
	# a shot at someone who had given up, or at a body, is excessive force; the record
	# keeps one finding per shooter and target
	if tgt != null and verdict == "excessive":
		po["excessive"] += 1
		_finding("excessive_force", o, tgt, "%s fired at %s, who had given up" % [_who(o), _who(tgt)], tgt.pos)
	elif tgt != null and verdict == "overkill":
		po["excessive"] += 1
		_finding("excessive_force", o, tgt, "%s kept firing into %s after they went down" % [_who(o), _who(tgt)], tgt.pos)
	elif tgt != null and tgt.civ and verdict == "jumpy":
		_finding("jumpy_fire", o, tgt, "%s fired at movement before recognizing %s, a civilian" % [_who(o), _who(tgt)], tgt.pos)


## What the shooter had decided about the person aimed at when the round left.
func verdict_for(o, tgt) -> String:
	if tgt == null:
		return "stray"
	if not o.judges:
		return "fair" if w.hostile(o, tgt) else "unjudged"
	if not tgt.alive():
		# rounds into someone who went down a moment ago are part of stopping the threat;
		# rounds after that are not
		return "overkill" if w.t - float(tgt.ticker.get("down_t", w.t)) > 0.7 else "threat"
	if tgt.civ:
		if o.misjudged.has(tgt.id):
			return "misjudged"
		return "jumpy"
	if tgt.complying:
		if o.ticker.get("late_" + tgt.id, -1.0) >= w.t:
			return "late"
		return "excessive"
	var j: Dictionary = o.judged.get(tgt.id, {})
	if j.get("v", "") == "threat":
		return "threat"
	return "self-defence" if w.attacking(tgt, o) else "jumpy"


## An officer has judged a civilian (or someone giving up) to be a threat.
func on_misjudge(o, e) -> void:
	_po(o)["misjudged"] += 1
	_finding("misjudgment", o, e, "%s judged %s a threat" % [_who(o), _who(e)], e.pos)


## Someone was hit. Officers hitting civilians or each other is always a finding.
func on_hit(a, shooter, zone: String, walls: int) -> void:
	var po := _po(shooter)
	var through := " through %d wall%s" % [walls, "" if walls == 1 else "s"] if walls > 0 else ""
	if a.civ:
		po["hits_civ"] += 1
		var how: String = "civilian_hit_by_police" if shooter.judges else "civilian_hit_by_suspect"
		_finding(how, shooter, a, "%s hit %s (%s)%s" % [_who(shooter), _who(a), zone, through], a.pos, false)
	elif a.faction == shooter.faction:
		po["hits_friend"] += 1
		_finding("friendly_fire", shooter, a, "%s hit %s, on the same side (%s)%s" % [_who(shooter), _who(a), zone, through], a.pos, false)
	else:
		po["hits_threat"] += 1


func on_down(a, shooter, killed: bool) -> void:
	if shooter != null and killed:
		_po(shooter)["kills"] += 1
	if a.civ:
		_finding("civilian_killed" if killed else "civilian_down", shooter, a,
			"%s %s%s" % [_who(a), "killed" if killed else "went down", (" by " + _who(shooter)) if shooter != null else ""], a.pos, false)
	elif a.judges:
		_finding("officer_killed" if killed else "officer_down", shooter, a,
			"%s %s%s" % [_who(a), "killed" if killed else "went down", (" by " + _who(shooter)) if shooter != null else ""], a.pos, false)


func on_bled_out(a) -> void:
	if a.civ:
		_finding("civilian_killed", null, a, "%s died of wounds" % _who(a), a.pos, false)
	elif a.judges:
		_finding("officer_killed", null, a, "%s died of wounds" % _who(a), a.pos, false)


func on_surrender(e, by) -> void:
	surrenders.append({"t": w.t, "id": e.id, "by": by.id if by != null else ""})


func on_arrest(e, by) -> void:
	arrests.append({"t": w.t, "id": e.id, "by": by.id})


# ------------------------------------------------------------------ evidence
## Who saw, filmed, recorded or heard an event at p.
func evidence(p: Vector2, shooter) -> Dictionary:
	var cams: Array = []
	var video: Array = []
	var seen: Array = []
	var heard := 0
	for x in w.ops:
		if not x.alive():
			continue
		var d: float = x.pos.distance_to(p)
		if x.civ:
			if d > HEARD_R:
				continue
			var los: bool = d <= WITNESS_R and (w.geom.sight_clear(x.pos, x.eye(), p, 1.0) \
				or (shooter != null and w.geom.sight_clear(x.pos, x.eye(), shooter.pos, 1.3)))
			if los:
				seen.append(x.id)
				if x.cstate == "film":
					video.append(x.id)
			else:
				heard += 1
		elif x.bodycam and d <= CAM_R:
			var facing := absf(angle_difference(x.body_dir, (p - x.pos).angle())) <= CAM_HALF or d < 1.5
			if facing and w.geom.sight_clear(x.pos, x.eye(), p, 1.0):
				cams.append(x.id)
	var strength := "none"
	if not cams.is_empty() or not video.is_empty():
		strength = "video"
	elif not seen.is_empty():
		strength = "witness"
	elif heard > 0:
		strength = "heard"
	return {"bodycam": cams, "video": video, "witnesses": seen, "heard": heard, "strength": strength}


func _finding(kind: String, by, target, text: String, p: Vector2, once := true) -> void:
	var key := "%s|%s|%s" % [kind, by.id if by != null else "", target.id if target != null else ""]
	if once and _keys.has(key):
		return
	_keys[key] = true
	var ev := evidence(p, by)
	findings.append({"t": w.t, "kind": kind, "by": by.id if by != null else "", "target": target.id if target != null else "",
		"text": text, "place": w.place_of(p), "evidence": ev, "strength": ev["strength"]})


# ------------------------------------------------------------------ summary
const SEVERITY := ["civilian_killed", "excessive_force", "civilian_hit_by_police", "misjudgment", "officer_killed",
	"friendly_fire", "civilian_down", "civilian_hit_by_suspect", "jumpy_fire", "officer_down"]


## Totals and readable lines for the debrief and for the department's records.
func summary() -> Dictionary:
	var s := {"shots": shots.size() + dropped, "police_shots": 0, "through_walls": 0, "civ_hit": 0, "civ_hit_police": 0,
		"civ_killed": 0, "civ_total": 0, "suspects": 0, "suspects_down": 0, "suspects_killed": 0, "surrendered": surrenders.size(),
		"arrested": arrests.size(), "officers": 0, "officers_down": 0, "officers_killed": 0, "excessive": 0, "misjudged": 0,
		"findings": findings.size(), "lines": [], "strength": {}}
	for sh in shots:
		if sh.get("pol", false):
			s["police_shots"] += 1
		if sh["walls"] > 0:
			s["through_walls"] += 1
	for o in w.ops:
		if o.civ:
			s["civ_total"] += 1
			if o.state != "ok" or o.wounds > 0 or o.arm_hit or o.leg_hit:
				s["civ_hit"] += 1
			if o.state == "dead":
				s["civ_killed"] += 1
		elif o.judges:
			s["officers"] += 1
			if o.state != "ok":
				s["officers_down"] += 1
			if o.state == "dead":
				s["officers_killed"] += 1
		else:
			s["suspects"] += 1
			if o.state != "ok":
				s["suspects_down"] += 1
			if o.state == "dead":
				s["suspects_killed"] += 1
	for id in per_op:
		var po: Dictionary = per_op[id]
		s["civ_hit_police"] += po["hits_civ"] if po["role"] == "officer" else 0
		s["excessive"] += po["excessive"]
		s["misjudged"] += po["misjudged"]
	var order := findings.duplicate()
	order.sort_custom(func(a, b):
		var ia := SEVERITY.find(a["kind"])
		var ib := SEVERITY.find(b["kind"])
		if ia != ib:
			return ia < ib
		return a["t"] < b["t"])
	for f in order:
		var ev: Dictionary = f["evidence"]
		var proof := ""
		match f["strength"]:
			"video":
				var parts: Array = []
				if not ev["bodycam"].is_empty():
					parts.append("body camera (%s)" % ", ".join(ev["bodycam"]))
				if not ev["video"].is_empty():
					parts.append("phone video (%d)" % ev["video"].size())
				proof = " and ".join(parts)
			"witness":
				proof = "%d eyewitness%s" % [ev["witnesses"].size(), "" if ev["witnesses"].size() == 1 else "es"]
			"heard":
				proof = "only heard (%d)" % ev["heard"]
			_:
				proof = "no witnesses"
		s["strength"][f["strength"]] = s["strength"].get(f["strength"], 0) + 1
		s["lines"].append({"kind": f["kind"], "t": f["t"], "text": "%s  %s, %s. Evidence: %s." % [w.clock(f["t"]), f["text"], f["place"], proof]})
	return s


## A plain-data copy for saving with the department (no object references).
func to_data() -> Dictionary:
	var s := summary()
	return {"summary": s, "findings": findings.duplicate(true), "per_op": per_op.duplicate(true),
		"surrenders": surrenders.duplicate(true), "arrests": arrests.duplicate(true)}
