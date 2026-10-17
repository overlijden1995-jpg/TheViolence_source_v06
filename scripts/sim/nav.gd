extends RefCounted
## Tactical navigation (bible section 6). Four AStarGrid2D grids share one walkable
## mask and differ only in their cost layers:
##   profile 0: shortest path          profile 1: + PF01 doorway cost (x8)
##   profile 2: + PF02 exposure cost   profile 3: both
## Exposure is static: each cell pays +3 per door or window that can see it (cap +9).
## Precomputed once per map (on a 1 m lattice for big maps) and cached across matches.

const Geom = preload("res://scripts/sim/geom.gd")
const CS := 0.25            # cell size, metres
const RADIUS := 0.30        # body radius + margin

static var _cache := {}     # map id -> layers and grids, shared between World instances

var level
var geom: Geom
var nx := 0
var ny := 0
var solid := PackedByteArray()
var reach := PackedByteArray()  # 1 = free and in the main connected region
var w_door := PackedFloat32Array()
var w_expo := PackedFloat32Array()
var grids: Array = []
var cover_spots: Array = []     # [{p: Vector2, gap: float}] candidate cover positions
var _spot_cells := {}           # Vector2i (2 m cell) -> Array of spots


func build(lv) -> void:
	level = lv
	geom = lv.geom
	nx = int(ceil(lv.W / CS))
	ny = int(ceil(lv.H / CS))
	var key: String = lv.id
	if _cache.has(key):
		var c: Dictionary = _cache[key]
		solid = c["solid"]
		reach = c["reach"]
		w_door = c["w_door"]
		w_expo = c["w_expo"]
		cover_spots = c["cover"]
		grids = c["grids"]
		_spot_cells = c["spot_cells"]
		lv.snap_posts(self)
		return
	_build_layers()
	_flood()
	var kept: Array = []
	for c in cover_spots:
		var cc := cell_of(c["p"])
		if reach[cc.y * nx + cc.x] == 1:
			kept.append(c)
	cover_spots = kept
	grids = []
	for prof in 4:
		var g := AStarGrid2D.new()
		g.region = Rect2i(0, 0, nx, ny)
		g.cell_size = Vector2(1, 1)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		g.update()
		for y in ny:
			for x in nx:
				var i := y * nx + x
				if solid[i] == 1:
					g.set_point_solid(Vector2i(x, y), true)
				else:
					var w := 1.0
					if prof & 1:
						w += w_door[i]
					if prof & 2:
						w += w_expo[i]
					if w != 1.0:
						g.set_point_weight_scale(Vector2i(x, y), w)
		grids.append(g)
	_spot_cells = {}
	for c in cover_spots:
		var k := Vector2i(int(c["p"].x / 2.0), int(c["p"].y / 2.0))
		if not _spot_cells.has(k):
			_spot_cells[k] = []
		_spot_cells[k].append(c)
	_cache[key] = {"solid": solid, "reach": reach, "w_door": w_door, "w_expo": w_expo, "cover": cover_spots,
		"grids": grids, "spot_cells": _spot_cells}
	lv.snap_posts(self)


## Cover spots within r of p, as [distance_squared, spot] pairs sorted nearest first.
func spots_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	var x0 := int((p.x - r) / 2.0)
	var x1 := int((p.x + r) / 2.0)
	var y0 := int((p.y - r) / 2.0)
	var y1 := int((p.y + r) / 2.0)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var k := Vector2i(cx, cy)
			if not _spot_cells.has(k):
				continue
			for c in _spot_cells[k]:
				var d2: float = p.distance_squared_to(c["p"])
				if d2 <= r2:
					out.append([d2, c])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func lv_area() -> float:
	return level.W * level.H


func _build_layers() -> void:
	var n := nx * ny
	solid.resize(n)
	w_door.resize(n)
	w_expo.resize(n)
	w_door.fill(0.0)
	w_expo.fill(0.0)
	for y in ny:
		for x in nx:
			var p := cell_centre(Vector2i(x, y))
			solid[y * nx + x] = 1 if geom.blocked_disc(p, RADIUS) else 0
	# PF01: doorway (threshold) cells within 1.5 m of every door
	for id in level.doors:
		var c: Vector2 = level.doors[id]["c"]
		var c0 := cell_of(c - Vector2(1.6, 1.6))
		var c1 := cell_of(c + Vector2(1.6, 1.6))
		for y in range(c0.y, c1.y + 1):
			for x in range(c0.x, c1.x + 1):
				if cell_centre(Vector2i(x, y)).distance_to(c) <= 1.5:
					w_door[y * nx + x] = 7.0
	# PF02: exposure from each opening's viewpoints, on a 0.5 m coarse grid within 14 m
	var step := 2 if lv_area() <= 1200.0 else 4
	var reach := 14.0
	for o in level.openings:
		for vp in o["vps"]:
			if geom.blocked_disc(vp, 0.05):
				continue
			var y0 := maxi(0, int((vp.y - reach) / CS) / step * step)
			var x0 := maxi(0, int((vp.x - reach) / CS) / step * step)
			var y1 := mini(ny, int((vp.y + reach) / CS) + 1)
			var x1 := mini(nx, int((vp.x + reach) / CS) + 1)
			for y in range(y0, y1, step):
				for x in range(x0, x1, step):
					var p := cell_centre(Vector2i(x, y)) + Vector2(CS, CS) * 0.5 * (step - 1)
					if p.distance_to(vp) > reach:
						continue
					if not geom.sight_clear(vp, 1.65, p, 1.3):
						continue
					for dy in step:
						for dx in step:
							var xx := x + dx
							var yy := y + dy
							if xx < nx and yy < ny:
								var i := yy * nx + xx
								w_expo[i] = minf(9.0, w_expo[i] + 3.0)
	# cover candidates: walkable spots near cover or walls
	for y in range(0, ny, 2):
		for x in range(0, nx, 2):
			var c2 := Vector2i(x, y)
			if solid[y * nx + x] == 1:
				continue
			var p2 := cell_centre(c2)
			var gap := geom.dist_to_kinds(p2, [Geom.COVER, Geom.WALL], 1.6)
			if gap < 1.5:
				cover_spots.append({"p": p2, "gap": gap})


## Mark the largest connected walkable region; isolated pockets (behind furniture,
## between a bed and a wall) are never used as path ends.
func _flood() -> void:
	var n := nx * ny
	var comp := PackedInt32Array()
	comp.resize(n)
	comp.fill(-1)
	var best_id := -1
	var best_size := 0
	var cid := 0
	for start in n:
		if solid[start] == 1 or comp[start] != -1:
			continue
		var stack := PackedInt32Array([start])
		comp[start] = cid
		var size := 0
		while stack.size() > 0:
			var i: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			size += 1
			var x := i % nx
			var y := i / nx
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx < 0 or yy < 0 or xx >= nx or yy >= ny:
					continue
				var j := yy * nx + xx
				if solid[j] == 0 and comp[j] == -1:
					comp[j] = cid
					stack.append(j)
		if size > best_size:
			best_size = size
			best_id = cid
		cid += 1
	reach.resize(n)
	for i in n:
		reach[i] = 1 if comp[i] == best_id else 0


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CS), 0, nx - 1), clampi(int(p.y / CS), 0, ny - 1))


func cell_centre(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CS, (c.y + 0.5) * CS)


## Free and in the main connected region.
func reachable(p: Vector2) -> bool:
	var c := cell_of(p)
	return reach[c.y * nx + c.x] == 1


func is_free(p: Vector2) -> bool:
	var c := cell_of(p)
	return solid[c.y * nx + c.x] == 0


func nearest_free(p: Vector2) -> Vector2i:
	var c := cell_of(p)
	if reach[c.y * nx + c.x] == 1:
		return c
	for r in range(1, 12):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var q := Vector2i(c.x + dx, c.y + dy)
				if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= ny:
					continue
				if reach[q.y * nx + q.x] == 1:
					var d := cell_centre(q).distance_squared_to(p)
					if d < bd:
						bd = d
						best = q
		if best.x >= 0:
			return best
	return c


func snap(p: Vector2) -> Vector2:
	var c := cell_of(p)
	if reach[c.y * nx + c.x] == 1:
		return p
	return cell_centre(nearest_free(p))


func weight_at(prof: int, p: Vector2) -> float:
	var c := cell_of(p)
	var i := c.y * nx + c.x
	var w := 1.0
	if prof & 1:
		w += w_door[i]
	if prof & 2:
		w += w_expo[i]
	return w


func exposure_at(p: Vector2) -> float:
	var c := cell_of(p)
	return w_expo[c.y * nx + c.x]


## Path as world points from a to b. Smoothed where the straight line stays walkable
## and no costlier than the cell it starts from.
var path_calls := 0
var path_us := 0


func find_path(prof: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	path_calls += 1
	var t0 := Time.get_ticks_usec()
	var res := _find_path(prof, a, b)
	path_us += Time.get_ticks_usec() - t0
	return res


func _find_path(prof: int, a: Vector2, b: Vector2) -> PackedVector2Array:
	var g: AStarGrid2D = grids[clampi(prof, 0, 3)]
	var ca := nearest_free(a)
	var cb := nearest_free(b)
	var ids: Array[Vector2i] = g.get_id_path(ca, cb)
	var pts := PackedVector2Array()
	if ids.is_empty():
		return pts
	pts.append(a if is_free(a) else cell_centre(ca))
	for k in range(1, ids.size() - 1):
		pts.append(cell_centre(ids[k]))
	pts.append(b if is_free(b) else cell_centre(cb))
	return _smooth(prof, pts)


func _smooth(prof: int, pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	var i := 0
	var n := pts.size()
	while i < n - 1:
		var j := mini(n - 1, i + 12)
		while j > i + 1 and not line_ok(prof, pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


func _w(prof: int, i: int) -> float:
	var v := 1.0
	if prof & 1:
		v += w_door[i]
	if prof & 2:
		v += w_expo[i]
	return v


func line_ok(prof: int, a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / CS) + 1
	var w0 := 1.0
	if prof != 0:
		w0 = _w(prof, clampi(int(a.y / CS), 0, ny - 1) * nx + clampi(int(a.x / CS), 0, nx - 1))
	for k in range(1, steps + 1):
		var p := a.lerp(b, float(k) / steps)
		var i := clampi(int(p.y / CS), 0, ny - 1) * nx + clampi(int(p.x / CS), 0, nx - 1)
		if solid[i] == 1:
			return false
		if prof != 0 and _w(prof, i) > w0 + 0.01:
			return false
	return true


func path_length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for k in range(1, pts.size()):
		s += pts[k - 1].distance_to(pts[k])
	return s
