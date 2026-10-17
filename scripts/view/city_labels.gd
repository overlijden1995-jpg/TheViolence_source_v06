extends Node2D
## Lettering for the city, always upright and sized for the zoom: neighbourhood names and
## their dominant gang from far out, street names and building addresses closer in, room
## names close up. Only what is on screen is drawn.

const FloorPlan = preload("res://scripts/view/floor_plan.gd")
const Palette = preload("res://scripts/view/palette.gd")
const PX := 40.0

var lv
var director
var view := Rect2()
var zoom := 1.0
var show_rooms := true


func setup(level, dir) -> void:
	lv = level
	director = dir


func update_view(r: Rect2, z: float) -> void:
	view = r
	zoom = z
	queue_redraw()


func _draw() -> void:
	if lv == null:
		return
	var font: Font = ThemeDB.fallback_font
	var inv := 1.0 / maxf(zoom, 0.01)
	var vr := view.grow(200.0)
	# neighbourhoods: name, dominant gang, share
	if zoom < 0.22:
		for h in lv.hoods:
			var c: Vector2 = h["centre"] * PX
			if not vr.has_point(c):
				continue
			var fs := int(clampf(24.0 * inv, 18.0, 1400.0))
			var nm: String = FloorPlan._spaced(h["name"].to_upper())
			var wsz := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var who := "unclaimed"
			var col := Color("#555555")
			var ow: int = h.get("owner", -1)
			if ow > 0 and director != null:
				who = "%s  %d%%" % [director.w.factions[ow]["name"], int(round(h.get("dominance", 0.0) * 100.0))]
				col = Palette.faction(ow).darkened(0.25)
			draw_string(font, c + Vector2(-wsz / 2.0 + 3, 3), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.8))
			draw_string(font, c + Vector2(-wsz / 2.0, 0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#1c1c1c"))
			var fs2 := int(fs * 0.62)
			var w2 := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			draw_string(font, c + Vector2(-w2 / 2.0, fs * 0.9), who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, col)
	# streets
	if zoom >= 0.06:
		var fs3 := int(clampf(12.0 * inv, 12.0, 120.0))
		for iy in lv.NROWS + 1:
			var yc: float = lv.node_pos(0, iy).y
			for bx in lv.NCOLS:
				var p: Vector2 = Vector2((lv.node_pos(bx, iy).x + lv.node_pos(bx + 1, iy).x) / 2.0, yc) * PX
				if vr.has_point(p):
					var t: String = lv.STREETS_H[iy].to_upper()
					var ww := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
					draw_string(font, p + Vector2(-ww / 2.0, fs3 * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Color("#8a8a86"))
		for ix in lv.NCOLS + 1:
			var xc: float = lv.node_pos(ix, 0).x
			for by in lv.NROWS:
				var p2: Vector2 = Vector2(xc, (lv.node_pos(ix, by).y + lv.node_pos(ix, by + 1).y) / 2.0) * PX
				if vr.has_point(p2):
					var t2: String = lv.STREETS_V[ix].to_upper()
					var ww2 := font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
					draw_set_transform(p2, PI / 2.0)
					draw_string(font, Vector2(-ww2 / 2.0, fs3 * 0.35), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Color("#8a8a86"))
					draw_set_transform(Vector2.ZERO, 0.0)
	# buildings: kind and address
	if zoom >= 0.07 and zoom < 0.6:
		var fs4 := int(clampf(11.0 * inv, 11.0, 60.0))
		for lot in lv.lots:
			var g: Vector2 = lot["gate_in"]
			var lr: Rect2 = lot["rect"]
			var p3 := Vector2(lr.get_center().x, g.y + (-1.6 if lot["side"] == 1 else 1.6)) * PX
			if not vr.has_point(p3):
				continue
			var t3 := "%s  ·  %s" % [lot["tpl"]["name"].to_upper(), lot["address"]]
			var ww3 := font.get_string_size(t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4).x
			draw_string(font, p3 + Vector2(-ww3 / 2.0, fs4 * (0.9 if lot["side"] == 0 else 0.0)), t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4, Color("#555555"))
	# rooms
	if zoom >= 0.3 and show_rooms:
		for name in lv.rooms:
			var rm: Dictionary = lv.rooms[name]
			if rm["exterior"] or rm["title"] == "":
				continue
			var c2: Vector2 = rm["label"] * PX
			if not view.has_point(c2):
				continue
			var area: float = rm["area"]
			var fs5 := 8 if area < 8.0 else (9 if area < 20.0 else (10 if area < 50.0 else (11 if area < 150.0 else 13)))
			FloorPlan._label(self, font, c2, FloorPlan._spaced(rm["title"]), fs5, Color("#3a3a3a"))
