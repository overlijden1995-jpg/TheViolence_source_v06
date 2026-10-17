extends SceneTree
## Compile check: loads every script so parse errors surface.
func _init() -> void:
	var dirs := ["res://scripts/sim", "res://scripts/data", "res://scripts/maps", "res://scripts/view", "res://scripts/ui", "res://scripts", "res://scripts/city"]
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null:
					print("FAILED ", d, "/", f)
	print("check done")
	quit()
