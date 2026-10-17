extends RefCounted
## Every playable map, in order of complexity. Map 00 is the original test range.

const MAPS := [
	preload("res://scripts/maps/m00_test_range.gd"),
	preload("res://scripts/maps/m01_lone_cabin.gd"),
	preload("res://scripts/maps/m02_bunkhouse.gd"),
	preload("res://scripts/maps/m03_corner_store.gd"),
	preload("res://scripts/maps/m04_center_hall.gd"),
	preload("res://scripts/maps/m05_duplex.gd"),
	preload("res://scripts/maps/m06_ranch.gd"),
	preload("res://scripts/maps/m07_motel.gd"),
	preload("res://scripts/maps/m08_warehouse.gd"),
	preload("res://scripts/maps/m09_compound.gd"),
	preload("res://scripts/maps/m10_apartments.gd"),
]

static var _built := {}


static func count() -> int:
	return MAPS.size()


## A built level, cached: levels are read-only once built.
static func get_level(i: int):
	i = clampi(i, 0, MAPS.size() - 1)
	if not _built.has(i):
		var lv = MAPS[i].new()
		lv.build()
		_built[i] = lv
	return _built[i]


static func names() -> Array:
	var out: Array = []
	for i in MAPS.size():
		var lv = MAPS[i].new()
		out.append("%02d  %s" % [i, lv.map_name])
	return out


static func index_of(map_id: String) -> int:
	for i in MAPS.size():
		var lv = MAPS[i].new()
		if lv.id == map_id or str(i) == map_id or ("%02d" % i) == map_id:
			return i
	return 0
