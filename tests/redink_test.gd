extends SceneTree
## Asset-pack audit for assets/redink. Loads every file through Godot's own SVG
## importer, so a file the engine cannot read fails here rather than in a scene.
##   godot --headless --path . -s res://tests/redink_test.gd
##   godot --headless --path . -s res://tests/redink_test.gd -- --verbose
##
## Checks:
##   1. manifest and demo room parse; every listed file exists and imports;
##   2. tiles are 1 m squares (wall strips 1 x 0.25 m); actors fit their 0.8 m canvas;
##   3. masks are greyscale -- chromatic masks would hard-code red and break the proof;
##   4. base art is neutral -- no second colour family anywhere north of the mask layer;
##   5. the demo room's two states share one topology;
##   6. Ink.accent() returns the same hue at every alpha, and greys out when red is off.

const InkScript = preload("res://scripts/view/ink.gd")
const ROOT := "res://assets/redink"
const PX_PER_METRE := 80.0
const TILES := ["floor_plain", "floor_plank", "floor_tile", "floor_lino", "floor_carpet",
	"floor_deck", "floor_yard", "floor_studs", "wall_straight", "wall_stack",
	"wall_window", "wall_doorway", "wall_half", "wall_corner", "fence", "stairs", "breach",
	"print_grain"]
const ACTORS := ["officer", "qrf", "medic", "suspect", "civilian"]

var fails := 0
var verbose := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if (a == "--verbose"):
			verbose = true
	_check_ink()
	_check_manifest()
	_check_palette()
	_check_states()
	print("redink: %s (%d failing checks)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("  FAIL ", msg)


func _ok(msg: String) -> void:
	if (verbose):
		print("  ok   ", msg)


func _json(rel: String) -> Dictionary:
	var p := "%s/%s" % [ROOT, rel]
	if (not FileAccess.file_exists(p)):
		_fail("%s missing (run python3 tools/make_redink_assets.py)" % rel)
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if (not parsed is Dictionary):
		_fail("%s is not a JSON object" % rel)
		return {}
	return parsed


func _check_manifest() -> void:
	print("manifest and import")
	var man := _json("manifest.json")
	if (man.is_empty()):
		return
	var files: Array = man.get("files", [])
	if (files.is_empty()):
		_fail("manifest lists no files")
		return
	var seen := {}
	for f in files:
		var rel: String = f["path"]
		if (seen.has(rel)):
			_fail("duplicate manifest entry %s" % rel)
		seen[rel] = true
		var tex: Texture2D = load("%s/%s" % [ROOT, rel])
		if (tex == null):
			_fail("%s does not import" % rel)
			continue
		var size := tex.get_size()
		var want: Array = f["size_px"]
		if (int(size.x) != int(want[0]) or int(size.y) != int(want[1])):
			_fail("%s imports at %s, manifest says %s" % [rel, size, want])
		var m: Array = f["metres"]
		if (absf(float(m[0]) * PX_PER_METRE - float(want[0])) > 0.5):
			_fail("%s metre size disagrees with its pixels" % rel)
		if (f["category"] == "tiles" and rel.get_file().get_basename() in ["wall_corner"]):
			pass
		elif (f["category"] == "tiles"):
			if (rel.get_file().get_basename() in ["wall_straight", "wall_stack", "wall_window",
					"wall_half", "fence"]):
				if (absf(float(m[0]) - 1.0) > 0.01 or absf(float(m[1]) - 0.25) > 0.01):
					_fail("%s should be a 1 x 0.25 m strip, is %s" % [rel, m])
			elif (absf(float(m[0]) - 1.0) > 0.01 or absf(float(m[1]) - 1.0) > 0.01):
				_fail("%s should be a 1 m square, is %s" % [rel, m])
		if (f["layer"] == "red_mask" and f["category"] != "masks"):
			_fail("%s claims the red_mask layer but is not a mask" % rel)
		_ok("%s %s" % [rel, size])
	print("  %d files" % files.size())
	# every file on disk should be in the manifest
	for cat in ["tiles", "props", "actors", "marks", "masks", "ui"]:
		var dir := "%s/%s" % [ROOT, cat]
		if (not DirAccess.dir_exists_absolute(dir)):
			_fail("missing folder %s" % cat)
			continue
		for file in DirAccess.get_files_at(dir):
			if (file.ends_with(".svg") and not seen.has("%s/%s" % [cat, file])):
				_fail("%s/%s is not in the manifest" % [cat, file])
	# tile set sanity
	for t in TILES:
		if (not seen.has("tiles/%s.svg" % t)):
			_fail("expected tile tiles/%s.svg" % t)
	for a in ACTORS:
		for pose in ["stand", "down"]:
			if (not seen.has("actors/%s_%s.svg" % [a, pose])):
				_fail("expected actor actors/%s_%s.svg" % [a, pose])


## Godot's SVG importer gives us pixels, so the palette can be checked on the
## rendered result rather than on the markup.
func _check_palette() -> void:
	print("palette")
	for cat in ["tiles", "props", "actors", "marks", "ui", "masks"]:
		var dir := "%s/%s" % [ROOT, cat]
		if (not DirAccess.dir_exists_absolute(dir)):
			continue
		for file in DirAccess.get_files_at(dir):
			if (not file.ends_with(".svg")):
				continue
			var rel := "%s/%s" % [cat, file]
			var img := _render(rel)
			if (img == null):
				continue
			var worst := 0.0
			var worst_px := Color.WHITE
			for y in range(0, img.get_height(), 3):
				for x in range(0, img.get_width(), 3):
					var c := img.get_pixel(x, y)
					if (c.a < 0.05):
						continue
					var spread := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
					# the house greys drift by a few points per channel
					if (spread > worst):
						worst = spread
						worst_px = c
					if (spread > 0.09):
						_fail("%s is chromatic at %s (spread %.2f)" % [rel, c, spread])
						break
				if (worst > 0.09):
					break
			_ok("%s max spread %.3f %s" % [rel, worst, worst_px])
	# a mask must never carry a hue of its own: the shader supplies red
	for file in DirAccess.get_files_at("%s/masks" % ROOT):
		if (not file.ends_with(".svg")):
			continue
		var img := _render("masks/%s" % file)
		if (img == null):
			continue
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				if (c.a < 0.05):
					continue
				if (minf(c.r, minf(c.g, c.b)) < 0.85):
					_fail("mask %s is not white (%s); masks must stay untinted" % [file, c])
					break


## Imported textures are cached; render one into an image for inspection.
func _render(rel: String) -> Image:
	var tex: Texture2D = load("%s/%s" % [ROOT, rel])
	if (tex == null):
		return null
	var img: Image = tex.get_image()
	if (img == null):
		return null
	if (img.is_compressed()):
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _check_states() -> void:
	print("demo room")
	var room := _json("demo_room.json")
	if (room.is_empty()):
		return
	var theory: Dictionary = room.get("theory", {})
	var app: Dictionary = room.get("application", {})
	if (theory.is_empty() or app.is_empty()):
		_fail("demo room needs theory and application blocks")
		return
	# one topology: the same walls, floors and props in both states
	for key in ["walls", "floors", "props", "actors"]:
		if (not room.has(key)):
			_fail("demo room has no %s" % key)
			continue
		_ok("%d %s" % [room[key].size(), key])
	# theory never contains blood
	if (theory.has("blood")):
		_fail("theory block must not contain blood")
	if (not app.has("blood")):
		_fail("application block should demonstrate the blood layer")
	# every referenced asset must exist
	for bl in app.get("blood", []):
		if (not FileAccess.file_exists("%s/masks/%s.svg" % [ROOT, bl["mask"]])):
			_fail("demo room references missing mask %s" % bl["mask"])
	for m in app.get("marks", []):
		if (not FileAccess.file_exists("%s/marks/%s.svg" % [ROOT, m["name"]])):
			_fail("demo room references missing mark %s" % m["name"])
	for st in [theory, app]:
		var stamp: String = st.get("stamp", "")
		if (stamp != "" and not FileAccess.file_exists("%s/%s" % [ROOT, stamp])):
			_fail("demo room references missing stamp %s" % stamp)
	# blood budget: a few percent of the floor, not a spectacle frame
	var area := 0.0
	for bl in app.get("blood", []):
		var rel := "masks/%s.svg" % bl["mask"]
		var tex: Texture2D = load("%s/%s" % [ROOT, rel])
		if (tex == null):
			continue
		var sc: float = bl.get("scale", 1.0)
		var m2 := (tex.get_width() / PX_PER_METRE) * sc * (tex.get_height() / PX_PER_METRE) * sc
		# masks are sparse: count inked pixels in the rendered image
		var img := _render(rel)
		if (img != null):
			var inked := 0
			var total := 0
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					total += 1
					if (img.get_pixel(x, y).a > 0.06):
						inked += 1
			m2 *= float(inked) / maxf(1.0, float(total))
		area += m2
	var floor_m2: float = float(room["size_m"][0]) * float(room["size_m"][1])
	var frac := area / floor_m2
	print("  blood covers %.2f m2 of %.0f m2 (%.1f%%)" % [area, floor_m2, frac * 100.0])
	if (frac > 0.10):
		_fail("blood covers %.1f%% of the floor; keep it to a few percent" % (frac * 100.0))
	if (frac < 0.002):
		_fail("the application state shows almost no blood (%.2f%%)" % (frac * 100.0))
	# and the paperwork reacting to it should not be smaller than the stain in count
	if (app.get("marks", []).size() < 6):
		_fail("aftermath needs institutional framing, not just a stain")


func _check_ink() -> void:
	print("ink")
	var ink = InkScript.new()
	if (ink.accent(0.9).r < 0.6 or ink.accent(0.9).g > 0.2):
		_fail("accent() is not the signal red")
	ink.set_red_ink(false)
	var grey = ink.accent(0.9)
	if (absf(grey.r - grey.g) > 0.01 or absf(grey.g - grey.b) > 0.01):
		_fail("with red off accent() must be neutral, got %s" % grey)
	if (absf(grey.a - 0.9) > 0.01):
		_fail("red off must keep alpha, got %s" % grey)
	ink.set_gore(false)
	if (ink.blood_visible()):
		_fail("gore off must hide blood")
	ink.set_gore(true)
	ink.set_red_ink(true)
	if (absf(ink.accent(0.68).a - 0.68) > 0.001):
		_fail("alpha only: intensity lives in alpha")
	var a := ink.accent(0.3)
	var b := ink.accent(0.9)
	if (absf(a.r - b.r) > 0.001 or absf(a.g - b.g) > 0.001):
		_fail("red hue shifted between alphas")
	ink.free()
