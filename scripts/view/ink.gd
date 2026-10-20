extends Node
## The Violence -- red-ink palette and presentation toggles (autoload "Ink").
##
## Red is the only colour that makes it onto the page, and it is never baked into
## base art: the pack in assets/redink stores red marks as white masks and this
## node supplies the hue. Intensity is alpha only, so nothing here ever shifts hue.
##
## Presentation only. Nothing in this file may change hitboxes, visibility, fog of
## war or rules: red_ink_enabled, gore_enabled and state are for drawing.

signal palette_changed

const PAPER := Color(0.93, 0.93, 0.91)      # #EDEDE8
const FLOOR := Color(0.83, 0.83, 0.81)      # #D4D4CF
const LIGHT := Color(0.75, 0.75, 0.73)      # #BFBFBA
const MID := Color(0.45, 0.45, 0.44)        # #737370
const DARK := Color(0.17, 0.17, 0.17)       # #2B2B2B
const INK := Color(0.07, 0.07, 0.07)        # #121212
const RED := Color(0.70, 0.12, 0.15)        # #B31F26
const MONO := Color(0.36, 0.36, 0.36)       # what red becomes with red ink off

var red_ink_enabled := true
var gore_enabled := true
var state := "theory"                       # "theory" or "application"


## Every red mark in the game goes through here.
func accent(alpha: float) -> Color:
	if (red_ink_enabled):
		return Color(RED.r, RED.g, RED.b, alpha)
	return Color(MONO.r, MONO.g, MONO.b, alpha)


func set_red_ink(enabled: bool) -> void:
	if (red_ink_enabled == enabled):
		return
	red_ink_enabled = enabled
	palette_changed.emit()


func set_gore(enabled: bool) -> void:
	if (gore_enabled == enabled):
		return
	gore_enabled = enabled
	palette_changed.emit()


func set_state(next_state: String) -> void:
	if (next_state != "theory" and next_state != "application"):
		return
	if (state == next_state):
		return
	state = next_state
	palette_changed.emit()


## Blood is application-only and obeys the gore toggle. Evidence markers, forms
## and beacons do not: with gore off the implication stays.
func blood_visible() -> bool:
	return gore_enabled and red_ink_enabled


func is_theory() -> bool:
	return state == "theory"


## Shader materials take the same flag as a uniform, so textured assets follow
## the toggle without a second code path.
func apply_material(mat: ShaderMaterial) -> void:
	if (mat == null):
		return
	if (mat.shader != null and mat.shader.code.findn("red_ink_enabled") >= 0):
		mat.set_shader_parameter("red_ink_enabled", red_ink_enabled)
