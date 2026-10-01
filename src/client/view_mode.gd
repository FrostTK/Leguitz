class_name ViewMode
extends RefCounted
## Chooses between the top-down view and the first-person view. Entering a
## cave (thick rock over the player's head) goes first person when the
## setting allows it, the open sky brings the top-down view back. F5 (see
## toggle) switches by hand, until the player next enters or leaves a cave.

var first_person := false
## Automatic first person in caves (Settings.cave_first_person).
var automatic := true

var _in_cave := false
var _manual := false


## Called every frame: `covered` when terrain is over the player's head,
## `deep` when it is thick rock (a cave). Between the two (a roof, a thin
## overhang) nothing changes, so the view does not flicker at cave mouths.
func update(covered: bool, deep: bool) -> void:
	if not _in_cave and deep:
		_in_cave = true
		_manual = false
		if automatic:
			first_person = true
	elif _in_cave and not covered:
		_in_cave = false
		_manual = false
		if automatic:
			first_person = false


## Switches by hand (F5).
func toggle() -> void:
	first_person = not first_person
	_manual = true


## The setting changed: the view follows it unless chosen by hand.
func set_automatic(value: bool) -> void:
	automatic = value
	if not _manual:
		first_person = automatic and _in_cave
