extends "res://scripts/sim/level.gd"
## Map 09, Walled Compound: a 3 m perimeter wall with a main gate, a west door and an
## east service gate around a courtyard, a large main house (a long corridor, bedrooms on
## one side, majlis, dining, kitchen and family room on the other), a guard house by the
## gate and a garage. The walls decide where anyone can get in.


func _init() -> void:
	id = "m09"
	map_name = "Walled Compound"
	title = "THE VIOLENCE  -  09 WALLED COMPOUND"
	notes = ["PERIMETER WALL 56 x 42 m, MAIN HOUSE 32 x 14 m", "GUARD HOUSE, GARAGE, COURTYARD  ·  1 SQUARE = 1 m", "MAP 09  ·  SHEET 10 OF 11"]
	W = 64.0
	H = 50.0
	time_limit = 600.0
	default_sizes = [16, 18]
	fenced = false
	stage_hint = "Team A comes at the walls from all four sides; team B holds the compound."


func _build() -> void:
	# main house: bedrooms north of the corridor, reception rooms south
	_room("BED 1", "BEDROOM", [Rect2(14, 8, 6, 4)])
	_room("BED 2", "BEDROOM", [Rect2(20, 8, 6, 4)])
	_room("BATH 1", "BATH", [Rect2(26, 8, 3, 4)])
	_room("BED 3", "BEDROOM", [Rect2(29, 8, 6, 4)])
	_room("BED 4", "BEDROOM", [Rect2(35, 8, 6, 4)])
	_room("BATH 2", "BATH", [Rect2(41, 8, 2.5, 4)])
	_room("STORE", "STORE", [Rect2(43.5, 8, 2.5, 4)])
	_room("CORRIDOR", "CORRIDOR", [Rect2(14, 12, 32, 2)], {"hall": true, "label": Vector2(32, 13)})
	_room("MAJLIS", "MAJLIS", [Rect2(14, 14, 10, 8)])
	_room("DINING", "DINING", [Rect2(24, 14, 7, 8)])
	_room("KITCHEN", "KITCHEN", [Rect2(31, 14, 7, 8)])
	_room("FAMILY", "FAMILY ROOM", [Rect2(38, 14, 8, 8)])
	_door(14, 13, 0.9, {"id": "WEST ENTRY"})
	_door(46, 13, 0.9, {"id": "EAST ENTRY"})
	_door(19, 22, 1.4, {"id": "MAIN DOOR"})
	_door(34.5, 22, 0.9, {"id": "KITCHEN DOOR"})
	_door(42, 22, 1.6, {"id": "FAMILY DOOR"})
	for x in [17.0, 23.0, 27.5, 32.0, 38.0, 42.25, 44.75]:
		_door(x, 12, 0.9)
	_door(19, 14, 1.4, {"arch": true})
	_door(27.5, 14, 0.9)
	_door(34.5, 14, 0.9)
	_door(42, 14, 0.9)
	_door(24, 18, 1.6, {"arch": true})
	_door(31, 18, 0.9)
	for w in [[17, 8, 1.2], [23, 8, 1.2], [27.5, 8, 0.6], [32, 8, 1.2], [38, 8, 1.2], [16, 22, 1.4], [22.2, 22, 1.2],
			[27.5, 22, 1.4], [32.6, 22, 1.0], [36.8, 22, 1.0], [39.5, 22, 1.0], [44.5, 22, 1.0]]:
		_window(w[0], w[1], w[2])
	_window(14, 10, 1.0)
	_window(14, 18, 1.4)
	_window(46, 18, 1.4)
	_window(46, 10, 1.0)
	# guard house by the main gate, garage on the west side
	_room("GUARD ROOM", "GUARD ROOM", [Rect2(40, 34, 6, 6)])
	_room("GUARD WC", "WC", [Rect2(46, 34, 2, 3)])
	_room("GUARD STORE", "STORE", [Rect2(46, 37, 2, 3)])
	_door(40, 37, 0.9, {"id": "GUARD DOOR"})
	_door(46, 35.5, 0.9)
	_door(46, 38.5, 0.9)
	_window(43, 40, 1.2)
	_window(43, 34, 1.2)
	_room("GARAGE", "GARAGE", [Rect2(12, 30, 8, 8)])
	_door(20, 34, 3.0, {"id": "GARAGE DOOR", "arch": true})
	_door(16, 30, 0.9, {"id": "GARAGE SIDE"})
	_window(12, 34, 1.0)
	_auto_walls()
	# perimeter wall with the main gate (south), a door (west) and a service gate (east)
	_hwall(4.0, 60.0, 4.2, 0.4, [], "perimeter")
	_hwall(4.0, 60.0, 45.8, 0.4, [[30.0, 34.0, "gap"]], "perimeter")
	_vwall(4.4, 45.6, 4.2, 0.4, [[19.4, 20.6, "gap"]], "perimeter")
	_vwall(4.4, 45.6, 59.8, 0.4, [[28.5, 31.5, "gap"]], "perimeter")
	_add_door("MAIN GATE", Vector2(32, 45.8), Vector2(0, -1), 2.0, true)
	_add_door("WEST GATE", Vector2(4.2, 20), Vector2(1, 0), 0.6)
	_add_door("EAST GATE", Vector2(59.8, 30), Vector2(-1, 0), 1.5, true)
	# house furniture
	for bx in [14.0, 20.0, 29.0, 35.0]:
		_p("furn/bed", bx + 0.3, 8.25, 2.0, 1.6, Geom.CONCEAL, 0.6)
		_p("furn/wardrobe", bx + 4.6, 8.25, 1.2, 0.5, Geom.COVER, 2.0, 0.0, "wardrobe")
	_p("furn/tub", 26.2, 8.25, 1.6, 0.72, Geom.COVER, 0.55, 0.0, "tub")
	_p("furn/toilet", 41.3, 8.3, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/shelving", 43.7, 8.2, 2.1, 0.6, Geom.CONCEAL, 1.8, 0.0, "shelving")
	for sx in [14.3, 20.5]:
		_p("furn/sofa", sx, 14.25, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/sofa", 14.25, 16.5, 0.85, 2.2, Geom.CONCEAL, 0.85, 90.0)
	_p("furn/sofa", 20.4, 20.9, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/coffee_table", 17.5, 17.2, 1.2, 0.6, Geom.LOW, 0.45)
	_p("furn/table", 25.5, 16.6, 4.0, 1.4, Geom.LOW, 0.75)
	_p("furn/dresser", 29.6, 14.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "sideboard")
	_p("furn/counter", 31.3, 14.25, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "counter")
	_p("furn/stove", 35.2, 14.25, 0.7, 0.65, Geom.COVER, 0.9, 0.0, "stove")
	_p("furn/fridge", 37.1, 14.25, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	_p("furn/counter", 33.4, 17.6, 2.0, 0.8, Geom.COVER, 0.92, 0.0, "island")
	_p("furn/sofa", 39.0, 20.9, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/armchair", 44.8, 16.5, 0.85, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/coffee_table", 40.0, 18.0, 1.2, 0.6, Geom.LOW, 0.45)
	_p("furn/dresser", 43.0, 14.25, 1.2, 0.5, Geom.COVER, 1.0, 0.0, "TV cabinet")
	# guard house and garage
	_p("furn/desk", 41.0, 38.9, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/bunk", 40.3, 34.2, 2.0, 0.9, Geom.CONCEAL, 1.6)
	_p("furn/lockers", 44.4, 37.2, 1.4, 0.45, Geom.COVER, 1.9, 0.0, "lockers")
	_p("furn/toilet", 47.2, 34.2, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/shelving", 47.25, 37.3, 0.6, 2.4, Geom.CONCEAL, 1.8, 90.0, "shelving")
	_p("yard/car", 13.0, 31.0, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "car")
	_p("furn/rack", 16.0, 37.0, 3.6, 0.8, Geom.COVER, 2.0, 0.0, "shelving")
	_p("yard/drum", 18.9, 30.4, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "fuel drum")
	# courtyard
	_p("yard/tank", 52.0, 7.5, 2.4, 2.4, Geom.WALL, 3.0, 0.0, "water tank")
	_p("yard/generator", 50.0, 16.0, 1.6, 0.9, Geom.COVER, 1.0, 0.0, "generator")
	_p("yard/drum", 50.2, 17.2, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "fuel drum")
	_p("yard/drum", 50.9, 17.4, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "fuel drum")
	_p("yard/van", 24.0, 29.5, 5.0, 2.0, Geom.COVER, 1.9, 0.0, "van")
	_p("yard/car", 28.0, 35.0, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "car")
	_p("yard/car", 8.0, 25.0, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "pickup")
	_p("yard/sandbags", 27.6, 41.5, 2.4, 0.6, Geom.COVER, 1.1, 0.0, "sandbags")
	_p("yard/sandbags", 34.0, 41.5, 2.4, 0.6, Geom.COVER, 1.1, 0.0, "sandbags")
	_p("yard/sandbags", 6.6, 17.6, 0.6, 2.4, Geom.COVER, 1.1, 90.0, "sandbags")
	_p("yard/sandbags", 55.6, 27.8, 0.6, 2.4, Geom.COVER, 1.1, 90.0, "sandbags")
	_p("yard/container", 50.0, 36.0, 6.1, 2.44, Geom.WALL, 2.6, 0.0, "container")
	_p("yard/planter", 25.0, 24.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 37.0, 24.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/low_wall", 14.0, 25.5, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_p("yard/low_wall", 45.0, 25.5, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "garden wall")
	_trunk(Vector2(9.5, 9.5), 3.6)
	_trunk(Vector2(50, 26), 3.6)
	_trunk(Vector2(22, 41), 3.6)
	_trunk(Vector2(55, 43), 3.0)
	_decor("hatch", {"r": Rect2(24.5, 22.6, 14.0, 1.0)})
	# outside the walls
	_decor("dash_rect", {"r": Rect2(26.0, 46.3, 12.0, 3.5)})
	_p("yard/car", 41.0, 47.0, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "car wreck")
	_p("yard/low_wall", 14.0, 47.6, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "ruined wall")
	_p("yard/low_wall", 0.8, 32.0, 0.4, 3.0, Geom.COVER, 1.0, 90.0, "ruined wall")
	_p("yard/barrier", 61.0, 14.0, 0.6, 3.0, Geom.COVER, 0.8, 90.0, "barrier")
	_trunk(Vector2(2.0, 44.0), 3.0)
	_trunk(Vector2(62.0, 2.0), 3.0)
	stage_a = [{"r": Rect2(18.0, 46.5, 26.0, 3.2), "face": -PI / 2.0}, {"r": Rect2(0.3, 8.0, 3.3, 30.0), "face": 0.0},
		{"r": Rect2(60.4, 10.0, 3.3, 30.0), "face": PI}, {"r": Rect2(8.0, 0.3, 48.0, 3.3), "face": PI / 2.0}]
