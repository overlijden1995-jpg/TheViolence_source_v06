extends Node2D
## Everyone on foot in the city, drawn by one node (hundreds of figures): plan symbols in
## their faction's look, weapons at low carry or up, the alert pip, stains where they were
## hit, the fallen lying in place. Only what is in view; dots when zoomed far out.

const Decals = preload("res://scripts/view/decals.gd")
const Palette = preload("res://scripts/view/palette.gd")
const Op = preload("res://scripts/sim/op.gd")
const PX := 40.0
const INK := Color("#1c1c1c")
const BLOOD := Color("#7d0a0a")

var world
var view := Rect2()
var zoom := 1.0
var selected := ""
var stains := {}       # op id -> [[local Vector2, rot, scale, key]]
var font: Font


func setup(w) -> void:
	world = w
	stains.clear()
	font = ThemeDB.fallback_font


func handle(ev: Dictionary) -> void:
	match ev["type"]:
		"blood":
			var lst: Array = stains.get(ev["id"], [])
			if lst.size() >= 6:
				return
			var h := hash(ev["id"] + str(lst.size()))
			var local := Vector2(-2, 0)
			match ev["zone"]:
				"head":
					local = Vector2(2, 0)
				"chest":
					local = Vector2(-2, float(h % 21) - 10.0)
				"abd":
					local = Vector2(-4, float(h % 13) - 6.0)
				"arm":
					local = Vector2(4, 18.0 * ev["side"])
				_:
					local = Vector2(-6, float(h % 29) - 14.0)
			lst.append([local, float(h % 628) / 100.0, 0.7 + float(h % 40) / 100.0, "fx/stain%d" % (1 + h % 3)])
			stains[ev["id"]] = lst
		"body_gone":
			stains.erase(ev["id"])


func _draw() -> void:
	if world == null:
		return
	var vr := view.grow(60.0)
	if zoom < 0.12:
		_draw_dots(vr)
		return
	for o in world.ops:
		if o.mounted != null:
			continue
		var p: Vector2 = o.pos * PX
		if not vr.has_point(p):
			continue
		var look: String = Palette.look(o, world)
		if not o.alive():
			_draw_down(o, p, look)
			continue
		var sc := 0.5
		if o.stance == Op.CROUCH:
			sc = 0.45
		elif o.stance == Op.DUCK:
			sc = 0.40
		# weapon under the arms
		if not o.medic:
			var rifle_lost: bool = o.weapons["rifle"]["lost"]
			var low: bool = o.alert == Op.GREEN and o.aim.is_empty() and not o.weapon_up
			var key := "op/pistol" if o.active == "pistol" else "op/rifle"
			var show: bool = not (o.active == "rifle" and rifle_lost) and not (low and o.active == "pistol")
			if show:
				var gt: Texture2D = Decals.tex(key)
				var gs: Vector2 = gt.get_size() * 0.5
				var rot: float = o.muzzle_dir
				var at: Vector2 = p + Vector2.from_angle(o.muzzle_dir) * 4.0
				var alpha := 1.0 if (o.weapon_up or not o.aim.is_empty()) else 0.65
				if low:
					rot = o.body_dir + 1.15
					at = p + Vector2.from_angle(o.body_dir - 1.2) * 9.0
					alpha = 0.55
				draw_set_transform(at, rot)
				draw_texture_rect(gt, Rect2(Vector2(0, -gs.y / 2.0), gs), false, Color(1, 1, 1, alpha))
		var bt: Texture2D = Decals.tex("op/%s_stand" % look)
		var bs: Vector2 = bt.get_size() * sc
		draw_set_transform(p, o.body_dir)
		draw_texture_rect(bt, Rect2(-bs / 2.0, bs), false)
		for st in stains.get(o.id, []):
			var stt: Texture2D = Decals.tex(st[3])
			var ss: Vector2 = stt.get_size() * 0.5 * st[2]
			draw_set_transform(p + (st[0] as Vector2).rotated(o.body_dir), o.body_dir + st[1])
			draw_texture_rect(stt, Rect2(-ss / 2.0, ss), false)
		draw_set_transform(Vector2.ZERO, 0.0)
		if not o.medic:
			draw_circle(p + Vector2(-14, 14), 4.6, Color(1, 1, 1, 0.95))
			draw_circle(p + Vector2(-14, 14), 3.4, Palette.ALERT[clampi(o.alert, 0, 2)])
		if o.carried:
			continue
		if zoom >= 0.5:
			draw_string(font, p + Vector2(-26, -22), o.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
			var t := ""
			if not o.action.is_empty():
				t = String(o.action["type"]).to_upper()
			elif o.ticker.has("retreat"):
				t = "RUNNING"
			if t != "":
				draw_string(font, p + Vector2(-26, 26), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#3a3a3a"))
		if o.id == selected:
			draw_arc(p, 24.0, 0.0, TAU, 28, INK, 2.0)
	_draw_selected_down(vr)


func _draw_down(o, p: Vector2, look: String) -> void:
	var h := hash(o.id)
	var rot: float = o.body_dir + (float(h % 120) / 100.0 - 0.6)
	var dt: Texture2D = Decals.tex("op/%s_down" % look)
	var ds: Vector2 = dt.get_size() * 0.5
	draw_set_transform(p, rot)
	draw_texture_rect(dt, Rect2(-ds / 2.0, ds), false)
	var n := maxi(2, o.wounds + 2)
	for k in n:
		var hk := hash(o.id + "s" + str(k))
		var st: Texture2D = Decals.tex("fx/stain%d" % (1 + hk % 3))
		var ss: Vector2 = st.get_size() * 0.5 * (0.9 + float(hk % 70) / 100.0)
		var local := Vector2(30.0 + float(hk % 33), float(hk % 23) - 11.0) - ds / 2.0 + Vector2(0, ds.y / 2.0)
		draw_set_transform(p + local.rotated(rot), rot + float(hk % 628) / 100.0)
		draw_texture_rect(st, Rect2(-ss / 2.0, ss), false)
	draw_set_transform(Vector2.ZERO, 0.0)
	if zoom >= 0.5 and not o.carried:
		draw_string(font, p + Vector2(-26, 26), "KIA" if o.state == "dead" else "DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BLOOD)


func _draw_selected_down(vr: Rect2) -> void:
	if selected == "":
		return
	var o = world.op_by_id(selected)
	if o == null or o.alive() or o.mounted != null:
		return
	var p: Vector2 = o.pos * PX
	if vr.has_point(p):
		draw_arc(p, 30.0, 0.0, TAU, 28, INK, 2.0)


## Far out: a dot per person, the faction's tone; the fallen in blood.
func _draw_dots(vr: Rect2) -> void:
	var r := clampf(2.2 / zoom, 6.0, 90.0)
	for o in world.ops:
		if o.mounted != null:
			continue
		var p: Vector2 = o.pos * PX
		if not vr.has_point(p):
			continue
		if not o.alive():
			draw_circle(p, r * 0.8, Color(BLOOD, 0.85))
			continue
		if o.medic:
			draw_circle(p, r, Color.WHITE)
			draw_arc(p, r, 0.0, TAU, 10, INK, -1.0)
			continue
		draw_circle(p, r, Palette.faction(o.faction))
		if o.alert == Op.RED:
			draw_arc(p, r * 1.7, 0.0, TAU, 12, Palette.ALERT[2], -1.0)
