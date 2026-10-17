extends CanvasLayer
## The endless battle's panel: clock and speed, who holds the city, the police and the
## ambulances at work, the selected person, and the running feed of what happens.

const UI = preload("res://scripts/ui/ui.gd")
const Op = preload("res://scripts/sim/op.gd")
const Habits = preload("res://scripts/data/habits.gd")
const PANEL_W := 460.0
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0]

var main
var root: PanelContainer
var clock: Label
var speed_note: Label
var pause_btn: Button
var speed_buttons: Array = []
var follow_btn: Button
var factions_box: RichTextLabel
var police_box: RichTextLabel
var card: RichTextLabel
var feed_box: RichTextLabel
var feed_shown := 0
var feed_t0 := -1.0


func build(m) -> void:
	main = m
	root = PanelContainer.new()
	root.theme = UI.make_theme()
	root.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	root.offset_left = -PANEL_W
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	root.add_child(v)
	var title := Label.new()
	title.text = "T H E   V I O L E N C E"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Endless battle  ·  Port Carrick  ·  seed %d" % main.seed_val
	sub.add_theme_color_override("font_color", Color("#666666"))
	v.add_child(sub)
	v.add_child(HSeparator.new())
	var h := _h(v)
	pause_btn = _btn(h, "Pause", func(on): main.paused = on, true)
	clock = Label.new()
	clock.text = "00:00.0"
	clock.add_theme_font_size_override("font_size", 18)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(clock)
	var hs := _h(v)
	var group := ButtonGroup.new()
	for sp in SPEEDS:
		var label := ("%sx" % str(sp)).replace(".0x", "x")
		var b := _btn(hs, label, func(on): _speed(sp, on), true)
		b.button_group = group
		b.custom_minimum_size = Vector2(44, 0)
		speed_buttons.append(b)
	speed_note = Label.new()
	speed_note.add_theme_color_override("font_color", Color("#666666"))
	speed_note.add_theme_font_size_override("font_size", 11)
	v.add_child(speed_note)
	var ho := _h(v)
	follow_btn = _btn(ho, "Follow the fighting", func(on): main.follow = on, true)
	follow_btn.tooltip_text = "Keep the camera on the busiest gunfight of the last 20 seconds"
	var tb := _btn(ho, "Territory", func(on): main.set_layer("territory", on), true)
	tb.set_pressed_no_signal(true)
	var lb := _btn(ho, "Labels", func(on): main.set_layer("labels", on), true)
	lb.set_pressed_no_signal(true)
	var cb := _btn(ho, "Cones", func(on): main.set_layer("cones", on), true)
	cb.set_pressed_no_signal(true)
	var gb := _btn(ho, "Ledger", func(on): main.set_layer("ledger", on), true)
	gb.set_pressed_no_signal(true)
	factions_box = _rich(v, 214)
	police_box = _rich(v, 196)
	card = _rich(v, 112)
	card.text = "[color=#777777]Click anyone on the plan to follow them here.[/color]"
	feed_box = _rich(v, 0)
	feed_box.scroll_following = true
	feed_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hb := _h(v)
	_btn(hb, "Back to setup", func(): main.back_to_setup())
	_btn(hb, "Fit the city", func(): main.fit_camera())
	_btn(hb, "Find selected", func(): main.focus_selected())


func _h(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	return h


func _btn(parent: Control, text: String, cb: Callable, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	if toggle:
		b.toggled.connect(func(on): cb.call(on))
	else:
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _rich(parent: Control, min_h: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.custom_minimum_size = Vector2(0, min_h)
	r.add_theme_font_size_override("normal_font_size", 11)
	r.add_theme_font_size_override("bold_font_size", 11)
	parent.add_child(r)
	return r


func _speed(sp: float, on: bool) -> void:
	if on:
		main.speed = sp


func set_speed(sp: float) -> void:
	for i in SPEEDS.size():
		speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], sp))


static func _esc(s: String) -> String:
	return s.replace("[", "(").replace("]", ")")


func refresh(w, d, actual: float) -> void:
	clock.text = w.clock(w.t)
	speed_note.text = "Running at %.1fx real time (target %sx)  ·  %d people on the streets  ·  %d units" % [actual, str(main.speed), _on_foot(w), _units(w)]
	# ---- the gangs
	var tx := "[b]WHO HOLDS PORT CARRICK[/b]\n"
	var held := {}
	for bs in d.bstate:
		held[bs["owner"]] = held.get(bs["owner"], 0) + 1
	var n_b: int = d.bstate.size() - held.get(0, 0)
	for g in d.gangs:
		var fi: int = g["fi"]
		var alive := 0
		var ech := {"untrained": 0, "militia": 0, "regular": 0}
		for o in w.ops:
			if o.faction == fi and o.alive():
				alive += 1
				ech[o.echelon] = ech.get(o.echelon, 0) + 1
		var hoods: Array = []
		for hi in g.get("hoods", []):
			hoods.append(d.lv.hoods[hi]["name"])
		var ex := ""
		if g["expansion"] >= 0:
			var tgt: int = w.teams[g["expansion"]].get("target", -1)
			ex = "  ·  [i]attacking %s[/i]" % (d.lv.bldgs[tgt]["address"] if tgt >= 0 else "?")
		tx += "[b]%s[/b] (%s)  %d / %d  ·  %d buildings  ·  %.1f recruits/min%s\n" % [g["name"], _pat(fi), alive, int(d.cfg["gang_cap"]),
			held.get(fi, 0), g["rate"], ex]
		tx += "[color=#555555]      %d untrained, %d militia, %d soldiers  ·  kills %d, dead %d, taken %d  ·  %s[/color]\n" % [
			ech["untrained"], ech["militia"], ech["regular"], g["kills"], g["lost"], g["captured"],
			(", ".join(hoods) if not hoods.is_empty() else "no neighbourhood")]
	tx += "[color=#555555]Unclaimed: %d of %d buildings.  Captures %d, assaults %d.[/color]" % [held.get(-1, 0), n_b, d.stats["captures"], d.stats["expansions"]]
	factions_box.text = tx
	# ---- police and ambulances
	var pt := "[b]PORT CARRICK PD[/b]  "
	var on_duty := 0
	var down := 0
	for o2 in w.ops:
		if o2.faction == 0 and not o2.medic:
			if o2.alive():
				on_duty += 1
			elif o2.state == "down":
				down += 1
	pt += "%d on duty, %d down, %d recovering, %d new hires due  ·  cap %d\n" % [on_duty, down, d.returning.size(), d.hires.size(), int(d.cfg["police_cap"])]
	pt += "[color=#555555]Reports %d  ·  incidents %d  ·  waiting for a QRF: %d[/color]\n" % [d.stats["reports"], d.stats["incidents"], d.queue.size()]
	for st in d.stations:
		var n_q := 0
		for m in w.teams[st["qrf"]]["members"]:
			if m.alive():
				n_q += 1
		var what: String = {"base": "at the station", "outbound": "boarding", "driving": "driving out", "search": "searching",
			"return": "walking back to the vans", "homebound": "driving home", "lost": "wiped out"}.get(st["state"], st["state"])
		if st["inc"] >= 0 and st["state"] in ["outbound", "driving", "search"]:
			var inc: Dictionary = d.incidents[st["inc"] - 1]
			what += " (incident %d, building %d of %d)" % [inc["id"], mini(st["search_i"] + 1, inc["search"].size()), inc["search"].size()] if st["state"] == "search" else " (incident %d)" % inc["id"]
		var cvs: Array = []
		for cv in st["convoys"]:
			cvs.append({"patrol": "patrolling", "respond": "out on foot", "remount": "remounting", "down": "out of action"}.get(cv["state"], cv["state"]))
		pt += "QRF %d [color=#555555](%d/10)[/color] %s  ·  [color=#555555]patrols: %s[/color]\n" % [st["i"] + 1, n_q, what, ", ".join(cvs)]
	var jobs := {}
	for v in d.roads.vehicles:
		if v["kind"] == "amb" or v["kind"] == "pamb":
			var j: String = v.get("job", "idle")
			jobs[j] = jobs.get(j, 0) + 1
	pt += "[b]AMBULANCES[/b]  "
	var jp: Array = []
	for j2 in ["idle", "out", "fetch", "treat", "carry", "hospital", "home"]:
		if jobs.has(j2):
			jp.append("%d %s" % [jobs[j2], {"idle": "standing by", "out": "on the way", "fetch": "reaching casualties", "treat": "treating",
				"carry": "carrying stretchers", "hospital": "to hospital", "home": "returning"}[j2]])
	pt += ", ".join(jp) + "\n"
	pt += "[color=#555555]Saved %d  ·  bodies recovered %d  ·  died waiting %d[/color]" % [d.stats["saved"], d.stats["evacuated_dead"], d.stats["bled_out"]]
	police_box.text = pt
	# ---- the selected person
	_card(w)
	# ---- the feed
	feed_shown = clampi(feed_shown, 0, d.feed.size())
	if d.feed.size() > 0 and d.feed[0]["t"] != feed_t0:
		# the feed was trimmed at the front: find our place again
		var last_t: float = feed_t0
		feed_t0 = d.feed[0]["t"]
		feed_shown = 0
		while feed_shown < d.feed.size() and d.feed[feed_shown]["t"] <= last_t and last_t >= 0.0:
			feed_shown += 1
	while feed_shown < d.feed.size():
		var ln: Dictionary = d.feed[feed_shown]
		feed_shown += 1
		feed_box.append_text("[color=#777777]%s[/color]  %s\n" % [w.clock(ln["t"]), _esc(ln["text"])])


func _pat(fi: int) -> String:
	return {1: "dots", 2: "bands", 3: "hatch", 4: "cross-hatch"}.get(fi, "")


func _on_foot(w) -> int:
	var n := 0
	for o in w.ops:
		if o.alive() and o.mounted == null:
			n += 1
	return n


func _units(w) -> int:
	var n := 0
	for tm in w.teams:
		if not tm["free"]:
			n += 1
	return n


func _card(w) -> void:
	var o = w.op_by_id(main.selected) if main.selected != "" else null
	if o == null:
		if main.selected != "":
			card.text = "[color=#777777]%s is no longer on the plan (taken to hospital or the morgue).[/color]" % main.selected
		return
	var fac: String = w.factions[o.faction]["name"]
	var tm: Dictionary = w.teams[o.team] if o.team >= 0 and o.team < w.teams.size() else {}
	var st := "on their feet"
	if o.state == "dead":
		st = "[color=#7d0a0a]dead[/color]"
	elif o.state == "down":
		st = "[color=#7d0a0a]down, %d s left to reach an ambulance[/color]" % int(maxf(0.0, w.BLEED_OUT - (w.t - o.ticker.get("down_t", w.t)))) if not o.carried else "down, aboard or on a stretcher"
	elif o.mounted != null:
		st = "in a vehicle"
	var al: String = ["[color=#3d7a46]GREEN[/color]", "[color=#a8861c]YELLOW[/color]", "[color=#9b2a27]RED[/color]"][clampi(o.alert, 0, 2)]
	var t := "[b]%s[/b]  %s, %s  ·  %s\n" % [_esc(o.name), o.rank, fac, o.id]
	t += "%s  ·  %s  ·  %s\n" % [Habits.ECHELONS[o.echelon]["name"], al, st]
	t += "[color=#555555]%s[/color]\n" % _esc(UI.quirks(o))
	if not o.medic:
		var s: Dictionary = o.ws()
		t += "%s %d+%d  ·  plates %d/%d  ·  experience %d  ·  stress %d%%%s\n" % ["Rifle" if o.active == "rifle" else "Pistol", s["mag"], s["spare"],
			o.plates, o.plates_max, o.exp, int(o.stress * 100.0), "  ·  [b]%s[/b]" % " ".join(o.active_bad.keys()) if not o.active_bad.is_empty() else ""]
	t += "[color=#555555]%s  ·  %s  ·  %s[/color]" % [_esc(tm.get("tag", "")), _esc(o.dbg), _esc(w.director.place_name(o.pos))]
	card.text = t
