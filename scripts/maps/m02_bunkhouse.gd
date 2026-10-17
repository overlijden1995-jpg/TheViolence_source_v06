extends "res://scripts/sim/level.gd"
## Map 02, Bunkhouse: two rooms in a row (bunkroom and mess hall), three doors. The
## first inside door, and the first choice of which way in.


func _init() -> void:
	id = "m02"
	map_name = "Bunkhouse"
	title = "THE VIOLENCE  -  02 BUNKHOUSE"
	notes = ["BUNKROOM AND MESS HALL, 15 x 6 m, THREE DOORS", "WORK CAMP YARD  ·  1 SQUARE = 1 m", "MAP 02  ·  SHEET 3 OF 11"]
	W = 36.0
	H = 22.0
	time_limit = 300.0
	default_sizes = [4, 4]
	stage_hint = "Team A forms up west of the camp; team B holds the bunkhouse."


func _build() -> void:
	_room("BUNKROOM", "BUNKROOM", [Rect2(10, 7, 8, 6)], {"label": Vector2(14.4, 11.3)})
	_room("MESS", "MESS HALL", [Rect2(18, 7, 7, 6)])
	_door(10, 10, 0.9, {"id": "WEST"})
	_door(18, 10, 0.9, {"id": "MID"})
	_door(21.5, 13, 1.0, {"id": "SOUTH"})
	for x in [12.0, 15.5, 20.5, 23.5]:
		_window(x, 7, 1.2)
	_window(12.5, 13, 1.2)
	_window(15.8, 13, 1.2)
	_window(24.0, 13, 1.0)
	_window(25, 10, 1.2)
	_auto_walls()
	_decor("rect", {"r": Rect2(9.3, 9.4, 0.6, 1.2)})
	_decor("rect", {"r": Rect2(21.0, 13.12, 1.0, 0.5)})
	# bunkroom: bunks on both long walls, a locker row in the middle
	for x in [10.3, 13.0, 15.7]:
		_p("furn/bunk", x, 7.3, 2.0, 0.9, Geom.CONCEAL, 1.6)
	for x2 in [10.4, 13.3, 15.7]:
		_p("furn/bunk", x2, 11.85, 2.0, 0.9, Geom.CONCEAL, 1.6)
	_p("furn/lockers", 13.2, 9.75, 2.4, 0.5, Geom.COVER, 1.9, 0.0, "steel lockers")
	_p("furn/crate", 16.0, 11.0, 0.6, 0.6, Geom.COVER, 0.6, 0.0, "footlocker")
	# mess hall
	_p("furn/dining", 19.2, 7.6, 2.2, 1.4, Geom.LOW, 0.75)
	_p("furn/dining", 19.2, 10.3, 2.2, 1.4, Geom.LOW, 0.75)
	_p("furn/counter", 24.2, 7.3, 0.6, 1.6, Geom.COVER, 0.92, 90.0, "counter")
	_p("furn/stove", 24.15, 9.1, 0.65, 0.7, Geom.COVER, 0.9, 90.0, "stove")
	_p("furn/fridge", 24.1, 11.9, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	# camp yard
	_p("yard/tank", 27.0, 2.6, 2.2, 2.2, Geom.WALL, 3.0, 0.0, "water tank")
	_p("yard/generator", 26.0, 8.0, 1.6, 0.9, Geom.COVER, 1.0, 0.0, "generator")
	_p("yard/drum", 26.0, 9.2, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "fuel drum")
	_p("yard/drum", 26.7, 9.4, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "fuel drum")
	_p("yard/car", 28.5, 14.5, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "pickup")
	_p("yard/woodpile", 12.0, 14.2, 2.0, 0.8, Geom.COVER, 1.1, 0.0, "woodpile")
	_p("yard/low_wall", 15.0, 17.2, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "stone wall")
	_p("yard/hedge", 33.5, 11.0, 0.8, 3.6, Geom.CONCEAL, 1.7, 0.0, "brush")
	_p("yard/picnic", 22.0, 16.2, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/shed", 30.0, 18.0, 1.6, 1.6, Geom.WALL, 2.2, 0.0, "latrine")
	_trunk(Vector2(5.5, 3.0), 4.0)
	_trunk(Vector2(32.0, 7.0), 3.6)
	_trunk(Vector2(7.0, 18.5), 3.8)
	_trunk(Vector2(19.5, 19.0), 4.0)
	stage_a = [{"r": Rect2(0.5, 5.5, 4.0, 11.0), "face": 0.0}]
