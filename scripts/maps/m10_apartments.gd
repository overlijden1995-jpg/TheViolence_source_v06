extends "res://scripts/sim/level.gd"
## Map 10, Apartment Block: the ground floor of a block, eight flats of five rooms off one
## 44 m corridor, a stair hall with a street door at each end. Forty-three rooms; the
## corridor is one long fatal funnel and every flat is a separate clearance.

const XS := [8.0, 19.0, 30.0, 41.0]


func _init() -> void:
	id = "m10"
	map_name = "Apartment Block"
	title = "THE VIOLENCE  -  10 APARTMENT BLOCK"
	notes = ["GROUND FLOOR, 8 FLATS, 2 STAIR HALLS, 52 x 22.5 m", "44 m CORRIDOR, COURTYARD, STREET  ·  1 SQUARE = 1 m", "MAP 10  ·  SHEET 11 OF 11"]
	W = 60.0
	H = 36.0
	time_limit = 600.0
	default_sizes = [20, 20]
	fenced = false
	stage_hint = "Team A comes at both stair halls and from the street; team B holds the flats."


## Flats on the south side mirror the north ones about the corridor's centre line.
func _my(y: float, south: bool) -> float:
	return 34.5 - y if south else y


func _ry(r: Rect2, south: bool) -> Rect2:
	if not south:
		return r
	return Rect2(r.position.x, 34.5 - r.end.y, r.size.x, r.size.y)


func _build() -> void:
	_room("STAIR W", "STAIRS", [Rect2(4, 14, 4, 7)], {"hall": true, "label": Vector2(6.6, 20.3)})
	_room("STAIR E", "STAIRS", [Rect2(52, 14, 4, 7)], {"hall": true, "label": Vector2(53.4, 20.3)})
	_room("CORRIDOR", "CORRIDOR", [Rect2(8, 16, 44, 2.5)], {"hall": true})
	_door(4, 17.5, 1.2, {"id": "WEST DOOR"})
	_door(56, 17.5, 1.2, {"id": "EAST DOOR"})
	_door(8, 17.25, 1.0)
	_door(52, 17.25, 1.0)
	var n := 0
	for south in [false, true]:
		for x in XS:
			n += 1
			var u := "%d " % n
			_room(u + "LIVING", "FLAT %d" % n, [_ry(Rect2(x, 10, 7, 6), south)])
			_room(u + "KITCHEN", "KITCHEN", [_ry(Rect2(x + 7, 10, 4, 6), south)])
			_room(u + "BED", "BED", [_ry(Rect2(x, 6, 5, 4), south)])
			_room(u + "BATH", "BATH", [_ry(Rect2(x + 5, 6, 2.5, 4), south)])
			_room(u + "STUDY", "STUDY", [_ry(Rect2(x + 7.5, 6, 3.5, 4), south)])
			_door(x + 2, _my(16, south), 0.9, {"id": "FLAT %d" % n})
			_door(x + 7, _my(13, south), 1.4, {"arch": true})
			_door(x + 2.5, _my(10, south), 0.9)
			_door(x + 6.25, _my(10, south), 0.9)
			_door(x + 9.25, _my(10, south), 0.9)
			_window(x + 2.5, _my(6, south), 1.2)
			_window(x + 6.25, _my(6, south), 0.6)
			_window(x + 9.25, _my(6, south), 1.2)
	for south2 in [false, true]:
		_window(8, _my(12, south2), 1.2)
		_window(8, _my(8, south2), 1.0)
		_window(52, _my(12, south2), 1.2)
		_window(52, _my(8, south2), 1.0)
	_auto_walls()
	# stairs
	for sx in [4.25, 54.45]:
		_p("furn/stairs", sx, 14.2, 1.3, 2.5, Geom.COVER, 1.2, 0.0, "stair flight")
		_p("furn/stairs", sx, 18.3, 1.3, 2.5, Geom.COVER, 1.2, 180.0, "stair flight")
	# flats
	for south in [false, true]:
		for x in XS:
			var dy := func(y: float, h: float) -> float: return 34.5 - y - h if south else y
			_p("furn/sofa", x + 0.2, dy.call(11.5, 2.2), 0.85, 2.2, Geom.CONCEAL, 0.85, 90.0)
			_p("furn/coffee_table", x + 1.6, dy.call(12.0, 1.2), 0.6, 1.2, Geom.LOW, 0.45, 90.0)
			_p("furn/dresser", x + 4.0, dy.call(15.3, 0.5), 1.2, 0.5, Geom.COVER, 1.0, 0.0, "TV cabinet")
			_p("furn/armchair", x + 4.5, dy.call(11.0, 0.85), 0.85, 0.85, Geom.CONCEAL, 0.85)
			_p("furn/bookshelf", x + 6.5, dy.call(14.2, 1.6), 0.4, 1.6, Geom.CONCEAL, 1.8, 90.0, "bookshelf")
			_p("furn/counter", x + 10.3, dy.call(11.4, 1.6), 0.6, 1.6, Geom.COVER, 0.92, 90.0, "counter")
			_p("furn/stove", x + 10.25, dy.call(13.1, 0.7), 0.65, 0.7, Geom.COVER, 0.9, 90.0, "stove")
			_p("furn/fridge", x + 10.2, dy.call(15.15, 0.7), 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
			_p("furn/dining", x + 7.8, dy.call(14.2, 0.8), 1.1, 0.8, Geom.LOW, 0.75)
			_p("furn/bed", x + 0.3, dy.call(6.3, 1.6), 2.0, 1.6, Geom.CONCEAL, 0.6)
			_p("furn/wardrobe", x + 4.2, dy.call(6.3, 1.2), 0.5, 1.2, Geom.COVER, 2.0, 90.0, "wardrobe")
			_p("furn/tub", x + 5.2, dy.call(6.2, 1.6), 0.72, 1.6, Geom.COVER, 0.55, 90.0, "tub")
			_p("furn/toilet", x + 6.8, dy.call(6.3, 0.65), 0.5, 0.65, Geom.LOW, 0.4)
			_p("furn/desk", x + 8.0, dy.call(6.3, 0.7), 1.4, 0.7, Geom.CONCEAL, 0.75)
			_p("furn/bookshelf", x + 10.4, dy.call(7.0, 1.6), 0.4, 1.6, Geom.CONCEAL, 1.8, 90.0, "bookshelf")
	# courtyard (north) and street (south)
	_p("yard/bins", 10.0, 2.0, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("yard/bins", 48.0, 2.0, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("yard/dumpster", 30.0, 1.5, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/bench", 22.0, 3.0, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/bench", 36.0, 3.0, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/planter", 26.0, 3.6, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 33.0, 3.6, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_trunk(Vector2(17, 3), 3.4)
	_trunk(Vector2(43, 3), 3.4)
	_decor("road", {"r": Rect2(0, 31.4, 60, 4.6), "axis": "h"})
	_decor("dash_rect", {"r": Rect2(0.3, 28.9, 59.4, 2.4)})
	_decor("text", {"p": Vector2(0.4, 35.6), "text": "STREET"})
	_p("yard/car", 10.0, 31.6, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/car", 22.0, 31.6, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/car", 36.0, 31.6, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/van", 46.0, 31.5, 5.0, 2.0, Geom.COVER, 1.9, 0.0, "van")
	_p("yard/planter", 2.0, 29.6, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 56.8, 29.6, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	stage_a = [{"r": Rect2(0.3, 7.0, 3.4, 22.0), "face": 0.0}, {"r": Rect2(56.3, 7.0, 3.4, 22.0), "face": PI},
		{"r": Rect2(12.0, 33.6, 36.0, 2.2), "face": -PI / 2.0}]
