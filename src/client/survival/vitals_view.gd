class_name VitalsView
extends Node
## What the player sees of their vitality (the server keeps it, Vitals):
## the gauge over the hotbar, a hurt reddening the body and pulsing the
## screen's edges, and passing out: the body lies down, screens close, the
## world darkens and says why (DeathScreen) until the player gets up.

## A hurt reddens the body this long; passing out lays it down this fast.
const HURT_GLOW_SECONDS := 0.35
const DOWN_SECONDS := 0.4

var client: GameClient
## Where it shows (added to the UI by GameClient).
var screen := DeathScreen.new()
## The vitality the server told, and whether the player passed out
## (waiting to get up).
var health := Vitals.MAX_HEALTH
var passed_out := false

var _hurt_glow := 0.0
var _down := 0.0


func _ready() -> void:
	screen.respawn_requested.connect(func() -> void: client.transport.send(Msg.respawn()))


## The vitality the server tells; a hurt flashes the body and the screen's
## edges red. Back above 0 after passing out: up again.
func on_health(points: int, hurt: bool) -> void:
	health = points
	client.hotbar.vitals.set_health(points)
	if hurt:
		_hurt_glow = 1.0
		screen.flash()
	if passed_out and points > 0:
		passed_out = false
		screen.close()
		client.local_player.controls_enabled = true
		if client.view_mode.first_person:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The player passed out from `cause` (Vitals.Cause).
func on_passed_out(cause: int) -> void:
	passed_out = true
	client.interaction.stop()
	client.inventory_screen.close()
	client.book_screen.close()
	client.local_player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	screen.open(cause)


func _process(delta: float) -> void:
	if client == null:
		return
	_hurt_glow = maxf(_hurt_glow - delta / HURT_GLOW_SECONDS, 0.0)
	client.player_model.set_hurt(_hurt_glow)
	_down = move_toward(_down, 1.0 if passed_out else 0.0, delta / DOWN_SECONDS)
	client.player_model.set_down(smoothstep(0.0, 1.0, _down))
