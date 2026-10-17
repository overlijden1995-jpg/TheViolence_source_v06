extends "res://scripts/sim/level.gd"
## Map 03, Corner Store: a big open shop floor cut up by shelving, a storeroom and an
## office behind it, a glass shopfront on the street and a back door on the alley.
## The first room too big to clear from the door.


func _init() -> void:
	id = "m03"
	map_name = "Corner Store"
	title = "THE VIOLENCE  -  03 CORNER STORE"
	notes = ["SHOP FLOOR 12 x 8 m, STOREROOM, OFFICE", "STREET FRONT, SERVICE ALLEY  ·  1 SQUARE = 1 m", "MAP 03  ·  SHEET 4 OF 11"]
	W = 40.0
	H = 26.0
	time_limit = 360.0
	default_sizes = [5, 6]
	fenced = false
	stage_hint = "Team A comes from the street and the back lot; team B holds the store."


func _build() -> void:
	_room("SHOP", "SHOP FLOOR", [Rect2(14, 8, 12, 8)])
	_room("STOREROOM", "STOREROOM", [Rect2(26, 8, 5, 5)])
	_room("OFFICE", "OFFICE", [Rect2(26, 13, 5, 3)])
	_door(18, 16, 1.6, {"id": "ENTRY"})
	_door(26, 10.5, 0.9, {"id": "STOCK"})
	_door(26, 14.5, 0.8, {"id": "OFFICE"})
	_door(28.5, 13, 0.8, {"id": "OS"})
	_door(31, 10.5, 0.9, {"id": "BACK"})
	_window(15.5, 16, 1.8)
	_window(21.5, 16, 3.6)
	_window(24.8, 16, 1.4)
	_window(14, 12, 1.4)
	_window(31, 14.5, 1.0)
	_window(28.5, 16, 1.0)
	_auto_walls()
	# street, sidewalk, alley
	_decor("road", {"r": Rect2(0, 19.6, 40, 6.4), "axis": "h"})
	_decor("dash_rect", {"r": Rect2(0.2, 16.3, 39.6, 3.2)})
	_decor("rect", {"r": Rect2(17.2, 16.12, 1.6, 0.5)})
	_decor("text", {"p": Vector2(0.4, 25.6), "text": "MAIN STREET"})
	# shop floor: coolers on the back wall, two gondola runs, checkout by the door
	for x in [14.3, 17.5, 20.7]:
		_p("furn/cooler", x, 8.25, 3.0, 0.8, Geom.COVER, 2.0, 0.0, "drinks cooler")
	_p("furn/shelving", 15.8, 10.2, 7.0, 0.9, Geom.CONCEAL, 1.6, 0.0, "shelving")
	_p("furn/shelving", 15.8, 12.4, 7.0, 0.9, Geom.CONCEAL, 1.6, 0.0, "shelving")
	_p("furn/checkout", 19.0, 14.4, 2.2, 0.8, Geom.COVER, 1.0, 0.0, "checkout counter")
	_p("furn/table", 14.5, 14.4, 1.2, 0.8, Geom.LOW, 0.9)
	# storeroom and office
	_p("furn/rack", 26.4, 8.25, 4.2, 0.9, Geom.COVER, 2.2, 0.0, "stock rack")
	_p("furn/crate", 26.5, 11.6, 1.1, 1.1, Geom.COVER, 1.1, 0.0, "crate")
	_p("furn/pallet", 29.4, 11.6, 1.2, 1.0, Geom.LOW, 0.3)
	_p("furn/desk", 28.6, 14.0, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/cabinet", 30.2, 13.25, 0.6, 0.6, Geom.COVER, 1.0, 0.0, "safe")
	_p("furn/cabinet", 26.3, 15.15, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "filing cabinet")
	# outside
	_p("yard/car", 6.0, 20.0, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/car", 27.0, 20.0, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "parked car")
	_p("yard/planter", 12.4, 16.7, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 25.8, 16.7, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/bench", 9.5, 16.9, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/dumpster", 33.0, 8.5, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/bins", 33.0, 10.2, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_p("furn/pallet", 35.5, 12.0, 1.2, 1.0, Geom.COVER, 1.0, 0.0, "pallet stack")
	_p("yard/ac_unit", 31.2, 8.6, 0.8, 0.6, Geom.COVER, 0.9, 0.0, "AC unit")
	_p("yard/van", 18.0, 2.5, 5.0, 2.0, Geom.COVER, 1.9, 0.0, "van")
	_p("yard/drum", 9.0, 9.0, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "drum")
	_p("yard/low_wall", 3.0, 11.0, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "brick wall")
	_trunk(Vector2(10, 4), 3.6)
	_trunk(Vector2(37, 4), 3.6)
	stage_a = [{"r": Rect2(1.0, 21.6, 14.0, 4.0), "face": -0.9}, {"r": Rect2(26.0, 0.6, 12.0, 3.6), "face": 1.7}]
