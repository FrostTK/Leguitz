# Leguitz — notes for Claude

Top-down pixel-art open-world sandbox (Stardew visuals, Minecraft mechanics), rendered in full 3D
(terrain cubes textured in pixel art, voxel models for everything else, orbit camera). Godot 4.7.
The owner speaks French: talk to them in French. Code, identifiers and comments are in English;
player-facing text goes through `i18n/strings.csv` (keys + en + fr), never hard-coded.

## Commands

```bash
bash tools/install_godot.sh --templates desktop && export PATH="$HOME/godot:$PATH"
godot --headless --path . --import                         # required before tests (class cache)
godot --headless --path . -s res://tests/run_tests.gd      # unit tests, exit code 1 on failure
gdlint src tests && gdformat --check src tests             # CI runs both
# Screenshot check (software Vulkan works: apt install mesa-vulkan-drivers xvfb):
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -- --seed=42 --debug --screenshot=/tmp/s.png
```

## Architecture rules

- `src/sim` is the authoritative server. It must not depend on nodes, input or rendering.
- The client (`src/client`) only learns about the world via `Msg` dictionaries from a `Transport`,
  and only changes it by sending messages. Keep solo on the same path as future multiplayer.
- World generation must be deterministic per seed: use `HashUtil` (never Godot's `hash()`/`randi()`)
  and derive sub-seeds with `HashUtil.derive_seed(world_seed, SALT)`.
- Tile/block ids are stored in chunks: only append to enums in `src/sim/world/tiles.gd`, never renumber.
- Timed gameplay durations are authored for the default 20-min day and must go through
  `WorldClock.scale_duration()` (pace = clamp((day_minutes/20)^0.25, 0.7, 2.5); synced = 24 h day).
  Only SYNCED worlds catch up offline, capped to one game day.
- Pixel art: 16 px tiles, integer world zoom, UI scaled via the window content scale factor.
- 3D view (`src/client/render`): terrain is meshed in local tile units (1 tile = 1 unit, 1 level =
  1 unit) under a world root whose basis (`Render3D.root_basis(yaw)`) stretches it so the default
  camera (pitch 60°) is pixel-perfect; the stretch turns with the camera yaw. The SubViewport renders
  at art resolution (1 texel per art pixel) unless HD. Lights and particles live outside the root
  (no non-uniform scale). Faces exist on every side: the camera can look from anywhere.
  Terrain textures come from `tools/gen_art.py`; its GROUNDS list must match the enum.
- Trees, plants, rocks and the player are voxel models (1 voxel = 1 art pixel = 1/16 tile):
  generators in `src/client/models/voxel_models.gd`, meshed by VoxelMesher (greedy faces + AO) and
  saved by `godot --headless --path . -s res://tools/gen_models.gd` into `assets/models/` (commit
  the .res files; rerun after changing a model). Every non-cube block needs a model (tested).
  `voxel.gdshader` handles wind, wetness, leaf backlight and the see-through hole around the player.
- Movement is Minecraft-like (`src/sim/physics/player_body.gd`, shared client/server): heights in
  levels from `ChunkData.top_height()` (INF = cannot stand there), walk up to 0.2, jump 1.25,
  fall off edges. No stairs: terrain levels rise one at a time so they can be climbed.
- World generation (`src/sim/world/generation/`): ClimateSampler (5 Minecraft climate noises,
  sampled every 4 tiles by ClimateGrid) -> TerrainShaper (splines, rivers, terrace levels) ->
  Biomes.select -> SurfaceBuilder (ground + vegetation) ; CaveGenerator for layers -1..-6.
  Chunks are keyed Vector3i(x, y, layer). Tune with `tools/render_world_map.gd` (map PNG + stats).
- generate_chunk() must stay thread-safe (read-only shared state): the server runs it on the
  WorkerThreadPool via ChunkGenerationQueue. Tests use `GameServer.new(settings, null, false)`.
- Add tests in `tests/unit/test_*.gd` (extend `TestCase`, methods named `test_*`).
