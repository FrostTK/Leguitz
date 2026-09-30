class_name WorldSettings
extends RefCounted
## Per-world settings chosen at creation (seed, game mode...).
## The time settings live in WorldClock, which is saved with the world too.

enum GameMode { CREATIVE, SURVIVAL, HARDCORE }

const GAME_MODE_KEYS := {
	GameMode.CREATIVE: "GAME_MODE_CREATIVE",
	GameMode.SURVIVAL: "GAME_MODE_SURVIVAL",
	GameMode.HARDCORE: "GAME_MODE_HARDCORE",
}

var world_name := "World"
var world_seed := 0
var game_mode: GameMode = GameMode.SURVIVAL
var created_unix := 0.0


static func create(name: String, seed_text: String, mode: GameMode) -> WorldSettings:
	var settings := WorldSettings.new()
	settings.world_name = name
	if seed_text.strip_edges().is_empty():
		settings.world_seed = random_seed()
	else:
		settings.world_seed = HashUtil.seed_from_text(seed_text)
	settings.game_mode = mode
	settings.created_unix = Time.get_unix_time_from_system()
	return settings


static func random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return (rng.randi() << 31) ^ rng.randi()


func to_dict() -> Dictionary:
	return {
		"world_name": world_name,
		"world_seed": world_seed,
		"game_mode": game_mode,
		"created_unix": created_unix,
	}


func load_dict(data: Dictionary) -> void:
	world_name = data.get("world_name", world_name)
	world_seed = data.get("world_seed", world_seed)
	game_mode = data.get("game_mode", GameMode.SURVIVAL) as GameMode
	created_unix = data.get("created_unix", 0.0)
