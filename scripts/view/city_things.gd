extends Node2D
## Moving things above the plan that are not people: vehicles (with flashing lights on a
## call), stretchers under carried casualties, and tree canopies over everything.
## One node draws them all; only what is in view.

const Decals = preload("res://scripts/view/decals.gd")
const PX := 40.0
const VEH := {"car": ["veh/police_car", Vector2(4.6, 1.9)], "van": ["veh/police_van", Vector2(5.6, 2.1)],
	"amb": ["veh/ambulance", Vector2(6.0, 2.2)], "pamb": ["veh/police_ambulance", Vector2(5.6, 2.1)]}

var roads
var world
var view := Rect2()
var t := 0.0
var mode := "vehicles"   # "vehicles" or "canopy"
var lv


func setup(r, w, level, m: String) -> void:
	roads = r
	world = w
	lv = level
	mode = m


func _draw() -> void:
	if mode == "canopy":
		_draw_canopy()
		return
	if roads == null:
		return
	var vr := view.grow(400.0)
	var blink := int(t * 4.0) % 2 == 0
	for v in roads.vehicles:
		var p: Vector2 = v["pos"] * PX
		if not vr.has_point(p):
			continue
		var spec: Array = VEH[v["kind"]]
		var sz: Vector2 = spec[1] * PX
		draw_set_transform(p, v["dir"])
		draw_texture_rect(Decals.tex(spec[0]), Rect2(-sz / 2.0, sz), false)
		if v.get("lights", false):
			# lights on a call: alternating strobes and a pulsing ring (greyscale, like the plan)
			var a := Color.WHITE if blink else Color("#1c1c1c")
			var b := Color("#1c1c1c") if blink else Color.WHITE
			draw_circle(Vector2(0, -sz.y * 0.28), 10.0, a)
			draw_circle(Vector2(0, sz.y * 0.28), 10.0, b)
			draw_arc(Vector2(0, -sz.y * 0.28), 10.0, 0.0, TAU, 12, Color("#1c1c1c"), 2.0)
			draw_arc(Vector2(0, sz.y * 0.28), 10.0, 0.0, TAU, 12, Color("#1c1c1c"), 2.0)
			var ring := fmod(t * 1.6, 1.0)
			draw_arc(Vector2.ZERO, sz.x * (0.6 + 0.5 * ring), 0.0, TAU, 28, Color(0.1, 0.1, 0.1, 0.5 * (1.0 - ring)), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0)
	# stretchers under casualties being carried
	if world != null:
		for o in world.ops:
			if not o.carried or o.mounted != null:
				continue
			var q: Vector2 = o.pos * PX
			if not vr.has_point(q):
				continue
			draw_set_transform(q, o.body_dir)
			draw_texture_rect(Decals.tex("fx/stretcher"), Rect2(Vector2(-40, -12), Vector2(80, 24)), false)
			draw_set_transform(Vector2.ZERO, 0.0)


func _draw_canopy() -> void:
	if lv == null:
		return
	var tex: Texture2D = Decals.tex("yard/tree")
	for lot in lv.lots:
		var tl = lot["tpl"]["lv"]
		for pr in tl.props:
			if not pr.get("under", false):
				continue
			var r: Rect2 = lv.xf_rect(lot, pr["r"])
			draw_texture_rect(tex, Rect2(r.position * PX, r.size * PX), false)
	for pr2 in lv.props:
		if pr2.get("lot", 0) == -1 and pr2.get("under", false):
			var r2: Rect2 = pr2["r"]
			draw_texture_rect(tex, Rect2(r2.position * PX, r2.size * PX), false)
