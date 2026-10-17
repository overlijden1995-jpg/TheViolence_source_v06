extends RefCounted
## One operator: configuration (echelon, habits, plates) plus all runtime state.

const Habits = preload("res://scripts/data/habits.gd")

enum {STAND, CROUCH, DUCK, DOWN}
enum {GREEN, YELLOW, RED}
const ALERT_NAMES := ["GREEN", "YELLOW", "RED"]
## Eye height and body zones [name, z_lo, z_hi, plan radius] per stance (bible 1.1).
## DUCK is "fully behind half cover": the eye sits below a 0.9 m sill or wall.
const STANCES := {
	STAND: {"eye": 1.65, "zones": [["legs", 0.0, 0.85, 0.16], ["abd", 0.85, 1.15, 0.18], ["chest", 1.15, 1.55, 0.20], ["head", 1.55, 1.80, 0.11]]},
	CROUCH: {"eye": 1.10, "zones": [["legs", 0.0, 0.45, 0.16], ["abd", 0.45, 0.70, 0.18], ["chest", 0.70, 1.00, 0.20], ["head", 1.00, 1.25, 0.11]]},
	DUCK: {"eye": 0.80, "zones": [["legs", 0.0, 0.30, 0.16], ["abd", 0.30, 0.50, 0.18], ["chest", 0.50, 0.72, 0.20], ["head", 0.72, 0.92, 0.11]]},
	DOWN: {"eye": 0.20, "zones": [["chest", 0.0, 0.30, 0.32]]},
}

# ---------------------------------------------------------------- config
var id := "A1"
var team := 0
var slot := 0
var echelon := "regular"
var ech: Dictionary = {}
var good := {}          # id -> bool (has the habit)
var bad := {}           # id -> bool (habit present)
var plates_max := 0
var traits := {}        # id -> bool (physical traits such as Tinnitus)
var exp := 1            # Experience tier 1-5: enemies tracked at once
var hear := 1.0         # hearing range multiplier (static; traits change it)
var spawn := Vector2.ZERO
var spawn_face := 0.0
var el := -1            # element index within the team (fire teams of up to five)
var eslot := 0          # position within the element
var faction := 0        # who this operator fights for (team = the unit within the faction)
var name := ""          # full name, for the ledger
var rank := ""          # rank or role, for the ledger
var medic := false      # paramedic: nobody targets them, bullets still hit them
var sidearm_only := false  # untrained carry only a pistol
var alert := 1          # GREEN relaxed (weapon low or holstered), YELLOW drawn, RED engaging
var alert_t := 0.0      # when the current alert level was last raised or refreshed
var alert_floor := 0    # never relaxes below this (a tasking or the team's starting state)
var officer_id := ""    # department record this officer was built from ("" = not from a roster)
var vest := false       # soft armour: stops pistol rounds to the chest, not rifle rounds
var bodycam := false    # records what the officer sees (evidence; v0.7: the player's live view)
var judgment := 50      # 0-100: how fast and how well a recognized person is judged a threat
var temper := 40        # 0-100: how long the trigger stays pulled after someone gives up
var integrity := 60     # 0-100: whether reports match what happened (record only, for now)
var civ := false        # a civilian: nobody targets them on purpose; every bullet can hit them

# ---------------------------------------------------------------- runtime
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var body_dir := 0.0
var look_dir := 0.0
var look_goal := 0.0
var muzzle_dir := 0.0
var stance := STAND
var stance_goal := STAND
var state := "ok"       # ok | down | dead
var wounds := 0
var arm_hit := false
var leg_hit := false
var stress := 0.0
var last_stress_t := -99.0
var plates := 0
var weapons := {}       # "rifle"/"pistol" -> {mag, spare, jam, lost}
var active := "rifle"
var recoil := 0.0
var weapon_up := false
var last_aim_t := -99.0

var rec := {}           # enemy id -> recognition progress 0..1+
var vis := {}           # enemy id -> {los, head_only, ecc, dist}
var first_rec := {}     # enemy id -> time first recognized
var tracked := {}       # enemy id -> {lost_t, ready_t}: the enemies held in attention
var cue := {}           # enemy id -> expiry time of a teammate callout
var lkp := {}           # enemy id -> {p, t}
var heard := {}         # last enemy sound heard {p, t, kind}
var perc_phase := 0.0
var n_los := 0          # enemies in line of sight at the last perception update

var active_bad := {}    # id -> true while active
var suspended := {}     # good id -> true while overridden
var m_h := 1.0          # habit multiplier on reaction times
var bad_lo := -INF      # effective-stress band inside which no bad habit can switch
var bad_hi := -INF

var action := {}        # current blocking action {type, left, ...}
var aim := {}           # aiming state
var path := PackedVector2Array()
var path_i := 0
var goal := Vector2.INF
var goal_mode := ""
var repath_t := 0.0
var moving := false
var speed := 0.0
var look_hint := {}     # {dir, until, why}
var sidestep := {}      # PF07 lateral step state
var freeze_add := 0.0   # BH01 delay added to next time on target
var hide_until := -1.0  # BH13
var last_exposure := Vector2.INF
var last_contact_t := -99.0
var last_shot_t := -99.0
var last_enemy_seen_t := -99.0
var reloaded_after_contact := true
var dbg := ""           # short text describing what the brain is doing
var events_bad := []    # for UI: recently activated bad habits
var shots := 0
var hits := 0
var kills := 0
var room := "OUT"
var stall_done := {}    # door ids where the doorway stall/pause already happened
var ticker := {}        # misc timers keyed by name

# ---------------------------------------------------------------- city (endless battle)
var assault := false    # gang expansion team: may fire on rival gangs and police at will
var clearing := false   # QRF member while the QRF is clearing its search buildings
var flag_t := -999.0    # last time police saw this gang member targeting someone
var armed_t := -999.0   # last time this operator was aiming at or firing on someone
var mounted = null      # vehicle carrying this operator (out of the simulation while aboard)
var carried := false    # a casualty on a stretcher or aboard an ambulance (no bleed-out clock)
var saved := false      # reached an ambulance alive
var hot := true         # a potential enemy is near (dormancy)
var hot_next := 0.0
var dormant := false
var idle_next := 0.0
var gid := 0            # serial number in the world
var gang := false       # city: a gang member (cached from the faction)
var police := false     # city: a police officer (paramedics included)

# ---------------------------------------------------------------- judgment, surrender (v0.6)
var judges := false     # must decide a recognized person is a threat before firing (police rules)
var judged := {}        # person id -> {"until": t, "v": "" | "threat" | "unknown" | "civilian" | "complying"}
var misjudged := {}     # person id -> true: a civilian or someone complying wrongly judged a threat
var cleared := {}       # person id -> time judged harmless (not re-judged for a while)
var complying := false  # has given up: hands up, kneeling, weapons dropped
var arrested := false   # cuffed
var cstate := ""        # civilian: unaware, alarmed, flee, hide, freeze, comply, film
var persona := {}       # civilian: {panic, curiosity, defiance, mobility, phone}


func configure(cfg: Dictionary) -> void:
	id = cfg["id"]
	team = cfg["team"]
	slot = cfg["slot"]
	echelon = cfg["echelon"]
	ech = Habits.ECHELONS[echelon]
	good = cfg["good"].duplicate()
	bad = cfg["bad"].duplicate()
	plates_max = cfg["plates"]
	traits = cfg.get("traits", {}).duplicate()
	hear = Habits.hearing(traits)
	exp = clampi(int(cfg.get("exp", Habits.PRESET_EXP[echelon])), 1, Habits.EXP_MAX)
	spawn = cfg["pos"]
	spawn_face = cfg["face"]
	faction = int(cfg.get("faction", team))
	name = cfg.get("name", "")
	rank = cfg.get("rank", "")
	medic = cfg.get("medic", false)
	sidearm_only = cfg.get("sidearm_only", echelon == "untrained")
	alert_floor = clampi(int(cfg.get("alert", 1)), 0, 2)
	# a department officer's stats were rolled once, at hire, and travel with the record
	if cfg.has("ech"):
		ech = (cfg["ech"] as Dictionary).duplicate(true)
	officer_id = cfg.get("officer_id", "")
	vest = cfg.get("vest", Habits.PRESET_VEST.get(echelon, false))
	bodycam = cfg.get("bodycam", false)
	judgment = int(cfg.get("judgment", Habits.PRESET_JUDGMENT.get(echelon, 50)))
	temper = int(cfg.get("temper", 40))
	integrity = int(cfg.get("integrity", 60))
	civ = cfg.get("civ", false)
	persona = cfg.get("persona", {}).duplicate()
	if civ:
		sidearm_only = false
		alert_floor = 0


func reset() -> void:
	pos = spawn
	body_dir = spawn_face
	look_dir = spawn_face
	look_goal = spawn_face
	muzzle_dir = spawn_face
	plates = plates_max
	stress = 0.0
	weapons = {
		"rifle": {"mag": Habits.WEAPONS["rifle"]["mag"], "spare": Habits.WEAPONS["rifle"]["spare"], "jam": false, "lost": false},
		"pistol": {"mag": Habits.WEAPONS["pistol"]["mag"], "spare": Habits.WEAPONS["pistol"]["spare"], "jam": false, "lost": false},
	}
	active = "rifle"
	if sidearm_only:
		weapons["rifle"] = {"mag": 0, "spare": 0, "jam": false, "lost": true, "none": true}
		weapons["pistol"]["spare"] += 1
		active = "pistol"
	if civ:
		weapons["rifle"] = {"mag": 0, "spare": 0, "jam": false, "lost": true, "none": true}
		weapons["pistol"] = {"mag": 0, "spare": 0, "jam": false, "lost": true, "none": true}
		active = "pistol"
		cstate = "unaware"
	alert = alert_floor
	alert_t = 0.0
	stress = clampf(float(ech.get("stress0", 0.0)), 0.0, 0.5)


## A good habit counts only if the operator has it and no active bad habit overrides it.
func has(gid: String) -> bool:
	return good.get(gid, false) and not suspended.has(gid)


func hb(bid: String) -> bool:
	return active_bad.has(bid)


func alive() -> bool:
	return state == "ok"


## Still in the fight: alive, not a civilian, not given up.
func fighting() -> bool:
	return state == "ok" and not civ and not complying


## What an observer can see in this person's hands: a rifle carried, or any weapon drawn.
func shows_weapon() -> bool:
	if civ or complying:
		return false
	if weapon_up or not aim.is_empty() or alert >= YELLOW:
		return not (weapons["rifle"]["lost"] and weapons["pistol"]["lost"])
	return active == "rifle" and not weapons["rifle"]["lost"]


func eye() -> float:
	return STANCES[stance]["eye"]


func zones() -> Array:
	return STANCES[stance]["zones"]


func zone_at(z: float) -> Array:
	for zn in zones():
		if z >= zn[1] and z <= zn[2]:
			return zn
	return []


func zone_centre(zone: String) -> float:
	for zn in zones():
		if zn[0] == zone:
			return (zn[1] + zn[2]) * 0.5
	var all: Array = zones()
	return (all[0][1] + all[-1][2]) * 0.5


func zone_radius(zone: String) -> float:
	for zn in zones():
		if zn[0] == zone:
			return zn[3]
	return 0.2


func wpn() -> Dictionary:
	return Habits.WEAPONS[active]


func ws() -> Dictionary:
	return weapons[active]


func other() -> String:
	return "pistol" if active == "rifle" else "rifle"


func usable(w: String) -> bool:
	var s: Dictionary = weapons[w]
	return not s["lost"] and s["mag"] > 0 and not s["jam"]


func any_loaded() -> bool:
	return usable("rifle") or usable("pistol")


func busy() -> bool:
	return not action.is_empty()


func moving_speed() -> float:
	return vel.length()
