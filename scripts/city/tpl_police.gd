extends "res://scripts/sim/level.gd"
## City template: precinct police station. Street to the south. Lobby and front desk on
## the street, offices and interview rooms either side, a long corridor, then the
## briefing room, lockers, armory, a cell block and the sally port on the yard behind.
## Police buildings are never captured.


func _init() -> void:
	id = "tpl_police"
	map_name = "Police Station"
	title = "PRECINCT STATION"
	W = 48.0
	H = 40.0
	fenced = false
	skip_posts = true


func _build() -> void:
	# north row: briefing, lockers over armory, cells over the cell hall, sally port
	_room("BRIEFING", "BRIEFING", [Rect2(4, 6, 12, 12)])
	_room("LOCKERS", "LOCKERS", [Rect2(16, 6, 8, 6)])
	_room("ARMORY", "ARMORY", [Rect2(16, 12, 8, 6)])
	for i in 4:
		_room("CELL %d" % (i + 1), "CELL", [Rect2(24 + 3 * i, 6, 3, 4)])
	_room("CELL HALL", "CELL BLOCK", [Rect2(24, 10, 12, 8)], {"hall": true})
	_room("SALLY PORT", "SALLY PORT", [Rect2(36, 6, 8, 12)])
	_room("CORRIDOR", "CORRIDOR", [Rect2(4, 18, 40, 2.5)], {"hall": true})
	# south row on the street
	_room("OFFICE", "SQUAD OFFICE", [Rect2(4, 20.5, 8, 9.5)])
	_room("RECORDS", "RECORDS", [Rect2(12, 20.5, 6, 9.5)])
	_room("LOBBY", "LOBBY", [Rect2(18, 20.5, 12, 9.5)])
	_room("INTERVIEW 1", "INTERVIEW", [Rect2(30, 20.5, 5, 9.5)])
	_room("INTERVIEW 2", "INTERVIEW", [Rect2(35, 20.5, 5, 9.5)])
	_room("RESTROOM", "WC", [Rect2(40, 20.5, 4, 9.5)])
	_room("STEPS", "", [Rect2(20, 30, 8, 1.6)], {"deck": true})
	# doors
	_door(24, 30, 1.8, {"id": "FRONT"})
	_door(26.5, 20.5, 1.0)
	_door(8, 20.5, 0.9)
	_door(15, 20.5, 0.9)
	_door(32.5, 20.5, 0.9)
	_door(37.5, 20.5, 0.9)
	_door(42, 20.5, 0.9)
	_door(12, 18, 1.2)
	_door(16, 9, 0.9)
	_door(22, 12, 0.9)
	_door(20, 18, 1.0)
	_door(30, 18, 1.2)
	for i in 4:
		_door(25.5 + 3 * i, 10, 0.9)
	_door(40, 18, 1.0)
	_door(40, 6, 3.6, {"arch": true, "id": "SALLY GATE"})
	_door(8, 6, 0.9, {"id": "BACK DOOR"})
	_door(4, 19.25, 1.0, {"id": "WEST DOOR"})
	_door(44, 19.25, 1.0, {"id": "EAST DOOR"})
	# windows
	_window(8, 30, 1.6)
	_window(15, 30, 1.2)
	_window(20.5, 30, 1.6)
	_window(27.5, 30, 1.6)
	_window(42, 30, 0.6)
	_window(4, 12, 1.6)
	_window(4, 25, 1.4)
	_window(44, 12, 1.2)
	_window(12, 6, 1.4)
	_auto_walls()
	_furnish()
	_yard()


func _furnish() -> void:
	# lobby: front desk across the room, benches by the windows
	_p("furn/counter", 18.4, 23.2, 0.6, 5.2, Geom.COVER, 1.1, 90.0, "front desk")
	_p("furn/desk", 18.9, 21.0, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("yard/bench", 21.0, 29.0, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/bench", 25.4, 29.0, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/planter", 28.4, 21.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	# squad office and records
	_p("furn/desk", 4.4, 22.0, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/desk", 7.4, 22.0, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/desk", 4.4, 25.6, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/desk", 7.4, 25.6, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/cabinet", 10.9, 28.9, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "filing cabinet")
	_p("furn/shelving", 12.3, 21.6, 1.0, 4.0, Geom.CONCEAL, 1.9, 90.0, "file shelving")
	_p("furn/shelving", 16.6, 21.6, 1.0, 4.0, Geom.CONCEAL, 1.9, 90.0, "file shelving")
	_p("furn/desk", 13.6, 27.6, 1.4, 0.7, Geom.CONCEAL, 0.75)
	# interview rooms
	for x in [30.0, 35.0]:
		_p("furn/table", x + 1.6, 23.5, 1.8, 0.9, Geom.LOW, 0.75)
		_p("furn/chair", x + 2.2, 22.7, 0.5, 0.5, Geom.LOW, 0.45)
		_p("furn/chair", x + 2.2, 24.6, 0.5, 0.5, Geom.LOW, 0.45)
	_p("furn/toilet", 40.4, 28.9, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/basin", 42.8, 21.0, 0.55, 0.42, Geom.LOW, 0.85)
	# briefing room: rows of tables facing the board
	for row in 3:
		_p("furn/table", 5.0, 8.6 + row * 2.6, 2.4, 1.0, Geom.LOW, 0.75)
		_p("furn/table", 9.4, 8.6 + row * 2.6, 2.4, 1.0, Geom.LOW, 0.75)
	_p("furn/desk", 13.6, 6.4, 1.4, 0.7, Geom.CONCEAL, 0.75)
	# lockers and armory
	_p("furn/lockers", 16.2, 6.15, 2.4, 0.5, Geom.COVER, 1.9, 0.0, "lockers")
	_p("furn/lockers", 19.3, 6.15, 2.4, 0.5, Geom.COVER, 1.9, 0.0, "lockers")
	_p("furn/lockers", 23.3, 7.0, 0.5, 2.4, Geom.COVER, 1.9, 90.0, "lockers")
	_p("furn/rack", 16.3, 14.5, 4.6, 0.9, Geom.COVER, 1.6, 0.0, "weapon rack")
	_p("furn/cabinet", 23.2, 12.3, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "ammo safe")
	_p("furn/cabinet", 23.2, 13.1, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "ammo safe")
	# cells
	for i in 4:
		_p("furn/bunk", 24.15 + 3 * i, 6.2, 0.9, 2.0, Geom.CONCEAL, 0.6, 90.0)
		_p("furn/toilet", 26.2 + 3 * i, 6.2, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/desk", 34.3, 16.9, 1.4, 0.7, Geom.CONCEAL, 0.75)
	# sally port: a squad car in the bay
	_p("yard/car", 38.6, 8.5, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "squad car")
	_p("furn/cabinet", 43.3, 16.9, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "cabinet")


func _yard() -> void:
	# front: walk to the steps, a few parked squad cars, planters
	_decor("dash_rect", {"r": Rect2(21.0, 31.6, 6.0, 8.2)})
	_decor("parking", {"r": Rect2(30.0, 33.4, 16.2, 5.2), "stall": 2.7, "axis": "v"})
	_p("yard/car", 30.3, 33.8, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "squad car")
	_p("yard/car", 35.7, 33.8, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "squad car")
	_p("yard/car", 41.1, 33.8, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "squad car")
	_p("yard/planter", 18.6, 31.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 28.2, 31.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/barrier", 4.0, 36.5, 3.0, 0.6, Geom.COVER, 0.8, 0.0, "jersey barrier")
	_p("yard/barrier", 11.0, 36.5, 3.0, 0.6, Geom.COVER, 0.8, 0.0, "jersey barrier")
	_trunk(Vector2(2.4, 32.0), 3.2)
	_trunk(Vector2(46.0, 32.0), 3.2)
	# yard behind: the sally gate apron, a generator and bins
	_decor("hatch", {"r": Rect2(37.0, 0.6, 6.0, 5.2)})
	_p("yard/generator", 30.0, 2.0, 1.6, 0.9, Geom.COVER, 1.2, 0.0, "generator")
	_p("yard/dumpster", 14.0, 2.0, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/bins", 17.0, 2.2, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
