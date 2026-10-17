extends "res://scripts/sim/level.gd"
## City template: neighbourhood school. Street to the south. Front hall and office on
## the street, classrooms both sides of a 40 m corridor, the cafeteria at its east end
## and a full-height gym beside it. The playground is behind. Gangs who hold it recruit
## here.


func _init() -> void:
	id = "tpl_school"
	map_name = "School"
	title = "NEIGHBOURHOOD SCHOOL"
	W = 64.0
	H = 44.0
	fenced = false
	skip_posts = true


func _build() -> void:
	_room("CLASS 1", "CLASSROOM 1", [Rect2(4, 14, 10, 10)])
	_room("CLASS 2", "CLASSROOM 2", [Rect2(14, 14, 10, 10)])
	_room("CLASS 3", "CLASSROOM 3", [Rect2(24, 14, 10, 10)])
	_room("CAFETERIA", "CAFETERIA", [Rect2(34, 14, 10, 10)])
	_room("GYM", "GYMNASIUM", [Rect2(44, 14, 16, 22)])
	_room("CORRIDOR", "CORRIDOR", [Rect2(4, 24, 40, 3)], {"hall": true})
	_room("OFFICE", "OFFICE", [Rect2(4, 27, 8, 9)])
	_room("ENTRY", "FRONT HALL", [Rect2(12, 27, 8, 9)], {"hall": true})
	_room("CLASS 4", "CLASSROOM 4", [Rect2(20, 27, 10, 9)])
	_room("CLASS 5", "CLASSROOM 5", [Rect2(30, 27, 8, 9)])
	_room("RESTROOMS", "WC", [Rect2(38, 27, 6, 9)])
	_room("PORCH", "", [Rect2(13, 36, 6, 1.8)], {"deck": true})
	# doors
	_door(16, 36, 2.4, {"id": "MAIN DOORS"})
	_door(16, 27, 2.4, {"arch": true})
	_door(12, 31.5, 0.9)
	_door(9, 24, 0.9)
	_door(19, 24, 0.9)
	_door(29, 24, 0.9)
	_door(39, 24, 1.6)
	_door(25, 27, 0.9)
	_door(34, 27, 0.9)
	_door(41, 27, 0.9)
	_door(44, 25.5, 1.8)
	_door(60, 25, 1.8, {"id": "GYM EAST DOORS"})
	_door(52, 14, 1.8, {"id": "GYM YARD DOORS"})
	_door(4, 25.5, 1.2, {"id": "WEST DOOR"})
	_door(6, 14, 0.9, {"id": "CLASS 1 YARD DOOR"})
	_door(39, 14, 1.4, {"id": "CAFETERIA YARD DOOR"})
	# windows
	_window(10.5, 14, 3.0)
	_window(19, 14, 3.0)
	_window(29, 14, 3.0)
	_window(36, 14, 2.0)
	_window(42, 14, 1.6)
	_window(8, 36, 1.6)
	_window(23, 36, 2.4)
	_window(27.5, 36, 2.4)
	_window(34, 36, 3.0)
	_window(41, 36, 0.6)
	_window(60, 18, 2.0)
	_window(60, 32, 2.0)
	_window(48, 14, 2.0)
	_window(57, 14, 2.0)
	_window(48, 36, 2.0)
	_window(56, 36, 2.0)
	_window(4, 19, 2.0)
	_window(4, 31.5, 1.4)
	_auto_walls()
	_furnish()
	_yard()


## Desks in rows facing the board, teacher's desk at the front, a shelf at the back.
func _classroom(r: Rect2, board_north: bool) -> void:
	var cols := int((r.size.x - 2.0) / 1.7)
	var rows := int((r.size.y - 3.6) / 1.5)
	var x0 := r.position.x + (r.size.x - cols * 1.7) / 2.0 + 0.25
	for i in cols:
		for j in rows:
			var y := r.position.y + 2.6 + j * 1.5 if board_north else r.end.y - 2.6 - 0.6 - j * 1.5
			_p("furn/desk", x0 + i * 1.7, y, 1.2, 0.6, Geom.CONCEAL, 0.72, 0.0, "school desk")
	var ty := r.position.y + 0.5 if board_north else r.end.y - 1.2
	_p("furn/desk", r.position.x + r.size.x * 0.5 + 1.0, ty, 1.4, 0.7, Geom.CONCEAL, 0.75, 0.0, "teacher's desk")
	var by := r.end.y - 0.55 if board_north else r.position.y + 0.15
	var bx := r.position.x + 0.4 if board_north else r.end.x - 2.0
	_p("furn/bookshelf", bx, by, 1.6, 0.4, Geom.CONCEAL, 1.8, 0.0, "bookshelf")


func _furnish() -> void:
	_classroom(Rect2(4, 14, 10, 10), false)
	_classroom(Rect2(14, 14, 10, 10), false)
	_classroom(Rect2(24, 14, 10, 10), false)
	_classroom(Rect2(20, 27, 10, 9), true)
	_classroom(Rect2(30, 27, 8, 9), true)
	# cafeteria tables and the serving counter
	for row in 3:
		_p("furn/table", 35.2, 16.0 + row * 2.4, 2.4, 1.0, Geom.LOW, 0.75)
		_p("furn/table", 38.6, 16.0 + row * 2.4, 2.4, 1.0, Geom.LOW, 0.75)
	_p("furn/counter", 43.2, 16.0, 0.6, 4.0, Geom.COVER, 0.95, 90.0, "serving counter")
	# gym: bleachers along the north wall, mats
	_p("furn/stairs", 44.6, 14.4, 6.0, 2.0, Geom.COVER, 1.2, 90.0, "bleachers")
	_p("furn/stairs", 53.8, 14.4, 5.4, 2.0, Geom.COVER, 1.2, 90.0, "bleachers")
	_decor("dash_rect", {"r": Rect2(46.0, 18.5, 12.0, 15.5)})
	_decor("rect", {"r": Rect2(56.0, 33.6, 3.6, 2.0)})
	# office and front hall
	_p("furn/counter", 4.6, 27.4, 4.0, 0.6, Geom.COVER, 1.0, 0.0, "office counter")
	_p("furn/desk", 5.0, 30.6, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/desk", 8.6, 33.2, 1.4, 0.7, Geom.CONCEAL, 0.75)
	_p("furn/cabinet", 11.1, 35.0, 0.5, 0.6, Geom.COVER, 1.3, 0.0, "filing cabinet")
	_p("furn/lockers", 19.4, 28.0, 0.5, 2.4, Geom.COVER, 1.9, 90.0, "lockers")
	_p("furn/lockers", 19.4, 32.6, 0.5, 2.4, Geom.COVER, 1.9, 90.0, "lockers")
	# restrooms
	for k in 3:
		_p("furn/toilet", 38.4 + k * 1.2, 35.2, 0.5, 0.65, Geom.LOW, 0.4)
	_p("furn/basin", 43.4, 28.6, 0.42, 0.55, Geom.LOW, 0.85, 90.0)
	_p("furn/basin", 43.4, 29.8, 0.42, 0.55, Geom.LOW, 0.85, 90.0)
	# lockers along the corridor
	for lx in [6.0, 22.0, 31.0]:
		_p("furn/lockers", lx, 26.45, 2.4, 0.5, Geom.COVER, 1.9, 0.0, "lockers")


func _yard() -> void:
	# playground behind: a court, benches, picnic tables, trees
	_decor("dash_rect", {"r": Rect2(6.0, 1.5, 22.0, 10.5)})
	_decor("dash_rect", {"r": Rect2(15.5, 4.5, 3.0, 4.5)})
	_p("yard/picnic", 32.0, 3.0, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/picnic", 36.0, 3.0, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/picnic", 32.0, 7.0, 1.8, 1.6, Geom.LOW, 0.75)
	_p("yard/bench", 42.0, 11.6, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/barrier", 46.0, 6.0, 3.0, 0.6, Geom.LOW, 0.6, 0.0, "climbing frame")
	_p("yard/barrier", 50.0, 6.0, 3.0, 0.6, Geom.LOW, 0.6, 0.0, "climbing frame")
	_trunk(Vector2(58.0, 4.0), 3.6)
	_trunk(Vector2(3.0, 4.0), 3.6)
	_p("yard/shed", 56.0, 9.0, 3.5, 3.0, Geom.WALL, 2.4, 0.0, "storage shed")
	# front: walk, flagpole planters, a bus bay
	_decor("dash_rect", {"r": Rect2(13.0, 37.8, 6.0, 6.0)})
	_p("yard/planter", 10.6, 37.4, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/planter", 20.2, 37.4, 1.2, 1.2, Geom.COVER, 0.8, 0.0, "planter")
	_p("yard/bench", 24.0, 37.4, 1.6, 0.5, Geom.LOW, 0.45)
	_p("yard/truck", 36.0, 39.2, 7.5, 2.5, Geom.COVER, 2.8, 0.0, "school bus")
	_trunk(Vector2(3.0, 40.0), 3.4)
	_trunk(Vector2(60.0, 40.0), 3.4)
