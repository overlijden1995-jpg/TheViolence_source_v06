extends Node2D
## The Violence - vertical slice. Setup: pick a map, place up to twenty operators per
## team and edit their habits and traits. Run: the simulation auto-resolves at up to
## 20x while the plan collects the evidence.

const Habits = preload("res://scripts/data/habits.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Op = preload("res://scripts/sim/op.gd")
const FloorPlan = preload("res://scripts/view/floor_plan.gd")
const Decals = preload("res://scripts/view/decals.gd")
const ActorView = preload("res://scripts/view/actor_view.gd")
const Overlay = preload("res://scripts/view/overlay.gd")
const Marks = preload("res://scripts/view/marks.gd")
const SetupMarks = preload("res://scripts/view/setup_marks.gd")
const UI = preload("res://scripts/ui/ui.gd")
const Ledger = preload("res://scripts/view/ledger.gd")
const Department = preload("res://scripts/campaign/department.gd")
const Operation = preload("res://scripts/campaign/operation.gd")
const PX := 40.0
const DT := 1.0 / 30.0

var level
var nav
var map_i := 0
var cfgs := {}
var postures := ["assault", "hold"]
var alerts := [1, 1]                # starting alert per team: 0 green, 1 yellow
var sizes := [3, 5]
var IDS: Array = []
var sel := "A1"
var world = null
var mode := "setup"
var speed := 2.0
var paused := false
var acc := 0.0
var actual_speed := 0.0
var _meas_real := 0.0
var _meas_sim := 0.0
var _ui_t := 0.0
var _banner_done := false

var cam: Camera2D
var plan
var props_layer: Node2D
var marks
var decals
var actors_layer: Node2D
var canopy_layer: Node2D
var overlay
var setup_marks
var ui
var ledger_layer: CanvasLayer
var ledger
var views := {}
var preview_ops := {}
var _panning := false

# v0.6 operations: civilians, police rules, night, and team A from the department
var n_civ := 0
var police_rules := false
var night := false
var use_dept := false
var dept = null                     # the department (persistent, saved in user://)
var dept_sel: Array = []            # officer ids picked for the next operation
var _a_backup := {}                 # team A's setup configurations while the department stands in
var _applied := false
var dept_lines: Array = []

# command-line test hooks: --autorun --seed=N --speed=X --shot=path --shot-at=T --setup-shot=path
var _args := {}


func _ready() -> void:
	get_window().title = "The Violence"
	RenderingServer.set_default_clear_color(Color("#d6d6d3"))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for t in ["A", "B"]:
		for k in range(1, 21):
			IDS.append("%s%d" % [t, k])
	map_i = Maps.index_of(_args.get("map", "0"))
	level = Maps.get_level(map_i)
	nav = Nav.new()
	nav.build(level)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	plan = FloorPlan.new()
	add_child(plan)
	plan.setup(level)
	props_layer = Node2D.new()
	add_child(props_layer)
	marks = Marks.new()
	add_child(marks)
	marks.setup(level)
	decals = Decals.new()
	add_child(decals)
	actors_layer = Node2D.new()
	add_child(actors_layer)
	canopy_layer = Node2D.new()
	canopy_layer.modulate.a = 0.8
	add_child(canopy_layer)
	_build_props()
	overlay = Overlay.new()
	add_child(overlay)
	setup_marks = SetupMarks.new()
	setup_marks.main = self
	add_child(setup_marks)
	_default_cfgs()
	_load_department()
	n_civ = clampi(int(_args.get("civ", "0")), 0, 40)
	police_rules = _args.has("police")
	night = _args.has("night")
	ui = UI.new()
	add_child(ui)
	ui.build(self)
	ledger_layer = CanvasLayer.new()
	ledger_layer.layer = 2
	add_child(ledger_layer)
	ledger = Ledger.new()
	ledger.position = Vector2(10, 10)
	ledger_layer.add_child(ledger)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	if _args.has("tab"):
		ui.tabs.current_tab = int(_args["tab"])
	if _args.has("select"):
		select_op(_args["select"])
	if _args.has("zoom"):
		var zf := float(_args["zoom"])
		cam.zoom *= zf
		var f: PackedStringArray = _args.get("focus", "18,12").split(",")
		cam.position = Vector2(float(f[0]), float(f[1])) * PX + Vector2(UI.PANEL_W / 2.0 / cam.zoom.x, 0)
	if _args.has("dept"):
		set_use_dept(true)
	_enter_setup()
	if _args.has("speed"):
		speed = float(_args["speed"])
	if _args.has("autorun"):
		start_run(int(_args.get("seed", "1001")))
	if _args.has("city"):
		start_city.call_deferred(int(_args.get("seed", "1001")), 60, 108)


# ------------------------------------------------------------------ configuration
func _cfg_for(id: String, team: int, slot: int, echelon: String) -> Dictionary:
	var c := {"id": id, "team": team, "slot": slot, "echelon": echelon, "good": {}, "bad": {},
		"plates": 0, "exp": 1, "traits": {}, "pos": level.spawns[id]["p"], "face": level.spawns[id]["face"], "enabled": true,
		"alert": alerts[team]}
	_apply_preset(c, echelon)
	return c


func _apply_preset(c: Dictionary, echelon: String) -> void:
	c["echelon"] = echelon
	c["good"] = {}
	for g in Habits.preset_good(echelon):
		c["good"][g] = true
	var keep := {}
	for b in c["bad"]:
		if Habits.bad_info(b)["kind"] == "trait" and c["bad"][b]:
			keep[b] = true
	c["bad"] = keep
	for b in Habits.stress_bad_ids():
		c["bad"][b] = true
	c["plates"] = Habits.PRESET_PLATES[echelon]
	c["exp"] = Habits.PRESET_EXP[echelon]


## Default: an outnumbered special-operations team assaults a house held by militia.
func _default_cfgs() -> void:
	var ea: String = _args.get("a", "sof")
	var eb: String = _args.get("b", "militia")
	sizes = [clampi(int(_args.get("na", str(level.default_sizes[0]))), 1, 20), clampi(int(_args.get("nb", str(level.default_sizes[1]))), 1, 20)]
	cfgs = {}
	for id in IDS:
		var team := 0 if id.begins_with("A") else 1
		var slot := int(id.substr(1)) - 1
		cfgs[id] = _cfg_for(id, team, slot, ea if team == 0 else eb)
	_apply_sizes()


func _apply_sizes() -> void:
	for id in IDS:
		var c: Dictionary = cfgs[id]
		c["enabled"] = c["slot"] < sizes[c["team"]]


func cfg_list() -> Array:
	var out: Array = []
	for id in IDS:
		out.append(cfgs[id])
	return out


func select_op(id: String) -> void:
	sel = id
	_refresh()


func set_team_size(k: int, n: int) -> void:
	sizes[k] = clampi(n, 1, 20)
	_apply_sizes()
	if not cfgs[sel]["enabled"]:
		sel = "AB"[k] + "1"
	_rebuild_previews()
	_refresh()


func set_posture(k: int, p: String) -> void:
	postures[k] = p


func set_alert(k: int, lvl: int) -> void:
	alerts[k] = lvl
	for id in IDS:
		if cfgs[id]["team"] == k:
			cfgs[id]["alert"] = lvl
	_rebuild_previews()


## Leave for the endless battle (its own scene); options travel in a static.
func start_city(seed_val: int, gang_cap: int, police_cap: int) -> void:
	var CityMain = load("res://scripts/city_main.gd")
	CityMain.opts = {"seed": seed_val, "gang_cap": gang_cap, "police_cap": police_cap, "speed": speed}
	get_tree().change_scene_to_file("res://scenes/city.tscn")


func set_echelon(e: String, apply: bool) -> void:
	if apply:
		_apply_preset(cfgs[sel], e)
	else:
		cfgs[sel]["echelon"] = e
	_refresh()


func set_plates(n: int) -> void:
	cfgs[sel]["plates"] = n
	_refresh()


func set_exp(n: int) -> void:
	cfgs[sel]["exp"] = clampi(n, 1, Habits.EXP_MAX)
	_refresh()


func set_trait(tid: String, on: bool) -> void:
	cfgs[sel]["traits"][tid] = on
	_refresh()


## Switch maps: rebuild the plan, keep everyone's habits, move them to the new posts.
func set_map(i: int) -> void:
	if i == map_i:
		return
	map_i = i
	level = Maps.get_level(i)
	nav = Nav.new()
	nav.build(level)
	plan.setup(level)
	marks.setup(level)
	for ch in props_layer.get_children():
		ch.queue_free()
	for ch2 in canopy_layer.get_children():
		ch2.queue_free()
	_build_props()
	for id in IDS:
		cfgs[id]["pos"] = level.spawns[id]["p"]
		cfgs[id]["face"] = level.spawns[id]["face"]
	sizes = [level.default_sizes[0], level.default_sizes[1]]
	_apply_sizes()
	if use_dept:
		_sync_dept_cfgs()
	if not cfgs[sel]["enabled"]:
		sel = "A1"
	ui.set_map_title(level)
	_fit_camera()
	_enter_setup()


func set_habit(hid: String, on: bool) -> void:
	var key := "good" if hid.substr(0, 2) != "BH" else "bad"
	cfgs[sel][key][hid] = on
	_refresh()


func bulk(kind: String, on: bool) -> void:
	var c: Dictionary = cfgs[sel]
	match kind:
		"good":
			for g in Habits.good_ids():
				c["good"][g] = on
		"stress":
			for b in Habits.stress_bad_ids():
				c["bad"][b] = on
		"bad":
			for b in Habits.bad_ids():
				c["bad"][b] = on
	_refresh()


## Copy the selected operator's echelon, habits and plates to every teammate.
func copy_to_team() -> void:
	var c: Dictionary = cfgs[sel]
	for id in IDS:
		var m: Dictionary = cfgs[id]
		if id == sel or m["team"] != c["team"]:
			continue
		m["echelon"] = c["echelon"]
		m["good"] = c["good"].duplicate()
		m["bad"] = c["bad"].duplicate()
		m["plates"] = c["plates"]
		m["exp"] = c["exp"]
		m["traits"] = c["traits"].duplicate()
	_refresh()


func _refresh() -> void:
	ui.refresh_setup(sel, cfgs, postures, sizes)
	setup_marks.queue_redraw()


# ------------------------------------------------------------------ the department (v0.5)
## Load the saved department, or found one.
func _load_department() -> void:
	dept = Department.load_from()
	if dept == null:
		dept = Department.new()
		dept.found(int(_args.get("dept-seed", "1001")))
		dept.save()
	_default_selection()


func _default_selection() -> void:
	var av: Array = dept.available()
	av.sort_custom(func(a, b):
		var ra: int = Department.RANKS.find(a["rank"])
		var rb: int = Department.RANKS.find(b["rank"])
		if ra != rb:
			return ra > rb
		return int(a["xp"]) > int(b["xp"]))
	dept_sel = []
	for r in av.slice(0, 6):
		dept_sel.append(r["id"])


## Team A is the department's officers (police rules on), or the setup's operators.
func set_use_dept(on: bool) -> void:
	if on == use_dept:
		return
	use_dept = on
	if on:
		_a_backup = {}
		for id in IDS:
			_a_backup[id] = cfgs[id].duplicate(true)
		_a_backup["_sizes"] = sizes.duplicate()
		_a_backup["_alerts"] = alerts.duplicate()
		_a_backup["_postures"] = postures.duplicate()
		_sync_dept_cfgs()
		# team B becomes a gang house: four suspects, relaxed, holding (change it freely)
		if not _args.has("nb"):
			var mix := ["militia", "untrained", "untrained", "militia"]
			for k in 4:
				_apply_preset(cfgs["B%d" % (k + 1)], mix[k])
			sizes[1] = 4
			postures[1] = "hold"
			set_alert(1, 0)
			_apply_sizes()
			_sync_dept_cfgs()
	else:
		for id in IDS:
			if _a_backup.has(id):
				cfgs[id] = _a_backup[id]
		sizes = _a_backup.get("_sizes", sizes)
		alerts = _a_backup.get("_alerts", alerts)
		postures = _a_backup.get("_postures", postures)
		_apply_sizes()
	if not cfgs[sel]["enabled"]:
		sel = "A1"
	_rebuild_previews()
	_refresh()


## Write the picked officers into team A's slots (keeping where they were placed).
func _sync_dept_cfgs() -> void:
	dept_sel = dept_sel.filter(func(oid): return dept.get_officer(oid).get("status", "") == "active")
	var picked: Array = []
	for oid in dept_sel:
		picked.append(dept.get_officer(oid))
	for k in 20:
		var id := "A%d" % (k + 1)
		if k < picked.size():
			var c: Dictionary = dept.to_cfg(picked[k], k, level, alerts[0])
			c["pos"] = cfgs[id]["pos"]
			c["face"] = cfgs[id]["face"]
			cfgs[id] = c
		else:
			cfgs[id]["enabled"] = false
	sizes[0] = maxi(1, picked.size())
	for k2 in 20:
		var id2 := "A%d" % (k2 + 1)
		cfgs[id2]["enabled"] = k2 < picked.size()


func toggle_officer(oid: String, on: bool) -> void:
	if on and not dept_sel.has(oid) and dept_sel.size() < 20:
		dept_sel.append(oid)
	elif not on:
		dept_sel.erase(oid)
	if use_dept:
		_sync_dept_cfgs()
		if not cfgs[sel]["enabled"]:
			sel = "A1" if cfgs["A1"]["enabled"] else "B1"
		_rebuild_previews()
		_refresh()
	ui.refresh_dept(dept, dept_sel)


func hire_recruit() -> void:
	var r: Dictionary = dept.hire()
	dept.note("Hired %s %s." % [r["rank"], r["name"]])
	dept.save()
	ui.refresh_dept(dept, dept_sel)


func next_week() -> void:
	for ln in dept.next_week():
		dept.note(ln)
	dept.save()
	ui.refresh_dept(dept, dept_sel)


func new_department(seed_val: int) -> void:
	dept = Department.new()
	dept.found(seed_val)
	dept.save()
	_default_selection()
	if use_dept:
		_sync_dept_cfgs()
		_rebuild_previews()
		_refresh()
	ui.refresh_dept(dept, dept_sel)


func set_bodycams(on: bool) -> void:
	dept.bodycams = on
	dept.save()
	if use_dept:
		_sync_dept_cfgs()


func set_civilians(n: int) -> void:
	n_civ = clampi(n, 0, 40)
	_rebuild_previews()


func set_police_rules(on: bool) -> void:
	police_rules = on


func set_night(on: bool) -> void:
	night = on


# ------------------------------------------------------------------ views
func _build_props() -> void:
	for pr in level.props:
		var s := Sprite2D.new()
		s.texture = Decals.tex(pr["key"])
		var r: Rect2 = pr["r"]
		s.position = r.get_center() * PX
		var rot: float = pr["rot"]
		s.rotation = deg_to_rad(rot)
		var ts: Vector2 = s.texture.get_size()
		var want := r.size * PX
		if int(rot) % 180 != 0:
			want = Vector2(want.y, want.x)
		s.scale = Vector2(want.x / ts.x, want.y / ts.y)
		if pr.get("under", false):
			canopy_layer.add_child(s)
		else:
			props_layer.add_child(s)


func _clear_views() -> void:
	for v in views.values():
		v.queue_free()
	views.clear()


func _rebuild_previews() -> void:
	_clear_views()
	preview_ops.clear()
	for id in cfgs:
		var c: Dictionary = cfgs[id]
		if not c["enabled"]:
			continue
		var o = Op.new()
		o.configure(c)
		o.reset()
		preview_ops[id] = o
		var v = ActorView.new()
		actors_layer.add_child(v)
		v.setup(o, null)
		views[id] = v
	if n_civ > 0 and ui != null:
		for c2 in Operation.civilians(level, nav, n_civ, int(ui.seed_spin.value)):
			var oc = Op.new()
			oc.configure(c2)
			oc.reset()
			var vc = ActorView.new()
			actors_layer.add_child(vc)
			vc.setup(oc, null)
			views[c2["id"]] = vc


func _enter_setup() -> void:
	mode = "setup"
	if world != null:
		world.dispose()
		world = null
	decals.setup_empty()
	overlay.setup(null)
	ledger.setup(null)
	overlay.queue_redraw()
	_rebuild_previews()
	ui.show_setup()
	_refresh()
	if _args.has("dept-panel"):
		ui.show_dept()


func start_run(seed_val: int) -> void:
	if world != null:
		world.dispose()
	var all: Array = Operation.build(cfg_list(), level, nav, {"civilians": n_civ, "seed": seed_val})
	world = World.new()
	world.setup(level, nav, all, postures, seed_val, alerts, {"police_rules": police_rules or use_dept, "night": night})
	_applied = false
	dept_lines = []
	decals.setup(world)
	overlay.setup(world)
	ledger.setup(world, 8)
	_clear_views()
	for o in world.ops:
		var v = ActorView.new()
		actors_layer.add_child(v)
		v.setup(o, world)
		views[o.id] = v
	mode = "run"
	acc = 0.0
	paused = false
	_banner_done = false
	ui.show_run(speed)
	setup_marks.queue_redraw()


func back_to_setup() -> void:
	_enter_setup()


func rerun(new_seed: bool) -> void:
	var s: int = world.seed_used if world != null else 1001
	if new_seed:
		s = randi_range(1, 999999)
	start_run(s)


func set_speed(sp: float) -> void:
	speed = sp


func set_paused(on: bool) -> void:
	paused = on


func set_overlay(nm: String, on: bool) -> void:
	match nm:
		"Cones":
			overlay.show_cones = on
		"Recognition":
			overlay.show_rec = on
		"Aim":
			overlay.show_aim = on
		"Paths":
			overlay.show_paths = on


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	if mode == "run" and world != null:
		var steps := 0
		if not paused and not world.over:
			acc += delta * speed
			var t0 := Time.get_ticks_usec()
			while acc >= DT and not world.over:
				world.step()
				acc -= DT
				steps += 1
				if Time.get_ticks_usec() - t0 > 33000:
					break
			acc = minf(acc, DT * 3.0)
		_meas_real += delta
		_meas_sim += steps * DT
		if _meas_real >= 0.5:
			actual_speed = _meas_sim / _meas_real
			_meas_real = 0.0
			_meas_sim = 0.0
		for ev in world.events:
			decals.handle(ev)
			overlay.handle(ev)
			if ev["type"] == "blood" and views.has(ev["id"]):
				views[ev["id"]].stain(ev["zone"], ev["side"])
		world.events.clear()
		for v in views.values():
			v.sync()
		overlay.tick_real(delta)
		ledger.tick(delta)
		_ui_t -= delta
		if _ui_t <= 0.0:
			_ui_t = 0.1
			ui.refresh_run(world, actual_speed, speed)
		if world.over and not _banner_done:
			_banner_done = true
			ui.refresh_run(world, actual_speed, speed)
			var names := ["TEAM A WINS", "TEAM B WINS", "DRAW"]
			if world.police_rules():
				names = ["SUSPECTS STOPPED", "POLICE DEFEATED", "DRAW"]
			ui.show_banner("%s   ·   %02d:%04.1f" % [names[world.winner], int(world.t / 60.0), fmod(world.t, 60.0)])
			if use_dept and not _applied and dept != null:
				_applied = true
				dept_lines = dept.apply_result(world, level.map_name)
				dept.save()
			ui.show_debrief(world, dept_lines, use_dept)
	_test_hooks()


func _test_hooks() -> void:
	if _args.has("setup-shot") and Engine.get_process_frames() == 8:
		_shot(_args["setup-shot"])
		if not _args.has("autorun"):
			get_tree().quit()
	if _args.has("shot") and world != null:
		var at := float(_args.get("shot-at", "9999"))
		if world.t >= at or world.over:
			if not _args.has("_shot_wait"):
				_args["_shot_wait"] = Engine.get_process_frames()
			elif Engine.get_process_frames() - int(_args["_shot_wait"]) > 3:
				_shot(_args["shot"])
				get_tree().quit()


func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


# ------------------------------------------------------------------ camera and input
func _fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	var avail := Vector2(vs.x - UI.PANEL_W, vs.y)
	var map_px := Vector2(level.W * PX + 140, level.H * PX + 250)
	var z := minf(avail.x / map_px.x, avail.y / map_px.y)
	cam.zoom = Vector2(z, z)
	var centre := Vector2(level.W * PX / 2.0, (level.H * PX + 90.0) / 2.0)
	cam.position = centre + Vector2(UI.PANEL_W / 2.0 / z, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
				var before := get_global_mouse_position()
				cam.zoom = (cam.zoom * f).clamp(Vector2(0.3, 0.3), Vector2(4, 4))
				cam.position += (before - cam.position) * (1.0 - 1.0 / f)
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_RIGHT and mode == "run"):
			_panning = mb.pressed
			return
		if mode == "setup" and mb.pressed:
			var p := get_global_mouse_position() / PX
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if p.x > 0.3 and p.y > 0.3 and p.x < level.W - 0.3 and p.y < level.H - 0.3 and nav.is_free(p):
					cfgs[sel]["pos"] = p
					_rebuild_previews()
					_refresh()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				var c: Dictionary = cfgs[sel]
				c["face"] = (p - c["pos"]).angle()
				_rebuild_previews()
				_refresh()
	elif event is InputEventMouseMotion and _panning:
		cam.position -= (event as InputEventMouseMotion).relative / cam.zoom.x
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if mode == "run":
			if k == KEY_SPACE:
				paused = not paused
				ui.pause_btn.set_pressed_no_signal(paused)
			elif k >= KEY_1 and k <= KEY_7:
				var i := k - KEY_1
				speed = UI.SPEEDS[i]
				ui.speed_buttons[i].set_pressed_no_signal(true)
			elif k == KEY_ESCAPE:
				back_to_setup()
		if k == KEY_HOME:
			_fit_camera()
