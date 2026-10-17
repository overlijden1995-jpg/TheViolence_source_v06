extends RefCounted
## Plan-view geometry with analytic height (bible section 1).
## Every obstacle is an axis-aligned rectangle in metres with a kind and a height.
## Sight lines and bullets are 2D segments whose height varies linearly along
## their length; the obstacle kind decides what each one stops.

enum {WALL, COVER, CONCEAL, WINDOW, LOW}

## Low cover (up to 1.3 m) does not get in the way of someone right beside it: they
## shoot and look over it. Its effective height for a sight line or shot grows with the
## distance from the line's origin (the shooter or observer) to the cover, from nothing
## within 0.4 m to full height at 3 m. Applies only when the origin is above the cover
## top (a ducked operator stays behind it). Cover near the target still protects fully
## against a distant shooter.
const LOW_COVER_H := 1.3
const LOW_NEAR := 0.4
const LOW_FULL := 3.0

var obs: Array = []        # [{r: Rect2, kind, h, sill, lintel, move: bool, name}]
var width := 0.0
var height := 0.0
var _cstart := PackedInt32Array()   # 1 m buckets of obstacle indices (CSR: start offsets)
var _citems := PackedInt32Array()   # obstacle indices, bucket by bucket
var _cw := 0
var _ch := 0
var _stamp := PackedInt32Array()
var _stamp_id := 0
# flat copies of the obstacle fields for the hot sight-line loop
var _rect: Array[Rect2] = []
var _kind := PackedInt32Array()
var _h := PackedFloat32Array()
var _sill := PackedFloat32Array()
var _lintel := PackedFloat32Array()
var _mv := PackedByteArray()


func setup(w: float, h: float) -> void:
	width = w
	height = h
	_cw = int(ceil(w))
	_ch = int(ceil(h))


func add(r: Rect2, kind: int, h: float = 3.0, name: String = "", move: bool = true,
		sill: float = 0.9, lintel: float = 2.1) -> int:
	obs.append({"r": r, "kind": kind, "h": h, "sill": sill, "lintel": lintel, "move": move, "name": name})
	return obs.size() - 1


func build_index() -> void:
	var n := _cw * _ch
	var counts := PackedInt32Array()
	counts.resize(n + 1)
	counts.fill(0)
	var spans: Array = []
	for i in obs.size():
		var r: Rect2 = obs[i]["r"]
		var x0 := clampi(int(floor(r.position.x)), 0, _cw - 1)
		var y0 := clampi(int(floor(r.position.y)), 0, _ch - 1)
		var x1 := clampi(int(floor(r.end.x - 0.0001)), 0, _cw - 1)
		var y1 := clampi(int(floor(r.end.y - 0.0001)), 0, _ch - 1)
		spans.append(Vector4i(x0, y0, x1, y1))
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				counts[cy * _cw + cx + 1] += 1
	for i in n:
		counts[i + 1] += counts[i]
	_cstart = counts
	_citems.resize(counts[n])
	var fill := counts.duplicate()
	for i in obs.size():
		var sp: Vector4i = spans[i]
		for cy in range(sp.y, sp.w + 1):
			for cx in range(sp.x, sp.z + 1):
				var c := cy * _cw + cx
				_citems[fill[c]] = i
				fill[c] += 1
	_stamp.resize(obs.size())
	_stamp.fill(0)
	_rect.clear()
	_kind.resize(obs.size())
	_h.resize(obs.size())
	_sill.resize(obs.size())
	_lintel.resize(obs.size())
	_mv.resize(obs.size())
	for i in obs.size():
		var o: Dictionary = obs[i]
		_rect.append(o["r"])
		_kind[i] = o["kind"]
		_h[i] = o["h"]
		_sill[i] = o["sill"]
		_lintel[i] = o["lintel"]
		_mv[i] = 1 if o["move"] else 0


func _collect(cx: int, cy: int, out: Array) -> void:
	if cx < 0 or cy < 0 or cx >= _cw or cy >= _ch:
		return
	var c := cy * _cw + cx
	for k in range(_cstart[c], _cstart[c + 1]):
		var idx: int = _citems[k]
		if _stamp[idx] != _stamp_id:
			_stamp[idx] = _stamp_id
			out.append(idx)


## Obstacle indices whose buckets the segment a->b passes through (2D DDA).
func candidates(a: Vector2, b: Vector2) -> Array:
	_stamp_id += 1
	var out: Array = []
	var x := int(floor(a.x))
	var y := int(floor(a.y))
	var xe := int(floor(b.x))
	var ye := int(floor(b.y))
	var d := b - a
	var step_x := 1 if d.x > 0.0 else -1
	var step_y := 1 if d.y > 0.0 else -1
	var t_max_x := INF
	var t_max_y := INF
	var t_dx := INF
	var t_dy := INF
	if absf(d.x) > 1e-9:
		t_max_x = ((x + (1 if d.x > 0.0 else 0)) - a.x) / d.x
		t_dx = absf(1.0 / d.x)
	if absf(d.y) > 1e-9:
		t_max_y = ((y + (1 if d.y > 0.0 else 0)) - a.y) / d.y
		t_dy = absf(1.0 / d.y)
	var guard := 0
	while true:
		_collect(x, y, out)
		if (x == xe and y == ye) or guard > 512:
			break
		if t_max_x < t_max_y:
			t_max_x += t_dx
			x += step_x
		else:
			t_max_y += t_dy
			y += step_y
		guard += 1
	return out


## Slab test. Returns Vector3(t_in, t_out, face) with face 0 = entered through an
## x face, 1 = through a y face, -1 = starts inside; t_in < 0 means no hit.
static func seg_rect(a: Vector2, d: Vector2, r: Rect2) -> Vector3:
	var t0 := 0.0
	var t1 := 1.0
	var face := -1
	for axis in 2:
		var p: float = a[axis]
		var dd: float = d[axis]
		var lo: float = r.position[axis]
		var hi: float = lo + r.size[axis]
		if absf(dd) < 1e-9:
			if p < lo or p > hi:
				return Vector3(-1, -1, -1)
		else:
			var ta := (lo - p) / dd
			var tb := (hi - p) / dd
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			if ta > t0:
				t0 = ta
				face = axis
			t1 = minf(t1, tb)
			if t0 > t1:
				return Vector3(-1, -1, -1)
	return Vector3(t0, t1, face)


func _stops(o: Dictionary, zlo: float, zhi: float, is_bullet: bool, d_in: float, z_origin: float) -> bool:
	match o["kind"]:
		WALL:
			return true
		COVER:
			return zlo < low_height(o, d_in, z_origin)
		CONCEAL:
			return (not is_bullet) and zlo < low_height(o, d_in, z_origin)
		WINDOW:
			return zlo < o["sill"] or zhi > o["lintel"]
	return false


## Effective height of an obstacle for a line that reaches it d_in metres from an origin
## at height z_origin (see LOW_COVER_H).
static func low_height(o: Dictionary, d_in: float, z_origin: float) -> float:
	var h: float = o["h"]
	if h > LOW_COVER_H or z_origin <= h:
		return h
	return h * clampf((d_in - LOW_NEAR) / (LOW_FULL - LOW_NEAR), 0.0, 1.0)


## True when nothing blocks sight from (a, za) to (b, zb).
var sight_calls := 0


func sight_clear(a: Vector2, za: float, b: Vector2, zb: float) -> bool:
	return sight_mask(a, za, b, zb, -1.0) != 0


## Two sight lines from one eye to two heights at the same point, walked once:
## bit 0 = the line to zb1 is clear, bit 1 = the line to zb2 is clear (zb2 < 0: one line).
## Cells are visited along the line and the walk stops as soon as every line is blocked.
func sight_mask(a: Vector2, za: float, b: Vector2, zb1: float, zb2: float) -> int:
	sight_calls += 1
	var mask := 1 if zb2 < 0.0 else 3
	_stamp_id += 1
	var d := b - a
	var L := d.length()
	var x := int(floor(a.x))
	var y := int(floor(a.y))
	var xe := int(floor(b.x))
	var ye := int(floor(b.y))
	var step_x := 1 if d.x > 0.0 else -1
	var step_y := 1 if d.y > 0.0 else -1
	var t_max_x := INF
	var t_max_y := INF
	var t_dx := INF
	var t_dy := INF
	if absf(d.x) > 1e-9:
		t_max_x = ((x + (1 if d.x > 0.0 else 0)) - a.x) / d.x
		t_dx = absf(1.0 / d.x)
	if absf(d.y) > 1e-9:
		t_max_y = ((y + (1 if d.y > 0.0 else 0)) - a.y) / d.y
		t_dy = absf(1.0 / d.y)
	var guard := 0
	while true:
		if x >= 0 and y >= 0 and x < _cw and y < _ch:
			var cc := y * _cw + x
			for kk in range(_cstart[cc], _cstart[cc + 1]):
				var idx: int = _citems[kk]
				if _stamp[idx] == _stamp_id:
					continue
				_stamp[idx] = _stamp_id
				var kind: int = _kind[idx]
				if kind == LOW:
					continue
				var r: Rect2 = _rect[idx]
				if r.has_point(a) or r.has_point(b):
					continue
				var tt := seg_rect(a, d, r)
				if tt.x < 0.0:
					continue
				if kind == WALL:
					return 0
				for k in 2:
					if mask & (1 << k) == 0:
						continue
					var zb: float = zb1 if k == 0 else zb2
					var z0 := lerpf(za, zb, tt.x)
					var z1 := lerpf(za, zb, tt.y)
					var zlo := minf(z0, z1)
					var stop := false
					if kind == WINDOW:
						stop = zlo < _sill[idx] or maxf(z0, z1) > _lintel[idx]
					else:
						var h: float = _h[idx]
						if h <= LOW_COVER_H and za > h:
							h *= clampf((tt.x * L - LOW_NEAR) / (LOW_FULL - LOW_NEAR), 0.0, 1.0)
						stop = zlo < h
					if stop:
						mask &= ~(1 << k)
				if mask == 0:
					return 0
		if (x == xe and y == ye) or guard > 512:
			break
		if t_max_x < t_max_y:
			t_max_x += t_dx
			x += step_x
		else:
			t_max_y += t_dy
			y += step_y
		guard += 1
	return mask


## First obstacle that stops a bullet on a->b. Returns {hit, t, p, n, idx, kind}.
func trace_shot(a: Vector2, za: float, b: Vector2, zb: float) -> Dictionary:
	var d := b - a
	var L := d.length()
	var best_t := 2.0
	var best_idx := -1
	var best_face := -1
	for idx in candidates(a, b):
		var kind: int = _kind[idx]
		if kind == LOW or kind == CONCEAL:
			continue
		var r: Rect2 = _rect[idx]
		if r.has_point(a):
			continue
		var tt := seg_rect(a, d, r)
		if tt.x < 0.0 or tt.x >= best_t:
			continue
		var z0 := lerpf(za, zb, tt.x)
		var z1 := lerpf(za, zb, tt.y)
		var zlo := minf(z0, z1)
		var stop := false
		if kind == WALL:
			stop = true
		elif kind == WINDOW:
			stop = zlo < _sill[idx] or maxf(z0, z1) > _lintel[idx]
		else:
			var h: float = _h[idx]
			if h <= LOW_COVER_H and za > h:
				h *= clampf((tt.x * L - LOW_NEAR) / (LOW_FULL - LOW_NEAR), 0.0, 1.0)
			stop = zlo < h
		if stop:
			best_t = tt.x
			best_idx = idx
			best_face = int(tt.z)
	if best_idx < 0:
		return {"hit": false, "t": 1.0, "p": b, "n": Vector2.ZERO, "idx": -1, "kind": -1, "z": zb}
	var n := Vector2.ZERO
	if best_face == 0:
		n = Vector2(-signf(d.x), 0)
	elif best_face == 1:
		n = Vector2(0, -signf(d.y))
	return {"hit": true, "t": best_t, "p": a + d * best_t, "n": n, "idx": best_idx, "kind": _kind[best_idx],
		"z": lerpf(za, zb, best_t)}


## What a wall is made of (v0.6), for rounds going through it: partitions (up to 0.15 m)
## are drywall, exterior walls of houses (up to 0.25 m) timber frame, yard fences fence;
## anything thicker, tree trunks and named masonry are solid.
func material(idx: int) -> String:
	if idx < 0 or idx >= obs.size():
		return "solid"
	var o: Dictionary = obs[idx]
	if o["kind"] != WALL:
		return "solid"
	var nm: String = o["name"]
	if nm == "fence":
		return "fence"
	if nm != "wall":
		return "solid"
	var r: Rect2 = o["r"]
	var th := minf(r.size.x, r.size.y)
	if th <= 0.15:
		return "drywall"
	if th <= 0.25:
		return "frame"
	return "solid"


## Does a disc of radius rad at p overlap any movement-blocking obstacle?
func blocked_disc(p: Vector2, rad: float) -> bool:
	if p.x < rad or p.y < rad or p.x > width - rad or p.y > height - rad:
		return true
	var x0 := clampi(int(floor(p.x - rad)), 0, _cw - 1)
	var x1 := clampi(int(floor(p.x + rad)), 0, _cw - 1)
	var y0 := clampi(int(floor(p.y - rad)), 0, _ch - 1)
	var y1 := clampi(int(floor(p.y + rad)), 0, _ch - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cy * _cw + cx
			for k in range(_cstart[c], _cstart[c + 1]):
				var idx: int = _citems[k]
				if _mv[idx] == 0:
					continue
				var r: Rect2 = _rect[idx]
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				if q.distance_squared_to(p) < rad * rad:
					return true
	return false


## Distance from p to the nearest obstacle of the given kinds (capped at cap).
func dist_to_kinds(p: Vector2, kinds: Array, cap: float = 3.0) -> float:
	var best := cap
	var x0 := clampi(int(floor(p.x - cap)), 0, _cw - 1)
	var x1 := clampi(int(floor(p.x + cap)), 0, _cw - 1)
	var y0 := clampi(int(floor(p.y - cap)), 0, _ch - 1)
	var y1 := clampi(int(floor(p.y + cap)), 0, _ch - 1)
	_stamp_id += 1
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cy * _cw + cx
			for k in range(_cstart[c], _cstart[c + 1]):
				var idx: int = _citems[k]
				if _stamp[idx] == _stamp_id:
					continue
				_stamp[idx] = _stamp_id
				if not kinds.has(_kind[idx]):
					continue
				var r: Rect2 = _rect[idx]
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				best = minf(best, q.distance_to(p))
	return best
