extends "res://scripts/sim/level.gd"
## Map 07, Roadside Motel: six rooms in a row off a covered walkway, each with a bath at
## the back, and an office with the manager's room. Every room is its own small fight;
## the walkway and the parking lot are a long, open killing ground.

const UNITS := [12.0, 17.0, 22.0, 27.0, 32.0, 37.0]


func _init() -> void:
	id = "m07"
	map_name = "Roadside Motel"
	title = "THE VIOLENCE  -  07 ROADSIDE MOTEL"
	notes = ["SIX ROOMS ON A WALKWAY, OFFICE, 36 x 8 m", "PARKING LOT, SERVICE LANE  ·  1 SQUARE = 1 m", "MAP 07  ·  SHEET 8 OF 11"]
	W = 56.0
	H = 34.0
	time_limit = 480.0
	default_sizes = [12, 12]
	fenced = false
	stage_hint = "Team A comes from the highway and the service lane; team B holds the motel."


func _build() -> void:
	for i in UNITS.size():
		var x: float = UNITS[i]
		var n := i + 1
		_room("ROOM %d" % n, "ROOM %d" % n, [Rect2(x, 10, 5, 6)])
		_room("BATH %d" % n, "BATH", [Rect2(x, 8, 5, 2)])
		_door(x + 1.0, 16, 0.9, {"id": "UNIT %d" % n})
		_door(x + 1.2, 10, 0.9)
		_window(x + 3.4, 16, 1.6)
		_window(x + 3.8, 8, 0.6)
	_room("LOBBY", "OFFICE", [Rect2(42, 11, 6, 5)])
	_room("MANAGER", "MANAGER", [Rect2(42, 8, 6, 3)])
	_room("WALKWAY", "WALKWAY", [Rect2(12, 16, 36, 1.8)], {"deck": true, "label": Vector2(30, 16.9)})
	_door(45, 16, 1.2, {"id": "OFFICE DOOR"})
	_door(44, 11, 0.9)
	_door(46.5, 8, 0.9, {"id": "MANAGER DOOR"})
	_door(48, 13.5, 0.9, {"id": "OFFICE SIDE"})
	_window(43.0, 16, 1.2)
	_window(47.0, 16, 1.2)
	_window(43.5, 8, 1.0)
	_window(12, 13, 1.0)
	_auto_walls()
	# walkway posts
	var px := 12.1
	while px < 48.0:
		_wall(Rect2(px - 0.09, 17.71, 0.18, 0.18), "post")
		px += 4.0
	_wall(Rect2(47.81, 17.71, 0.18, 0.18), "post")
	# rooms
	for x in UNITS:
		_p("furn/bed", x + 2.9, 10.25, 1.6, 2.0, Geom.CONCEAL, 0.6, 90.0)
		_p("furn/dresser", x + 0.2, 12.9, 0.5, 1.2, Geom.COVER, 1.0, 90.0, "dresser")
		_p("furn/coffee_table", x + 3.2, 14.6, 0.6, 0.6, Geom.LOW, 0.7)
		_p("furn/chair", x + 4.0, 15.0, 0.5, 0.5, Geom.LOW, 0.9)
		_p("furn/tub", x + 3.1, 8.2, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "tub")
		_p("furn/toilet", x + 2.2, 8.2, 0.5, 0.65, Geom.LOW, 0.4)
	# office
	_p("furn/checkout", 43.0, 12.2, 2.4, 0.8, Geom.COVER, 1.1, 0.0, "front desk")
	_p("yard/bench", 46.0, 15.15, 1.6, 0.5, Geom.LOW, 0.45)
	_p("furn/cooler", 42.2, 14.4, 0.8, 1.2, Geom.COVER, 1.9, 90.0, "vending machine")
	_p("furn/desk", 42.4, 8.4, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/cabinet", 47.2, 10.2, 0.6, 0.6, Geom.COVER, 1.0, 0.0, "safe")
	_p("furn/cabinet", 42.3, 10.2, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "filing cabinet")
	# parking lot and highway
	_decor("parking", {"r": Rect2(10.0, 19.6, 40.5, 5.4), "axis": "v", "stall": 2.7})
	_decor("parking", {"r": Rect2(10.0, 25.4, 40.5, 4.8), "axis": "v", "stall": 2.7})
	_decor("road", {"r": Rect2(0, 31.0, 56, 3.0), "axis": "h"})
	_decor("text", {"p": Vector2(0.4, 30.7), "text": "HIGHWAY"})
	_p("yard/car", 13.4, 20.2, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/car", 21.5, 20.2, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/car", 29.6, 20.2, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/car", 45.8, 20.2, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/van", 15.0, 27.0, 5.0, 2.0, Geom.COVER, 1.9, 0.0, "van")
	_p("yard/truck", 34.0, 26.6, 7.5, 2.5, Geom.COVER, 2.6, 0.0, "box truck")
	_p("yard/car", 26.0, 25.9, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("yard/dumpster", 51.5, 20.0, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/planter", 50.5, 15.5, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "sign base")
	# service lane behind
	_decor("dash_rect", {"r": Rect2(0.3, 2.0, 55.4, 4.0)})
	_p("yard/dumpster", 8.0, 5.0, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/tank", 49.5, 3.8, 1.6, 1.6, Geom.COVER, 1.2, 0.0, "propane tank")
	for x2 in [14.0, 24.0, 34.0]:
		_p("yard/ac_unit", x2, 7.15, 0.8, 0.6, Geom.COVER, 0.9, 0.0, "AC unit")
	_p("yard/bins", 40.5, 7.1, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
	_trunk(Vector2(4, 14), 4.0)
	_trunk(Vector2(53, 26), 4.0)
	_trunk(Vector2(30, 3.5), 3.6)
	_trunk(Vector2(4, 26), 3.6)
	stage_a = [{"r": Rect2(2.0, 31.2, 24.0, 2.5), "face": -PI / 2.0}, {"r": Rect2(30.0, 31.2, 24.0, 2.5), "face": -PI / 2.0},
		{"r": Rect2(14.0, 0.4, 28.0, 1.5), "face": PI / 2.0}]
