extends "res://scripts/sim/level.gd"
## Map 04, Center-Hall Bungalow: a long hall down the middle with rooms off both sides,
## a bathroom and a laundry off the back rooms, and four ways in. The first map where
## clearing order matters and small rooms must be checked.


func _init() -> void:
	id = "m04"
	map_name = "Center-Hall Bungalow"
	title = "THE VIOLENCE  -  04 CENTER-HALL BUNGALOW"
	notes = ["CENTRE HALL, 4 ROOMS, BATH, LAUNDRY, 16 x 12 m", "FENCED LOT, DRIVEWAY, SHED  ·  1 SQUARE = 1 m", "MAP 04  ·  SHEET 5 OF 11"]
	W = 40.0
	H = 28.0
	time_limit = 360.0
	default_sizes = [6, 8]
	stage_hint = "Team A comes from the street and the east lane; team B holds the bungalow."


func _build() -> void:
	_room("HALL", "HALL", [Rect2(19, 8, 2, 12)], {"hall": true, "label": Vector2(20, 14.5)})
	_room("BED1", "BEDROOM", [Rect2(12, 8, 7, 5)])
	_room("LIVING", "LIVING ROOM", [Rect2(12, 13, 7, 7)])
	_room("BED2", "BEDROOM", [Rect2(21, 8, 4, 5)], {"label": Vector2(23, 10.4)})
	_room("BATH", "BATH", [Rect2(25, 8, 3, 2.5)])
	_room("LAUNDRY", "LAUNDRY", [Rect2(25, 10.5, 3, 2.5)])
	_room("KITCHEN", "KITCHEN", [Rect2(21, 13, 7, 7)], {"label": Vector2(24.5, 18.6)})
	_room("PORCH", "PORCH", [Rect2(18, 20, 4, 1.8)], {"deck": true})
	_door(20, 20, 1.0, {"id": "FRONT"})
	_door(20, 8, 0.9, {"id": "REAR"})
	_door(28, 11.75, 0.9, {"id": "SIDE"})
	_door(28, 17.5, 0.9, {"id": "KBACK"})
	_door(19, 10.5, 0.9)
	_door(19, 16.5, 1.4, {"arch": true})
	_door(21, 10.5, 0.9)
	_door(21, 16.5, 0.9)
	_door(25, 9.25, 0.9)
	_door(26.5, 13, 0.9)
	_window(14, 8, 1.2)
	_window(17, 8, 1.2)
	_window(12, 10.5, 1.2)
	_window(12, 15, 1.2)
	_window(12, 18, 1.2)
	_window(14.5, 20, 1.6)
	_window(23, 8, 1.2)
	_window(26.5, 8, 0.6)
	_window(23.5, 20, 1.2)
	_window(26.5, 20, 1.0)
	_window(28, 15, 1.0)
	_auto_walls()
	# porch
	_prop("", Rect2(17.96, 20.12, 0.08, 1.68), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(21.96, 20.12, 0.08, 1.68), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(18.0, 21.76, 1.5, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(20.5, 21.76, 1.5, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	for c in [Vector2(18, 21.8), Vector2(22, 21.8)]:
		_wall(Rect2(c - Vector2(0.09, 0.09), Vector2(0.18, 0.18)), "porch post")
	_decor("steps", {"r": Rect2(19.5, 21.84, 1.0, 0.6), "n": 3, "axis": "h"})
	_decor("rect", {"r": Rect2(19.5, 7.3, 1.0, 0.58)})
	# bedroom 1
	_p("furn/bed", 12.3, 8.3, 2.0, 1.6, Geom.CONCEAL, 0.6)
	_p("furn/dresser", 15.8, 8.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
	_p("furn/wardrobe", 16.5, 12.3, 1.2, 0.5, Geom.COVER, 2.0, 0.0, "wardrobe")
	# living room
	_p("furn/sofa", 13.0, 13.3, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/armchair", 12.3, 15.6, 0.85, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/coffee_table", 13.5, 14.8, 1.2, 0.6, Geom.LOW, 0.45)
	_p("furn/bookshelf", 16.0, 19.35, 1.6, 0.4, Geom.CONCEAL, 1.8, 0.0, "bookshelf")
	_p("furn/dresser", 16.8, 13.2, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "TV cabinet")
	# bedroom 2, bath, laundry
	_p("furn/bed", 22.4, 11.2, 2.0, 1.6, Geom.CONCEAL, 0.6)
	_p("furn/dresser", 21.2, 8.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
	_p("furn/tub", 26.2, 8.25, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "cast-iron tub")
	_p("furn/toilet", 27.25, 9.35, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/washer", 27.2, 10.62, 0.65, 0.62, Geom.COVER, 0.9, 0.0, "washer")
	_p("furn/washer", 25.2, 12.2, 0.65, 0.65, Geom.COVER, 0.9, 0.0, "dryer")
	# kitchen
	_p("furn/counter", 22.0, 13.2, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "counter")
	_p("furn/fridge", 23.7, 13.2, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	_p("furn/stove", 24.5, 13.2, 0.7, 0.65, Geom.COVER, 0.9, 0.0, "stove")
	_p("furn/dining", 23.5, 16.0, 1.6, 1.2, Geom.LOW, 0.75)
	# lot
	_decor("dash_rect", {"r": Rect2(3.6, 13.5, 3.4, 14.4)})
	_decor("dash_rect", {"r": Rect2(19.4, 22.5, 1.2, 5.4)})
	_p("yard/car", 4.3, 17.5, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/shed", 33.5, 10.5, 3.5, 3.0, Geom.WALL, 2.4, 0.0, "shed")
	_p("yard/picnic", 23.0, 3.5, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/low_wall", 13.0, 23.0, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/low_wall", 24.0, 23.0, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/hedge", 2.0, 2.0, 0.8, 3.6, Geom.CONCEAL, 1.7, 0.0, "hedge")
	_p("yard/hedge", 36.5, 18.0, 0.8, 3.6, Geom.CONCEAL, 1.7, 0.0, "hedge")
	_p("yard/bins", 29.0, 19.0, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("yard/ac_unit", 28.15, 13.6, 0.6, 0.8, Geom.COVER, 0.9, 90.0, "AC unit")
	_p("yard/woodpile", 30.5, 7.6, 2.0, 0.8, Geom.COVER, 1.1, 0.0, "woodpile")
	_p("yard/drum", 31.5, 20.5, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "oil drum")
	_trunk(Vector2(8, 4), 4.2)
	_trunk(Vector2(33, 4.5), 4.0)
	_trunk(Vector2(9, 23.5), 3.6)
	_trunk(Vector2(31, 24), 4.0)
	stage_a = [{"r": Rect2(13.0, 24.4, 14.0, 3.3), "face": -PI / 2.0}, {"r": Rect2(35.2, 13.0, 4.5, 9.0), "face": PI}]
