extends Node2D
## Red-ink asset pack gallery and demo room.
##   xvfb-run -a godot --path . res://tests/redink_gallery.tscn -- --shot=/tmp/redink.png
##
## Keys (they touch presentation only, never rules):
##   Space  red ink on/off        G  gore on/off        R  theory/application
##   1/2    theory/application    H  show/hide the plan guides
##
## The demo room is read from assets/redink/demo_room.json, the same file the
## contact sheet and the state sheet are built from, so the layout is authored once.

const RedInk = preload("res://scripts/view/redink.gd")

## Ink (scripts/view/ink.gd) is an autoload: every colour here goes through it.

const ROOM_JSON := "res://assets/redink/demo_room.json"
const PX := 40.0
const PX_PER_METRE := 80.0

var room: Dictionary = {}
var ppm := 1.0
var layer_base: Node2D
var layer_red: Node2D
var layer_gore: Node2D
var ruler: Control
var camera: Camera2D


func _ready() -> void:
	# 80 px per metre of sheet, so a 12 m room reads the same as the sheets
	ppm = PX_PER_METRE * 0.5
	RenderingServer.set_default_clear_color(Ink.PAPER)
	var hud := CanvasLayer.new()
	add_child(hud)
	var bg := ColorRect.new()
	bg.color = Ink.PAPER
	bg.position = Vector2.ZERO
	bg.size = Vector2(1600, 900)
	hud.add_child(bg)
	_label(hud, "THE VIOLENCE  ·  RED INK ASSET PACK", Vector2(24, 14), 20, Ink.INK)
	_label(hud, "SPACE RED  ·  G GORE  ·  R STATE  ·  1 THEORY  ·  2 APPLICATION  ·  H GUIDES",
		Vector2(24, 42), 11, Ink.MID)
	room = _load_json(ROOM_JSON)
	layer_base = Node2D.new()
	layer_red = Node2D.new()
	layer_gore = Node2D.new()
	add_child(layer_base)
	add_child(layer_red)
	add_child(layer_gore)
	var origin := Vector2(24, 84)
	layer_base.position = origin
	layer_red.position = origin
	layer_gore.position = origin
	# the sheet's margin, in sheet pixels
	ruler = Control.new()
	ruler.position = origin
	ruler.size = Vector2(1600, 900)
	ruler.draw.connect(_draw_ruler)
	add_child(ruler)
	# frame the room without upscaling the sprite textures
	camera = Camera2D.new()
	camera.zoom = Vector2(1.45, 1.45)
	var size_m: Array = room.get("size_m", [12, 8])
	camera.position = origin + Vector2(size_m[0], size_m[1]) * ppm * 0.5
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	Ink.palette_changed.connect(_refresh)
	_rebuild()


func _load_json(p: String) -> Dictionary:
	if (not FileAccess.file_exists(p)):
		push_warning("redink gallery: %s missing, run tools/make_redink_assets.py" % p)
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if (not event is InputEventKey or not event.pressed or event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			Ink.set_red_ink(not Ink.red_ink_enabled)
		KEY_G:
			Ink.set_gore(not Ink.gore_enabled)
		KEY_R:
			Ink.set_state("application" if Ink.is_theory() else "theory")
		KEY_1:
			Ink.set_state("theory")
		KEY_2:
			Ink.set_state("application")
		KEY_H:
			ruler.visible = not ruler.visible


func _refresh() -> void:
	_rebuild()


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


func _rebuild() -> void:
	if (room.is_empty()):
		return
	_clear(layer_base)
	_clear(layer_red)
	_clear(layer_gore)
	var state: String = Ink.state
	var st: Dictionary = room.get(state, {})
	# ---- base: floors, walls, props, actors (neutral, never tinted)
	for f in room.get("floors", []):
		for gy in range(int(f["h"])):
			for gx in range(int(f["w"])):
				_tile("tiles/" + f["tile"], Vector2(f["x"] + gx, f["y"] + gy))
	for wl in room.get("walls", []):
		if (wl["kind"] != "wall"):
			continue
		for k in range(int(ceil(wl["len"]))):
			_wall("tiles/wall_stack", wl, k)
	var breach = st.get("breach") if state == "application" else null
	for wl in room.get("walls", []):
		if (wl["kind"] == "wall"):
			continue
		var tile := "tiles/wall_window"
		if (wl["kind"] == "door"):
			var broken: bool = breach != null and breach == {"x": wl["x"], "y": wl["y"]}
			tile = "tiles/breach" if broken else "tiles/wall_doorway"
		for k in range(int(ceil(wl["len"]))):
			_wall(tile, wl, k)
	for p in room.get("props", []):
		var at := Vector2(p["x"], p["y"])
		_add(RedInk.make("props/" + p["name"], at, deg_to_rad(p.get("rot", 0.0))))
	var swapped: Dictionary = {}
	if (state == "application"):
		swapped = room.get("application", {}).get("actor_state", {})
	for a in room.get("actors", []):
		var name: String = swapped.get(a["name"], a["name"])
		var pose := "down" if name.ends_with("_down") else "stand"
		var rot := deg_to_rad(a.get("rot", 0.0))
		_add(RedInk.make("actors/shadow_" + pose, Vector2(a["x"], a["y"]), rot, 1.0, 1.0, false))
		_add(RedInk.make("actors/" + name, Vector2(a["x"], a["y"]), rot))
	# ---- red mask: blood first (it slides under edges), then route, rings, arrow
	if (state == "application"):
		for bl in st.get("blood", []):
			var s := _gore("masks/" + bl["mask"], Vector2(bl["x"], bl["y"]),
				deg_to_rad(bl.get("rot", 0.0)), bl.get("scale", 1.0), bl.get("alpha", 0.8))
			if (s != null):
				s.z_index = 1
	_route(st, state)
	# ---- institutional marks: evidence, paperwork, scuffs, stamps
	if (state == "application"):
		for m in st.get("marks", []):
			var s2 := RedInk.make("marks/" + m["name"], Vector2(m["x"], m["y"]),
				deg_to_rad(m.get("rot", 0.0)), m.get("scale", 1.0))
			s2.z_index = 5
			_add(s2)
		_stamp(st)
	_labels(st)
	ruler.queue_redraw()


func _add(s: Sprite2D) -> void:
	layer_base.add_child(s)


func _tile(key: String, cell: Vector2) -> void:
	var s := RedInk.make(key, Vector2.ZERO, 0.0, 1.0, 1.0, false)
	if (s.texture != null):
		s.centered = false
		s.position = cell * PX
		layer_base.add_child(s)


func _wall(key: String, wl: Dictionary, k: int) -> void:
	var vertical: bool = wl["o"] == "v"
	var cell := Vector2(wl["x"], wl["y"] + k) if vertical else Vector2(wl["x"] + k, wl["y"])
	var rot := deg_to_rad(90.0) if vertical else 0.0
	var s := RedInk.make(key, Vector2.ZERO, rot, 1.0, 1.0, false)
	if (s.texture == null):
		return
	s.centered = false
	# the strip art hangs below its wall line; a vertical strip is the same tile
	# rotated 90 degrees, which keeps the poche on the line
	s.position = cell * PX
	layer_base.add_child(s)


func _gore(key: String, at: Vector2, rot: float, scale_f: float, alpha: float) -> Sprite2D:
	if (not RedInk.blood_visible()):
		return null
	var s := RedInk.make_blob(key, at, rot, scale_f, alpha)
	s.name = key.get_file().get_basename()
	layer_gore.add_child(s)
	return s


func _route(st: Dictionary, state: String) -> void:
	var pts: Array = []
	for p in st.get("route", []):
		pts.append(Vector2(p[0], p[1]) * PX)
	if (pts.size() < 2):
		return
	var pts2 := PackedVector2Array(pts)
	if (state == "application"):
		# the plan as drawn (faint, offset) versus the plan as walked
		var ghost := PackedVector2Array()
		for p in pts:
			ghost.append(p + Vector2(5, 6))
		_red_line(ghost, 4.0, 0.16)
		_red_line(pts2, 6.0, 0.9)
	else:
		_red_line(pts2, 4.0, 0.95)
	var i := 0
	for r in st.get("rings", []):
		i += 1
		var s := RedInk.make_blob("masks/ring_%d" % (((i - 1) % 5) + 1),
			Vector2(r[0], r[1]), 0.0, 0.62, 1.0)
		s.z_index = 3
		layer_red.add_child(s)
	var last: Vector2 = pts[pts.size() - 1]
	var prev: Vector2 = pts[pts.size() - 2]
	var ang := (last - prev).angle()
	var arrow := RedInk.make_blob("masks/route_arrow", (last + prev) * 0.5, ang, 0.55, 0.9)
	arrow.z_index = 3
	layer_red.add_child(arrow)


func _red_line(pts: PackedVector2Array, width: float, alpha: float) -> void:
	var ln := Line2D.new()
	ln.points = pts
	ln.width = width
	ln.default_color = RedInk.accent(alpha)
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	ln.z_index = 2
	layer_red.add_child(ln)


func _stamp(st: Dictionary) -> void:
	var s := RedInk.make_blob(str(st.get("stamp", "ui/stamp_theory")), Vector2.ZERO, 0.0, 1.0, 1.0)
	if (s.texture == null):
		return
	var size_m: Array = room.get("size_m", [12, 8])
	s.centered = false
	s.position = Vector2(size_m[0] * PX - s.texture.get_width() * s.scale.x - 8.0,
		size_m[1] * PX + 8.0)
	s.z_index = 4
	layer_red.add_child(s)


func _labels(st: Dictionary) -> void:
	var h: float = room.get("size_m", [12, 8])[1] * PX
	var y := h + 8.0
	for lb in st.get("labels", []):
		var text: String = lb[0]
		var chip := ColorRect.new()
		chip.color = Ink.PAPER
		var lw := 10.0 + text.length() * 6.6
		chip.size = Vector2(lw, 17)
		chip.position = Vector2(lb[1], y + lb[2])
		chip.z_index = 4
		var border := ReferenceRect.new()
		border.border_color = Ink.INK
		border.border_width = 1.0
		border.editor_only = false
		border.size = chip.size
		chip.add_child(border)
		layer_base.add_child(chip)
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Ink.INK)
		l.position = chip.position + Vector2(4, 2)
		l.z_index = 5
		layer_base.add_child(l)


func _draw_ruler() -> void:
	# the plan's own paper edge and the 1 m grid, drawn as the sheet margin
	if (room.is_empty()):
		return
	var w: float = room.get("size_m", [12, 8])[0] * PX
	var h: float = room.get("size_m", [12, 8])[1] * PX
	ruler.draw_rect(Rect2(0, 0, w, h), Ink.FLOOR, false, 1.0)
	for x in range(0, int(room["size_m"][0]) + 1):
		ruler.draw_line(Vector2(x * PX, 0), Vector2(x * PX, h), Color(0, 0, 0, 0.07), 1.0)
	for y in range(0, int(room["size_m"][1]) + 1):
		ruler.draw_line(Vector2(0, y * PX), Vector2(w, y * PX), Color(0, 0, 0, 0.07), 1.0)
	ruler.draw_rect(Rect2(0, 0, w, h), Ink.INK, false, 1.5)
