extends RefCounted
## Navigation for the city, with the same interface the brain uses on a single map.
## Inside a lot, paths come from the lot's template navigator (four cost profiles,
## cover spots, exposure), run in the template's own frame and turned back into the
## world. Between lots, people walk the sidewalks: a graph of sidewalk corners, lot gates
## and crosswalks at every intersection (parked cars line the kerbs, so the road is
## crossed at the corners). Someone caught in the roadway first steps to the centre line,
## which is always clear, and walks it to the nearest intersection.

var level
var geom
var astar := AStar2D.new()
var corner := {}            # Vector3i(ix, iy, q) -> id; q: 0 NW, 1 NE, 2 SW, 3 SE
var centre := {}            # Vector2i(ix, iy) -> id
var gate_node: Array = []   # lot -> id
var lines := {}             # Vector4i(axis, street, side, segment) -> [[along, id], ...] sorted
var _street_spots := {}     # Vector2i (2 m) -> [{p, gap}]
var _next_id := 0
var path_calls := 0
var path_us := 0
const TMP_A := 900000
const TMP_B := 900001
const TMP_C := 900002


func build(lv) -> void:
	level = lv
	geom = lv.geom
	var walk: float = lv.WALK_OFF
	# intersections: centre and four sidewalk corners
	for iy in lv.NROWS + 1:
		for ix in lv.NCOLS + 1:
			var c: Vector2 = lv.node_pos(ix, iy)
			centre[Vector2i(ix, iy)] = _add(c, 1.4)
			var qs := [Vector2(-walk, -walk), Vector2(walk, -walk), Vector2(-walk, walk), Vector2(walk, walk)]
			for q in 4:
				corner[Vector3i(ix, iy, q)] = _add(c + qs[q], 1.0)
			var ce: int = centre[Vector2i(ix, iy)]
			for q2 in 4:
				astar.connect_points(ce, corner[Vector3i(ix, iy, q2)])
			# crosswalks round the intersection
			astar.connect_points(corner[Vector3i(ix, iy, 0)], corner[Vector3i(ix, iy, 1)])
			astar.connect_points(corner[Vector3i(ix, iy, 2)], corner[Vector3i(ix, iy, 3)])
			astar.connect_points(corner[Vector3i(ix, iy, 0)], corner[Vector3i(ix, iy, 2)])
			astar.connect_points(corner[Vector3i(ix, iy, 1)], corner[Vector3i(ix, iy, 3)])
	# road centre lines between intersections (always clear; slightly dearer than sidewalks)
	for iy2 in lv.NROWS + 1:
		for ix2 in lv.NCOLS + 1:
			if ix2 < lv.NCOLS:
				astar.connect_points(centre[Vector2i(ix2, iy2)], centre[Vector2i(ix2 + 1, iy2)])
			if iy2 < lv.NROWS:
				astar.connect_points(centre[Vector2i(ix2, iy2)], centre[Vector2i(ix2, iy2 + 1)])
	# sidewalk lines: corners at both ends, gates in between
	for iy3 in lv.NROWS + 1:
		for ix3 in lv.NCOLS:
			# north sidewalk (side 0) runs from NE of (ix, iy) to NW of (ix+1, iy); south from SE to SW
			_line(Vector4i(0, iy3, 0, ix3), corner[Vector3i(ix3, iy3, 1)], corner[Vector3i(ix3 + 1, iy3, 0)], true)
			_line(Vector4i(0, iy3, 1, ix3), corner[Vector3i(ix3, iy3, 3)], corner[Vector3i(ix3 + 1, iy3, 2)], true)
	for ix4 in lv.NCOLS + 1:
		for iy4 in lv.NROWS:
			_line(Vector4i(1, ix4, 0, iy4), corner[Vector3i(ix4, iy4, 2)], corner[Vector3i(ix4, iy4 + 1, 0)], false)
			_line(Vector4i(1, ix4, 1, iy4), corner[Vector3i(ix4, iy4, 3)], corner[Vector3i(ix4, iy4 + 1, 1)], false)
	gate_node.resize(lv.lots.size())
	for lot in lv.lots:
		var gp: Vector2 = lot["gate_out"]
		var gid := _add(gp, 1.0)
		gate_node[lot["i"]] = gid
		var key := _line_key(gp)
		if lines.has(key):
			lines[key].append([gp.x if key.x == 0 else gp.y, gid])
	for key2 in lines:
		var lst: Array = lines[key2]
		lst.sort_custom(func(a, b): return a[0] < b[0])
		for i in range(lst.size() - 1):
			astar.connect_points(lst[i][1], lst[i + 1][1])
	# cover spots behind parked cars and street trees, on both sides
	for r in lv.parked:
		var rr: Rect2 = r
		var horiz: bool = rr.size.x >= rr.size.y
		for f in [0.2, 0.5, 0.8]:
			for sgn in [-1.0, 1.0]:
				var p := Vector2.ZERO
				if horiz:
					p = Vector2(rr.position.x + rr.size.x * f, rr.get_center().y + sgn * (rr.size.y / 2.0 + 0.7))
				else:
					p = Vector2(rr.get_center().x + sgn * (rr.size.x / 2.0 + 0.7), rr.position.y + rr.size.y * f)
				if is_free(p):
					var k := Vector2i(int(p.x / 2.0), int(p.y / 2.0))
					if not _street_spots.has(k):
						_street_spots[k] = []
					_street_spots[k].append({"p": p, "gap": 0.7})


func _add(p: Vector2, weight: float) -> int:
	var i := _next_id
	_next_id += 1
	astar.add_point(i, p, weight)
	return i


## A sidewalk line between two corners; gates are added to it later.
func _line(key: Vector4i, a: int, b: int, horiz: bool) -> void:
	var pa := astar.get_point_position(a)
	var pb := astar.get_point_position(b)
	lines[key] = [[pa.x if horiz else pa.y, a], [pb.x if horiz else pb.y, b]]


## Which sidewalk line a point lies on (Vector4i(-1...) if none).
func _line_key(p: Vector2) -> Vector4i:
	var lv = level
	var s: Vector2i = lv.street_at(p)
	if s.x >= 0 and s.y < 0:
		var yc: float = lv.node_pos(0, s.x).y
		var seg := int((p.x - lv.ST) / (lv.BW + lv.ST))
		if absf(p.y - (yc - lv.WALK_OFF)) <= 1.6:
			return Vector4i(0, s.x, 0, seg)
		if absf(p.y - (yc + lv.WALK_OFF)) <= 1.6:
			return Vector4i(0, s.x, 1, seg)
	elif s.y >= 0 and s.x < 0:
		var xc: float = lv.node_pos(s.y, 0).x
		var seg2 := int((p.y - lv.ST) / (lv.BH + lv.ST))
		if absf(p.x - (xc - lv.WALK_OFF)) <= 1.6:
			return Vector4i(1, s.y, 0, seg2)
		if absf(p.x - (xc + lv.WALK_OFF)) <= 1.6:
			return Vector4i(1, s.y, 1, seg2)
	return Vector4i(-1, -1, -1, -1)


# ================================================================== the brain's interface
func lot_at(p: Vector2) -> int:
	return level.lot_at(p)


func reachable(p: Vector2) -> bool:
	var li: int = level.lot_at(p)
	if li >= 0:
		var lot: Dictionary = level.lots[li]
		return lot["tpl"]["nav"].reachable(level.inv(lot, p))
	return _street_free(p)


func is_free(p: Vector2) -> bool:
	var li: int = level.lot_at(p)
	if li >= 0:
		var lot: Dictionary = level.lots[li]
		var q: Vector2 = level.inv(lot, p)
		var lv = lot["tpl"]["lv"]
		if q.x < 0.0 or q.y < 0.0 or q.x > lv.W or q.y > lv.H:
			return false
		return lot["tpl"]["nav"].is_free(q)
	return _street_free(p)


func _street_free(p: Vector2) -> bool:
	if not level.in_street(p):
		return false
	if p.x < 0.6 or p.y < 0.6 or p.x > level.W - 0.6 or p.y > level.H - 0.6:
		return false
	return not geom.blocked_disc(p, 0.3)


func snap(p: Vector2) -> Vector2:
	var li: int = level.lot_at(p)
	if li >= 0:
		var lot: Dictionary = level.lots[li]
		return level.xf(lot, lot["tpl"]["nav"].snap(level.inv(lot, p)))
	if _street_free(p):
		return p
	if level.in_street(p):
		# beside a parked car: step out sideways
		for r in [0.5, 1.0, 1.5, 2.2, 3.0]:
			for d in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
				if _street_free(p + d * r):
					return p + d * r
		return p
	# a fenced garden or the gap between lots: out to the nearest sidewalk
	var bk: Vector2i = level.block_of(p)
	var br: Rect2 = level.blocks[bk]["rect"]
	var cands := [Vector2(p.x, br.position.y - 1.5), Vector2(p.x, br.end.y + 1.5),
		Vector2(br.position.x - 1.5, p.y), Vector2(br.end.x + 1.5, p.y)]
	var best: Vector2 = cands[0]
	for c in cands:
		if c.distance_to(p) < best.distance_to(p):
			best = c
	return best


func spots_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var li: int = level.lot_at(p)
	if li >= 0:
		var lot: Dictionary = level.lots[li]
		for item in lot["tpl"]["nav"].spots_near(level.inv(lot, p), r):
			var c: Dictionary = item[1]
			out.append([item[0], {"p": level.xf(lot, c["p"]), "gap": c["gap"]}])
	if li < 0 or level.lot_at(p + Vector2(0, r)) != li or level.lot_at(p - Vector2(0, r)) != li:
		var r2 := r * r
		for cy in range(int((p.y - r) / 2.0), int((p.y + r) / 2.0) + 1):
			for cx in range(int((p.x - r) / 2.0), int((p.x + r) / 2.0) + 1):
				for sp in _street_spots.get(Vector2i(cx, cy), []):
					var d2: float = p.distance_squared_to(sp["p"])
					if d2 <= r2:
						out.append([d2, sp])
		out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func path_length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for k in range(1, pts.size()):
		s += pts[k - 1].distance_to(pts[k])
	return s


func find_path(prof: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	path_calls += 1
	var t0 := Time.get_ticks_usec()
	var res := _find_path(prof, a, b)
	path_us += Time.get_ticks_usec() - t0
	return res


func _lot_path(li: int, prof: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	var lot: Dictionary = level.lots[li]
	var loc: PackedVector2Array = lot["tpl"]["nav"].find_path(prof, level.inv(lot, a), level.inv(lot, b))
	var out := PackedVector2Array()
	for q in loc:
		out.append(level.xf(lot, q))
	return out


func _find_path(prof: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	var la: int = level.lot_at(a)
	var lb: int = level.lot_at(b)
	if la >= 0 and la == lb:
		return _lot_path(la, prof, a, b)
	var out := PackedVector2Array()
	var sa := a
	if la >= 0:
		var lot_a: Dictionary = level.lots[la]
		var pa := _lot_path(la, prof, a, lot_a["gate_in"])
		if pa.is_empty():
			return PackedVector2Array()
		out.append_array(pa)
		sa = lot_a["gate_out"]
	elif not level.in_street(a):
		sa = snap(a)
		out.append(a)
	var sb := b
	if lb >= 0:
		sb = level.lots[lb]["gate_out"]
	elif not level.in_street(b):
		sb = snap(b)
	var mid := _street_path(sa, sb, la, lb)
	if mid.is_empty():
		return PackedVector2Array()
	out.append_array(mid)
	if lb >= 0:
		var lot_b: Dictionary = level.lots[lb]
		var pb := _lot_path(lb, prof, lot_b["gate_in"], b)
		if pb.is_empty():
			return PackedVector2Array()
		out.append(lot_b["gate_in"])
		out.append_array(pb)
	elif sb != b:
		out.append(b)
	return _dedupe(out)


static func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 0.0004:
			out.append(p)
	return out


## Sidewalk path between two street points (or lot gates).
func _street_path(a: Vector2, b: Vector2, la: int, lb: int) -> PackedVector2Array:
	var pre := PackedVector2Array()
	var post := PackedVector2Array()
	var ida := -1
	var idb := -1
	if la >= 0:
		ida = gate_node[la]
	else:
		pre.append(a)
		ida = _temp(TMP_A, a, pre)
	if lb >= 0:
		idb = gate_node[lb]
	else:
		idb = _temp(TMP_B, b, post)
	if ida < 0 or idb < 0:
		_clear_temp()
		return PackedVector2Array()
	var path := PackedVector2Array()
	if ida == idb:
		path.append(astar.get_point_position(ida))
	else:
		path = astar.get_point_path(ida, idb)
	_clear_temp()
	if path.is_empty():
		return path
	var out := PackedVector2Array()
	out.append_array(pre)
	out.append_array(path)
	if lb < 0:
		post.reverse()
		out.append_array(post)
		out.append(b)
	return out


## Hook a free street point into the graph through a temporary node. `via` receives the
## points walked before reaching the node (a step to the road's centre line).
func _temp(tid: int, p: Vector2, via: PackedVector2Array) -> int:
	var lv = level
	var key := _line_key(p)
	if lines.has(key):
		astar.add_point(tid, p, 1.0)
		var lst: Array = lines[key]
		var along: float = p.x if key.x == 0 else p.y
		var prev = null
		var nxt = null
		for it in lst:
			if it[0] <= along:
				prev = it
			elif nxt == null:
				nxt = it
		if prev != null:
			astar.connect_points(tid, prev[1])
		if nxt != null:
			astar.connect_points(tid, nxt[1])
		return tid
	var s: Vector2i = lv.street_at(p)
	if s.x >= 0 and s.y >= 0:
		# inside an intersection: everything round it is in reach
		var ix: int = s.y
		var iy: int = s.x
		astar.add_point(tid, p, 1.0)
		astar.connect_points(tid, centre[Vector2i(ix, iy)])
		for q in 4:
			astar.connect_points(tid, corner[Vector3i(ix, iy, q)])
		return tid
	if s.x >= 0:
		# a horizontal street's roadway: step to the centre line first
		var yc: float = lv.node_pos(0, s.x).y
		var q2 := Vector2(p.x, yc)
		via.append(q2)
		astar.add_point(tid, q2, 1.0)
		var ix2 := clampi(int(p.x / (lv.BW + lv.ST)), 0, lv.NCOLS)
		astar.connect_points(tid, centre[Vector2i(ix2, s.x)])
		if ix2 + 1 <= lv.NCOLS:
			astar.connect_points(tid, centre[Vector2i(ix2 + 1, s.x)])
		return tid
	if s.y >= 0:
		var xc: float = lv.node_pos(s.y, 0).x
		var q3 := Vector2(xc, p.y)
		via.append(q3)
		astar.add_point(tid, q3, 1.0)
		var iy3 := clampi(int(p.y / (lv.BH + lv.ST)), 0, lv.NROWS)
		astar.connect_points(tid, centre[Vector2i(s.y, iy3)])
		if iy3 + 1 <= lv.NROWS:
			astar.connect_points(tid, centre[Vector2i(s.y, iy3 + 1)])
		return tid
	return -1


func _clear_temp() -> void:
	for tid in [TMP_A, TMP_B, TMP_C]:
		if astar.has_point(tid):
			astar.remove_point(tid)
