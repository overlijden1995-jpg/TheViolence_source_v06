extends "res://scripts/sim/level.gd"
## Map 05, Duplex: two mirrored units sharing a party wall, joined by one kitchen door.
## Twelve rooms, six outside doors, two halls. Two elements can work the two units in
## parallel, or one can be drawn through the party-wall door into the other.

const MID := 22.0   # party wall


func _init() -> void:
	id = "m05"
	map_name = "Duplex"
	title = "THE VIOLENCE  -  05 DUPLEX"
	notes = ["TWO MIRRORED UNITS, 6 ROOMS EACH, 20 x 13 m", "PARTY-WALL DOOR, FRONT AND BACK YARDS  ·  1 SQUARE = 1 m", "MAP 05  ·  SHEET 6 OF 11"]
	W = 44.0
	H = 30.0
	time_limit = 420.0
	default_sizes = [8, 10]
	stage_hint = "Team A comes from the street and the back lane; team B holds both units."


## Mirror a west-unit x coordinate or rectangle into the east unit.
func _mx(x: float, east: bool) -> float:
	return 2.0 * MID - x if east else x


func _mr(r: Rect2, east: bool) -> Rect2:
	if not east:
		return r
	return Rect2(2.0 * MID - r.end.x, r.position.y, r.size.x, r.size.y)


func _build() -> void:
	for east in [false, true]:
		var u := "E " if east else "W "
		_room(u + "LIVING", "LIVING", [_mr(Rect2(12, 15, 6, 6), east)])
		_room(u + "KITCHEN", "KITCHEN", [_mr(Rect2(18, 15, 4, 6), east)])
		_room(u + "BED1", "BEDROOM", [_mr(Rect2(12, 8, 4, 7), east)])
		_room(u + "HALL", "HALL", [_mr(Rect2(16, 8, 2, 7), east), _mr(Rect2(18, 12, 1.5, 3), east)],
			{"hall": true, "label": Vector2(_mx(17, east), 10.5)})
		_room(u + "BED2", "BEDROOM", [_mr(Rect2(18, 8, 4, 4), east)])
		_room(u + "BATH", "BATH", [_mr(Rect2(19.5, 12, 2.5, 3), east)])
		_room(u + "PORCH", "PORCH", [_mr(Rect2(13.5, 21, 3, 1.6), east)], {"deck": true})
		_door(_mx(15, east), 21, 0.9, {"id": u + "FRONT"})
		_door(_mx(20.5, east), 21, 0.9, {"id": u + "SIDE"})
		_door(_mx(17, east), 8, 0.9, {"id": u + "REAR"})
		_door(_mx(18, east), 18, 1.6, {"arch": true})
		_door(_mx(17, east), 15, 0.9)
		_door(_mx(16, east), 11.5, 0.9)
		_door(_mx(18, east), 10, 0.9)
		_door(_mx(19.5, east), 13.5, 0.9)
		_window(_mx(12, east), 11.5, 1.2)
		_window(_mx(14, east), 8, 1.2)
		_window(_mx(20, east), 8, 1.2)
		_window(_mx(12, east), 18, 1.2)
		_window(_mx(13, east), 21, 1.2)
		_window(_mx(17, east), 21, 1.2)
		_window(_mx(19, east), 21, 1.0)
	_door(MID, 18, 0.9, {"id": "PARTY"})
	_auto_walls()
	for east in [false, true]:
		# porch rails and steps, rear step
		var px := _mx(13.5, east) if not east else _mx(16.5, east)
		_prop("", Rect2(px - 0.04, 21.12, 0.08, 1.48), Geom.CONCEAL, 0.95, 0.0, "porch rail")
		_prop("", Rect2(px + 2.96, 21.12, 0.08, 1.48), Geom.CONCEAL, 0.95, 0.0, "porch rail")
		_prop("", Rect2(px, 22.56, 1.0, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
		_prop("", Rect2(px + 2.0, 22.56, 1.0, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
		_decor("steps", {"r": Rect2(px + 1.0, 22.64, 1.0, 0.6), "n": 3, "axis": "h"})
		_decor("rect", {"r": Rect2(_mx(17, east) - 0.5, 7.3, 1.0, 0.58)})
		_decor("rect", {"r": Rect2(_mx(20.5, east) - 0.5, 21.12, 1.0, 0.5)})
		# living
		_p("furn/sofa", _mx(12.3, east) - (0.85 if east else 0.0), 16.0, 0.85, 2.2, Geom.CONCEAL, 0.85, 90.0)
		_p("furn/coffee_table", _mx(13.5, east) - (0.6 if east else 0.0), 16.6, 0.6, 1.2, Geom.LOW, 0.45, 90.0)
		_p("furn/armchair", _mx(16.7, east) - (0.85 if east else 0.0), 19.8, 0.85, 0.85, Geom.CONCEAL, 0.85)
		_p("furn/dresser", _mx(13.2, east) - (1.2 if east else 0.0), 15.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "TV cabinet")
		# kitchen
		_p("furn/counter", _mx(21.3, east) - (0.6 if east else 0.0), 15.3, 0.6, 1.6, Geom.COVER, 0.92, 90.0, "counter")
		_p("furn/fridge", _mx(18.2, east) - (0.7 if east else 0.0), 15.2, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
		_p("furn/dining", _mx(19.2, east) - (1.1 if east else 0.0), 18.4, 1.1, 0.8, Geom.LOW, 0.75)
		# bedrooms and bath
		_p("furn/bed", _mx(12.3, east) - (2.0 if east else 0.0), 12.6, 2.0, 1.6, Geom.CONCEAL, 0.6)
		_p("furn/dresser", _mx(14.5, east) - (1.2 if east else 0.0), 8.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
		_p("furn/wardrobe", _mx(15.4, east) - (0.5 if east else 0.0), 13.2, 0.5, 1.2, Geom.COVER, 2.0, 90.0, "wardrobe")
		_p("furn/bed", _mx(19.8, east) - (2.0 if east else 0.0), 8.3, 2.0, 1.4, Geom.CONCEAL, 0.6)
		_p("furn/tub", _mx(20.2, east) - (1.6 if east else 0.0), 12.2, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "tub")
		_p("furn/toilet", _mx(21.3, east) - (0.5 if east else 0.0), 14.1, 0.5, 0.65, Geom.LOW, 0.4)
	# yards: chain-link between the back yards, a hedge between the front yards
	_prop("", Rect2(MID - 0.05, 0.12, 0.1, 7.6), Geom.CONCEAL, 1.2, 0.0, "chain-link")
	_p("yard/hedge", MID - 0.4, 23.2, 0.8, 3.6, Geom.CONCEAL, 1.0, 0.0, "hedge")
	_p("yard/car", 4.0, 19.5, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/car", 38.1, 19.5, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_decor("dash_rect", {"r": Rect2(3.4, 14.0, 3.2, 15.9)})
	_decor("dash_rect", {"r": Rect2(37.4, 14.0, 3.2, 15.9)})
	_p("yard/picnic", 14.0, 3.0, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/drum", 29.8, 3.4, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "barbecue")
	_p("yard/woodpile", 25.5, 1.8, 2.0, 0.8, Geom.COVER, 1.1, 0.0, "woodpile")
	_p("yard/shed", 2.0, 1.5, 3.5, 3.0, Geom.WALL, 2.4, 0.0, "shed")
	_p("yard/bins", 10.6, 21.6, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("yard/bins", 32.6, 21.6, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("yard/low_wall", 12.5, 25.2, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/low_wall", 28.5, 25.2, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/ac_unit", 11.2, 9.0, 0.6, 0.8, Geom.COVER, 0.9, 90.0, "AC unit")
	_trunk(Vector2(7, 5), 4.2)
	_trunk(Vector2(37, 5), 4.2)
	_trunk(Vector2(7.5, 11.5), 3.4)
	_trunk(Vector2(36.5, 11.5), 3.4)
	stage_a = [{"r": Rect2(8.0, 26.4, 12.0, 3.3), "face": -PI / 2.0}, {"r": Rect2(24.0, 26.4, 12.0, 3.3), "face": -PI / 2.0},
		{"r": Rect2(15.0, 0.4, 14.0, 1.8), "face": PI / 2.0}]
