extends Node2D
## Persistent marks left on the plan: blood (the only colour), wall smears, pools
## under the fallen, drip trails, bullet chips and spent casings.

const Geom = preload("res://scripts/sim/geom.gd")
const PX := 40.0
const SVG_SCALE := 0.5          # SVGs are authored at 80 px/m; the world is 40 px/m
const MAX_MARKS := 2200

static var _tex := {}

var world
var rng := RandomNumberGenerator.new()
var pools: Array = []           # [{s: Sprite2D, t0, full}]


static func tex(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load("res://assets/svg/%s.svg" % key)
	return _tex[key]


func setup_empty() -> void:
	world = null
	for c in get_children():
		c.queue_free()
	pools.clear()


func setup(w) -> void:
	world = w
	rng.seed = w.seed_used + 77
	for c in get_children():
		c.queue_free()
	pools.clear()


func _sprite(key: String, p_m: Vector2, rot: float, scale_f: float, alpha := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(key)
	s.position = p_m * PX
	s.rotation = rot
	s.scale = Vector2.ONE * SVG_SCALE * scale_f
	s.modulate.a = alpha
	add_child(s)
	if get_child_count() > MAX_MARKS:
		get_child(0).queue_free()
	return s


func handle(ev: Dictionary) -> void:
	match ev["type"]:
		"blood":
			_blood(ev)
		"drip":
			_sprite("fx/drip%d" % rng.randi_range(1, 2), ev["p"], rng.randf() * TAU, rng.randf_range(0.8, 1.3), 0.9)
		"impact":
			if ev["kind"] == Geom.WALL or ev["kind"] == Geom.COVER or ev["kind"] == Geom.WINDOW:
				_sprite("fx/chip", ev["p"] + ev["n"] * 0.02, rng.randf() * TAU, rng.randf_range(0.6, 1.0), 0.85)
		"casing":
			var side := Vector2.from_angle(ev["dir"] + PI / 2.0)
			var p: Vector2 = ev["p"] + side * rng.randf_range(0.5, 1.2) + Vector2.from_angle(ev["dir"]) * rng.randf_range(-0.3, 0.3)
			_sprite("fx/casing", p, rng.randf() * TAU, 1.0, 0.9)
		"plate":
			_sprite("fx/scuff", ev["p"] - ev["dir"] * 0.18, 0.0, 0.8, 0.6)
		"down":
			var s := _sprite("fx/pool" if rng.randf() < 0.5 else "fx/pool2", ev["p"] + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15)), rng.randf() * TAU, 0.05, 0.92)
			pools.append({"s": s, "t0": world.t, "full": rng.randf_range(0.55, 0.8) * (1.2 if ev["killed"] else 1.0)})


func _blood(ev: Dictionary) -> void:
	var p: Vector2 = ev["p"]
	var u: Vector2 = ev["dir"]
	var power: float = ev["power"]
	# exit spray, starting at the body and running away from the shooter
	var key := "fx/spray%d" % rng.randi_range(1, 4)
	var s := Sprite2D.new()
	s.texture = tex(key)
	s.centered = false
	s.offset = Vector2(-18.0, -s.texture.get_height() / 2.0)
	s.position = (p + u * 0.08) * PX
	s.rotation = u.angle() + rng.randf_range(-0.15, 0.15)
	var reach := clampf(power, 0.4, 1.7)
	s.scale = Vector2(reach, rng.randf_range(0.7, 1.1) * (0.8 + 0.3 * power)) * SVG_SCALE
	s.modulate.a = 0.92
	add_child(s)
	# a splat at the feet
	_sprite("fx/splat%d" % rng.randi_range(1, 4), p + u * rng.randf_range(0.1, 0.35), rng.randf() * TAU, rng.randf_range(0.25, 0.45) * power, 0.9)
	# smear where the spray meets a wall
	var g: Geom = world.geom
	var tr: Dictionary = g.trace_shot(p, 1.2, p + u * 2.4 * reach, 1.0)
	if tr["hit"] and (tr["kind"] == Geom.WALL or tr["kind"] == Geom.COVER):
		var n: Vector2 = tr["n"]
		var along := n.orthogonal()
		_sprite("fx/smear%d" % rng.randi_range(1, 2), tr["p"] + n * 0.05, along.angle(), rng.randf_range(0.7, 1.3) * power, 0.9)


func _process(_dt: float) -> void:
	if world == null:
		return
	for pl in pools:
		var k := clampf((world.t - pl["t0"]) / 14.0, 0.0, 1.0)
		var s: Sprite2D = pl["s"]
		if is_instance_valid(s):
			s.scale = Vector2.ONE * SVG_SCALE * maxf(0.05, sqrt(k) * pl["full"])
