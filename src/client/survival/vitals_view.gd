class_name VitalsView
extends Node
## What the player sees of their vitality and satiety (the server keeps
## them, Vitals): the gauges over the hotbar, a hurt reddening the body and
## pulsing the screen's edges, passing out (the body lies down, screens
## close, the world darkens and says why, DeathScreen, until the player
## gets up), air (a breath gauge while the eye is under water; a blue veil
## over the first-person view), and eating: food in hand, the right button (or the left
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
	Items.Id.CARROT: Color("e8792a"),
	Items.Id.POTATO: Color("c9a66b"),
	Items.Id.BAKED_POTATO: Color("b8853f"),
	Items.Id.BREAD: Color("c98a3e"),
}
const CRUMB_SECONDS := 0.22
## The veil over the first-person view with the eye in water or lava.
const WATER_VEIL := Color(0.06, 0.22, 0.45, 0.42)
const LAVA_VEIL := Color(0.9, 0.3, 0.05, 0.6)

var client: GameClient
## Where it shows (added to the UI by GameClient), and the veil under
## water.
var screen := DeathScreen.new()
var veil := ColorRect.new()
## The vitality the server told, and whether the player passed out
## (waiting to get up).
var health := Vitals.MAX_HEALTH
var food := Vitals.MAX_FOOD
var passed_out := false
## Eating now, and for how long (the arm and the first-person hand bob).
var eating := false
var eat_time := 0.0
## What the dishes eaten do (Effects: kind -> seconds left, as the server
## told, running out here too).
var effects := {}

var _hurt_glow := 0.0
var _down := 0.0
var _wanted := false
var _eaten := Items.Id.NONE
var _crumb_left := 0.0


func _ready() -> void:
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.visible = false
	screen.respawn_requested.connect(_on_get_up)


## The vitality and satiety the server tells; a hurt flashes the body and
## the screen's edges red. Back above 0 after passing out: up again.
func on_vitals(points: int, satiety: int, hurt: bool, air: float) -> void:
	health = points
	food = satiety
	client.hotbar.vitals.set_health(points)
	client.hotbar.vitals.set_food(satiety)
	client.hotbar.vitals.set_air(air)
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


## The effects as the server tells them (Msg.VITALS).
func on_effects(told: Dictionary) -> void:
	effects = Effects.from_dict(told)
	client.hotbar.effects.set_effects(effects)


## The player passed out from `cause` (Vitals.Cause).
func on_passed_out(cause: int) -> void:
	passed_out = true
	client.interaction.stop()
	client.inventory_screen.close()
	client.book_screen.close()
	client.local_player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	screen.open(cause, client.modes.mode == WorldSettings.GameMode.HARDCORE)


## The death screen's button: up again at the spawn (the server says so,
## Msg.VITALS), or in hardcore, watching the world (GameModeView).
func _on_get_up() -> void:
	if not client.modes.spectator:
		client.transport.send(Msg.respawn())
		return
	passed_out = false
	screen.close()
	client.modes.watch()
	if client.view_mode.first_person:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if client == null:
		return
	_hurt_glow = maxf(_hurt_glow - delta / HURT_GLOW_SECONDS, 0.0)
	client.player_model.set_hurt(_hurt_glow)
	_down = move_toward(_down, 1.0 if passed_out else 0.0, delta / DOWN_SECONDS)
	client.player_model.set_down(smoothstep(0.0, 1.0, _down))
	_update_eating(delta)
	_update_veil()
	if not effects.is_empty():
		Effects.wear(effects, delta)
		client.hotbar.effects.set_effects(effects)
	var swift := Effects.has(effects, Effects.Kind.SWIFT)
	client.local_player.speed_bonus = Effects.SWIFT_SPEED if swift else 1.0
	client.hotbar.vitals.set_defense(Armor.defense(client.inventory))


## First person with the eye in water or lava: the view is veiled.
func _update_veil() -> void:
	var player := client.local_player
	var eye := PlayerBody.liquid_at(
		player.position, player.height + PlayerBody.EYE_HEIGHT, client.world.voxel_at
	)
	veil.visible = client.first_person >= 1.0 and eye != Voxels.AIR
	if veil.visible:
		var lava := Voxels.is_lava(eye)
		veil.color = LAVA_VEIL if lava else WATER_VEIL


## Eats while the player holds the button with food in hand (not when
## full, but for dishes with effects: said over the hotbar once).
func _update_eating(delta: float) -> void:
	var wants := client.wants_to_eat()
	var item := client.held_item()
	var full := food >= Vitals.MAX_FOOD and not Effects.gives(item)
	if wants and not _wanted and full:
		client.hotbar.announce(tr("HUD_NOT_HUNGRY"))
	_wanted = wants
	if not wants or full or item != _eaten:
		eat_time = 0.0
	_eaten = item
	eating = wants and not full
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
