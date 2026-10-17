extends "res://scripts/sim/level.gd"
## Map 01, Lone Cabin: one room, one door, a porch and a woodlot. The simplest
## possible problem: one entry, nowhere to go but in.


func _init() -> void:
	id = "m01"
	map_name = "Lone Cabin"
	title = "THE VIOLENCE  -  01 LONE CABIN"
	notes = ["ONE-ROOM CABIN, 7 x 5 m, ONE DOOR, PORCH", "WOODLOT CLEARING  ·  1 SQUARE = 1 m", "MAP 01  ·  SHEET 2 OF 11"]
	W = 30.0
	H = 20.0
	time_limit = 240.0
	default_sizes = [2, 2]
	stage_hint = "Team A comes up the track from the south; team B holds the cabin."


func _build() -> void:
	_room("CABIN", "CABIN", [Rect2(12, 7, 7, 5)])
	_room("PORCH", "PORCH", [Rect2(13.5, 12, 4, 1.6)], {"deck": true})
	_door(15.5, 12, 0.9, {"id": "FRONT"})
	_window(13.8, 7, 1.2)
	_window(17.2, 7, 1.2)
	_window(19, 9.5, 1.0)
	_window(12, 9.5, 1.0)
	_window(18.2, 12, 1.0)
	_auto_walls()
	# porch rails with a gap for the steps, corner posts
	_prop("", Rect2(13.5, 13.56, 1.5, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(16.0, 13.56, 1.5, 0.08), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(13.46, 12.12, 0.08, 1.48), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	_prop("", Rect2(17.46, 12.12, 0.08, 1.48), Geom.CONCEAL, 0.95, 0.0, "porch rail")
	for c in [Vector2(13.5, 13.6), Vector2(17.5, 13.6)]:
		_wall(Rect2(c - Vector2(0.09, 0.09), Vector2(0.18, 0.18)), "porch post")
	_decor("steps", {"r": Rect2(15.0, 13.64, 1.0, 0.6), "n": 3, "axis": "h"})
	# inside
	_p("furn/stove", 12.25, 7.3, 0.7, 0.65, Geom.COVER, 0.9, 0.0, "wood stove")
	_p("furn/counter", 14.4, 7.25, 1.6, 0.6, Geom.COVER, 0.92, 0.0, "counter")
	_p("furn/bed", 16.9, 7.25, 1.9, 0.95, Geom.CONCEAL, 0.6)
	_p("furn/dining", 13.5, 9.2, 1.2, 0.8, Geom.LOW, 0.75)
	_p("furn/armchair", 12.3, 10.9, 0.85, 0.85, Geom.CONCEAL, 0.85)
	_p("furn/wardrobe", 18.35, 10.2, 0.45, 1.1, Geom.COVER, 2.0, 90.0, "wardrobe")
	# clearing
	_p("yard/woodpile", 20.4, 8.4, 0.8, 2.0, Geom.COVER, 1.1, 90.0, "woodpile")
	_p("yard/car", 5.5, 13.4, 4.4, 1.9, Geom.COVER, 1.45, 0.0, "pickup")
	_p("yard/shed", 24.0, 3.0, 1.5, 1.5, Geom.WALL, 2.2, 0.0, "outhouse")
	_p("yard/drum", 19.6, 12.6, 0.6, 0.6, Geom.COVER, 0.9, 0.0, "oil drum")
	_p("yard/low_wall", 8.6, 16.6, 3.0, 0.4, Geom.COVER, 1.0, 0.0, "stone wall")
	_p("yard/hedge", 2.0, 3.0, 0.8, 3.6, Geom.CONCEAL, 1.7, 0.0, "brush")
	_p("yard/picnic", 21.5, 4.6, 1.8, 1.6, Geom.LOW, 0.75)
	_trunk(Vector2(8, 5), 4.2)
	_trunk(Vector2(23.5, 14.0), 3.8)
	_trunk(Vector2(4, 17.5), 3.6)
	_trunk(Vector2(27, 9), 3.4)
	_decor("dash_rect", {"r": Rect2(0.2, 13.0, 11.6, 2.4)})
	_decor("dash_rect", {"r": Rect2(14.9, 14.3, 1.2, 5.5)})
	stage_a = [{"r": Rect2(11.0, 16.6, 9.0, 3.1), "face": -PI / 2.0}]
