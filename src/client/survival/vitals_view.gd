class_name VitalsView
extends Node
## What the player sees of their vitality and satiety (the server keeps
## them, Vitals): the gauges over the hotbar, a hurt reddening the body and
## pulsing the screen's edges, passing out (the body lies down, screens
## close, the world darkens and says why, DeathScreen, until the player
## gets up), and eating: food in hand, the right button (or the left
## trigger) held, one is eaten every Vitals.EAT_SECONDS (the arm at the
## mouth, crumbs), predicted and told to the server (Msg.EAT).

## A hurt reddens the body this long; passing out lays it down this fast.
const HURT_GLOW_SECONDS := 0.35
const DOWN_SECONDS := 0.4
## Crumbs flying off each food while it is eaten.
const CRUMBS := {
	Items.Id.BERRIES: Color("c4283a"),
	Items.Id.DRIED_BERRIES: Color("6e1d2a"),
	Items.Id.MUSHROOM_RED: Color("c7302f"),
	Items.Id.MUSHROOM_BROWN: Color("8a5a3a"),
	Items.Id.MUSHROOM_STEW: Color("8a4a2a"),
	Items.Id.CHARRED_FOOD: Color("1f1a19"),
}
const CRUMB_SECONDS := 0.22

var client: GameClient
## Where it shows (added to the UI by GameClient).
var screen := DeathScreen.new()
## The vitality the server told, and whether the player passed out
## (waiting to get up).
var health := Vitals.MAX_HEALTH
var food := Vitals.MAX_FOOD
var passed_out := false
## Eating now, and for how long (the arm and the first-person hand bob).
var eating := false
var eat_time := 0.0

var _hurt_glow := 0.0
var _down := 0.0
var _wanted := false
var _eaten := Items.Id.NONE
var _crumb_left := 0.0


func _ready() -> void:
	screen.respawn_requested.connect(func() -> void: client.transport.send(Msg.respawn()))


## The vitality and satiety the server tells; a hurt flashes the body and
## the screen's edges red. Back above 0 after passing out: up again.
func on_vitals(points: int, satiety: int, hurt: bool) -> void:
	health = points
	food = satiety
	client.hotbar.vitals.set_health(points)
	client.hotbar.vitals.set_food(satiety)
	client.local_player.can_sprint = satiety >= Vitals.WEAK
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
	_update_eating(delta)


## Eats while the player holds the button with food in hand (not when
## full: said over the hotbar once).
func _update_eating(delta: float) -> void:
	var wants := client.wants_to_eat()
	if wants and not _wanted and food >= Vitals.MAX_FOOD:
		client.hotbar.announce(tr("HUD_NOT_HUNGRY"))
	_wanted = wants
	var item := client.held_item()
	if not wants or food >= Vitals.MAX_FOOD or item != _eaten:
		eat_time = 0.0
	_eaten = item
	eating = wants and food < Vitals.MAX_FOOD
	client.player_model.eating = eating
	if not eating:
		return
	eat_time += delta
	_crumb_left -= delta
	if _crumb_left <= 0.0:
		_crumb_left = CRUMB_SECONDS
		client.interaction.crumbs(CRUMBS.get(item, Color.SADDLE_BROWN))
	if eat_time >= Vitals.EAT_SECONDS:
		eat_time = 0.0
		var slot := client.inventory.selected
		client.inventory.take(slot, 1)
		client.transport.send(Msg.eat(slot))
		food = mini(food + Items.FOOD.get(item, 0), Vitals.MAX_FOOD)
