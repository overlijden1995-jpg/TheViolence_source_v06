extends "res://scripts/sim/level.gd"
## City template: district hospital. Street to the south. The main entrance opens into
## the waiting room; the emergency lobby and the trauma bay with its ambulance doors sit
## beside it. A 56 m corridor runs east to west with two wards, operating theatres, a
## pharmacy and staff room to the north, imaging and the lab to the east.
## Faction-neutral ambulances are based here; gangs who take it spawn recruits here.


func _init() -> void:
	id = "tpl_hospital"
	map_name = "Hospital"
	title = "DISTRICT HOSPITAL"
	W = 64.0
	H = 48.0
	fenced = false
	skip_posts = true


func _build() -> void:
	_room("WARD A", "WARD A", [Rect2(4, 4, 14, 14)])
	_room("WARD B", "WARD B", [Rect2(18, 4, 14, 14)])
	_room("OR 1", "THEATRE 1", [Rect2(32, 4, 9, 8)])
	_room("OR 2", "THEATRE 2", [Rect2(41, 4, 9, 8)])
	_room("PREP", "SCRUB & PREP", [Rect2(32, 12, 18, 6)])
	_room("PHARMACY", "PHARMACY", [Rect2(50, 4, 10, 7)])
	_room("STAFF", "STAFF ROOM", [Rect2(50, 11, 10, 7)])
	_room("CORRIDOR", "CORRIDOR", [Rect2(4, 18, 56, 3)], {"hall": true})
	_room("WAITING", "WAITING ROOM", [Rect2(4, 21, 14, 15)])
	_room("TRIAGE", "TRIAGE", [Rect2(18, 21, 12, 7)])
	_room("EXAM 1", "EXAM", [Rect2(18, 28, 6, 8)])
	_room("EXAM 2", "EXAM", [Rect2(24, 28, 6, 8)])
	_room("ER LOBBY", "EMERGENCY", [Rect2(30, 21, 4, 15)], {"hall": true})
	_room("TRAUMA", "TRAUMA BAY", [Rect2(34, 21, 14, 15)])
	_room("IMAGING", "IMAGING", [Rect2(48, 21, 12, 8)])
	_room("LAB", "LAB", [Rect2(48, 29, 12, 7)])
	_room("CANOPY", "", [Rect2(36, 36, 10, 3.0)], {"deck": true})
	# doors
	_door(11, 36, 1.8, {"id": "MAIN ENTRANCE"})
	_door(11, 21, 1.8, {"arch": true})
	_door(24, 21, 1.2)
	_door(21, 28, 0.9)
	_door(27, 28, 0.9)
	_door(18, 24.5, 1.0)
	_door(32, 36, 2.0, {"id": "ER ENTRANCE"})
	_door(32, 21, 3.0, {"arch": true})
	_door(34, 26, 1.4)
	_door(30, 32, 0.9)
	_door(41, 36, 2.4, {"id": "AMBULANCE BAY"})
	_door(41, 21, 1.6)
	_door(54, 21, 1.2)
	_door(54, 29, 0.9)
	_door(60, 32.5, 1.0, {"id": "STAFF EXIT"})
	_door(11, 18, 1.4)
	_door(25, 18, 1.4)
	_door(18, 11, 0.9)
	_door(36.5, 12, 1.2)
	_door(45.5, 12, 1.2)
	_door(41, 18, 1.6)
	_door(55, 11, 0.9)
	_door(55, 18, 1.0)
	_door(4, 19.5, 1.2, {"id": "WEST DOOR"})
	_door(60, 19.5, 1.2, {"id": "EAST DOOR"})
	_door(8, 4, 1.0, {"id": "SERVICE DOOR"})
	# windows
	_window(12.0, 4, 1.6)
	_window(15.5, 4, 1.4)
	_window(21.5, 4, 1.6)
	_window(27.5, 4, 1.6)
	_window(4, 10, 1.6)
	_window(4, 28.5, 2.0)
	_window(6.5, 36, 1.8)
	_window(15.5, 36, 1.8)
	_window(21, 36, 1.2)
	_window(27, 36, 1.2)
	_window(60, 25, 1.2)
	_window(60, 7.5, 1.2)
	_window(60, 14.5, 1.2)
	_window(55, 4, 1.6)
	_auto_walls()
	_furnish()
	_yard()


func _furnish() -> void:
	# wards: beds head to the outer walls, curtains between (concealment)
	for wx in [4.0, 18.0]:
		for bx in [0.6, 5.0, 8.3, 11.6]:
			_p("furn/bed", wx + bx, 4.3, 1.0, 2.0, Geom.CONCEAL, 0.7, 90.0)
		for bx2 in [0.6, 3.4, 9.0, 11.8]:
			_p("furn/bed", wx + bx2, 15.6, 1.0, 2.0, Geom.CONCEAL, 0.7, 90.0)
		_p("furn/cabinet", wx + 13.2, 7.4, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "med cart")
	_p("furn/desk", 9.0, 9.9, 1.4, 0.7, Geom.CONCEAL, 0.75, 0.0, "nurse station")
	_p("furn/desk", 23.0, 9.9, 1.4, 0.7, Geom.CONCEAL, 0.75, 0.0, "nurse station")
	# theatres and prep
	for ox in [32.0, 41.0]:
		_p("furn/table", ox + 3.3, 6.0, 2.4, 1.0, Geom.LOW, 0.9, 0.0, "operating table")
		_p("furn/cabinet", ox + 0.3, 4.3, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "cabinet")
		_p("furn/cabinet", ox + 8.2, 4.3, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "cabinet")
	_p("furn/counter", 33.0, 12.3, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "scrub sink")
	_p("furn/counter", 47.4, 12.3, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "scrub sink")
	_p("furn/bed", 39.0, 15.4, 2.0, 1.0, Geom.CONCEAL, 0.7, 0.0, "gurney")
	# pharmacy and staff room
	_p("furn/shelving", 50.4, 4.4, 4.0, 1.0, Geom.CONCEAL, 1.9, 0.0, "shelving")
	_p("furn/shelving", 55.4, 4.4, 4.0, 1.0, Geom.CONCEAL, 1.9, 0.0, "shelving")
	_p("furn/counter", 51.0, 9.2, 1.6, 0.6, Geom.COVER, 1.0, 0.0, "dispensary counter")
	_p("furn/dining", 52.0, 13.5, 1.1, 0.8, Geom.LOW, 0.75)
	_p("furn/sofa", 56.6, 16.9, 2.2, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/fridge", 59.0, 11.4, 0.7, 0.7, Geom.COVER, 1.8, 0.0, "fridge")
	# waiting room: rows of seats, reception
	for row in 4:
		_p("yard/bench", 5.4, 24.0 + row * 2.4, 1.6, 0.5, Geom.LOW, 0.45)
		_p("yard/bench", 7.6, 24.0 + row * 2.4, 1.6, 0.5, Geom.LOW, 0.45)
	_p("furn/counter", 13.0, 23.6, 0.6, 4.0, Geom.COVER, 1.1, 90.0, "reception")
	_p("furn/desk", 14.6, 24.6, 0.7, 1.4, Geom.CONCEAL, 0.75, 90.0)
	_p("yard/planter", 16.5, 34.4, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	# triage and exams
	_p("furn/desk", 26.6, 21.4, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/bed", 19.0, 24.6, 2.0, 1.0, Geom.CONCEAL, 0.7, 0.0, "exam couch")
	_p("furn/bed", 23.4, 24.6, 2.0, 1.0, Geom.CONCEAL, 0.7, 0.0, "exam couch")
	for ex in [18.0, 24.0]:
		_p("furn/bed", ex + 0.4, 32.6, 2.0, 1.0, Geom.CONCEAL, 0.7, 0.0, "exam couch")
		_p("furn/cabinet", ex + 5.1, 35.0, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "cabinet")
	# trauma bay: four bays with gurneys, the centre island
	for gx in [34.6, 37.6, 43.0, 46.0]:
		_p("furn/bed", gx, 21.5, 1.0, 2.0, Geom.CONCEAL, 0.7, 90.0, "gurney")
	_p("furn/counter", 39.0, 27.6, 4.0, 1.0, Geom.COVER, 1.0, 0.0, "nurses' island")
	_p("furn/cabinet", 47.2, 30.0, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "crash cart")
	# imaging and lab
	_p("yard/tank", 51.6, 22.6, 2.4, 2.4, Geom.COVER, 1.3, 0.0, "scanner")
	_p("furn/desk", 57.4, 27.6, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/counter", 48.4, 29.4, 4.0, 0.7, Geom.COVER, 0.92, 0.0, "lab bench")
	_p("furn/counter", 48.4, 33.0, 4.0, 0.7, Geom.COVER, 0.92, 0.0, "lab bench")
	_p("furn/counter", 54.0, 33.0, 4.0, 0.7, Geom.COVER, 0.92, 0.0, "lab bench")


func _yard() -> void:
	# drop-off loop and ambulance apron under the canopy
	_decor("dash_rect", {"r": Rect2(6.0, 38.0, 20.0, 9.4)})
	_decor("hatch", {"r": Rect2(36.0, 39.2, 10.0, 8.4)})
	_decor("dash_rect", {"r": Rect2(29.0, 36.2, 6.0, 11.4)})
	for c in [Vector2(36.3, 36.3), Vector2(45.5, 36.3)]:
		_wall(Rect2(c, Vector2(0.25, 0.25)), "canopy post")
	_p("yard/planter", 2.0, 38.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 26.8, 38.0, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/bench", 8.0, 37.0, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/bench", 14.0, 37.0, 1.6, 0.5, Geom.LOW, 0.45)
	_decor("parking", {"r": Rect2(48.0, 39.0, 13.5, 5.4), "stall": 2.7, "axis": "v"})
	_p("yard/car", 48.4, 39.4, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "parked car")
	_p("yard/car", 56.5, 39.4, 1.9, 4.4, Geom.COVER, 1.45, 90.0, "parked car")
	_trunk(Vector2(2.6, 44.0), 3.4)
	_trunk(Vector2(61.4, 44.0), 3.4)
	# service yard behind
	_p("yard/dumpster", 12.0, 1.4, 1.9, 1.1, Geom.COVER, 1.4, 0.0, "dumpster")
	_p("yard/generator", 40.0, 1.4, 1.6, 0.9, Geom.COVER, 1.2, 0.0, "generator")
	_p("yard/tank", 46.0, 0.8, 2.2, 2.2, Geom.COVER, 2.0, 0.0, "oxygen tank")
	_p("yard/bins", 20.0, 1.6, 0.8, 0.6, Geom.CONCEAL, 1.1, 0.0, "bins")
