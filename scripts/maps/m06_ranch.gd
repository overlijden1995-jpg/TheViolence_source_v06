extends "res://scripts/sim/level.gd"
## Map 06, L-Shaped Ranch: a garage, an open great room that must be swept, a kitchen
## core with pantry and laundry, and a long bedroom hall down the wing. Patio doors and
## a pool out back. Thirteen rooms, six ways in.


func _init() -> void:
	id = "m06"
	map_name = "L-Shaped Ranch"
	title = "THE VIOLENCE  -  06 L-SHAPED RANCH"
	notes = ["RANCH HOUSE, GARAGE, 13 ROOMS, 32 x 18 m", "STREET FRONT, PATIO AND POOL  ·  1 SQUARE = 1 m", "MAP 06  ·  SHEET 7 OF 11"]
	W = 48.0
	H = 34.0
	time_limit = 480.0
	default_sizes = [10, 10]
	fenced = false
	stage_hint = "Team A comes off the street and round the east side; team B holds the ranch."


func _build() -> void:
	_room("GARAGE", "GARAGE", [Rect2(4, 10, 8, 8)])
	_room("GREAT", "GREAT ROOM", [Rect2(12, 10, 10, 8)])
	_room("PANTRY", "PANTRY", [Rect2(22, 10, 3, 3)])
	_room("LAUNDRY", "LAUNDRY", [Rect2(25, 10, 3, 3)])
	_room("KITCHEN", "KITCHEN", [Rect2(22, 13, 6, 5)])
	_room("HALL", "HALL", [Rect2(28, 10, 2, 18)], {"hall": true, "label": Vector2(29, 22.5)})
	_room("MASTER", "MASTER BED", [Rect2(30, 10, 6, 5)])
	_room("ENSUITE", "ENSUITE", [Rect2(30, 15, 6, 3)])
	_room("BATH", "BATH", [Rect2(22, 18, 6, 3)])
	_room("DEN", "DEN", [Rect2(22, 21, 6, 7)])
	_room("BED2", "BEDROOM", [Rect2(30, 18, 6, 5)])
	_room("BED3", "BEDROOM", [Rect2(30, 23, 6, 5)])
	_room("PORCH", "PORCH", [Rect2(15, 8.2, 4, 1.8)], {"deck": true})
	_room("PATIO", "PATIO", [Rect2(13, 18, 8, 3.5)], {"deck": true})
	_door(17, 10, 1.0, {"id": "FRONT"})
	_door(8, 10, 3.0, {"id": "GARAGE DOOR", "arch": true})
	_door(4, 14, 0.9, {"id": "GARAGE SIDE"})
	_door(12, 15.5, 0.9)
	_door(22, 15.5, 2.0, {"arch": true})
	_door(23.5, 13, 0.9)
	_door(26.5, 13, 0.9)
	_door(26.5, 10, 0.9, {"id": "LAUNDRY DOOR"})
	_door(28, 15.5, 0.9)
	_door(30, 12.5, 0.9)
	_door(33, 15, 0.9)
	_door(28, 19.5, 0.9)
	_door(28, 24.5, 0.9)
	_door(30, 20.5, 0.9)
	_door(30, 25.5, 0.9)
	_door(29, 28, 0.9, {"id": "HALL DOOR"})
	_door(17, 18, 1.8, {"id": "PATIO DOOR"})
	_door(22, 24.5, 1.6, {"id": "DEN DOOR"})
	for w in [[8, 18, 1.2], [13.5, 10, 1.4], [20.5, 10, 1.4], [14.0, 18, 1.4], [20.2, 18, 1.0], [33, 10, 1.4],
			[33, 28, 1.2], [25, 28, 1.4]]:
		_window(w[0], w[1], w[2])
	for v in [[4, 11.5, 1.0], [36, 12.5, 1.2], [36, 16.5, 0.8], [36, 20.5, 1.2], [36, 25.5, 1.2], [22, 22.2, 1.0], [22, 19.5, 0.8]]:
		_window(v[0], v[1], v[2])
	_auto_walls()
	# garage
	_p("yard/car", 5.0, 11.5, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("furn/table", 9.4, 17.15, 2.0, 0.6, Geom.LOW, 0.9)
	_p("furn/rack", 4.25, 16.5, 3.0, 0.9, Geom.COVER, 2.0, 0.0, "shelving")
	_p("yard/drum", 10.9, 10.4, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "drum")
	# great room
	_p("furn/sofa", 13.5, 12.5, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/armchair", 16.2, 12.5, 0.85, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/coffee_table", 14.0, 13.8, 1.2, 0.6, Geom.LOW, 0.45)
	_p("furn/dining", 18.5, 14.5, 1.6, 1.2, Geom.LOW, 0.75)
	_p("furn/bookshelf", 12.25, 16.0, 0.4, 1.6, Geom.CONCEAL, 1.8, 90.0, "bookshelf")
	_p("furn/dresser", 20.4, 10.3, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "sideboard")
	# kitchen core
	_p("furn/counter", 22.4, 17.2, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "counter")
	_p("furn/stove", 24.2, 17.2, 0.7, 0.65, Geom.COVER, 0.9, 0.0, "stove")
	_p("furn/fridge", 25.1, 17.15, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	_p("furn/counter", 24.0, 14.6, 1.6, 0.8, Geom.COVER, 0.92, 0.0, "island")
	_p("furn/shelving", 22.2, 10.2, 2.6, 0.6, Geom.CONCEAL, 1.8, 0.0, "shelving")
	_p("furn/washer", 27.2, 10.3, 0.65, 0.65, Geom.COVER, 0.9, 0.0, "washer")
	_p("furn/washer", 27.2, 11.0, 0.65, 0.65, Geom.COVER, 0.9, 0.0, "dryer")
	# master and ensuite
	_p("furn/bed", 32.5, 10.3, 2.0, 1.6, Geom.CONCEAL, 0.6)
	_p("furn/dresser", 30.3, 14.3, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
	_p("furn/wardrobe", 35.3, 13.4, 0.5, 1.2, Geom.COVER, 2.0, 90.0, "wardrobe")
	_p("furn/tub", 34.2, 15.2, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "tub")
	_p("furn/toilet", 31.0, 17.2, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/basin", 32.5, 17.4, 0.55, 0.42, Geom.LOW, 0.85)
	# bath, den, bedrooms
	_p("furn/tub", 24.0, 20.1, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "tub")
	_p("furn/toilet", 22.3, 18.3, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/sofa", 25.5, 27.0, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/desk", 22.4, 21.3, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/bookshelf", 26.0, 21.2, 1.6, 0.4, Geom.CONCEAL, 1.8, 0.0, "bookshelf")
	_p("furn/armchair", 23.0, 26.8, 0.85, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/bed", 32.0, 21.2, 2.0, 1.6, Geom.CONCEAL, 0.6)
	_p("furn/dresser", 34.6, 18.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
	_p("furn/bed", 32.0, 23.3, 2.0, 1.6, Geom.CONCEAL, 0.6)
	_p("furn/dresser", 34.6, 27.3, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "dresser")
	# porch rails
	_prop("", Rect2(14.96, 8.2, 0.08, 1.68), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(18.96, 8.2, 0.08, 1.68), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	# street, drive, walk
	_decor("road", {"r": Rect2(0, 0, 48, 5.6), "axis": "h"})
	_decor("dash_rect", {"r": Rect2(5.5, 5.6, 5.0, 4.3)})
	_decor("dash_rect", {"r": Rect2(16.4, 5.6, 1.2, 2.6)})
	_decor("text", {"p": Vector2(0.4, 5.2), "text": "ROAD"})
	_p("yard/car", 9.6, 5.7, 1.9, 4.1, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/car", 30.0, 0.9, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/hedge", 30.0, 6.6, 3.6, 0.8, Geom.CONCEAL, 1.5, 90.0, "hedge")
	_p("yard/hedge", 44.0, 14.0, 0.8, 3.6, Geom.CONCEAL, 1.7, 0.0, "hedge")
	_trunk(Vector2(25, 7.6), 4.0)
	_trunk(Vector2(40, 7.0), 4.2)
	# back yard: patio, pool, shed
	_p("yard/drum", 20.0, 19.5, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "barbecue")
	_p("yard/picnic", 14.0, 19.2, 1.8, 1.6, Geom.LOW, 0.75)
	_pool(Rect2(8, 24, 8, 4))
	_p("yard/shed", 2.5, 29.0, 3.5, 3.0, Geom.WALL, 2.4, 0.0, "shed")
	_p("yard/ac_unit", 36.15, 17.2, 0.6, 0.8, Geom.COVER, 0.9, 90.0, "AC unit")
	_p("yard/woodpile", 39.0, 24.0, 0.8, 2.0, Geom.COVER, 1.1, 90.0, "woodpile")
	_p("yard/low_wall", 30.0, 31.0, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/bench", 18.0, 25.0, 1.6, 0.5, Geom.LOW, 0.45)
	_trunk(Vector2(19, 30.5), 4.0)
	_trunk(Vector2(4, 22), 3.6)
	_trunk(Vector2(42, 30), 4.0)
	# property fence round the back and sides, open to the street
	_vwall(5.6, 34.0, 0.06, 0.12, [], "fence")
	_vwall(5.6, 34.0, 47.94, 0.12, [], "fence")
	_hwall(0.0, 48.0, 33.94, 0.12, [], "fence")
	stage_a = [{"r": Rect2(1.0, 0.5, 21.0, 4.6), "face": PI / 2.0}, {"r": Rect2(26.0, 0.5, 21.0, 4.6), "face": PI / 2.0},
		{"r": Rect2(41.5, 18.0, 6.0, 12.0), "face": PI}]
