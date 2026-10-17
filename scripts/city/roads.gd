extends RefCounted
## Vehicles on rails. Every street has two lanes, one each way, 1.75 m either side of the
## centre line; traffic keeps right. A route is a polyline along lane centres, turning
## at intersections; a vehicle runs along it at a fixed cruising speed, slowing for turns.

var level
var astar := AStar2D.new()   # intersections: id = iy * (NCOLS + 1) + ix
var vehicles: Array = []
var _vid := 0

const CRUISE := {"car": 12.0, "van": 10.5, "amb": 11.0, "pamb": 11.5}
const SLOW := 4.5


func build(lv) -> void:
	level = lv
	for iy in lv.NROWS + 1:
		for ix in lv.NCOLS + 1:
			astar.add_point(_nid(ix, iy), lv.node_pos(ix, iy))
	for iy2 in lv.NROWS + 1:
		for ix2 in lv.NCOLS + 1:
			if ix2 < lv.NCOLS:
				astar.connect_points(_nid(ix2, iy2), _nid(ix2 + 1, iy2))
			if iy2 < lv.NROWS:
				astar.connect_points(_nid(ix2, iy2), _nid(ix2, iy2 + 1))


func _nid(ix: int, iy: int) -> int:
	return iy * (level.NCOLS + 1) + ix


func _nxy(id: int) -> Vector2i:
	return Vector2i(id % (level.NCOLS + 1), id / (level.NCOLS + 1))


## The point on a street's centre line nearest p, and the intersections bracketing it.
## Returns {c: centre-line point, ends: [node ids]}.
func _on_road(p: Vector2) -> Dictionary:
	var lv = level
	var s: Vector2i = lv.street_at(p)
	if s.x >= 0 and s.y >= 0:
		var id := _nid(s.y, s.x)
		return {"c": lv.node_pos(s.y, s.x), "ends": [id]}
	if s.x >= 0:
		var yc: float = lv.node_pos(0, s.x).y
		var ix := clampi(int(p.x / (lv.BW + lv.ST)), 0, lv.NCOLS - 1)
		return {"c": Vector2(p.x, yc), "ends": [_nid(ix, s.x), _nid(ix + 1, s.x)]}
	if s.y >= 0:
		var xc: float = lv.node_pos(s.y, 0).x
		var iy := clampi(int(p.y / (lv.BH + lv.ST)), 0, lv.NROWS - 1)
		return {"c": Vector2(xc, p.y), "ends": [_nid(s.y, iy), _nid(s.y, iy + 1)]}
	# off the road: the nearest street edge of the block
	var bk: Vector2i = lv.block_of(p)
	var br: Rect2 = lv.blocks[bk]["rect"]
	var opts := [Vector2(p.x, br.position.y - lv.ST / 2.0), Vector2(p.x, br.end.y + lv.ST / 2.0)]
	var q: Vector2 = opts[0] if p.distance_to(opts[0]) < p.distance_to(opts[1]) else opts[1]
	return _on_road(q)


## Centre-line route from a to b through the intersections.
func _centre_route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ra := _on_road(a)
	var rb := _on_road(b)
	var out := PackedVector2Array()
	out.append(ra["c"])
	# same stretch of street: straight along it
	var same := false
	if ra["ends"].size() == 2 and rb["ends"].size() == 2:
		same = (ra["ends"][0] == rb["ends"][0] and ra["ends"][1] == rb["ends"][1])
	if not same:
		var best := PackedVector2Array()
		var best_c := INF
		for ia in ra["ends"]:
			for ib in rb["ends"]:
				var mid: PackedVector2Array = astar.get_point_path(ia, ib)
				if mid.is_empty():
					continue
				var c: float = (ra["c"] as Vector2).distance_to(mid[0]) + _len(mid) + mid[mid.size() - 1].distance_to(rb["c"])
				if c < best_c:
					best_c = c
					best = mid
		out.append_array(best)
	out.append(rb["c"])
	var clean := PackedVector2Array()
	for p in out:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.5:
			clean.append(p)
	# drop a first or last point that doubles back past the next one (no reversing out)
	return clean


static func _len(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i - 1].distance_to(pts[i])
	return s


static func _right(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


## Offset a centre-line route onto the right-hand lanes.
func lane_route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var c := _centre_route(a, b)
	var out := PackedVector2Array()
	var n := c.size()
	if n < 2:
		out.append(a)
		return out
	var lane: float = level.LANE
	for i in n:
		var din := Vector2.ZERO
		var dout := Vector2.ZERO
		if i > 0:
			din = (c[i] - c[i - 1]).normalized()
		if i < n - 1:
			dout = (c[i + 1] - c[i]).normalized()
		if din == Vector2.ZERO:
			out.append(c[i] + _right(dout) * lane)
		elif dout == Vector2.ZERO:
			out.append(c[i] + _right(din) * lane)
		elif din.dot(dout) > 0.9:
			out.append(c[i] + _right(din) * lane)
		elif din.dot(dout) < -0.9:
			# a U-turn: swing across through the centre
			out.append(c[i] + _right(din) * lane + din * 3.0)
			out.append(c[i] + _right(dout) * lane + din * 3.0)
		else:
			out.append(c[i] + _right(din) * lane + _right(dout) * lane)
	return out


## The kerbside lane point to stop at for a lot (in front of its gate).
func lot_stop(lot: Dictionary) -> Vector2:
	var gp: Vector2 = lot["gate_out"]
	var yc: float = level.node_pos(0, lot["street"]).y
	return Vector2(gp.x, yc + (level.LANE if lot["side"] == 0 else -level.LANE))


# ================================================================== vehicles
## kind: car (patrol car, 2 seats), van (QRF, 5 seats), pamb (police ambulance), amb (ambulance)
func add_vehicle(kind: String, pos: Vector2, dir: float, extra := {}) -> Dictionary:
	_vid += 1
	var v := {"id": _vid, "kind": kind, "pos": pos, "dir": dir, "route": PackedVector2Array(), "cum": PackedFloat32Array(),
		"s": 0.0, "lag": 0.0, "speed": 0.0, "moving": false, "arrived": true, "seats": [], "cap": {"car": 2, "van": 5, "pamb": 2, "amb": 2}[kind],
		"cargo": [], "home": pos, "home_dir": dir, "lights": false}
	for k in extra:
		v[k] = extra[k]
	vehicles.append(v)
	return v


## Send a vehicle to b along the lanes. lag: drive this far behind the route's start
## (the second car of a convoy shares the lead car's route).
func drive(v: Dictionary, b: Vector2, lag := 0.0) -> void:
	var r := lane_route(v["pos"], b)
	if r.size() > 0 and (r[0] as Vector2).distance_to(v["pos"]) > 0.3:
		r.insert(0, v["pos"])
	_set_route(v, r, lag)


func follow(v: Dictionary, lead: Dictionary, lag: float) -> void:
	var r: PackedVector2Array = lead["route"].duplicate()
	if r.size() > 0 and (r[0] as Vector2).distance_to(v["pos"]) > 0.3:
		r.insert(0, v["pos"])
	_set_route(v, r, 0.0)
	v["follow"] = lead["id"]


func _set_route(v: Dictionary, r: PackedVector2Array, lag: float) -> void:
	v["route"] = r
	var cum := PackedFloat32Array()
	var s := 0.0
	for i in r.size():
		if i > 0:
			s += r[i - 1].distance_to(r[i])
		cum.append(s)
	v["cum"] = cum
	v["s"] = -lag
	v["moving"] = r.size() >= 2
	v["arrived"] = r.size() < 2


func stop(v: Dictionary) -> void:
	v["moving"] = false
	v["speed"] = 0.0
	v["arrived"] = true


## Advance every moving vehicle by dt.
func step(dt: float) -> void:
	for v in vehicles:
		if not v["moving"]:
			continue
		var r: PackedVector2Array = v["route"]
		var cum: PackedFloat32Array = v["cum"]
		var total: float = cum[cum.size() - 1]
		var cruise: float = CRUISE.get(v["kind"], 10.0)
		var target := cruise
		# slow for the next bend and for the end of the route
		var s: float = v["s"]
		var k := 1
		while k < cum.size() - 1 and cum[k] < s:
			k += 1
		if k < cum.size() - 1:
			var d_in: Vector2 = (r[k] - r[k - 1]).normalized()
			var d_out: Vector2 = (r[k + 1] - r[k]).normalized()
			if d_in.dot(d_out) < 0.85 and cum[k] - s < 10.0:
				target = SLOW
		if total - s < 12.0:
			target = maxf(2.5, cruise * (total - s) / 12.0)
		var spd: float = v["speed"]
		spd = move_toward(spd, target, (6.0 if target > spd else 9.0) * dt)
		v["speed"] = spd
		s += spd * dt
		if s >= total:
			s = total
			v["moving"] = false
			v["arrived"] = true
			v["speed"] = 0.0
		v["s"] = s
		if s >= 0.0:
			var p := point_at(v, s)
			var ahead := point_at(v, minf(total, s + 1.0))
			if ahead.distance_to(p) > 0.05:
				v["dir"] = lerp_angle(v["dir"], (ahead - p).angle(), minf(1.0, 8.0 * dt))
			v["pos"] = p


func point_at(v: Dictionary, s: float) -> Vector2:
	var r: PackedVector2Array = v["route"]
	var cum: PackedFloat32Array = v["cum"]
	if r.size() == 0:
		return v["pos"]
	if s <= 0.0:
		return r[0]
	for i in range(1, cum.size()):
		if cum[i] >= s:
			var seg: float = cum[i] - cum[i - 1]
			var f: float = (s - cum[i - 1]) / seg if seg > 0.0 else 1.0
			return r[i - 1].lerp(r[i], f)
	return r[r.size() - 1]


## Kerbside points beside a stopped vehicle where its passengers step out.
func doors_of(v: Dictionary, n: int) -> Array:
	var out: Array = []
	var d := Vector2.from_angle(v["dir"])
	var side := _right(d)
	var p: Vector2 = v["pos"]
	for i in n:
		var along := (float(i) - (n - 1) / 2.0) * 1.1
		out.append(p + side * 2.4 + d * along)
	return out
