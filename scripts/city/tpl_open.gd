extends "res://scripts/sim/level.gd"
## City filler lots of any size, street to the south: a pocket park (paths, trees,
## benches, hedges) or a surface car park (stalls and parked cars). No rooms.

var kind := "park"
var variant := 0


func _init(k := "park", w := 20.0, h := 30.0, v := 0) -> void:
	kind = k
	variant = v
	W = w
	H = h
	id = "tpl_%s_%d_%d_%d" % [k, int(w * 10), int(h * 10), v]
	map_name = "Pocket Park" if k == "park" else "Car Park"
	title = map_name.to_upper()
	fenced = false
	skip_posts = true


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	if kind == "park":
		_park(rng)
	else:
		_parking(rng)


func _park(rng: RandomNumberGenerator) -> void:
	# a walk in from the street, a loop, trees and benches along it
	var cx := W / 2.0
	_decor("dash_rect", {"r": Rect2(cx - 1.0, H * 0.45, 2.0, H * 0.55)})
	_decor("dash_rect", {"r": Rect2(2.5, H * 0.25, W - 5.0, H * 0.25)})
	var n_trees := int(W * H / 140.0)
	var placed: Array = []
	for k in n_trees * 3:
		if placed.size() >= n_trees:
			break
		var p := Vector2(rng.randf_range(2.5, W - 2.5), rng.randf_range(2.5, H - 4.5))
		if absf(p.x - cx) < 2.6 and p.y > H * 0.4:
			continue
		var ok := true
		for q in placed:
			if (q as Vector2).distance_to(p) < 5.0:
				ok = false
		if ok:
			placed.append(p)
			_trunk(p, rng.randf_range(3.2, 4.6))
	for k2 in 2 + int(W / 12.0):
		var bx := rng.randf_range(3.0, W - 5.0)
		if absf(bx + 0.8 - cx) < 2.4:
			continue
		_p("yard/bench", bx, H * 0.25 - 0.9, 1.6, 0.5, Geom.LOW, 0.45)
	if W >= 16.0:
		_p("yard/hedge", 1.2, H * 0.6, 0.8, 3.6, Geom.CONCEAL, 1.6, 0.0, "hedge")
		_p("yard/hedge", W - 2.0, H * 0.6, 0.8, 3.6, Geom.CONCEAL, 1.6, 0.0, "hedge")
	if variant % 2 == 0 and W >= 14.0:
		_p("yard/low_wall", cx - 4.0, H * 0.25 + 3.2, 3.0, 0.4, Geom.COVER, 0.9, 0.0, "low wall")
	_p("yard/bins", cx + 1.6, H - 2.2, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")


func _parking(rng: RandomNumberGenerator) -> void:
	# two rows of nose-in stalls either side of a drive aisle from the street
	var rows := [Vector2(1.0, 1.0), Vector2(1.0, H - 7.0)] if H >= 20.0 else [Vector2(1.0, 1.0)]
	for rw in rows:
		var y: float = rw.y
		_decor("parking", {"r": Rect2(1.0, y, W - 2.0, 5.4), "stall": 2.7, "axis": "v"})
		var x := 1.4
		while x + 1.9 <= W - 1.0:
			if rng.randf() < 0.6 and absf(x + 0.95 - W / 2.0) > 3.0:
				var key := "yard/car" if rng.randf() < 0.8 else "yard/van"
				var L := 4.4 if key == "yard/car" else 5.0
				_p(key, x, y + 0.4, 1.9 if key == "yard/car" else 2.0, L, Geom.COVER, 1.45 if key == "yard/car" else 1.9, 90.0, "parked car")
			x += 2.7
	_p("yard/bins", W - 2.0, H * 0.5, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	if W >= 18.0:
		_p("yard/dumpster", 1.2, H * 0.5 - 0.5, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
