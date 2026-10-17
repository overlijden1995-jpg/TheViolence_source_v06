extends SceneTree
## Playtest matrix for 1-5 operator teams. Team A starts on the front walk, team B in
## the house and back yard. Each cell runs N seeded matches and prints one CSV row.
##   godot --headless --path . -s res://tests/playtest.gd -- --n=30 --cells=all
##   godot --headless --path . -s res://tests/playtest.gd -- --n=30 --cells=0-9 --out=/tmp/a.csv
## Columns: cell, a_win%, b_win%, draw%, mean_s, a_down, b_down, exchange (B down per A down),
##          friendly_hits/match, a_hit%, b_hit%, stray/match, a_shots/match, b_shots/match
## --set=followup runs the second round of single-habit variations.

const Teams = preload("res://tests/teams.gd")
const Maps = preload("res://scripts/maps/registry.gd")
const Nav = preload("res://scripts/sim/nav.gd")
const World = preload("res://scripts/sim/world.gd")

const AGG := ["BH11", "BH12"]
const COMP := ["BH17", "BH18"]


func cells() -> Array:
	var c: Array = []
	# --- outnumbered attackers (A assaults the house held by B)
	c.append(["atk 2 SOF vs 5 untrained", {"n": 2, "ech": "sof"}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["atk 2 SOF vs 5 militia", {"n": 2, "ech": "sof"}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	c.append(["atk 3 SOF vs 5 militia", {"n": 3, "ech": "sof"}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	c.append(["atk 3 SOF vs 5 regular", {"n": 3, "ech": "sof"}, {"n": 5, "ech": "regular"}, "assault", "hold"])
	c.append(["atk 3 police vs 5 militia", {"n": 3, "ech": "police"}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	c.append(["atk 3 regular vs 5 untrained", {"n": 3, "ech": "regular"}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["atk 3 SOF-habits vs 5 SOF-no-habits", {"n": 3, "ech": "sof", "habits": "all"}, {"n": 5, "ech": "sof", "habits": "none"}, "assault", "hold"])
	# --- outnumbered defenders (B holds the house against a larger A assault)
	c.append(["def 5 untrained vs 2 SOF", {"n": 5, "ech": "untrained"}, {"n": 2, "ech": "sof"}, "assault", "hold"])
	c.append(["def 5 militia vs 2 SOF", {"n": 5, "ech": "militia"}, {"n": 2, "ech": "sof"}, "assault", "hold"])
	c.append(["def 5 militia vs 3 SOF", {"n": 5, "ech": "militia"}, {"n": 3, "ech": "sof"}, "assault", "hold"])
	c.append(["def 5 regular vs 3 SOF", {"n": 5, "ech": "regular"}, {"n": 3, "ech": "sof"}, "assault", "hold"])
	c.append(["def 5 militia vs 3 police", {"n": 5, "ech": "militia"}, {"n": 3, "ech": "police"}, "assault", "hold"])
	c.append(["def 5 untrained vs 3 regular", {"n": 5, "ech": "untrained"}, {"n": 3, "ech": "regular"}, "assault", "hold"])
	c.append(["def 5 SOF-no-habits vs 3 SOF-habits", {"n": 5, "ech": "sof", "habits": "none"}, {"n": 3, "ech": "sof", "habits": "all"}, "assault", "hold"])
	# --- meeting engagements (both teams hunt)
	c.append(["hunt 2 SOF vs 5 militia", {"n": 2, "ech": "sof"}, {"n": 5, "ech": "militia"}, "hunt", "hunt"])
	c.append(["hunt 3 SOF vs 5 militia", {"n": 3, "ech": "sof"}, {"n": 5, "ech": "militia"}, "hunt", "hunt"])
	c.append(["hunt 3 regular vs 5 untrained", {"n": 3, "ech": "regular"}, {"n": 5, "ech": "untrained"}, "hunt", "hunt"])
	# --- controls (equal numbers)
	c.append(["ctl 5 regular vs 5 regular", {"n": 5, "ech": "regular"}, {"n": 5, "ech": "regular"}, "assault", "hold"])
	c.append(["ctl 5 SOF vs 5 SOF", {"n": 5, "ech": "sof"}, {"n": 5, "ech": "sof"}, "assault", "hold"])
	c.append(["ctl 5 militia vs 5 militia", {"n": 5, "ech": "militia"}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	# --- personality flaws on one member of a small elite team
	c.append(["flaw 3 SOF (A1 aggressive) vs 5 militia", {"n": 3, "ech": "sof", "flaws": AGG, "flaw_slots": [0]}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	c.append(["flaw 3 SOF (A1 complacent) vs 5 militia", {"n": 3, "ech": "sof", "flaws": COMP, "flaw_slots": [0]}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	c.append(["flaw 3 SOF (all aggressive) vs 5 militia", {"n": 3, "ech": "sof", "flaws": AGG}, {"n": 5, "ech": "militia"}, "assault", "hold"])
	# --- break-even curves: 2 attackers of each echelon vs 1-5 militia defenders
	for ech in ["sof", "police", "regular"]:
		for nb in range(1, 6):
			c.append(["be 2 %s vs %d militia" % [ech, nb], {"n": 2, "ech": ech}, {"n": nb, "ech": "militia"}, "assault", "hold"])
	return c


## Second round: single-habit and posture variations suggested by the first matrix.
func followups() -> Array:
	var c: Array = []
	c.append(["fu 3 regular vs 5 untrained (baseline)", {"n": 3, "ech": "regular"}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 3 regular +PF10 vs 5 untrained", {"n": 3, "ech": "regular", "add": ["PF10"]}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 3 regular +PF10 +ED09 vs 5 untrained", {"n": 3, "ech": "regular", "add": ["PF10", "ED09"]}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 3 SOF -PF10 vs 5 untrained", {"n": 3, "ech": "sof", "remove": ["PF10"]}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 3 police vs 5 untrained", {"n": 3, "ech": "police"}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 3 police +PF10 vs 5 untrained", {"n": 3, "ech": "police", "add": ["PF10"]}, {"n": 5, "ech": "untrained"}, "assault", "hold"])
	c.append(["fu 2 SOF vs 5 regular", {"n": 2, "ech": "sof"}, {"n": 5, "ech": "regular"}, "assault", "hold"])
	c.append(["fu 3 SOF (all aggressive) vs 5 regular", {"n": 3, "ech": "sof", "flaws": AGG}, {"n": 5, "ech": "regular"}, "assault", "hold"])
	c.append(["fu 2 SOF vs 5 militia hunting", {"n": 2, "ech": "sof"}, {"n": 5, "ech": "militia"}, "assault", "hunt"])
	c.append(["fu 3 SOF vs 5 regular hunting", {"n": 3, "ech": "sof"}, {"n": 5, "ech": "regular"}, "assault", "hunt"])
	return c


## Third round: which entry habit decides the kitchen fight (regulars lose 37 of 40).
func ablation() -> Array:
	var c: Array = []
	var B := {"n": 5, "ech": "untrained"}
	c.append(["ab 3 regular baseline", {"n": 3, "ech": "regular"}, B, "assault", "hold"])
	c.append(["ab 3 regular +PF04", {"n": 3, "ech": "regular", "add": ["PF04"]}, B, "assault", "hold"])
	c.append(["ab 3 regular +ED03", {"n": 3, "ech": "regular", "add": ["ED03"]}, B, "assault", "hold"])
	c.append(["ab 3 regular +ED10", {"n": 3, "ech": "regular", "add": ["ED10"]}, B, "assault", "hold"])
	c.append(["ab 3 regular +PF03", {"n": 3, "ech": "regular", "add": ["PF03"]}, B, "assault", "hold"])
	c.append(["ab 3 regular +PF04 +ED03", {"n": 3, "ech": "regular", "add": ["PF04", "ED03"]}, B, "assault", "hold"])
	c.append(["ab 3 regular + all 8 police habits", {"n": 3, "ech": "regular", "preset_of": "police"}, B, "assault", "hold"])
	c.append(["ab 3 police-stats regular-habits", {"n": 3, "ech": "police", "preset_of": "regular"}, B, "assault", "hold"])
	c.append(["ab 3 police -PF04", {"n": 3, "ech": "police", "remove": ["PF04"]}, B, "assault", "hold"])
	c.append(["ab 3 police -PF04 -ED03", {"n": 3, "ech": "police", "remove": ["PF04", "ED03"]}, B, "assault", "hold"])
	return c


func _init() -> void:
	var n := 20
	var sel := "all"
	var out := ""
	var set_name := "main"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			set_name = a.trim_prefix("--set=")
		if a.begins_with("--n="):
			n = int(a.trim_prefix("--n="))
		elif a.begins_with("--cells="):
			sel = a.trim_prefix("--cells=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var map_i := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_i = Maps.index_of(a.trim_prefix("--map="))
	var lv = Maps.get_level(map_i)
	var nav = Nav.new()
	nav.build(lv)
	var all := cells()
	if set_name == "followup":
		all = followups()
	elif set_name == "ablate":
		all = ablation()
	var pick: Array = []
	if sel == "all":
		pick = range(all.size())
	else:
		for part in sel.split(","):
			if "-" in part:
				var ab := part.split("-")
				for i in range(int(ab[0]), int(ab[1]) + 1):
					pick.append(i)
			else:
				pick.append(int(part))
	var f: FileAccess = null
	if out != "":
		f = FileAccess.open(out, FileAccess.WRITE)
	for idx in pick:
		if idx >= all.size():
			continue
		var cell: Array = all[idx]
		var r := run_cell(lv, nav, cell, n)
		var line := "%d,%s,%.1f,%.1f,%.1f,%.1f,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f,%.2f,%.1f,%.1f" % [idx, cell[0],
			r["a"], r["b"], r["d"], r["t"], r["ad"], r["bd"], r["ex"], r["ff"], r["ah"], r["bh"], r["stray"], r["as"], r["bs"]]
		print(line)
		if f != null:
			f.store_line(line)
			f.flush()
	quit()


func run_cell(lv, nav, cell: Array, n: int) -> Dictionary:
	var wins := [0, 0, 0]
	var tot := {"t": 0.0, "ad": 0, "bd": 0, "ff": 0, "as": 0, "ah": 0, "bs": 0, "bh": 0, "stray": 0}
	for s in n:
		var cfgs: Array = Teams.team(lv, 0, cell[1]) + Teams.team(lv, 1, cell[2])
		var w = World.new()
		w.keep_events = false
		w.setup(lv, nav, cfgs, [cell[3], cell[4]], 7000 + s)
		while not w.over:
			w.step()
		wins[w.winner] += 1
		tot["t"] += w.t
		tot["ff"] += w.stat["friendly"]
		tot["stray"] += w.stat["stray"]
		for o in w.ops:
			var down := 0 if o.alive() else 1
			if o.team == 0:
				tot["ad"] += down
				tot["as"] += o.shots
				tot["ah"] += o.hits
			else:
				tot["bd"] += down
				tot["bs"] += o.shots
				tot["bh"] += o.hits
		w.dispose()
	return {"a": 100.0 * wins[0] / n, "b": 100.0 * wins[1] / n, "d": 100.0 * wins[2] / n,
		"t": tot["t"] / n, "ad": float(tot["ad"]) / n, "bd": float(tot["bd"]) / n,
		"ex": float(tot["bd"]) / maxf(1.0, tot["ad"]), "ff": float(tot["ff"]) / n,
		"ah": 100.0 * tot["ah"] / maxf(1.0, tot["as"]), "bh": 100.0 * tot["bh"] / maxf(1.0, tot["bs"]),
		"stray": float(tot["stray"]) / n, "as": float(tot["as"]) / n, "bs": float(tot["bs"]) / n}
