extends RefCounted
## Asset-pack loader for assets/redink (build it with
## `python3 tools/make_redink_assets.py`).
##
## Encoding, so no sprite is ever placed wrong:
##   * files are authored at 80 px per metre; the game world is 40 px per metre,
##     so every sprite is placed at scale 0.5 (PX / PX_PER_METRE) unless the
##     caller overrides it;
##   * actors, props and marks are centred on their canvas;
##   * tiles are top-left anchored (place with add_tile(), not make()).
##
## Red masks are white on transparent. The tint always comes from Ink.accent(),
## never from the file, so the monochrome proof and the gore toggle are free.

const ROOT := "res://assets/redink"
const PX := 40.0
const PX_PER_METRE := 80.0
const SVG_SCALE := 0.5
## Signal red and the grey it becomes with red ink off, used only if the Ink
## autoload is not available (a script run outside the scene tree, say).
const RED := Color(0.70, 0.12, 0.15)
const MONO := Color(0.36, 0.36, 0.36)
const ALPHA := {
	"red_mask": 0.85,
	"gore": 0.8,
}


static func path(key: String) -> String:
	return "%s/%s.svg" % [ROOT, key]


static func tex(key: String) -> Texture2D:
	if (not ResourceLoader.exists(path(key))):
		push_warning("redink: missing asset %s (run tools/make_redink_assets.py)" % key)
		return null
	return load(path(key))


## The Ink autoload, or null when there is no scene tree to ask.
static func ink() -> Node:
	var loop := Engine.get_main_loop()
	if (not loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	if (root == null):
		return null
	return root.get_node_or_null("/root/Ink")


## Every red mark in the pack goes through here.
static func accent(alpha: float) -> Color:
	var i := ink()
	if (i != null):
		return i.accent(alpha)
	return Color(RED.r, RED.g, RED.b, alpha)


static func blood_visible() -> bool:
	var i := ink()
	if (i != null):
		return i.blood_visible()
	return true


static func is_theory() -> bool:
	var i := ink()
	if (i != null):
		return i.is_theory()
	return true


static func _tint(key: String, alpha: float) -> Color:
	if (ALPHA.has(key)):
		return accent(alpha * ALPHA[key])
	if (key.begins_with("masks/blood")):
		return accent(alpha)
	return Color(1.0, 1.0, 1.0, alpha)


## Centred sprite in metres. `scale_f` multiplies the 80 px/m -> 40 px/m base.
static func make(key: String, at_m: Vector2, rot := 0.0, scale_f := 1.0, alpha := 1.0,
		tint := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(key)
	s.position = at_m * PX
	s.rotation = rot
	s.scale = Vector2.ONE * (SVG_SCALE * scale_f)
	s.modulate = _tint(key, alpha) if tint else Color(1.0, 1.0, 1.0, alpha)
	s.name = key.get_file().get_basename()
	return s


## A red-mask sprite: blood, routes, rings, beacons, stamps. Blood obeys the gore
## toggle; the markers that frame it never do.
static func make_blob(key: String, at_m: Vector2, rot := 0.0, scale_f := 1.0,
		alpha := 1.0) -> Sprite2D:
	return make(key, at_m, rot, scale_f, alpha, true)


## Top-left tile placement, in cell coordinates: cell (3, 2) is 3 m right and 2 m
## down from the room's top-left corner.
static func add_tile(parent: Node2D, key: String, cell: Vector2, rot := 0.0,
		scale_f := 1.0) -> Sprite2D:
	var s := make(key, cell, rot, scale_f, 1.0, false)
	s.centered = false
	s.position = cell * PX
	parent.add_child(s)
	return s


## Add a blood sprite unless gore is off. Returns null when nothing was added.
static func add_blood(parent: Node2D, key: String, at_m: Vector2, rot := 0.0,
		scale_f := 1.0, alpha := 1.0) -> Sprite2D:
	if (not blood_visible()):
		return null
	var s := make_blob(key, at_m, rot, scale_f, alpha)
	parent.add_child(s)
	return s
