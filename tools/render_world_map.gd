extends SceneTree
## Renders the map of a world seed to a PNG and prints biome statistics.
##
##   godot --headless --path . -s res://tools/render_world_map.gd -- \
##       --seed=42 --size=512 --scale=4 --layer=0 --out=/tmp/map.png
##
## --center=X,Y centers the map (default: the world spawn).
## --bench also measures chunk generation speed.


func _initialize() -> void:
	var options := _parse(OS.get_cmdline_user_args())
	var seed_text: String = options.get("seed", "42")
	var world_seed := HashUtil.seed_from_text(seed_text)
	var generator := WorldGenerator.new(world_seed)
	var size := int(options.get("size", "512"))
	var scale := int(options.get("scale", "4"))
	var layer := int(options.get("layer", "0"))
	var out: String = options.get("out", "user://map.png")

	var started := Time.get_ticks_msec()
	var spawn := generator.find_spawn_tile()
	print("Seed %s -> %d, spawn %s (%d ms)" % [seed_text, world_seed, spawn, _since(started)])
	var center := spawn
	if options.has("center"):
		var xy: PackedStringArray = options["center"].split(",")
		center = Vector2i(xy[0].to_int(), xy[1].to_int())

	started = Time.get_ticks_msec()
	var image := WorldMapRenderer.render(generator, layer, center, size, scale)
	_mark(image, (spawn - center) / scale + Vector2i(size / 2, size / 2))
	image.save_png(out)
	print("Map %dx%d px, %d tiles/px -> %s (%d ms)" % [size, size, scale, out, _since(started)])

	if layer == 0:
		_print_biome_stats(generator, center, size * scale)
	if options.has("bench"):
		_bench(generator, spawn)
	quit()


func _print_biome_stats(generator: WorldGenerator, center: Vector2i, span: int) -> void:
	var counts := {}
	var samples := 0
	var step := maxi(8, span / 200)
	for y in range(center.y - span / 2, center.y + span / 2, step):
		for x in range(center.x - span / 2, center.x + span / 2, step):
			var biome := generator.sample_column(x, y).biome
			counts[biome] = counts.get(biome, 0) + 1
			samples += 1
	var ids := counts.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	for id: int in ids:
		print("  %-22s %5.1f%%" % [Biomes.Id.find_key(id), 100.0 * counts[id] / samples])


func _bench(generator: WorldGenerator, spawn: Vector2i) -> void:
	var base := Coords.tile_to_chunk(spawn)
	for layer in [0, -1, -5]:
		var started := Time.get_ticks_usec()
		var count := 0
		for dy in 5:
			for dx in 5:
				generator.generate_chunk(base + Vector2i(dx, dy), layer)
				count += 1
		var per_chunk := (Time.get_ticks_usec() - started) / 1000.0 / count
		print("  layer %d: %.2f ms per chunk" % [layer, per_chunk])


func _mark(image: Image, at: Vector2i) -> void:
	for d in range(-3, 4):
		for p in [at + Vector2i(d, 0), at + Vector2i(0, d)]:
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(p, Color.RED)


func _since(started_msec: int) -> int:
	return Time.get_ticks_msec() - started_msec


func _parse(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg in args:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return options
