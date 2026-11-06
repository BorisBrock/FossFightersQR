class_name Boss
extends RefCounted
## One boss. What all bosses have in common lives here: the text for the menus, the
## pictures, how the fight looks and the rules every boss follows.
##
## Each boss is a script in scripts/bosses/ that extends this one. It fills in its data in
## _init() and overrides the hooks below for whatever makes it special. A boss with no
## special rules overrides nothing but _init(). See docs/bosses.md.

## The drifting particles over the background. All are tinted with ambience_color.
enum Ambience {
	## Rising from the bottom, like sparks from a fire.
	EMBERS,
	## Floating everywhere and fading in and out.
	FIREFLIES,
	## Drifting slowly across the screen.
	DUST,
}

## How the boss moves while it waits, anchored at its feet.
enum Motion {
	## Grows a little taller and back, like taking deep breaths.
	BREATHE,
	## Floats up and down, for anything with wings.
	HOVER,
	## Leans from side to side.
	SWAY,
}

## Set from its file name by Bosses.
var id := ""

#region Menus
## For the boss list, the overview and the fight. All text is { "de": …, "en": … }.
var title := {}
var tagline := {}
## A few sentences for the overview.
var story := {}
## Short strategy hints for the overview, as many as needed.
var hints: Array[Dictionary] = []
## The picture in the boss list and the overview: landscape, 4:3.
var art := ""
#endregion

#region Fight
## The boss itself, centred and large: portrait, transparent around it.
var figure := ""
## Behind the boss, covering the screen: portrait, 9:16.
var background := ""
## Health on normal difficulty. The difficulty scales it (Bosses.DIFFICULTIES).
var health := 40
var ambience := Ambience.EMBERS
var ambience_color := Color(1.0, 0.7, 0.35)
## The colour of the mist that drifts over the ground of the background.
var mist_color := Color(0.8, 0.8, 0.8)
var motion := Motion.BREATHE
## How far the boss moves, in pixels of its picture.
var motion_amount := 12.0
## How long one movement takes, back and forth.
var motion_seconds := 4.0
#endregion


## The health the boss starts with on a difficulty.
func max_health(difficulty: String) -> int:
	return maxi(1, roundi(health * Bosses.DIFFICULTIES[difficulty].health_factor))


#region Hooks for special rules
# Each is called by the fight at the moment its name says. The defaults do what a boss
# without special rules does. The fight passes itself, so a boss can read and change it.

func fight_started(_fight: Fight) -> void:
	pass


func round_started(_fight: Fight) -> void:
	pass


## Returns the damage the boss really takes from an attack of amount, for bosses that
## resist or are weak to something. kind is the attack's symbol, such as "attack".
func damage_taken(_fight: Fight, amount: int, _kind: String) -> int:
	return amount
#endregion
