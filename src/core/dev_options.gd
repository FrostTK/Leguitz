class_name DevOptions
extends RefCounted
## Developer command-line options, passed after "--":
##   godot --path . -- --seed=42 --spawn=100,-40 --time=21.5 --screenshot=shot.png
##
## --seed=TEXT          world seed (number or any text): a throwaway world,
##                      never saved, or with --new-world the new world's seed
## --new-world          start the saved world over (the old one is deleted)
## --world=NAME         play the saved world NAME (folder in user://worlds/)
## --spawn=X,Y          spawn tile override
## --time=HOURS         start time of day (e.g. 6.5, 21)
## --time-mode=MODE     normal | synced | frozen
## --day-minutes=N      day length for normal mode
## --game-mode=MODE     creative | survival | hardcore
## --debug              show the F3 overlay
## --hide-debug         hide it (screenshots, whatever the settings say)
## --lang=CODE          fr | en
## --zoom=N             world zoom
## --screenshot=PATH    save a screenshot once the world is ready, then quit
## --screenshot-delay=N extra frames to wait before the screenshot (default 10)
## --autowalk=DX,DY     hold a movement direction once the world is ready
## --jump               hold the jump key once the world is ready
## --pause-menu         open the pause menu once the world is ready
## --descend=N          go down N caves (negative: up), like Page Down
## --noclip             start in debug ghost mode
## --map                open the debug map once the world is ready
## --weather=KIND       clear | rain | thunder
## --quality=N          graphics quality 0 (low) to 3 (ultra)
## --hd                 render the 3D world at full resolution
## --camera=YAW,PITCH   camera orbit angles in degrees (default 0,60)
## --first-person       start in first person (like F5)
## --look=PITCH         first-person look pitch in degrees (default -11)
## --dive=T             hold the dive into first person at T (0..1)
## --aim=X,Y            aim at this point (screen units from its center)
## --mine               hold the break button once the world is ready
## --place              place a block at what is aimed at, once
## --give=ITEM:N,...    put items in the inventory (dirt:20,diamond:3...)
## --animals=KIND:N,... bring animals around the player (sheep:3,deer:2...)
## --inventory          open the inventory once the world is ready
## --drop               throw the stack in hand once the world is ready
## --book[=SPREAD]      open the player's book (at two pages SPREAD, from 0)
## --grid=ROW/ROW...   fill the crafting grid (5 x 5 at most), rows split
##                      by "/", cells by "," ("none" leaves a cell empty):
##                      oak_planks,oak_planks/stick,oak_planks/stick

var seed_text := ""
var new_world := false
var world_folder := WorldStorage.FIRST_WORLD
var spawn_override := Vector2i.ZERO
var has_spawn_override := false
var start_hour := -1.0
var time_mode := ""
var day_minutes := 0.0
var game_mode := WorldSettings.GameMode.SURVIVAL
var show_debug := false
var hide_debug := false
var language := ""
var zoom := 0
var screenshot_path := ""
var screenshot_delay := 10
var autowalk := Vector2i.ZERO
var hold_jump := false
var open_pause_menu := false
var descend := 0
var noclip := false
var open_map := false
var weather := -1
var quality := -1
var hd := false
var camera_angles := Vector2(0.0, Render3D.DEFAULT_PITCH)
var first_person := false
var look_pitch := -11.5
var dive := -1.0
var aim := Vector2.INF
var hold_break := false
var place_once := false
## [[item, count], ...]
var give: Array[Vector2i] = []
## [[species, count], ...]
var animals: Array[Vector2i] = []
var open_inventory := false
var drop_held := false
## The spread the player's book opens at (-1: closed).
var book_spread := -1
## Items put in the crafting grid's cells: rows of items.
var grid: Array[Array] = []


static func parse(args: PackedStringArray) -> DevOptions:
	var options := DevOptions.new()
	for arg in args:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() > 1 else ""
		match key:
			"seed":
				options.seed_text = value
			"new-world":
				options.new_world = true
			"world":
				if not value.validate_filename().is_empty():
					options.world_folder = value.validate_filename()
			"spawn":
				var xy := value.split(",")
				if xy.size() == 2:
					options.spawn_override = Vector2i(xy[0].to_int(), xy[1].to_int())
					options.has_spawn_override = true
			"time":
				options.start_hour = value.to_float()
			"time-mode":
				options.time_mode = value
			"day-minutes":
				options.day_minutes = value.to_float()
			"game-mode":
				match value:
					"creative":
						options.game_mode = WorldSettings.GameMode.CREATIVE
					"hardcore":
						options.game_mode = WorldSettings.GameMode.HARDCORE
			"debug":
				options.show_debug = true
			"hide-debug":
				options.hide_debug = true
			"lang":
				options.language = value
			"zoom":
				options.zoom = value.to_int()
			"screenshot":
				options.screenshot_path = value
			"screenshot-delay":
				options.screenshot_delay = value.to_int()
			"autowalk":
				var dxy := value.split(",")
				if dxy.size() == 2:
					options.autowalk = Vector2i(dxy[0].to_int(), dxy[1].to_int())
			"jump":
				options.hold_jump = true
			"pause-menu":
				options.open_pause_menu = true
			"descend":
				options.descend = value.to_int()
			"noclip":
				options.noclip = true
			"map":
				options.open_map = true
			"weather":
				options.weather = ["clear", "rain", "thunder"].find(value)
			"quality":
				options.quality = value.to_int()
			"hd":
				options.hd = true
			"first-person":
				options.first_person = true
			"look":
				options.look_pitch = value.to_float()
			"dive":
				options.dive = clampf(value.to_float(), 0.0, 1.0)
			"aim":
				var point := value.split(",")
				if point.size() == 2:
					options.aim = Vector2(point[0].to_float(), point[1].to_float())
			"mine":
				options.hold_break = true
			"give":
				for entry in value.split(","):
					var parts_of := entry.split(":")
					var item: int = Items.Id.get(parts_of[0].to_upper(), Items.Id.NONE)
					if item != Items.Id.NONE:
						var count := parts_of[1].to_int() if parts_of.size() > 1 else 1
						options.give.append(Vector2i(item, maxi(count, 1)))
			"animals":
				for entry in value.split(","):
					var parts_of := entry.split(":")
					var kind: int = Species.Id.get(parts_of[0].to_upper(), -1)
					if kind >= 0:
						var count := parts_of[1].to_int() if parts_of.size() > 1 else 1
						options.animals.append(Vector2i(kind, maxi(count, 1)))
			"inventory":
				options.open_inventory = true
			"book":
				options.book_spread = maxi(value.to_int(), 0)
			"grid":
				for row in value.split("/"):
					var items := []
					for item_name in row.split(","):
						items.append(Items.Id.get(item_name.to_upper(), Items.Id.NONE))
					options.grid.append(items)
			"drop":
				options.drop_held = true
			"place":
				options.place_once = true
			"camera":
				var angles := value.split(",")
				if angles.size() == 2:
					options.camera_angles = Vector2(angles[0].to_float(), angles[1].to_float())
	return options


## Whether this run plays the saved world: always, but for a dev seed on
## its own (screenshots, generation checks), which plays a throwaway one.
func saves_world() -> bool:
	return seed_text.is_empty() or new_world


## Applies the time options to a freshly created world clock.
func apply_to_clock(clock: WorldClock) -> void:
	if start_hour >= 0.0:
		clock.total_game_seconds = start_hour * 3600.0
	if day_minutes > 0.0:
		clock.set_normal(day_minutes)
	match time_mode:
		"synced":
			clock.set_synced()
		"frozen":
			clock.set_frozen(clock.time_of_day())
