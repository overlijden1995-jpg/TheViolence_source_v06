extends Node2D
## One city lot: its building template drawn as a floor plan in the template's own frame,
## turned and placed by this node's transform. Room lettering is drawn upright by the
## city's label layer instead, and tree canopies by the canopy layer.

const FloorPlan = preload("res://scripts/view/floor_plan.gd")
const Decals = preload("res://scripts/view/decals.gd")
const PX := 40.0

var tpl_level
var lot: Dictionary = {}


func setup(lv_city, lot_rec: Dictionary) -> void:
	lot = lot_rec
	tpl_level = lot["tpl"]["lv"]
	var k: int = lot["k"]
	var W: float = tpl_level.W
	var H: float = tpl_level.H
	var off: Vector2 = [Vector2.ZERO, Vector2(H, 0), Vector2(W, H), Vector2(0, W)][k]
	position = ((lot["origin"] as Vector2) + off) * PX
	rotation = k * PI / 2.0
	queue_redraw()


func _draw() -> void:
	if tpl_level == null:
		return
	var font: Font = ThemeDB.fallback_font
	# yard ground, then the plan
	draw_rect(Rect2(0, 0, tpl_level.W * PX, tpl_level.H * PX), Color("#f6f6f4"))
	FloorPlan.paint_site(self, tpl_level, font)
	for pr in tpl_level.props:
		if pr.get("under", false):
			continue
		var tex: Texture2D = Decals.tex(pr["key"])
		var r: Rect2 = pr["r"]
		var rot: float = pr["rot"]
		var want: Vector2 = r.size * PX
		if int(rot) % 180 != 0:
			want = Vector2(want.y, want.x)
		draw_set_transform(r.get_center() * PX, deg_to_rad(rot))
		draw_texture_rect(tex, Rect2(-want / 2.0, want), false)
	draw_set_transform(Vector2.ZERO, 0.0)
