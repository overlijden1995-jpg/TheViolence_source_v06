extends Control
## The ledger of the dead. Every death slides in at the top of a column on the left of the
## screen: when, who (name, rank, side), how (hit where, by whom, or died of wounds while
## waiting for an ambulance) and where they fell. Older lines move down and fade out; a
## running count by side heads the column. Used in normal matches and the endless battle.

const INK := Color("#1c1c1c")
const BLOOD := Color("#7d0a0a")
const W := 384.0
const ROW_H := 47.0
const HEAD_H := 46.0

var world
var shown := 0
var entries: Array = []        # [{rec, age, y}]
var totals := {}               # faction -> deaths
var bled := 0
var max_rows := 12
var font: Font
var bold: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.7
	bold = fv


func setup(w, rows := 12) -> void:
	world = w
	max_rows = rows
	shown = 0
	entries.clear()
	totals.clear()
	bled = 0
	size = Vector2(W, HEAD_H + max_rows * ROW_H + 8.0)
	queue_redraw()


func tick(dt: float) -> void:
	if world == null:
		return
	var base: int = world.deaths_base
	shown = maxi(shown, base)
	while shown < base + world.deaths.size():
		var rec: Dictionary = world.deaths[shown - base]
		shown += 1
		totals[rec["faction"]] = totals.get(rec["faction"], 0) + 1
		if rec["cause"] == "died of wounds":
			bled += 1
		entries.push_front({"rec": rec, "age": 0.0, "y": HEAD_H - ROW_H * 0.6})
	if entries.size() > max_rows:
		entries.resize(max_rows)
	for i in entries.size():
		var e: Dictionary = entries[i]
		e["age"] += dt
		var ty: float = HEAD_H + i * ROW_H
		e["y"] = lerpf(e["y"], ty, minf(1.0, dt * 9.0))
	queue_redraw()


func _side_name(fi: int) -> String:
	if world == null or fi < 0 or fi >= world.factions.size():
		return "?"
	return world.factions[fi]["name"]


func _how(rec: Dictionary) -> String:
	var where: String = rec["where"]
	var by: String = rec["by_name"] if rec["by_name"] != "" else rec["by"]
	var side: String = rec["by_fac_name"]
	var who: String = ("%s (%s)" % [by, side]) if side != "" else by
	if rec["cause"] == "died of wounds":
		var mins := int(rec["after"] / 60.0)
		return "died of wounds, %d min after a %s hit by %s" % [mins, where if where != "" else "gunshot", who]
	match where:
		"head":
			return "shot in the head by %s" % who
		"chest":
			return "shot through the chest by %s" % who
		"abdomen":
			return "shot in the stomach by %s" % who
		"melee":
			return "killed hand to hand by %s" % who
	return "killed by %s" % who


func _draw() -> void:
	if world == null:
		return
	# header: total and the count per side
	var total := 0
	for k in totals:
		total += totals[k]
	draw_rect(Rect2(0, 0, W, HEAD_H - 6.0), Color(1, 1, 1, 0.92))
	draw_rect(Rect2(0, 0, W, HEAD_H - 6.0), INK, false, 1.0)
	draw_string(bold, Vector2(10, 18), "T H E   D E A D   %d" % total, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BLOOD)
	var parts: Array = []
	var keys: Array = totals.keys()
	keys.sort()
	for k2 in keys:
		parts.append("%s %d" % [world.factions[k2].get("tag", "?") if k2 < world.factions.size() else "?", totals[k2]])
	if bled > 0:
		parts.append("of wounds %d" % bled)
	draw_string(font, Vector2(10, 34), "   ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, W - 20.0, 11, Color("#444444"))
	for i in entries.size():
		var e: Dictionary = entries[i]
		var rec: Dictionary = e["rec"]
		var age: float = e["age"]
		var slide := clampf(age / 0.35, 0.0, 1.0)
		slide = 1.0 - pow(1.0 - slide, 3.0)
		var x := -W * (1.0 - slide)
		var a := clampf(1.0 - maxf(0.0, i - (max_rows - 4)) * 0.22, 0.15, 1.0)
		var y: float = e["y"]
		var box := Rect2(x, y, W, ROW_H - 4.0)
		draw_rect(box, Color(1, 1, 1, 0.9 * a))
		if age < 1.4:
			draw_rect(box, Color(BLOOD, 0.22 * (1.0 - age / 1.4)))
		draw_rect(Rect2(x, y, 4.0, ROW_H - 4.0), Color(BLOOD, a))
		draw_rect(box, Color(0, 0, 0, 0.35 * a), false, 1.0)
		var t: String = world.clock(rec["t"])
		var who: String = rec["name"] if rec["name"] != "" else rec["id"]
		draw_string(font, Vector2(x + 10, y + 15), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.35, 0.35, 0.35, a))
		draw_string(bold, Vector2(x + 66, y + 15), who, HORIZONTAL_ALIGNMENT_LEFT, W - 76.0, 12, Color(INK, a))
		var nw := bold.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tag: String = ("%s, %s" % [rec["rank"], _side_name(rec["faction"])]) if rec["rank"] != "" else _side_name(rec["faction"])
		if rec.get("medic", false):
			tag = "%s, %s" % [rec["rank"], _side_name(rec["faction"])]
		draw_string(font, Vector2(x + 72 + nw, y + 15), tag, HORIZONTAL_ALIGNMENT_LEFT, maxf(20.0, W - 82.0 - nw), 10, Color(0.4, 0.4, 0.4, a))
		draw_string(font, Vector2(x + 10, y + 29), _how(rec), HORIZONTAL_ALIGNMENT_LEFT, W - 20.0, 11, Color(0.12, 0.12, 0.12, a))
		draw_string(font, Vector2(x + 10, y + 42), rec["place"], HORIZONTAL_ALIGNMENT_LEFT, W - 20.0, 10, Color(0.45, 0.45, 0.45, a))
