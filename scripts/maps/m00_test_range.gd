extends "res://scripts/sim/level.gd"
## Map 00, Test Range 01: a shotgun house in a fenced yard (the original slice, kept
## exactly). Adapted from the 14x32 ft shotgun-house sketch, scaled up to 5 x 13 m so
## two-person teams can move through it, and laid on its side: the street and porch
## are west, the back door is east. Rooms run front to back: living & guest room,
## kitchen with the bathroom off it, bedroom. Every door sits on the "shotgun" line.


func _init() -> void:
	id = "m00"
	map_name = "Test Range 01 - Shotgun House"
	title = "THE VIOLENCE  -  TEST RANGE 01"
	notes = ["14 x 32 SHOTGUN HOUSE, DRAWN AT 5 x 13 m", "YARD WITH SCATTERED COVER  ·  1 SQUARE = 1 m", "MAP 00  ·  SHEET 1 OF 11"]
	W = 36.0
	H = 24.0
	time_limit = 300.0
	default_sizes = [3, 5]
	stage_hint = "Team A forms up on the front walk; team B holds the house."


func _build() -> void:
	_house()
	_furniture()
	_yard()
	# default posts for the first five attackers; the rest are generated
	spawns = {
		"A1": {"p": Vector2(3.0, 13.0), "face": 0.0},
		"A2": {"p": Vector2(3.0, 14.3), "face": 0.0},
		"A3": {"p": Vector2(1.8, 13.0), "face": 0.0},
		"A4": {"p": Vector2(1.8, 14.3), "face": 0.0},
		"A5": {"p": Vector2(0.75, 13.65), "face": 0.0},
	}
	# team B posts are generated: defensive squads of five, one squad per room
	stage_a = [{"r": Rect2(0.3, 8.0, 3.4, 10.5), "face": 0.0}]
	patrol = [Vector2(8.5, 12.0), Vector2(14.5, 12.4), Vector2(19.6, 13.4), Vector2(23.4, 12.4),
		Vector2(27.5, 12.5), Vector2(27.0, 18.5), Vector2(18.0, 17.0), Vector2(8.0, 20.0),
		Vector2(8.0, 4.0), Vector2(20.0, 3.5), Vector2(31.0, 8.0)]
	dims = [{"a": Vector2(12, 8.6), "b": Vector2(25, 8.6), "text": "13.00 m", "ticks": [17.0, 21.0]},
		{"a": Vector2(25.9, 9.5), "b": Vector2(25.9, 14.5), "text": "5.00", "ticks": []}]


func _house() -> void:
	rooms.clear()
	_room("LIVING", "LIVING & GUEST RM", [Rect2(12, 9.5, 5, 5)], {"label": Vector2(14.5, 12.25), "nowalls": true})
	_room("KITCHEN", "KITCHEN", [Rect2(19.2, 9.5, 1.8, 2.4), Rect2(17, 11.9, 4, 2.6)], {"label": Vector2(18.45, 14.05), "nowalls": true})
	_room("BATH", "BATH", [Rect2(17, 9.5, 2.2, 2.4)], {"label": Vector2(18.35, 11.55), "nowalls": true})
	_room("BEDROOM", "BEDROOM", [Rect2(21, 9.5, 4, 5)], {"label": Vector2(23.0, 11.75), "nowalls": true})
	_room("PORCH", "PORCH", [Rect2(10, 9.5, 2, 5)], {"label": Vector2(11.0, 10.4), "deck": true})
	var e := 0.22  # exterior wall thickness
	var p := 0.12  # partitions
	# exterior: north (y 9.5) and south (y 14.5) long walls
	_hwall(11.89, 25.11, 9.5, e, [[13.2, 15.0, "window"], [19.6, 20.6, "window"], [22.0, 23.6, "window"]])
	_hwall(11.89, 25.11, 14.5, e, [[13.4, 15.2, "window"], [18.2, 19.6, "window"], [22.2, 23.8, "window"]])
	# front (west, x 12) and back (east, x 25) walls, doors on the shotgun line y 12.9-13.8
	_vwall(9.61, 14.39, 12.0, e, [[10.1, 11.5, "window"], [12.9, 13.8, "door"]])
	_vwall(9.61, 14.39, 25.0, e, [[10.2, 11.6, "window"], [12.9, 13.8, "door"]])
	# partitions on the same line
	_vwall(9.61, 14.39, 17.0, p, [[12.9, 13.8, "door"]])
	_vwall(9.61, 14.39, 21.0, p, [[12.9, 13.8, "door"]])
	# bathroom off the kitchen
	_vwall(9.61, 11.96, 19.2, p, [])
	_hwall(17.06, 19.26, 11.9, p, [[17.25, 18.05, "door"]])
	# porch: railings (wood spindles: concealment, not cover) and corner posts
	_prop("", Rect2(10.0, 9.45, 1.89, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(10.0, 14.47, 1.89, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(9.98, 9.45, 0.08, 3.1), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(9.98, 14.15, 0.08, 0.4), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	for c in [Vector2(10.02, 9.49), Vector2(10.02, 14.51), Vector2(10.02, 12.55), Vector2(10.02, 14.15)]:
		_wall(Rect2(c - Vector2(0.09, 0.09), Vector2(0.18, 0.18)), "porch post")
	_add_door("FRONT", Vector2(12.0, 13.35), Vector2(1, 0), 0.45)
	_add_door("LK", Vector2(17.0, 13.35), Vector2(1, 0), 0.45)
	_add_door("KB", Vector2(21.0, 13.35), Vector2(1, 0), 0.45)
	_add_door("BACK", Vector2(25.0, 13.35), Vector2(1, 0), 0.45, false, -1)
	_add_door("BATH", Vector2(17.65, 11.9), Vector2(0, -1), 0.40)


func _furniture() -> void:
	# living & guest room
	_prop("furn/sofa", Rect2(13.0, 9.62, 2.2, 0.85), Geom.CONCEAL, 0.85)
	_prop("furn/armchair", Rect2(15.7, 9.66, 0.85, 0.85), Geom.CONCEAL, 0.85)
	_prop("furn/coffee_table", Rect2(13.5, 10.9, 1.2, 0.6), Geom.LOW, 0.45)
	_prop("furn/bookshelf", Rect2(15.3, 13.98, 1.6, 0.4), Geom.CONCEAL, 1.8, 0.0, "bookshelf")
	# kitchen
	_prop("furn/counter", Rect2(19.32, 9.62, 1.6, 0.6), Geom.COVER, 0.92, 0.0, "counter")
	_prop("furn/fridge", Rect2(20.24, 10.3, 0.68, 0.7), Geom.COVER, 1.8, 0.0, "fridge")
	_prop("furn/dining", Rect2(19.3, 11.95, 1.1, 0.8), Geom.LOW, 0.75)
	# bath
	_prop("furn/tub", Rect2(17.08, 9.62, 1.6, 0.72), Geom.COVER, 0.55, 0.0, "cast-iron tub")
	_prop("furn/toilet", Rect2(18.5, 10.75, 0.65, 0.5), Geom.LOW, 0.4, 90.0)
	_prop("furn/basin", Rect2(18.72, 9.66, 0.42, 0.55), Geom.LOW, 0.85, 90.0)
	# bedroom
	_prop("furn/bed", Rect2(22.7, 9.62, 2.0, 1.6), Geom.CONCEAL, 0.6)
	_prop("furn/dresser", Rect2(21.15, 9.64, 1.2, 0.5), Geom.COVER, 1.0, 0.0, "dresser")
	_prop("furn/wardrobe", Rect2(23.95, 13.93, 0.95, 0.45), Geom.COVER, 2.0, 0.0, "wardrobe")


func _yard() -> void:
	# front yard (west, street side)
	_prop("yard/car", Rect2(3.8, 16.2, 4.4, 1.9), Geom.COVER, 1.45, 0.0, "car")
	_prop("yard/low_wall", Rect2(2.2, 6.6, 3.0, 0.4), Geom.COVER, 1.0, 0.0, "brick wall")
	_prop("yard/hedge", Rect2(0.6, 1.6, 0.8, 3.6), Geom.CONCEAL, 1.7, 0.0, "hedge")
	_prop("yard/drum", Rect2(7.6, 6.8, 0.6, 0.6), Geom.COVER, 0.9, 0.0, "oil drum")
	_trunk(Vector2(4.6, 11.4))
	# north side yard
	_trunk(Vector2(15.4, 4.2), 4.0)
	_prop("yard/low_wall", Rect2(18.6, 6.0, 3.0, 0.4), Geom.COVER, 1.0, 0.0, "brick wall")
	_prop("yard/drum", Rect2(22.4, 4.8, 0.6, 0.6), Geom.COVER, 0.9, 0.0, "oil drum")
	_prop("yard/drum", Rect2(23.1, 5.2, 0.6, 0.6), Geom.COVER, 0.9, 0.0, "oil drum")
	_prop("yard/picnic", Rect2(26.6, 6.6, 1.8, 1.6), Geom.LOW, 0.75)
	# south side yard
	_prop("yard/ac_unit", Rect2(19.3, 14.64, 0.8, 0.6), Geom.COVER, 0.9, 0.0, "AC unit")
	_prop("yard/bins", Rect2(23.0, 14.66, 0.8, 0.6), Geom.CONCEAL, 1.1, 0.0, "plastic bins")
	_prop("yard/low_wall", Rect2(14.0, 19.0, 3.0, 0.4), Geom.COVER, 1.0, 0.0, "brick wall")
	_trunk(Vector2(21.6, 20.2))
	# back yard (east)
	_prop("yard/shed", Rect2(30.0, 2.0, 3.5, 3.0), Geom.WALL, 2.4, 0.0, "shed")
	_prop("yard/woodpile", Rect2(28.0, 16.6, 2.0, 0.8), Geom.COVER, 1.1, 0.0, "woodpile")
	_prop("yard/drum", Rect2(32.0, 17.4, 0.6, 0.6), Geom.COVER, 0.9, 0.0, "oil drum")
	_prop("yard/drum", Rect2(32.7, 17.9, 0.6, 0.6), Geom.COVER, 0.9, 0.0, "oil drum")
	_prop("yard/hedge", Rect2(34.6, 8.4, 0.8, 3.6), Geom.CONCEAL, 1.7, 0.0, "hedge")
	_prop("yard/low_wall", Rect2(29.4, 10.8, 0.4, 3.0), Geom.COVER, 1.0, 90.0, "brick wall")
	_trunk(Vector2(32.8, 14.2))
	# drawing-only: front walk, driveway, back step, porch steps, street
	decor.append({"type": "dash_rect", "r": Rect2(2.6, 15.6, 7.2, 3.1)})
	decor.append({"type": "dash_rect", "r": Rect2(0.15, 12.6, 9.8, 1.5)})
	decor.append({"type": "rect", "r": Rect2(25.11, 12.75, 0.6, 1.2)})
	decor.append({"type": "steps", "r": Rect2(9.05, 12.55, 0.6, 1.6), "n": 3, "axis": "v"})
	decor.append({"type": "text", "p": Vector2(0, H + 2.05), "text": "STREET"})
