# Leguitz — notes for Claude

Top-down pixel-art open-world sandbox (Stardew visuals, Minecraft mechanics), rendered in full 3D:
a true voxel world (16x16x128 chunks, cubes textured in pixel art), voxel models for everything else
(trees, plants, player), orbit camera, cut-away view underground. Godot 4.7.
The owner speaks French: talk to them in French. Code, identifiers and comments are in English;
player-facing text goes through `i18n/strings.csv` (keys + en + fr), never hard-coded.

**New conversation? Read `CLAUDE-README.md` first**: the owner's decisions, the current state,
what to do when they say "go" (the next phase) and the detailed remaining roadmap. Work phase by
phase and wait for "go"; keep that file up to date at the end of each phase.

## Commands

```bash
bash tools/install_godot.sh --templates desktop && export PATH="$HOME/godot:$PATH"
godot --headless --path . --import                         # required before tests (class cache)
godot --headless --path . -s res://tests/run_tests.gd      # unit tests, exit code 1 on failure
gdlint src tests && gdformat --check src tests             # CI runs both
# Screenshot check (software Vulkan works: apt install mesa-vulkan-drivers xvfb):
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1280x720 -- --seed=42 --debug --screenshot=/tmp/s.png
```

On the owner's Windows PC (Git Bash; Godot in `C:\Users\guill\godot\`, real GPU, no xvfb; the
gdtoolkit scripts are not on PATH, use `py -m`). Dev options (`--zoom`, `--debug`...) are session
overrides and never reach the owner's settings file:

```bash
G=/c/Users/guill/godot/Godot_v4.7.2-stable_win64_console.exe   # console build: prints to the terminal
$G --headless --path . --import && $G --headless --path . -s res://tests/run_tests.gd
py -m gdtoolkit.linter src tests && py -m gdtoolkit.formatter --check src tests
$G --path . --audio-driver Dummy --resolution 1280x720 -- --seed=42 --screenshot="$SCRATCH/s.png"
```

gdformat writes CRLF line endings on Windows: convert the files it touched back to LF.

## Architecture rules

- `src/sim` is the authoritative server. It must not depend on nodes, input or rendering.
- The client (`src/client`) only learns about the world via `Msg` dictionaries from a `Transport`,
  and only changes it by sending messages. Keep solo on the same path as future multiplayer.
- World generation must be deterministic per seed: use `HashUtil` (never Godot's `hash()`/`randi()`)
  and derive sub-seeds with `HashUtil.derive_seed(world_seed, SALT)`.
- Voxel ids (`src/sim/world/voxels.gd`, one byte per voxel, stored in chunks and saves): grounds
  keep their `Tiles.Ground` id (< 64), blocks are 64 + `Tiles.Block`. Only append to the enums in
  `src/sim/world/tiles.gd`, never renumber. `ChunkData` is a 16x16 column of WORLD_HEIGHT (128)
  voxels stored column by column ((z * 16 + x) * 128 + y), plus per column its biome and terrain
  top. Row SEA_LEVEL (64) is level 0: heights in levels everywhere (physics, rendering) are rows
  minus 64. Chunks are keyed by Vector2i; there are no separate underground layers any more.
- Timed gameplay durations are authored for the default 20-min day and must go through
  `WorldClock.scale_duration()` (pace = clamp((day_minutes/20)^0.25, 0.7, 2.5); synced = 24 h day).
  Only SYNCED worlds catch up offline, capped to one game day.
- Pixel art: 16 px tiles, integer world zoom, UI scaled via the window content scale factor.
- 3D view (`src/client/render`): terrain is meshed in local tile units (1 tile = 1 unit, 1 level =
  1 unit) under a world root whose basis (`Render3D.root_basis(yaw, pitch)`) stretches it so the
  default camera (pitch 60°) is pixel-perfect. Lower (down to 15°) the height stretch is
  1/cos(pitch), so things keep their height on screen, and both stretches fade out towards the
  horizon (a cube looks like a cube): nothing gets taller when the camera goes down. Steeper than
  60° keeps the default stretch. The stretch turns with the camera yaw. The SubViewport renders
  at art resolution (1 texel per art pixel) unless HD. Lights and particles live outside the root
  (no non-uniform scale). Terrain textures come from `tools/gen_art.py`; its GROUNDS list must
  match the enum.
- Terrain meshes (`ChunkMesher`, on worker threads via WorldView3D): tops of cube/liquid voxels
  open to the air (merged into rectangles; the top shader blends grounds per pixel from the
  chunk's surface map, ChunkMesher.surface_map), sides of cubes (vertical runs of one material
  merged, the ground hangs over as a lip) and undersides (never seen front-on, the camera always
  looks down). Faces open to the sky and cave faces go to separate meshes; caves show only when
  the player is under cover (ClientWorld.is_covered): the view then cuts everything above their
  head (global `cut_height`), the surface maps are rebuilt for the cut, and the back of the faces
  closing the rock draws its section in dark (`see_through.gdshaderinc`).
- Trees, plants, rocks and the player are voxel models (1 voxel = 1 art pixel = 1/16 tile):
  generators in `src/client/models/voxel_models.gd`, meshed by VoxelMesher (greedy faces + AO) and
  saved by `godot --headless --path . -s res://tools/gen_models.gd` into `assets/models/` (commit
  the .res files; rerun after changing a model). Every non-cube block needs a model (tested).
  `voxel.gdshader` handles wind, wetness and leaf backlight. `see_through.gdshaderinc` (voxel and
  terrain shaders) dithers away what stands between the camera and the player, around them.
  Each model also has coarser copies (`_lod1` = 2 voxels per voxel, `_lod2` = 4) used when the
  ground in view is large (WorldView3D.lod_for_view); lod1 casts its shadows with lod2.
- Keep the GPU cool: Settings.max_fps (default 60, 15 in the background), the world SubViewport
  stops rendering while paused, and the client only asks for the chunks its view needs.
- Movement is Minecraft-like (`src/sim/physics/player_body.gd`, shared client/server) among voxels
  (`voxel_at` callable, Voxels.UNKNOWN = not loaded = solid): body 1.7 levels tall, walk up 0.2,
  jump 1.25, bump ceilings, fall off edges; solid objects (trees, rocks) block 3 levels up; water
  is walked on for now (swimming comes with survival), lava blocks. No stairs: terrain levels rise
  one at a time so they can be climbed.
- World generation (`src/sim/world/generation/`): ClimateSampler (5 Minecraft climate noises,
  sampled every 4 tiles by ClimateGrid) -> TerrainShaper (splines, rivers, terrace levels) ->
  Biomes.select -> SurfaceBuilder (surface voxel, filler, vegetation) fill the columns; then
  CaveGenerator carves 3D caves under the terrain (cheese chambers, spaghetti tunnels, lakes, lava,
  ore veins), never closer than a few rows to it. Tune with `tools/render_world_map.gd`.
- generate_chunk() must stay thread-safe (read-only shared state): the server runs it on the
  WorkerThreadPool via ChunkGenerationQueue. Tests use `GameServer.new(settings, null, false)`.
- GDScript on worker threads: plain GDScript scales over the cores, but calls on native objects
  (FastNoiseLite...) and allocations barely do. Sample noises in bulk (`get_image_3d`, see
  CaveGenerator._rows), keep hot loops free of allocations and calls, read static tables into
  locals first. `threading/worker_pool/low_priority_thread_ratio` is 0.75 (generation and meshing
  run as low-priority tasks; high priority starves the engine's own work).
- Add tests in `tests/unit/test_*.gd` (extend `TestCase`, methods named `test_*`).
