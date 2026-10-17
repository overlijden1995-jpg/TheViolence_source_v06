extends SceneTree
## Debug: run a few matches and count kill causes from the log.
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")
const Teams = preload("res://tests/teams.gd")

func _init() -> void:
	var counts := {}
	for mi in [0, 4, 6, 10]:
		var lv = Maps.get_level(mi)
		var nav = Nav.new()
		nav.build(lv)
		for sd in 3:
			var cfgs: Array = Teams.team(lv, 0, {"n": 5, "ech": "sof"}) + Teams.team(lv, 1, {"n": 5, "ech": "militia"})
			var w = World.new()
			w.setup(lv, nav, cfgs, ["assault", "hold"], 500 + sd)
			while not w.over:
				w.step()
			for ln in w.log_lines:
				var tx: String = ln["text"]
				if tx.find("hand to hand") >= 0:
					counts["melee"] = counts.get("melee", 0) + 1
				elif tx.find("KILLED (head") >= 0:
					counts["head kill"] = counts.get("head kill", 0) + 1
				elif tx.find("KILLED (chest") >= 0:
					counts["chest kill"] = counts.get("chest kill", 0) + 1
				elif tx.find("DOWN (") >= 0:
					counts["down"] = counts.get("down", 0) + 1
			counts["shots"] = counts.get("shots", 0) + w.stat["shots"]
			counts["hits"] = counts.get("hits", 0) + w.stat["hits"]
			w.dispose()
	print(counts)
	quit()
