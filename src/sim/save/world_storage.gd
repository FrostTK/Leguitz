class_name WorldStorage
extends RefCounted
## A world saved on disk, in its own folder:
## - world.cfg: the world's settings, clock and weather, and when it was
##   last saved,
## - players/<name>.cfg: where each player stands (inventory later),
## - regions/r.<x>.<z>.bin: the chunks players changed, REGION_SIZE x
##   REGION_SIZE chunks per file, voxels compressed (the other chunks are
##   generated again from the seed).
## A file is first written aside, then swapped in; the copy it replaces is
## kept as .bak until then, so a save cut short leaves a readable file.
## Server side only: clients never read saves.

const FORMAT_VERSION := 1
const WORLDS_DIR := "user://worlds/"
## The only world until a title screen lets players pick one.
const FIRST_WORLD := "world_1"
const REGION_SIZE := 32
const COMPRESSION := FileAccess.COMPRESSION_ZSTD
const WORLD_FILE := "world.cfg"

var folder := ""
## Saved chunks of the regions read so far: region -> {chunk coord: data}.
var _regions: Dictionary[Vector2i, Dictionary] = {}
## Regions changed since they were last written.
var _dirty: Dictionary[Vector2i, bool] = {}


func _init(world_folder: String) -> void:
	folder = world_folder.trim_suffix("/") + "/"


## The storage of a world of WORLDS_DIR (by folder name).
static func of_world(world: String) -> WorldStorage:
	return WorldStorage.new(WORLDS_DIR + world)


## The region file holding a chunk.
static func region_of(coord: Vector2i) -> Vector2i:
	return Vector2i(floori(coord.x / float(REGION_SIZE)), floori(coord.y / float(REGION_SIZE)))


## True once the world was saved.
func exists() -> bool:
	return _readable(folder + WORLD_FILE) != ""


## Deletes everything saved: the world starts over.
func erase() -> void:
	_regions.clear()
	_dirty.clear()
	if folder.begins_with("user://"):
		_erase_dir(folder)


## What world.cfg holds: "settings", "clock" and "weather" (dictionaries,
## see their to_dict), "items" (the items lying around, see
## DroppedItem.to_dict) and "saved_unix"; empty if the world was never
## saved.
func read_world() -> Dictionary:
	var file := _load_config(WORLD_FILE)
	if file == null:
		return {}
	return {
		"settings": file.get_value("world", "settings", {}),
		"clock": file.get_value("world", "clock", {}),
		"weather": file.get_value("world", "weather", {}),
		"items": file.get_value("world", "items", []),
		"saved_unix": file.get_value("world", "saved_unix", 0.0),
	}


func save_world(
	settings: WorldSettings, clock: WorldClock, weather: Weather, items: Array = []
) -> bool:
	var file := ConfigFile.new()
	file.set_value("world", "format", FORMAT_VERSION)
	file.set_value("world", "settings", settings.to_dict())
	file.set_value("world", "clock", clock.to_dict())
	file.set_value("world", "weather", weather.to_dict())
	file.set_value("world", "items", items)
	file.set_value("world", "saved_unix", Time.get_unix_time_from_system())
	return _save_config(file, WORLD_FILE)


## A player's saved state (see GameServer.player_state), empty if none.
func load_player(player_name: String) -> Dictionary:
	var file := _load_config(_player_file(player_name))
	return file.get_value("player", "state", {}) if file != null else {}


func save_player(player_name: String, state: Dictionary) -> bool:
	var file := ConfigFile.new()
	file.set_value("player", "state", state)
	return _save_config(file, _player_file(player_name))


func has_chunk(coord: Vector2i) -> bool:
	return _region(region_of(coord)).has(coord)


## A saved chunk (marked modified), or null if it was never changed.
func load_chunk(coord: Vector2i) -> ChunkData:
	var data: Dictionary = _region(region_of(coord)).get(coord, {})
	if data.is_empty():
		return null
	var compressed: PackedByteArray = data["voxels"]
	var chunk := (
		ChunkData
		. from_dict(
			{
				"x": coord.x,
				"y": coord.y,
				"voxels": compressed.decompress(int(data["size"]), COMPRESSION),
				"biome": data["biome"],
			}
		)
	)
	chunk.modified = true
	for cell: Vector3i in data.get("chests", {}):
		var chest := Inventory.new()
		chest.load_dict(data["chests"][cell])
		chunk.chests[cell] = chest
	for cell: Vector3i in data.get("furnaces", {}):
		chunk.furnaces[cell] = Furnace.from_dict(data["furnaces"][cell])
	return chunk


## Keeps a changed chunk until the next flush().
func store_chunk(chunk: ChunkData) -> void:
	var key := region_of(chunk.coord)
	var chests := {}
	for cell: Vector3i in chunk.chests:
		chests[cell] = chunk.chests[cell].contents(Inventory.CHEST)
	var furnaces := {}
	for cell: Vector3i in chunk.furnaces:
		furnaces[cell] = chunk.furnaces[cell].to_dict()
	_region(key)[chunk.coord] = {
		"voxels": chunk.voxels.compress(COMPRESSION),
		"size": chunk.voxels.size(),
		"biome": chunk.biome,
		"chests": chests,
		"furnaces": furnaces,
	}
	_dirty[key] = true


## Writes the regions changed since the last flush. False if one could
## not be written (it stays to write next time).
func flush() -> bool:
	var ok := true
	for key: Vector2i in _dirty.keys():
		if _write_region(key):
			_dirty.erase(key)
		else:
			ok = false
	return ok


func _region(key: Vector2i) -> Dictionary:
	if not _regions.has(key):
		_regions[key] = _read_region(key)
	return _regions[key]


func _region_file(key: Vector2i) -> String:
	return "regions/r.%d.%d.bin" % [key.x, key.y]


func _read_region(key: Vector2i) -> Dictionary:
	var path := _readable(folder + _region_file(key))
	if path.is_empty():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if data is Dictionary and data.get("chunks") is Dictionary:
		return data["chunks"]
	push_warning("Unreadable region file %s" % path)
	return {}


func _write_region(key: Vector2i) -> bool:
	var path := folder + _region_file(key)
	if not _make_dir(path.get_base_dir()):
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"format": FORMAT_VERSION, "chunks": _regions[key]})
	file.close()
	return _replace(path)


static func _player_file(player_name: String) -> String:
	return "players/%s.cfg" % player_name.validate_filename()


func _load_config(relative: String) -> ConfigFile:
	var path := _readable(folder + relative)
	if path.is_empty():
		return null
	var file := ConfigFile.new()
	if file.load(path) != OK:
		push_warning("Unreadable save file %s" % path)
		return null
	return file


func _save_config(file: ConfigFile, relative: String) -> bool:
	var path := folder + relative
	if not _make_dir(path.get_base_dir()):
		return false
	if file.save(path + ".tmp") != OK:
		return false
	return _replace(path)


## The file to read for `path`: itself, or the copy a save cut short left
## (empty if neither exists).
static func _readable(path: String) -> String:
	if FileAccess.file_exists(path):
		return path
	if FileAccess.file_exists(path + ".bak"):
		return path + ".bak"
	return ""


## Swaps the freshly written `path`.tmp in for `path`.
static func _replace(path: String) -> bool:
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(path, backup) != OK:
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return true


static func _make_dir(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path) or DirAccess.make_dir_recursive_absolute(path) == OK


static func _erase_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_erase_dir(path.path_join(sub))
	DirAccess.remove_absolute(path)
