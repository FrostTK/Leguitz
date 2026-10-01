class_name DebugOverlay
extends PanelContainer
## F3 debug screen (like Minecraft): performance, position, world and time.

const REFRESH_INTERVAL := 0.25

var client: GameClient
## Optional: extra lines supplied by the integrated server (solo only).
var server_stats: Callable

var _label := Label.new()
var _refresh_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)
	_label.add_theme_font_size_override("font_size", 6)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	add_child(_label)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 4)
	visible = Settings.show_debug


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputBindings.TOGGLE_DEBUG):
		visible = not visible
		Settings.set_show_debug(visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or client == null:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	_label.text = "\n".join(_lines())


func _lines() -> PackedStringArray:
	var info := client.world_info
	var player := client.local_player
	var tile := player.current_tile()
	var chunk := Coords.tile_to_chunk(tile)
	var clock := client.clock
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	var mode_key: String = WorldSettings.GAME_MODE_KEYS.get(int(info.get("game_mode", 1)), "")
	var gpu := RenderingServer.get_video_adapter_name()
	var renderer := RenderingServer.get_current_rendering_method()
	var ground: String = Tiles.Ground.find_key(client.world.ground_at(tile))
	var layer := client.world.layer
	var layer_name := tr("LAYER_SURFACE") if layer >= 0 else tr("LAYER_UNDERGROUND") % -layer

	var world_args := [
		tr("DEBUG_WORLD"),
		info.get("world_name", "?"),
		tr("DEBUG_SEED"),
		info.get("world_seed", "?"),
		tr(mode_key),
	]
	var position_args := [
		tr("DEBUG_POSITION"),
		player.position.x,
		player.position.y,
		player.height,
		tr("DEBUG_TILE"),
		tile.x,
		tile.y,
		chunk.x,
		chunk.y,
	]
	var ground_args := [
		tr("DEBUG_LAYER"),
		layer_name,
		tr("DEBUG_BIOME"),
		tr(Biomes.name_key(client.world.biome_at(tile))),
		tr("DEBUG_LEVEL"),
		client.world.level_at(tile),
		tr("DEBUG_GROUND"),
		ground,
	]
	var time_args := [
		tr("DEBUG_DAY"),
		clock.day_index() + 1,
		clock.formatted_time(),
		_time_mode_text(clock),
		tr("DEBUG_PACE"),
		clock.pace_factor(),
		tr("DEBUG_MOON"),
		clock.moon_phase(),
	]
	var view_args := [
		tr("DEBUG_CHUNKS"),
		client.world_view.visible_chunk_count(),
		client.view_distance,
		client.world_view.lod,
		client.world_viewport.world_zoom,
		" HD" if client.world_viewport.hd else "",
		int(get_window().content_scale_factor),
		rad_to_deg(client.world_viewport.yaw),
		rad_to_deg(client.world_viewport.pitch),
	]

	var lines := PackedStringArray()
	lines.append("Leguitz %s  |  %d FPS" % [version, Engine.get_frames_per_second()])
	lines.append("GPU: %s  |  %s" % [gpu, renderer])
	lines.append("%s: %s  |  %s: %s  |  %s" % world_args)
	lines.append("%s: %.1f, %.1f, h %.2f  |  %s: %d, %d  |  Chunk: %d, %d" % position_args)
	lines.append("%s: %s  |  %s: %s  |  %s %d  |  %s: %s" % ground_args)
	if player.noclip:
		lines.append(tr("DEBUG_NOCLIP"))
	lines.append("%s %d  %s  |  %s  |  %s x%.2f  |  %s %d/8" % time_args)
	lines.append("%s: %d (r%d, LOD %d)  |  Zoom x%d%s  |  UI x%d  |  Cam %.0f / %.0f" % view_args)
	if server_stats.is_valid():
		lines.append_array(server_stats.call())
	return lines


func _time_mode_text(clock: WorldClock) -> String:
	match clock.mode:
		WorldClock.Mode.NORMAL:
			return tr("TIME_MODE_NORMAL") + " (" + tr("DAY_LENGTH_VALUE") % clock.day_minutes + ")"
		WorldClock.Mode.SYNCED:
			return tr("TIME_MODE_SYNCED")
		_:
			return tr("TIME_MODE_FROZEN")
