class_name GameModeView
extends Node
## The world's game mode on the client (the server decides, GameModes;
## Msg.GAME_MODE). In creative the player flies (two presses of jump,
## LocalPlayer.can_fly), breaks at once (BlockInteraction), places without
## using up their blocks, finds every item in the inventory's catalog, has
## no gauges and the debug keys (ghost, weather, tools, caves, map: see
## debug_key). In hardcore, once the player passed out and chose to watch
## (DeathScreen), they are a spectator: a ghost flying through everything,
## unseen, without a hand nor gauges, a line at the bottom of the screen
## saying why.

## The spectator's line: how far over the bottom of the screen (UI units).
const BANNER_MARGIN := 10.0

var client: GameClient
## WorldSettings.GameMode, as the server last told.
var mode := WorldSettings.GameMode.SURVIVAL
## The player's one life is over (hardcore): they only watch the world
## once they chose to (watching).
var spectator := false
var watching := false
## Says the player only watches (added to the UI by GameClient).
var banner := Label.new()

## The material whose tools the debug key gives next (Items.Tier).
var _tools_tier := 0


func _ready() -> void:
	banner.text = "SPECTATOR_BANNER"
	banner.add_theme_color_override("font_color", Color.WHITE)
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	banner.add_theme_constant_override("font_outline_size", 2)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	banner.offset_top = -BANNER_MARGIN
	banner.offset_bottom = -BANNER_MARGIN
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false


func creative() -> bool:
	return mode == WorldSettings.GameMode.CREATIVE


## The server told the mode, and whether the player only watches (they
## start watching at once unless the death screen is up: then when they
## choose to).
func on_game_mode(new_mode: int, is_spectator: bool) -> void:
	mode = new_mode as WorldSettings.GameMode
	spectator = is_spectator
	client.local_player.can_fly = creative()
	if not creative():
		client.local_player.noclip = false
	client.inventory_screen.creative = creative()
	client.pause_menu.game_mode = mode
	if client.pause_menu.visible:
		client.pause_menu.refresh_from_state()
	if spectator and not client.vitals.passed_out:
		watch()
	_update_hud()


## The spectator starts watching the world (after the death screen).
func watch() -> void:
	watching = true
	client.interaction.stop()
	client.inventory_screen.close()
	client.book_screen.close()
	client.book_in_hand = false
	client.local_player.ghost = true
	client.local_player.controls_enabled = true
	client.player_model.set_ghost(true)
	_update_hud()


## The gauges only in survival and hardcore; a spectator has no hand.
func _update_hud() -> void:
	client.hotbar.visible = not watching
	client.hotbar.vitals.visible = not creative() and not watching
	banner.visible = watching


## The debug keys, for creative players: the map, the next cave down or
## up, the weather, the ghost mode, a set of tools. Returns true when the
## event was one of them.
func debug_key(event: InputEvent) -> bool:
	if not creative():
		return false
	if event.is_action_pressed(InputBindings.TOGGLE_MAP):
		client.debug_map.cycle(client.local_player.current_tile(), client.map_row())
	elif event.is_action_pressed(InputBindings.DEPTH_UP):
		client.transport.send(Msg.debug_move_depth(1))
	elif event.is_action_pressed(InputBindings.DEPTH_DOWN):
		client.transport.send(Msg.debug_move_depth(-1))
	elif event.is_action_pressed(InputBindings.CYCLE_WEATHER):
		var next := (client.weather_effects.weather.kind + 1) % Weather.Kind.size()
		client.transport.send(Msg.debug_set_weather(next))
	elif event.is_action_pressed(InputBindings.TOGGLE_NOCLIP):
		client.local_player.noclip = not client.local_player.noclip
	elif event.is_action_pressed(InputBindings.GIVE_TOOLS):
		client.transport.send(Msg.debug_give_tools(_tools_tier))
		client.hotbar.announce("HUD_TOOLS_" + String(Items.Tier.find_key(_tools_tier)))
		_tools_tier = (_tools_tier + 1) % Items.Tier.size()
	else:
		return false
	return true
