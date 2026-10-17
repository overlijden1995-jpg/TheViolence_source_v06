extends "res://scripts/sim/level.gd"
## Map 08, Warehouse & Offices: a 32 x 24 m racked warehouse with three dock doors and a
## roll-up, joined to a two-storey-deep office block (corridor, nine offices, washroom,
## store, conference room, reception). A huge open fight and a tight one side by side.


func _init() -> void:
	id = "m08"
	map_name = "Warehouse & Offices"
	title = "THE VIOLENCE  -  08 WAREHOUSE & OFFICES"
	notes = ["RACKED WAREHOUSE 32 x 24 m, OFFICE BLOCK 10 x 24 m", "TRUCK COURT, STAFF PARKING  ·  1 SQUARE = 1 m", "MAP 08  ·  SHEET 9 OF 11"]
	W = 64.0
	H = 44.0
	time_limit = 600.0
	default_sizes = [15, 15]
	stage_hint = "Team A comes from the truck court, the north road and the staff lot; team B holds the site."


func _build() -> void:
	_room("WAREHOUSE", "WAREHOUSE", [Rect2(14, 8, 32, 24)], {"label": Vector2(30, 19.3)})
	_room("OFFICE 1", "OFFICE", [Rect2(46, 8, 3, 4)])
	_room("OFFICE 2", "OFFICE", [Rect2(46, 12, 3, 4)])
	_room("OFFICE 3", "OFFICE", [Rect2(46, 16, 3, 4)])
	_room("WASHROOM", "WC", [Rect2(46, 20, 3, 3)])
	_room("STORE", "STORE", [Rect2(46, 23, 3, 3)])
	_room("CORRIDOR", "CORRIDOR", [Rect2(49, 8, 2, 18)], {"hall": true, "label": Vector2(50, 21)})
	_room("CONFERENCE", "CONFERENCE", [Rect2(51, 8, 5, 6)])
	_room("OFFICE 4", "OFFICE", [Rect2(51, 14, 5, 4)])
	_room("OFFICE 5", "OFFICE", [Rect2(51, 18, 5, 4)])
	_room("BREAK", "BREAK ROOM", [Rect2(51, 22, 5, 4)])
	_room("RECEPTION", "RECEPTION", [Rect2(46, 26, 10, 6)], {"label": Vector2(51, 30.3)})
	_door(14, 20, 0.9, {"id": "WEST DOOR"})
	_door(20, 32, 3.0, {"id": "DOCK 1", "arch": true})
	_door(26, 32, 3.0, {"id": "DOCK 2", "arch": true})
	_door(32, 32, 3.0, {"id": "DOCK 3", "arch": true})
	_door(30, 8, 3.5, {"id": "ROLL-UP", "arch": true})
	_door(46, 24.5, 0.9)
	_door(46, 29, 0.9)
	for y in [10.0, 14.0, 18.0, 21.5, 24.5]:
		_door(49, y, 0.9)
	for y2 in [11.0, 16.0, 20.0, 24.0]:
		_door(51, y2, 0.9)
	_door(50, 26, 1.4, {"arch": true})
	_door(50, 8, 0.9, {"id": "FIRE EXIT"})
	_door(51, 32, 1.6, {"id": "ENTRANCE"})
	_door(56, 29, 0.9, {"id": "RECEPTION SIDE"})
	_window(47.5, 8, 1.0)
	_window(53.5, 8, 1.6)
	_window(56, 11, 1.4)
	_window(56, 16, 1.2)
	_window(56, 20, 1.2)
	_window(56, 24, 1.2)
	_window(48, 32, 2.0)
	_window(54, 32, 2.0)
	_window(14, 12, 1.2)
	_window(14, 28, 1.2)
	_window(20, 8, 1.6)
	_window(40, 8, 1.6)
	_auto_walls()
	# racking: four rows, a cross aisle in the middle
	for y3 in [12.0, 16.5, 21.0, 25.5]:
		_p("furn/rack", 17.0, y3, 8.1, 1.1, Geom.COVER, 2.8, 0.0, "pallet rack")
		_p("furn/rack", 28.0, y3, 12.0, 1.1, Geom.COVER, 2.8, 0.0, "pallet rack")
	_p("yard/forklift", 34.0, 28.5, 2.6, 1.2, Geom.COVER, 1.6, 0.0, "forklift")
	_p("furn/pallet", 21.0, 28.4, 1.2, 1.0, Geom.COVER, 1.2, 0.0, "loaded pallet")
	_p("furn/pallet", 29.0, 28.6, 1.2, 1.0, Geom.COVER, 1.2, 0.0, "loaded pallet")
	_p("furn/pallet", 38.5, 29.5, 1.2, 1.0, Geom.COVER, 1.2, 0.0, "loaded pallet")
	_p("furn/crate", 41.5, 14.0, 1.2, 1.2, Geom.COVER, 1.2, 0.0, "crate")
	_p("furn/crate", 42.9, 14.0, 1.2, 1.2, Geom.COVER, 1.2, 0.0, "crate")
	_p("furn/crate", 41.5, 15.4, 1.2, 1.2, Geom.COVER, 1.2, 0.0, "crate")
	_p("furn/crate", 15.0, 9.0, 1.2, 1.2, Geom.COVER, 1.2, 0.0, "crate")
	_p("furn/table", 42.0, 9.0, 2.0, 0.8, Geom.LOW, 0.9)
	# offices
	for y4 in [8.0, 12.0, 16.0]:
		_p("furn/desk", 46.3, y4 + 0.4, 1.4, 0.7, Geom.CONCEAL, 0.75)
		_p("furn/cabinet", 46.3, y4 + 3.2, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "filing cabinet")
	for y5 in [14.0, 18.0]:
		_p("furn/desk", 54.3, y5 + 0.4, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/toilet", 46.3, 20.2, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/basin", 47.6, 22.35, 0.55, 0.42, Geom.LOW, 0.85)
	_p("furn/shelving", 46.2, 23.2, 2.6, 0.6, Geom.CONCEAL, 1.8, 0.0, "shelving")
	_p("furn/shelving", 46.2, 25.3, 2.6, 0.6, Geom.CONCEAL, 1.8, 0.0, "shelving")
	_p("furn/table", 52.2, 10.0, 2.6, 1.2, Geom.LOW, 0.75)
	_p("furn/dining", 52.5, 23.5, 1.6, 1.2, Geom.LOW, 0.75)
	_p("furn/fridge", 55.1, 22.2, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	_p("furn/checkout", 49.0, 27.6, 2.4, 0.8, Geom.COVER, 1.1, 0.0, "reception desk")
	_p("furn/sofa", 53.0, 30.9, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("yard/planter", 46.3, 30.5, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	# truck court
	_decor("dash_rect", {"r": Rect2(12.0, 32.2, 30.0, 11.5)})
	_p("yard/truck", 22.25, 33.0, 2.5, 7.5, Geom.COVER, 2.6, 90.0, "truck")
	_p("yard/container", 28.3, 33.5, 2.44, 6.1, Geom.WALL, 2.6, 90.0, "trailer")
	_p("yard/container", 36.0, 39.0, 6.1, 2.44, Geom.WALL, 2.6, 0.0, "trailer")
	_p("yard/container", 4.0, 37.0, 6.1, 2.44, Geom.WALL, 2.6, 0.0, "container")
	_p("yard/dumpster", 10.5, 30.0, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("furn/pallet", 10.0, 12.0, 1.2, 1.0, Geom.COVER, 1.0, 0.0, "pallet stack")
	_p("furn/pallet", 10.0, 13.4, 1.2, 1.0, Geom.COVER, 1.0, 0.0, "pallet stack")
	_p("yard/barrier", 4.0, 25.0, 3.0, 0.6, Geom.COVER, 0.8, 0.0, "jersey barrier")
	_p("yard/barrier", 47.0, 36.0, 3.0, 0.6, Geom.COVER, 0.8, 0.0, "jersey barrier")
	_p("yard/barrier", 52.0, 36.0, 3.0, 0.6, Geom.COVER, 0.8, 0.0, "jersey barrier")
	# staff parking
	_decor("parking", {"r": Rect2(57.3, 8.0, 6.3, 21.6), "axis": "h", "stall": 2.7})
	_p("yard/car", 58.4, 8.4, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "car")
	_p("yard/car", 58.4, 13.8, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "car")
	_p("yard/car", 58.4, 21.9, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "car")
	# north road
	_decor("road", {"r": Rect2(0.12, 0.12, 63.76, 4.6), "axis": "h"})
	_trunk(Vector2(6, 7), 4.0)
	_trunk(Vector2(60, 39), 4.0)
	_trunk(Vector2(3, 42), 3.0)
	stage_a = [{"r": Rect2(1.0, 30.5, 10.0, 12.5), "face": -0.7}, {"r": Rect2(57.5, 31.0, 6.0, 12.0), "face": -2.4},
		{"r": Rect2(14.0, 0.5, 30.0, 4.0), "face": PI / 2.0}, {"r": Rect2(0.5, 8.0, 4.5, 16.0), "face": 0.0}]
