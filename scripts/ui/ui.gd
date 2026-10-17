extends CanvasLayer
## Right-hand panel: setup (placement, echelon presets, habits, seed) and run
## (speed up to 20x, overlays, operator cards, event log). Built in code so the
## whole UI lives in one readable file. Greyscale, drafting-table style.

const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const PANEL_W := 460.0
const INK := Color("#1c1c1c")
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0]
const SHORT := {"untrained": "Untrained", "militia": "Militia", "patrol": "Patrol", "regular": "Regular", "police": "Police tac", "sof": "Spec ops"}

var main
var root: PanelContainer
var setup_box: VBoxContainer
var run_box: VBoxContainer
var banner: PanelContainer
var banner_label: Label
var sel_buttons := {}
var size_spins: Array = []
var posture_opts: Array = []
var alert_opts: Array = []
var cfg_title: Label
var sub: Label
var map_opt: OptionButton
var exp_spin: SpinBox
var exp_label: Label
var ech_opt: OptionButton
var plate_spin: SpinBox
var habit_buttons := {}
var tabs: TabContainer
var summary: Label
var seed_spin: SpinBox
var clock: Label
var speed_buttons: Array = []
var pause_btn: Button
var roster: RichTextLabel
var log_box: RichTextLabel
var log_shown := 0
var speed_note: Label
var gang_cap_spin: SpinBox
var police_cap_spin: SpinBox
var _updating := false
# v0.6
var civ_spin: SpinBox
var police_btn: Button
var night_btn: Button
var dept_btn: Button
var cam_btn: Button
var dept_box: VBoxContainer
var dept_head: Label
var dept_list: VBoxContainer
var dept_notes: RichTextLabel
var dept_seed: SpinBox
var debrief: RichTextLabel


func build(m) -> void:
	main = m
	var th := _theme()
	root = PanelContainer.new()
	root.theme = th
	root.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	root.offset_left = -PANEL_W
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	var title := Label.new()
	title.text = "T H E   V I O L E N C E"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	sub = Label.new()
	sub.add_theme_color_override("font_color", Color("#666666"))
	v.add_child(sub)
	set_map_title(main.level)
	v.add_child(HSeparator.new())
	setup_box = VBoxContainer.new()
	setup_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(setup_box)
	run_box = VBoxContainer.new()
	run_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	run_box.visible = false
	v.add_child(run_box)
	dept_box = VBoxContainer.new()
	dept_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dept_box.visible = false
	v.add_child(dept_box)
	_build_setup()
	_build_run()
	_build_dept()
	banner = PanelContainer.new()
	banner.theme = th
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(40, 18)
	banner.visible = false
	add_child(banner)
	banner_label = Label.new()
	banner_label.add_theme_font_size_override("font_size", 22)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_label)


# ================================================================== theme
static func _sb(bg: Color, border: Color, bw := 1, margin := 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	return s


func _theme() -> Theme:
	return make_theme()


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 13
	th.set_stylebox("panel", "PanelContainer", _sb(Color("#f3f3f1"), INK, 1, 12.0))
	var normal := _sb(Color("#ffffff"), Color("#9a9a9a"), 1, 5.0)
	var hover := _sb(Color("#f4f4f4"), INK, 1, 5.0)
	var pressed := _sb(Color("#d4d4d1"), INK, 1, 5.0)
	var disabled := _sb(Color("#eeeeee"), Color("#cccccc"), 1, 5.0)
	var focus := StyleBoxEmpty.new()
	for t in ["Button", "OptionButton"]:
		th.set_stylebox("normal", t, normal)
		th.set_stylebox("hover", t, hover)
		th.set_stylebox("pressed", t, pressed)
		th.set_stylebox("hover_pressed", t, pressed)
		th.set_stylebox("disabled", t, disabled)
		th.set_stylebox("focus", t, focus)
		th.set_color("font_color", t, INK)
		th.set_color("font_hover_color", t, Color.BLACK)
		th.set_color("font_pressed_color", t, Color.BLACK)
		th.set_color("font_hover_pressed_color", t, Color.BLACK)
		th.set_color("font_focus_color", t, INK)
		th.set_color("font_disabled_color", t, Color("#9a9a9a"))
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("normal", "LineEdit", _sb(Color("#ffffff"), Color("#9a9a9a"), 1, 4.0))
	th.set_stylebox("focus", "LineEdit", _sb(Color("#ffffff"), INK, 1, 4.0))
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_stylebox("normal", "RichTextLabel", _sb(Color("#ffffff"), Color("#9a9a9a"), 1, 6.0))
	th.set_stylebox("background", "ProgressBar", _sb(Color("#e4e4e2"), Color("#9a9a9a"), 1, 0.0))
	th.set_stylebox("fill", "ProgressBar", _sb(Color("#3a3a3a"), Color("#3a3a3a"), 0, 0.0))
	th.set_stylebox("panel", "PopupMenu", _sb(Color("#ffffff"), INK, 1, 4.0))
	th.set_stylebox("hover", "PopupMenu", _sb(Color("#e8e8e8"), Color("#e8e8e8"), 0, 2.0))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", Color.BLACK)
	th.set_stylebox("panel", "TooltipPanel", _sb(Color("#ffffff"), INK, 1, 6.0))
	th.set_color("font_color", "TooltipLabel", INK)
	th.set_stylebox("panel", "TabContainer", _sb(Color("#ffffff"), Color("#9a9a9a"), 1, 6.0))
	th.set_stylebox("tab_selected", "TabContainer", _sb(INK, INK, 1, 6.0))
	th.set_stylebox("tab_unselected", "TabContainer", _sb(Color("#ffffff"), Color("#9a9a9a"), 1, 6.0))
	th.set_stylebox("tab_hovered", "TabContainer", _sb(Color("#eeeeee"), INK, 1, 6.0))
	th.set_color("font_selected_color", "TabContainer", Color.WHITE)
	th.set_color("font_unselected_color", "TabContainer", INK)
	th.set_color("font_hovered_color", "TabContainer", Color.BLACK)
	return th


# ================================================================== setup panel
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


func _heading(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#555555"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func set_map_title(lv) -> void:
	sub.text = "%s  ·  %d x %d m  ·  up to 20 a side" % [lv.map_name, int(lv.W), int(lv.H)]
	if map_opt != null:
		map_opt.select(main.map_i)


func _build_setup() -> void:
	var s := setup_box
	s.add_theme_constant_override("separation", 5)
	var hm := _h(s)
	var ml := Label.new()
	ml.text = "Map"
	ml.custom_minimum_size = Vector2(56, 0)
	hm.add_child(ml)
	map_opt = OptionButton.new()
	for nm in Maps.names():
		map_opt.add_item(nm)
	map_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_opt.select(main.map_i)
	map_opt.item_selected.connect(func(i): main.set_map(i))
	hm.add_child(map_opt)
	_heading(s, "1  PLACE  ·  click the plan to place the selected operator; right-click sets facing; wheel zooms, middle-drag pans")
	var group := ButtonGroup.new()
	for k in 2:
		var h := _h(s)
		var l := Label.new()
		l.text = "Team %s" % "AB"[k]
		l.custom_minimum_size = Vector2(56, 0)
		h.add_child(l)
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = 20
		sp.suffix = "operators"
		sp.custom_minimum_size = Vector2(132, 0)
		sp.value_changed.connect(func(v): _size(k, v))
		h.add_child(sp)
		size_spins.append(sp)
		var o := OptionButton.new()
		o.custom_minimum_size = Vector2(110, 0)
		for p in ["Assault", "Hold", "Hunt"]:
			o.add_item(p)
		o.item_selected.connect(func(i): main.set_posture(k, ["assault", "hold", "hunt"][i]))
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(o)
		posture_opts.append(o)
		var ao := OptionButton.new()
		ao.custom_minimum_size = Vector2(86, 0)
		for an in ["Green", "Yellow"]:
			ao.add_item(an)
		ao.tooltip_text = "Starting alert state.\nGreen: relaxed, rifles at low carry and pistols holstered (slower to fire, slower to notice).\nYellow: weapons drawn and ready.\nRed (engaging) and the step down to green after a quiet minute happen on their own."
		ao.item_selected.connect(func(i): main.set_alert(k, i))
		h.add_child(ao)
		alert_opts.append(ao)
		var grid := GridContainer.new()
		grid.columns = 10
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		s.add_child(grid)
		for slot in 20:
			var id := "%s%d" % ["AB"[k], slot + 1]
			var b := _btn(grid, id, func(on): _sel(id, on), true)
			b.button_group = group
			b.custom_minimum_size = Vector2(41, 0)
			b.add_theme_font_size_override("font_size", 11)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sel_buttons[id] = b
	s.add_child(HSeparator.new())
	cfg_title = _heading(s, "2  CONFIGURE")
	var he := _h(s)
	ech_opt = OptionButton.new()
	for e in Habits.ECHELON_ORDER:
		ech_opt.add_item(Habits.ECHELONS[e]["name"])
	ech_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ech_opt.item_selected.connect(func(i): main.set_echelon(Habits.ECHELON_ORDER[i], false))
	he.add_child(ech_opt)
	_btn(he, "Apply preset", func(): main.set_echelon(Habits.ECHELON_ORDER[ech_opt.selected], true))
	var pl := Label.new()
	pl.text = "Plates"
	he.add_child(pl)
	plate_spin = SpinBox.new()
	plate_spin.min_value = 0
	plate_spin.max_value = 4
	plate_spin.custom_minimum_size = Vector2(72, 0)
	plate_spin.value_changed.connect(func(v): _plates(v))
	he.add_child(plate_spin)
	var hq := _h(s)
	_btn(hq, "All good", func(): main.bulk("good", true))
	_btn(hq, "No good", func(): main.bulk("good", false))
	_btn(hq, "Stress on", func(): main.bulk("stress", true))
	_btn(hq, "No bad", func(): main.bulk("bad", false))
	_btn(hq, "Copy to team", func(): main.copy_to_team())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.add_child(tabs)
	var names := {"Pathfinding": "Path", "Group discipline": "Group", "Eye discipline": "Eyes", "Weapon discipline": "Weapon"}
	for grp in Habits.GROUPS:
		var sc := ScrollContainer.new()
		sc.name = names[grp]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(col)
		for g in Habits.GOOD:
			if g["group"] != grp:
				continue
			var gid: String = g["id"]
			var b := _btn(col, "", func(on): _habit(gid, on), true)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = "%s %s\nWith it: %s\nWithout it: %s\nOverridden by: %s" % [gid, g["name"], g["with"], g["without"], _overriders(gid)]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			habit_buttons[gid] = b
	var scb := ScrollContainer.new()
	scb.name = "Bad"
	scb.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scb)
	var colb := VBoxContainer.new()
	colb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scb.add_child(colb)
	_heading(colb, "Stress-triggered: present habits switch on under fire")
	for kind in ["stress", "trait"]:
		if kind == "trait":
			_heading(colb, "Personality: present habits are always on")
		for b0 in Habits.BAD:
			if b0["kind"] != kind:
				continue
			var bid: String = b0["id"]
			var bb := _btn(colb, "", func(on): _habit(bid, on), true)
			bb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var trig: String = ("stress %.2f" % b0["t"]) if kind == "stress" else b0["trait"]
			bb.tooltip_text = "%s %s (%s)\n%s\nOverrides: %s" % [bid, b0["name"], trig, b0["desc"], ", ".join(b0["over"])]
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			habit_buttons[bid] = bb
	var sct := ScrollContainer.new()
	sct.name = "Traits"
	sct.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sct)
	var colt := VBoxContainer.new()
	colt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sct.add_child(colt)
	_heading(colt, "Experience: how many enemies the operator tracks at once. Tracked enemies are recognized and aimed for in parallel; switching to one already acquired takes under a tenth of a second. Tier 1 takes one enemy at a time, from scratch.")
	var hx := _h(colt)
	var xl := Label.new()
	xl.text = "Experience tier"
	hx.add_child(xl)
	exp_spin = SpinBox.new()
	exp_spin.min_value = 1
	exp_spin.max_value = Habits.EXP_MAX
	exp_spin.custom_minimum_size = Vector2(72, 0)
	exp_spin.value_changed.connect(func(v): _exp(v))
	hx.add_child(exp_spin)
	exp_label = Label.new()
	exp_label.add_theme_color_override("font_color", Color("#555555"))
	hx.add_child(exp_label)
	_heading(colt, "Hearing: every operator hears the same (shots, footsteps, reloads; walls halve it) unless a trait changes it.")
	for tr in Habits.TRAITS:
		var tid: String = tr["id"]
		var tb := _btn(colt, "", func(on): _trait(tid, on), true)
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tb.tooltip_text = "%s %s (%s)\n%s" % [tid, tr["name"], tr["kind"], tr["desc"]]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		habit_buttons[tid] = tb
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.add_child(summary)
	s.add_child(HSeparator.new())
	var hs := _h(s)
	var sl := Label.new()
	sl.text = "Seed"
	hs.add_child(sl)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = 1001
	seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.add_child(seed_spin)
	_btn(hs, "Random", func(): seed_spin.value = randi_range(1, 999999))
	seed_spin.custom_minimum_size = Vector2(120, 0)
	seed_spin.value_changed.connect(func(_v): if main.n_civ > 0: main.set_civilians(main.n_civ))
	_heading(s, "3  OPERATION  ·  civilians on the map; police rules (team A judges a person before firing, challenges, arrests); team A from the department")
	var hc := _h(s)
	var cl := Label.new()
	cl.text = "Civilians"
	hc.add_child(cl)
	civ_spin = SpinBox.new()
	civ_spin.min_value = 0
	civ_spin.max_value = 40
	civ_spin.value = main.n_civ
	civ_spin.custom_minimum_size = Vector2(72, 0)
	civ_spin.tooltip_text = "Civilians placed from the seed, about two in three indoors.\nNobody targets them on purpose; every bullet can hit them."
	civ_spin.value_changed.connect(func(v): if not _updating: main.set_civilians(int(v)))
	hc.add_child(civ_spin)
	police_btn = _btn(hc, "Police rules", func(on): main.set_police_rules(on), true)
	police_btn.set_pressed_no_signal(main.police_rules)
	police_btn.tooltip_text = "Team A judges every recognized person before firing: a threat (armed or attacking),\nunknown (challenged: Police! Show me your hands!) or a civilian. Judgment can be wrong.\nSuspects may give up; officers cuff them. Always on with the department."
	night_btn = _btn(hc, "Night", func(on): main.set_night(on), true)
	night_btn.set_pressed_no_signal(main.night)
	night_btn.tooltip_text = "Darkness: recognition and judgment take longer, and civilians are misjudged more often."
	var hd := _h(s)
	dept_btn = _btn(hd, "Team A: department", func(on): main.set_use_dept(on), true)
	dept_btn.set_pressed_no_signal(main.use_dept)
	dept_btn.tooltip_text = "Team A is the officers picked in the department (Patrol echelon, rolled at hire).\nAfter the operation their experience, wounds and files are written back and saved."
	cam_btn = _btn(hd, "Body cameras", func(on): main.set_bodycams(on), true)
	cam_btn.set_pressed_no_signal(main.dept.bodycams)
	cam_btn.tooltip_text = "Department officers wear body cameras: what they see is recorded as evidence."
	_btn(hd, "Department  ...", func(): show_dept())
	var run := _btn(s, "RUN   >   auto-resolve", func(): main.start_run(int(seed_spin.value)))
	run.custom_minimum_size = Vector2(0, 40)
	run.add_theme_font_size_override("font_size", 16)
	s.add_child(HSeparator.new())
	_heading(s, "ENDLESS BATTLE  ·  a city of four gangs, six police precincts and three hospitals that fights on for as long as you watch (uses the seed above)")
	var he2 := _h(s)
	var gl := Label.new()
	gl.text = "Gang cap"
	he2.add_child(gl)
	gang_cap_spin = SpinBox.new()
	gang_cap_spin.min_value = 20
	gang_cap_spin.max_value = 120
	gang_cap_spin.value = 60
	gang_cap_spin.tooltip_text = "Most members a gang can have at once"
	he2.add_child(gang_cap_spin)
	var pl2 := Label.new()
	pl2.text = "Police cap"
	he2.add_child(pl2)
	police_cap_spin = SpinBox.new()
	police_cap_spin.min_value = 40
	police_cap_spin.max_value = 200
	police_cap_spin.value = 108
	police_cap_spin.tooltip_text = "No new officers are hired while on duty + recovering + already hired reach this.\nFull strength is 108: six ten-man QRFs and twelve four-officer patrol convoys."
	he2.add_child(police_cap_spin)
	var eb := _btn(s, "ENDLESS BATTLE   >   Port Carrick", func(): main.start_city(int(seed_spin.value), int(gang_cap_spin.value), int(police_cap_spin.value)))
	eb.custom_minimum_size = Vector2(0, 34)
	eb.add_theme_font_size_override("font_size", 14)


func _size(k: int, v: float) -> void:
	if not _updating:
		main.set_team_size(k, int(v))


func _sel(id: String, on: bool) -> void:
	if on and not _updating:
		main.select_op(id)


func _plates(v: float) -> void:
	if not _updating:
		main.set_plates(int(v))


func _habit(hid: String, on: bool) -> void:
	if not _updating:
		main.set_habit(hid, on)


func _trait(tid: String, on: bool) -> void:
	if not _updating:
		main.set_trait(tid, on)


func _exp(v: float) -> void:
	if not _updating:
		main.set_exp(int(v))


func _speed(sp: float, on: bool) -> void:
	if on:
		main.set_speed(sp)


func _overriders(gid: String) -> String:
	var out: Array = []
	for b in Habits.BAD:
		if gid in b["over"]:
			out.append("%s %s" % [b["id"], b["name"]])
	return ", ".join(out) if not out.is_empty() else "none"


## Refresh the setup controls from main's configuration of the selected operator.
func refresh_setup(sel: String, cfgs: Dictionary, postures: Array, sizes: Array) -> void:
	_updating = true
	for id in sel_buttons:
		sel_buttons[id].set_pressed_no_signal(id == sel)
		sel_buttons[id].disabled = not cfgs[id]["enabled"]
		var ec: String = cfgs[id]["echelon"]
		sel_buttons[id].tooltip_text = "%s  %s" % [id, Habits.ECHELONS[ec]["name"]]
	for k in 2:
		size_spins[k].set_value_no_signal(sizes[k])
	for k in 2:
		posture_opts[k].select(["assault", "hold", "hunt"].find(postures[k]))
		alert_opts[k].select(clampi(main.alerts[k], 0, 1))
	var c: Dictionary = cfgs[sel]
	cfg_title.text = "2  CONFIGURE %s   ·   team %s" % [sel, "AB"[c["team"]]]
	ech_opt.select(Habits.ECHELON_ORDER.find(c["echelon"]))
	plate_spin.set_value_no_signal(c["plates"])
	var n_good := 0
	var n_bad := 0
	for g in Habits.GOOD:
		var on: bool = c["good"].get(g["id"], false)
		n_good += 1 if on else 0
		var b: Button = habit_buttons[g["id"]]
		b.set_pressed_no_signal(on)
		b.text = "%s  %s   %s" % ["[x]" if on else "[  ]", g["id"], g["name"]]
	for b0 in Habits.BAD:
		var on2: bool = c["bad"].get(b0["id"], false)
		n_bad += 1 if on2 else 0
		var bb: Button = habit_buttons[b0["id"]]
		bb.set_pressed_no_signal(on2)
		var trig: String = ("stress %.2f" % b0["t"]) if b0["kind"] == "stress" else b0["trait"]
		bb.text = "%s  %s   %s   (%s)" % ["[x]" if on2 else "[  ]", b0["id"], b0["name"], trig]
	var xp: int = c.get("exp", 1)
	exp_spin.set_value_no_signal(xp)
	exp_label.text = "  %s: tracks %d enem%s" % [Habits.EXP_NAMES[xp], xp, "y" if xp == 1 else "ies"]
	var traits: Dictionary = c.get("traits", {})
	var tnames: Array = []
	for tr in Habits.TRAITS:
		var on3: bool = traits.get(tr["id"], false)
		var tb: Button = habit_buttons[tr["id"]]
		tb.set_pressed_no_signal(on3)
		tb.text = "%s  %s   %s   (hearing x%s)" % ["[x]" if on3 else "[  ]", tr["id"], tr["name"], str(tr["hear"])]
		if on3:
			tnames.append(tr["name"])
	var e: Dictionary = Habits.ECHELONS[c["echelon"]]
	summary.text = "%s: %d good habits (reaction time x%.3f), %d bad habits present, experience %d. Recognition base %.2f s, stress resistance %.2f, %d plate%s, hearing x%.2f%s." % [
		sel, n_good, 1.0 - 0.005 * n_good, n_bad, xp, e["t_rec0"], e["resist"], c["plates"], "" if c["plates"] == 1 else "s",
		Habits.hearing(traits), (" (" + ", ".join(tnames) + ")") if not tnames.is_empty() else ""]
	_updating = false


# ================================================================== run panel
func _build_run() -> void:
	var r := run_box
	r.add_theme_constant_override("separation", 6)
	var h := _h(r)
	pause_btn = _btn(h, "Pause", func(on): main.set_paused(on), true)
	clock = Label.new()
	clock.text = "00:00.0"
	clock.add_theme_font_size_override("font_size", 18)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(clock)
	var hs := _h(r)
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
	r.add_child(speed_note)
	var ho := _h(r)
	for nm in ["Cones", "Recognition", "Aim", "Paths"]:
		var b2 := _btn(ho, nm, func(on): main.set_overlay(nm, on), true)
		b2.set_pressed_no_signal(nm != "Paths")
	debrief = RichTextLabel.new()
	debrief.bbcode_enabled = true
	debrief.scroll_active = true
	debrief.custom_minimum_size = Vector2(0, 300)
	debrief.add_theme_font_size_override("normal_font_size", 11)
	debrief.add_theme_font_size_override("bold_font_size", 11)
	debrief.visible = false
	r.add_child(debrief)
	roster = RichTextLabel.new()
	roster.bbcode_enabled = true
	roster.scroll_active = true
	roster.custom_minimum_size = Vector2(0, 380)
	roster.add_theme_font_size_override("normal_font_size", 11)
	roster.add_theme_font_size_override("bold_font_size", 11)
	r.add_child(roster)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_size_override("normal_font_size", 11)
	log_box.add_theme_font_size_override("bold_font_size", 11)
	r.add_child(log_box)
	var hb := _h(r)
	_btn(hb, "Back to setup", func(): main.back_to_setup())
	_btn(hb, "Rerun same seed", func(): main.rerun(false))
	_btn(hb, "Rerun new seed", func(): main.rerun(true))


func show_setup() -> void:
	setup_box.visible = true
	run_box.visible = false
	dept_box.visible = false
	banner.visible = false


func show_run(speed: float) -> void:
	setup_box.visible = false
	run_box.visible = true
	dept_box.visible = false
	banner.visible = false
	debrief.visible = false
	roster.custom_minimum_size = Vector2(0, 380)
	log_box.clear()
	log_shown = 0
	pause_btn.set_pressed_no_signal(false)
	for i in SPEEDS.size():
		speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], speed))
	roster.clear()


func refresh_run(w, actual_speed: float, target_speed: float) -> void:
	var mm := int(w.t / 60.0)
	clock.text = "%02d:%04.1f" % [mm, fmod(w.t, 60.0)]
	speed_note.text = "Simulation runs at %.1fx real time (target %sx). 30 ticks per simulated second." % [actual_speed, str(target_speed)]
	var txt_all := ""
	var many: bool = w.ops.size() > 10
	var pol: bool = w.police_rules()
	for k in 2:
		var tm: Dictionary = w.teams[k]
		var n_alive := 0
		for o in tm["members"]:
			if o.fighting():
				n_alive += 1
		txt_all += "[b]%s[/b]  %d / %d standing  ·  %s  ·  %d element%s\n" % [(["POLICE", "SUSPECTS"][k] if pol else "TEAM " + "AB"[k]), n_alive, tm["members"].size(),
			tm["posture"], tm["elements"].size(), "" if tm["elements"].size() == 1 else "s"]
		for o in tm["members"]:
			var st := "OK"
			if o.state == "dead":
				st = "KIA"
			elif o.state == "down":
				st = "DOWN"
			elif o.wounds > 0 or o.arm_hit or o.leg_hit:
				st = "WND"
			var s: Dictionary = o.ws()
			var bad: Array = []
			for b in o.active_bad:
				bad.append(b)
			var bar := ""
			for i in 10:
				bar += "|" if i < int(o.stress * 10.0) else "."
			var head := "[hint=\"%s\"][b]%s[/b][/hint] %s %s" % [quirks(o).replace("\"", "'"), o.id, SHORT.get(o.echelon, o.echelon), st]
			if st == "KIA" or st == "DOWN":
				txt_all += "[color=#7d0a0a]%s[/color]\n" % head
				continue
			if o.complying:
				txt_all += "%s  [b]%s[/b]\n" % [head, "CUFFED" if o.arrested else "HANDS UP"]
				continue
			var line := "%s %s  %s %d+%d  pl %d/%d  xp %d  st %s" % [head, ["[color=#3d7a46]G[/color]", "[color=#a8861c]Y[/color]", "[color=#9b2a27]R[/color]"][o.alert],
				"R" if o.active == "rifle" else "P", s["mag"], s["spare"], o.plates, o.plates_max, o.exp, bar]
			if not bad.is_empty():
				line += "  [b]%s[/b]" % " ".join(bad)
			txt_all += line + "\n"
			if not many:
				txt_all += "[color=#555555]      %s[/color]\n" % quirks(o)
			if not many or o.dbg != "":
				txt_all += "[color=#555555]      %s[/color]\n" % o.dbg.replace("[", "(")
	if w.teams.size() > 2 and w.teams[2].get("civ", false) and not w.teams[2]["members"].is_empty():
		var counts := {}
		var hit := 0
		var dead := 0
		for c in w.teams[2]["members"]:
			if c.state == "dead":
				dead += 1
			elif c.state != "ok" or c.wounds > 0 or c.leg_hit or c.arm_hit:
				hit += 1
			else:
				counts[c.cstate] = counts.get(c.cstate, 0) + 1
		var parts: Array = []
		for st2 in ["unaware", "alarmed", "flee", "hide", "freeze", "comply", "film"]:
			if counts.has(st2):
				parts.append("%d %s" % [counts[st2], {"unaware": "unaware", "alarmed": "alarmed", "flee": "fleeing", "hide": "hiding",
					"freeze": "frozen", "comply": "hands up", "film": "filming"}[st2]])
		txt_all += "[b]CIVILIANS[/b]  %d  ·  %s%s%s\n" % [w.teams[2]["members"].size(), ", ".join(parts),
			("  ·  [color=#7d0a0a]%d hurt[/color]" % hit) if hit > 0 else "", ("  ·  [color=#7d0a0a][b]%d dead[/b][/color]" % dead) if dead > 0 else ""]
	roster.text = txt_all
	log_shown = maxi(log_shown, w.log_base)
	while log_shown < w.log_base + w.log_lines.size():
		var ln: Dictionary = w.log_lines[log_shown - w.log_base]
		var txt: String = ln["text"].replace("[", "(").replace("]", ")")
		match ln["kind"]:
			"kill":
				log_box.append_text("[b][color=#7d0a0a]%s[/color][/b]\n" % txt)
			"hit":
				log_box.append_text("[color=#5a1a1a]%s[/color]\n" % txt)
			"bad":
				log_box.append_text("[b]%s[/b]\n" % txt)
			"end":
				log_box.append_text("[b]%s[/b]\n" % txt)
			"comms":
				log_box.append_text("[i][color=#555555]%s[/color][/i]\n" % txt)
			"civ":
				log_box.append_text("[color=#666666]%s[/color]\n" % txt)
			"rule":
				log_box.append_text("[color=#333333]%s[/color]\n" % txt)
			_:
				log_box.append_text("[color=#444444]%s[/color]\n" % txt)
		log_shown += 1


## An operator's roll for this match: form and named strengths and weaknesses.
static func quirks(o) -> String:
	var e: Dictionary = o.ech
	var parts: Array = ["%s, form %+d%%" % [o.name, int(round((1.0 - float(e.get("form", 1.0))) * 100.0))]]
	for q in e.get("plus", []):
		parts.append("+" + q)
	for q2 in e.get("minus", []):
		parts.append("-" + q2)
	return "  ".join(parts)


func show_banner(text: String) -> void:
	banner_label.text = text
	banner.visible = true


# ================================================================== debrief (v0.6)
## The incident record when the operation ends: what happened, what can be proved, and
## (with the department) what was written into the officers' files.
func show_debrief(w, dept_lines: Array, used_dept: bool) -> void:
	if w.incident == null:
		return
	var s: Dictionary = w.incident.summary()
	var t := "[b]INCIDENT RECORD[/b]  %s\n" % ("(the department's copy is saved)" if used_dept else "")
	if w.police_rules():
		t += "Suspects: %d, %d down (%d killed), %d gave up, %d cuffed.  Officers: %d, %d down (%d killed).\n" % [
			s["suspects"], s["suspects_down"], s["suspects_killed"], s["surrendered"], s["arrested"],
			s["officers"], s["officers_down"], s["officers_killed"]]
	if s["civ_total"] > 0:
		t += "Civilians: %d, [color=#7d0a0a]%d hurt, %d killed[/color]; %d police round%s struck a civilian.\n" % [
			s["civ_total"], s["civ_hit"], s["civ_killed"], s["civ_hit_police"], "" if s["civ_hit_police"] == 1 else "s"]
	t += "Rounds fired: %d (police %d); %d went through a wall.  Misjudgments: %d.  Shots after someone gave up or went down: %d.\n" % [
		s["shots"], s["police_shots"], s["through_walls"], s["misjudged"], s["excessive"]]
	if s["lines"].is_empty():
		t += "\nNo findings.\n"
	else:
		t += "\n[b]FINDINGS[/b]  %d\n" % s["lines"].size()
		for ln in s["lines"]:
			var red: bool = ln["kind"] in ["civilian_killed", "excessive_force", "civilian_hit_by_police", "misjudgment", "officer_killed"]
			var txt: String = String(ln["text"]).replace("[", "(").replace("]", ")")
			t += ("[color=#7d0a0a]%s[/color]\n" % txt) if red else (txt + "\n")
	if not dept_lines.is_empty():
		t += "\n[b]THE DEPARTMENT[/b]\n"
		for d in dept_lines:
			t += String(d).replace("[", "(") + "\n"
	debrief.text = t
	debrief.visible = true
	roster.custom_minimum_size = Vector2(0, 160)


# ================================================================== the department (v0.5)
func _build_dept() -> void:
	var d := dept_box
	d.add_theme_constant_override("separation", 5)
	dept_head = Label.new()
	dept_head.add_theme_font_size_override("font_size", 15)
	dept_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(dept_head)
	_heading(d, "Every officer was rolled once, at hire, and keeps that roll. Tick who goes on the next operation (team A, in this order). Hover a name for their file.")
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.add_child(sc)
	dept_list = VBoxContainer.new()
	dept_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dept_list.add_theme_constant_override("separation", 2)
	sc.add_child(dept_list)
	dept_notes = RichTextLabel.new()
	dept_notes.bbcode_enabled = true
	dept_notes.custom_minimum_size = Vector2(0, 150)
	dept_notes.scroll_following = true
	dept_notes.add_theme_font_size_override("normal_font_size", 11)
	d.add_child(dept_notes)
	var h := _h(d)
	_btn(h, "Hire a recruit", func(): main.hire_recruit())
	_btn(h, "Next week", func(): main.next_week())
	var h2 := _h(d)
	_btn(h2, "New department", func(): main.new_department(int(dept_seed.value)))
	dept_seed = SpinBox.new()
	dept_seed.min_value = 1
	dept_seed.max_value = 999999
	dept_seed.value = 1001
	dept_seed.prefix = "seed"
	dept_seed.custom_minimum_size = Vector2(130, 0)
	h2.add_child(dept_seed)
	var back := _btn(d, "Back to setup", func(): show_setup())
	back.custom_minimum_size = Vector2(0, 34)


func show_dept() -> void:
	setup_box.visible = false
	run_box.visible = false
	dept_box.visible = true
	refresh_dept(main.dept, main.dept_sel)


func refresh_dept(dep, picked: Array) -> void:
	if dep == null or dept_head == null:
		return
	var av: Array = dep.available()
	dept_head.text = "PORT CARRICK PD  ·  week %d  ·  %d officers, %d fit  ·  %d operation%s" % [dep.week,
		dep.officers.filter(func(r): return r["status"] != "dead").size(), av.size(), dep.ops_run, "" if dep.ops_run == 1 else "s"]
	for ch in dept_list.get_children():
		ch.queue_free()
	var order: Array = dep.officers.duplicate()
	order.sort_custom(func(a, b):
		var sa: int = 0 if a["status"] == "active" else (1 if a["status"] == "injured" else 2)
		var sb: int = 0 if b["status"] == "active" else (1 if b["status"] == "injured" else 2)
		if sa != sb:
			return sa < sb
		var ra: int = dep.RANKS.find(a["rank"])
		var rb: int = dep.RANKS.find(b["rank"])
		if ra != rb:
			return ra > rb
		return int(a["xp"]) > int(b["xp"]))
	for r in order:
		var oid: String = r["id"]
		var status: String = "fit"
		if r["status"] == "injured":
			status = "out until week %d" % int(r["out_until"])
		elif r["status"] == "dead":
			status = "killed"
		var k: int = picked.find(oid)
		var b := _btn(dept_list, "", func(on): main.toggle_officer(oid, on), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		b.set_pressed_no_signal(k >= 0)
		b.disabled = r["status"] != "active"
		var pers: String = "" if r["personality"] == "" else " (" + String(r["personality"]).to_lower() + ")"
		b.text = "%s %s %s%s   %s %d xp   J %d   %s%s" % ["[A%d]" % (k + 1) if k >= 0 else "[   ]", String(r["rank"]).substr(0, 3) + ".",
			r["name"], pers, Habits.EXP_NAMES[int(r["exp"])], int(r["xp"]), int(r["judgment"]), status,
			("   trauma %.0f" % float(r["trauma"])) if float(r["trauma"]) >= 1.0 else ""]
		b.tooltip_text = officer_file(r)
	var nt := ""
	for n in dep.notes.slice(maxi(0, dep.notes.size() - 30)):
		nt += "[color=#555555]wk %d[/color]  %s\n" % [int(n["week"]), String(n["text"]).replace("[", "(")]
	dept_notes.text = nt
	if cam_btn != null:
		cam_btn.set_pressed_no_signal(dep.bodycams)


static func officer_file(r: Dictionary) -> String:
	var e: Dictionary = r["ech"]
	var t := "%s %s  ·  badge %d  ·  %s  ·  hired week %d%s\n" % [r["rank"], r["name"], int(r["badge"]), r["id"], int(r["hired_week"]),
		" (lateral)" if r.get("lateral", false) else ""]
	var plus: Array = []
	for q in e.get("plus", []):
		plus.append("+" + String(q))
	for q2 in e.get("minus", []):
		plus.append("-" + String(q2))
	t += "Patrol, form %+d%%  %s\n" % [int(round((1.0 - float(e.get("form", 1.0))) * 100.0)), "  ".join(plus)]
	t += "Recognition %.2f s, stress resistance %.2f.  Judgment %d, temper %d, integrity %d%s\n" % [float(e["t_rec0"]), float(e["resist"]),
		int(r["judgment"]), int(r["temper"]), int(r["integrity"]), ("  ·  " + String(r["personality"])) if r["personality"] != "" else ""]
	t += "Habits (%d): %s\n" % [r["good"].size(), " ".join(r["good"])]
	if not r["bad_traits"].is_empty():
		t += "Trait habits: %s\n" % " ".join(r["bad_traits"])
	t += "Experience %s (%d xp).  Operations %d, rounds %d, hits %d, down %d, arrests %d, civilians hit %d, wounded %d times.\n" % [
		Habits.EXP_NAMES[int(r["exp"])], int(r["xp"]), int(r["ops"]), int(r["shots"]), int(r["hits"]), int(r["kills"]), int(r["arrests"]),
		int(r["civ_hits"]), int(r["wounded"])]
	t += "\nFILE\n"
	for fe in (r["file"] as Array).slice(maxi(0, r["file"].size() - 14)):
		t += "wk %d  %s\n" % [int(fe["week"]), fe["text"]]
	return t
