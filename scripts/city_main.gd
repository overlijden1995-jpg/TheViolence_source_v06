extends Node2D
## The endless battle: Port Carrick, its four gangs, six police precincts and three
## hospitals, fighting on for as long as you watch. Builds the city behind a loading
## screen, then runs the simulation and the director at up to 20x.
##
## Test hooks (after --): --seed=N --speed=X --zoom=Z --focus=x,y (metres) --follow
##   --shot=path.png --shot-at=SIMSECONDS --select=ID

const CityLevel = preload("res://scripts/city/city_level.gd")
const CityNav = preload("res://scripts/city/city_nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Director = preload("res://scripts/city/director.gd")
const CityGround = preload("res://scripts/view/city_ground.gd")
const LotView = preload("res://scripts/view/lot_view.gd")
const TerritoryView = preload("res://scripts/view/territory_view.gd")
const CityLabels = preload("res://scripts/view/city_labels.gd")
const CityThings = preload("res://scripts/view/city_things.gd")
const CrowdView = preload("res://scripts/view/crowd_view.gd")
const Decals = preload("res://scripts/view/decals.gd")
const Overlay = preload("res://scripts/view/overlay.gd")
const Ledger = preload("res://scripts/view/ledger.gd")
const CityUI = preload("res://scripts/ui/city_ui.gd")
const UI = preload("res://scripts/ui/ui.gd")
const PX := 40.0
const DT := 1.0 / 30.0

static var opts := {}

var seed_val := 1001
var lv
var nav
var world
var director
var ready_to_run := false
var speed := 1.0
var paused := false
var follow := false
var selected := ""
var acc := 0.0
var actual := 0.0
var _meas_real := 0.0
var _meas_sim := 0.0
var _ui_t := 0.0
var _dyn_t := 0.0
var _follow_t := 0.0
var _panning := false
var _last_view := Rect2()
var _args := {}

var cam: Camera2D
var ground
var lots_layer: Node2D
var overview: Node2D
var terr_static
var terr_dynamic
var decals
var crowd
var things
var canopy
var labels
var overlay
var ui
var ledger_layer: CanvasLayer
var ledger
var loading_layer: CanvasLayer
var loading_label: Label
var loading_bar: ProgressBar


class Overview extends Node2D:
	## Far out: every building as a solid footprint, nothing else.
	var lv

	func _draw() -> void:
		if lv == null:
			return
		for b in lv.bldgs:
			for rn in b["rooms"]:
				for rv in lv.rooms[rn]["rects"]:
					var r: Rect2 = rv
					draw_rect(Rect2(r.position * 40.0, r.size * 40.0), Color("#fbfbfa"))
			var box: Rect2 = b["rect"]
			draw_rect(Rect2(box.position * 40.0, box.size * 40.0), Color("#1c1c1c"), false, -1.0)


func _ready() -> void:
	get_window().title = "The Violence - Endless Battle"
	RenderingServer.set_default_clear_color(Color("#d6d6d3"))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	seed_val = int(_args.get("seed", str(opts.get("seed", 1001))))
	speed = float(_args.get("speed", str(opts.get("speed", 1.0))))
	follow = _args.has("follow")
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_loading_screen()
	_build()


func _loading_screen() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 10
	add_child(loading_layer)
	var bg := ColorRect.new()
	bg.color = Color("#f3f3f1")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 0)
	box.position = Vector2(-260, -60)
	box.theme = UI.make_theme()
	loading_layer.add_child(box)
	var t := Label.new()
	t.text = "T H E   V I O L E N C E   ·   P O R T   C A R R I C K"
	t.add_theme_font_size_override("font_size", 20)
	box.add_child(t)
	loading_label = Label.new()
	loading_label.text = "..."
	box.add_child(loading_label)
	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size = Vector2(520, 14)
	loading_bar.show_percentage = false
	box.add_child(loading_bar)


func _stage(text: String, f: float) -> void:
	loading_label.text = text
	loading_bar.value = f * 100.0
	await get_tree().process_frame
	await get_tree().process_frame


func _build() -> void:
	lv = CityLevel.new(seed_val)
	var steps: Array = lv.build_steps()
	var n := steps.size() + 4
	for i in steps.size():
		await _stage(steps[i][0], float(i) / n)
		steps[i][1].call()
	await _stage("Laying out the sidewalks", float(steps.size()) / n)
	nav = CityNav.new()
	nav.build(lv)
	await _stage("Raising four gangs, six precincts and three hospitals", float(steps.size() + 1) / n)
	world = World.new()
	world.setup_empty(lv, nav, seed_val, Director.faction_list())
	world.log_kinds = {"city": true}
	director = Director.new(world, lv, nav, seed_val, {"gang_cap": int(opts.get("gang_cap", 60)), "police_cap": int(opts.get("police_cap", 108))})
	world.director = director
	director.setup()
	await _stage("Drawing the city", float(steps.size() + 2) / n)
	_build_views()
	if _args.has("warp"):
		# test hook: run the battle unseen up to a time, then show it
		var until := float(_args["warp"])
		while world.t < until:
			for k in 300:
				world.step()
			world.events.clear()
			await _stage("Warping: %s" % world.clock(world.t), clampf(world.t / until, 0.0, 1.0))
	await _stage("Ready", 1.0)
	loading_layer.queue_free()
	ready_to_run = true
	fit_camera()
	if _args.has("zoom"):
		var z := float(_args["zoom"])
		cam.zoom = Vector2(z, z)
		var f: PackedStringArray = _args.get("focus", "%f,%f" % [lv.W / 2.0, lv.H / 2.0]).split(",")
		cam.position = Vector2(float(f[0]), float(f[1])) * PX + Vector2(CityUI.PANEL_W / 2.0 / z, 0)
	if _args.has("select"):
		selected = _args["select"]
	ui.set_speed(speed)
	ui.follow_btn.set_pressed_no_signal(follow)


func _build_views() -> void:
	ground = CityGround.new()
	add_child(ground)
	ground.setup(lv)
	overview = Overview.new()
	overview.lv = lv
	add_child(overview)
	lots_layer = Node2D.new()
	add_child(lots_layer)
	for lot in lv.lots:
		var lvw = LotView.new()
		lots_layer.add_child(lvw)
		lvw.setup(lv, lot)
	terr_static = TerritoryView.new()
	add_child(terr_static)
	terr_static.setup(lv, director, "static")
	decals = Decals.new()
	add_child(decals)
	decals.setup(world)
	crowd = CrowdView.new()
	add_child(crowd)
	crowd.setup(world)
	things = CityThings.new()
	add_child(things)
	things.setup(director.roads, world, lv, "vehicles")
	canopy = CityThings.new()
	canopy.modulate.a = 0.8
	add_child(canopy)
	canopy.setup(director.roads, world, lv, "canopy")
	canopy.queue_redraw()
	terr_dynamic = TerritoryView.new()
	add_child(terr_dynamic)
	terr_dynamic.setup(lv, director, "dynamic")
	labels = CityLabels.new()
	add_child(labels)
	labels.setup(lv, director)
	overlay = Overlay.new()
	add_child(overlay)
	overlay.setup(world)
	overlay.show_rec = true
	ui = CityUI.new()
	add_child(ui)
	ui.build(self)
	ledger_layer = CanvasLayer.new()
	ledger_layer.layer = 2
	add_child(ledger_layer)
	ledger = Ledger.new()
	ledger.position = Vector2(10, 10)
	ledger_layer.add_child(ledger)
	ledger.setup(world, 9)
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	_last_view = Rect2()


# ------------------------------------------------------------------ controls from the panel
func set_layer(nm: String, on: bool) -> void:
	match nm:
		"territory":
			terr_static.show_tint = on
			terr_static.queue_redraw()
		"labels":
			labels.visible = on
		"cones":
			overlay.show_cones = on
		"ledger":
			ledger.visible = on


func back_to_setup() -> void:
	if world != null:
		world.dispose()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func fit_camera() -> void:
	var vs := get_viewport().get_visible_rect().size
	var avail := Vector2(vs.x - CityUI.PANEL_W, vs.y)
	var z := minf(avail.x / (lv.W * PX + 200.0), avail.y / (lv.H * PX + 200.0))
	cam.zoom = Vector2(z, z)
	cam.position = Vector2(lv.W, lv.H) * PX / 2.0 + Vector2(CityUI.PANEL_W / 2.0 / z, 0)


func focus_selected() -> void:
	var o = world.op_by_id(selected) if selected != "" else null
	if o == null:
		return
	if cam.zoom.x < 0.6:
		cam.zoom = Vector2(0.9, 0.9)
	cam.position = o.pos * PX + Vector2(CityUI.PANEL_W / 2.0 / cam.zoom.x, 0)


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	if not ready_to_run:
		return
	var steps := 0
	if not paused:
		acc += delta * speed
		var t0 := Time.get_ticks_usec()
		while acc >= DT:
			world.step()
			acc -= DT
			steps += 1
			if Time.get_ticks_usec() - t0 > 30000:
				break
		acc = minf(acc, DT * 3.0)
	_meas_real += delta
	_meas_sim += steps * DT
	if _meas_real >= 0.5:
		actual = _meas_sim / _meas_real
		_meas_real = 0.0
		_meas_sim = 0.0
	var captured := false
	for ev in world.events:
		match ev["type"]:
			"blood", "drip", "impact", "casing", "plate", "down":
				decals.handle(ev)
			"capture":
				captured = true
		crowd.handle(ev)
		overlay.handle(ev)
	world.events.clear()
	if captured:
		terr_static.queue_redraw()
	_camera_follow(delta)
	_update_view()
	crowd.queue_redraw()
	things.t += delta
	things.queue_redraw()
	overlay.tick_real(delta)
	ledger.tick(delta)
	_dyn_t -= delta
	if _dyn_t <= 0.0:
		_dyn_t = 0.1
		terr_dynamic.queue_redraw()
	_ui_t -= delta
	if _ui_t <= 0.0:
		_ui_t = 0.25
		ui.refresh(world, director, actual)
	_test_hooks()


func _update_view() -> void:
	var vs := get_viewport().get_visible_rect().size
	var z := cam.zoom.x
	var view := Rect2(cam.position - vs / 2.0 / z, vs / z)
	crowd.view = view
	crowd.zoom = z
	crowd.selected = selected
	things.view = view
	overlay.view = view
	overlay.zoom = z
	var far := z < 0.1
	var want_fill := z < 0.3
	if terr_static.fill != want_fill:
		terr_static.fill = want_fill
		terr_static.queue_redraw()
	lots_layer.visible = not far
	overview.visible = far
	canopy.visible = z >= 0.06
	if view != _last_view:
		_last_view = view
		labels.update_view(view, z)


## Test hook --watch=qrf|amb|pamb|convoy: keep the camera on the first such vehicle at work
## (or its crew on foot).
func _watch_target():
	var kind: String = _args["watch"]
	for v in director.roads.vehicles:
		var k: String = v["kind"]
		var busy := false
		match kind:
			"qrf":
				busy = k == "van" and v.get("lights", false)
			"amb":
				busy = k == "amb" and v.get("job", "idle") != "idle"
			"pamb":
				busy = k == "pamb" and v.get("job", "idle") != "idle"
			"convoy":
				busy = k == "car" and v.get("lights", false)
		if busy:
			if v["seats"].is_empty() and kind == "qrf":
				var st: Dictionary = director.stations[v["station"]]
				for m in world.teams[st["qrf"]]["members"]:
					if m.alive() and m.mounted == null:
						return m.pos
			if (kind == "amb" or kind == "pamb") and v.has("carrying"):
				var pat = world.op_by_id(v["carrying"])
				if pat != null:
					return pat.pos
			return v["pos"]
	return null


func _camera_follow(delta: float) -> void:
	if _args.has("watch"):
		var wp = _watch_target()
		if wp != null:
			var fzw := float(_args.get("follow-zoom", "0.6"))
			cam.zoom = Vector2(fzw, fzw)
			cam.position = (wp as Vector2) * PX + Vector2(CityUI.PANEL_W / 2.0 / fzw, 0)
		return
	if not follow:
		return
	_follow_t -= delta
	var h = director.hottest()
	if h == null:
		return
	var fz := float(_args.get("follow-zoom", "0.5"))
	if cam.zoom.x < fz * 0.7 or _args.has("follow-zoom"):
		cam.zoom = cam.zoom.lerp(Vector2(fz, fz), minf(1.0, delta * 2.0))
	var want: Vector2 = (h["p"] as Vector2) * PX + Vector2(CityUI.PANEL_W / 2.0 / cam.zoom.x, 0)
	cam.position = cam.position.lerp(want, minf(1.0, delta * 1.5))


func _test_hooks() -> void:
	if _args.has("shot"):
		var at := float(_args.get("shot-at", "5"))
		if world.t >= at:
			if not _args.has("_shot_wait"):
				_args["_shot_wait"] = Engine.get_process_frames()
			elif Engine.get_process_frames() - int(_args["_shot_wait"]) > 3:
				var img := get_viewport().get_texture().get_image()
				img.save_png(_args["shot"])
				print("city: %s  %d ops  shot saved" % [world.clock(world.t), world.ops.size()])
				get_tree().quit()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_run:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				var before := get_global_mouse_position()
				cam.zoom = (cam.zoom * f).clamp(Vector2(0.015, 0.015), Vector2(3, 3))
				cam.position += (before - cam.position) * (1.0 - 1.0 / f)
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pick(get_global_mouse_position() / PX)
	elif event is InputEventMouseMotion and _panning:
		cam.position -= (event as InputEventMouseMotion).relative / cam.zoom.x
		if follow:
			follow = false
			ui.follow_btn.set_pressed_no_signal(false)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE:
			paused = not paused
			ui.pause_btn.set_pressed_no_signal(paused)
		elif k >= KEY_1 and k <= KEY_7:
			speed = CityUI.SPEEDS[k - KEY_1]
			ui.set_speed(speed)
		elif k == KEY_HOME:
			fit_camera()
		elif k == KEY_F:
			follow = not follow
			ui.follow_btn.set_pressed_no_signal(follow)
		elif k == KEY_ESCAPE:
			back_to_setup()


func _pick(p: Vector2) -> void:
	var best = null
	var bd := maxf(1.2, 14.0 / PX / cam.zoom.x)
	for o in world.ops:
		if o.mounted != null:
			continue
		var d: float = o.pos.distance_to(p)
		if d < bd:
			bd = d
			best = o
	selected = best.id if best != null else ""
