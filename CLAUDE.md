# Leguitz — notes for Claude

Top-down pixel-art open-world sandbox (Stardew visuals, Minecraft mechanics), rendered in full 3D:
a true voxel world (16x16x128 chunks, cubes textured in pixel art), voxel models for everything else
(trees, plants, player), orbit camera, cut-away view underground, first person in caves (and with
F5). Godot 4.7.
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
- Voxel ids (`src/sim/world/voxels.gd`, 16 bits: Voxels.ID_COUNT, stored as ints in
  `ChunkData.voxels`, a PackedInt32Array, and in saves): grounds keep their `Tiles.Ground` id
  (< 64: the shaders read a ground in 6 bits, their arrays are 64 long, TerrainRenderer.MAX_GROUNDS),
  blocks are 64 + `Tiles.Block` (thousands more possible), UNKNOWN is ID_COUNT - 1 (never stored).
  Tables by voxel id are ID_COUNT long (Voxels) or `Voxels.used_ids()` long where UNKNOWN never
  comes (ChunkMesher's, read from loaded chunks); WorldView3D's variants and TileAtlas.wall_lookup
  are Tiles.Block.size() long. Saves: ChunkData.FORMAT_VERSION 4 stores the ints (zstd); worlds
  saved one byte per voxel still load (WorldStorage.load_chunk, ChunkData.ids_from_bytes: the
  same ids). Only append to the enums in `src/sim/world/tiles.gd`, never renumber. `ChunkData` is
  a 16x16 column of WORLD_HEIGHT (128) voxels stored column by column ((z * 16 + x) * 128 + y),
  plus per column its biome and terrain top. Row SEA_LEVEL (64) is level 0: heights in levels everywhere (physics, rendering) are rows
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
- Terrain meshes (`ChunkMesher`, on worker threads via WorldView3D): tops of cube and lava voxels
  open to the air or under clear water (merged into rectangles; the top shader blends grounds per
  pixel from the chunk's surface map, ChunkMesher.surface_map, shared code in
  `terrain3d_surface.gdshaderinc`), sides of cubes open to the air or to clear water (vertical
  runs of one material merged, the ground hangs over as a lip) and undersides (never seen
  front-on, the camera always looks down). Faces open to the sky (also through water, glass and
  thin covers: building blocks, ChunkMesher.BUILT, never hide what is under them, only
  THICK_COVER natural cubes in a row do, so a house's rooms show through its windows and doors)
  and cave faces go to separate meshes; caves show only when the player is under cover
  (ClientWorld.is_covered; water and lava over the head are no roof): the view then cuts everything above their head (global
  `cut_height`; under a building's roof only over the building, so the world around keeps its
  mountains and trees: CutRegion, the covered room joined to the player's tile, flood filled,
  and a tile around it for the walls, given to the shaders as `cut_mask` (+ `cut_mask_origin`,
  `cut_local`, `world_to_local`) and to the chunk builds as Job.cut_columns (surface maps and
  caps cut there only); under rock or underground everywhere; undersides in the cut's plane go too, `underside_cut`: a beam or a ceiling right
  over the cut would cover what lies under it), the surface maps are rebuilt for the cut, and the
  back of the faces closing the rock draws its section in dark (`see_through.gdshaderinc`); building blocks cut through
  (TileAtlas.BUILDING_WALLS: planks, bricks, glass...) get a cap instead, their top at the cut
  (ChunkMesher Part.CAPS, also in surface-map-only builds; ChunkView3D.caps with the top shader's
  `cap`: a little darker, outlined where it drops), shown only while the view cuts.
- Water (the water grounds; lava stays opaque): its surfaces are meshes of their own (Part.WATER,
  DEEP_WATER in caves) drawn by `water.gdshader`, casting no shadow. It reads the screen and depth
  textures: what lies behind fades with the thickness of water the eye looks through (local
  units, per-water clarity and tint in TerrainRenderer), by steps; the ripples bend it by whole
  art pixels (only what is under the surface), caustics light the shallows; shores, foam and
  ripples as before. The surface map's 4th channel holds the bed under clear water
  (ChunkMesher.bed_code / bed_of in the shader) so beds blend like land.
- First person (`ViewMode`: automatic when entering a cave, setting `cave_first_person`; F5 any
  time): WorldViewport.dive_frame blends the ortho top-down camera into a perspective one at the
  eye (a 1° perspective from far away opening to 70°), the world root stretch fades to identity
  (`Render3D.root_basis(yaw, pitch, amount)`), the body dithers away (shadow kept), the lantern is
  carried in the left hand. No cut, no see-through hole (globals `cut_height`, `see_through_on`); during the
  dive the backs of faces vanish (`section_on`) so the camera sees through the rock it crosses.
  In first person: caves always shown, props' detail by distance, haze, split sun shadows, a
  procedural sky, 6 chunks loaded; the mouse is captured (released by the pause menu).
- Trees, plants, rocks and the player are voxel models (1 voxel = 1 art pixel = 1/16 tile):
  generators in `src/client/models/voxel_models.gd` (trees: `tree_models.gd`, detailed procedural
  trees: tapering, leaning trunks on roots, forking limbs, lit leaf clusters, bark grooves and
  moss), meshed by VoxelMesher (greedy faces + AO) and saved by
  `godot --headless --path . -s res://tools/gen_models.gd [-- --only=oak]` into `assets/models/`
  (commit the .res files; rerun after changing a model; all of them take ~15 min). Every non-cube
  block needs a model (tested). `voxel.gdshader` handles wind, wetness and leaf backlight;
  VoxelGrid.Kind.GLOW voxels (fire) light themselves (VoxelMesher UV.y = 2, EMISSION).
  `see_through.gdshaderinc` (voxel and terrain shaders) dithers away what stands between the
  camera and the player, around them. Each model also has coarser copies (`_lod1` = 2 voxels per
  voxel, `_lod2` = 4). Top-down, the ground in view sets the detail (WorldView3D.lod_for_view)
  and chunks out of view (they only cast shadows into it) use lod2; in first person it follows
  the distance from the player to each chunk's middle (FIRST_PERSON_FULL/HALF_DETAIL). Low and
  Medium graphics qualities shrink the detail's reach (DETAIL_BY_QUALITY). Shadows are most of the cost; ArrayMesh.shadow_mesh does not help (Godot ignores
  it with this shader: vertex code, discard). Trees are 4-75k triangles (jungle and dark
  oaks the heaviest): watch the triangle count and GPU time in the F3 overlay.
- Objects in voxels (`ObjectShapes`, shared by physics and models): each block has a few
  versions (trees 8, of different trunk sizes) picked by tile hash, wandering small things get an
  offset in their tile. Only a tree's trunk blocks bodies (TileCollider moves among obstacle
  boxes, PlayerBody.obstacle); generation never puts two solid objects on neighboring tiles
  (WorldGenerator._spaced), so bodies can always walk between them.
- Weather (`src/client/effects/weather_effects.gd`): GPU particles in world space around the
  camera target (rain, snow, leaves, fireflies, dust). Rain and snow end on the first thing they
  meet from above: a GPUParticlesCollisionHeightField3D over the emitters (shown only while it
  rains), moved on a HEIGHT_FIELD_STEP grid and drawn again when chunks or blocks change
  (`terrain_changed`, twice: the new mesh comes a moment later); drops are DROP art pixels from
  above, FINE_DROP in first person and HD.
- Keep the GPU cool: Settings.max_fps (default 60, 15 in the background), the world SubViewport
  stops rendering while paused, and the client only asks for the chunks its view needs.
- Movement is Minecraft-like (`src/sim/physics/player_body.gd`, shared client/server) among voxels
  (`voxel_at` callable, Voxels.UNKNOWN = not loaded = solid): body 1.7 levels tall, walk up 0.2,
  jump 1.25, bump ceilings, fall off edges; solid objects block their footprint up their height
  (trees: the trunk, see ObjectShapes); furniture (workbench, chest, furnaces: ObjectShapes.TOPS,
  the height of their models' tops) blocks up to its top and is stood on once the feet get there
  (PlayerBody.support looks for it under the body's box; dropped items rest on it too). Water
  and lava are swum in (PlayerBody.liquid_at: the feet under a liquid's surface; `_swim`): the
  body sinks (SINK_SPEED), rises while jump is held (SWIM_UP) to float FLOAT_DEPTH under the
  surface, leaps out (LEAP_HEIGHT) when held against a bank near the surface; slower
  (LocalPlayer WATER_SPEED, LAVA_SPEED); liquids never block bodies. PlayerBody measures falls
  from their highest point (`take_fall`); a fall ends in a liquid (never hurts).
  `eye_in_water`: the eye (EYE_HEIGHT) under water, no air. Client: the swimming body (arms
  sweeping, legs kicking), a splash going in, a veil over the first-person view under water
  (VitalsView.veil). No stairs: terrain levels rise
  one at a time so they can be climbed.
- World generation (`src/sim/world/generation/`): ClimateSampler (5 Minecraft climate noises,
  sampled every 4 tiles by ClimateGrid) -> TerrainShaper (splines, rivers, terrace levels) ->
  Biomes.select -> SurfaceBuilder (surface voxel, filler, vegetation) fill the columns; then
  CaveGenerator carves 3D caves under the terrain (cheese chambers, spaghetti tunnels, lakes, lava,
  ore veins), never closer than a few rows to it. Tune with `tools/render_world_map.gd`.
- Breaking and placing: rules in `Mining` (sim, shared: reach 5 from the eye, breaking times by hand
  and with tools, what can be placed, water filling holes next to it), aiming by `VoxelRay` (DDA in
  local units; objects are met on their body, trees on their trunk). The client's BlockInteraction
  aims (top-down: the mouse ray through the ortho camera, taken back to local units by the root's
  inverse; first person: the crosshair; gamepad: in front of the player), always clamped to the
  reach sphere, through what the view cuts away (GameClient.shown_below_row where
  GameClient.cut_region reaches: a roof over the player is not met, nor a creature standing on
  it), draws the frame (one art pixel thick top-down; in perspective about two pixels of
  the screen, at least a texel: BlockHighlight.thickness_for), cracks, chips and falling trees, and shows
  each change at once (prediction). Msg.BLOCK_BREAK / BLOCK_PLACE go to the server, which checks
  reach, what is there, room and support, changes the voxel through WorldState.set_voxel (objects
  above go with a broken voxel) and sends BLOCK_CHANGED to players having the chunk (also its answer
  to a refused guess). WorldView3D.voxel_changed rebuilds the chunk and the neighbors whose border
  the voxel lies on. Left button held breaks, right click places (a right drag still turns the
  camera), gamepad triggers; placing uses the block in hand. E (gamepad B, InputBindings.USE)
  uses what is aimed at: opens a workbench, a chest or a furnace (`Mining.opens`,
  BlockInteraction.use_target); the right click never opens them.
- Items (`src/sim/items/`): `Items` is the registry (ids saved: only append; name key ITEM_<ID>
  in i18n, stack size, the voxel a block item places, what each broken voxel gives: grass gives
  dirt, a tree a log per level of trunk). `Inventory` (hotbar 9 + bag 27 + the cursor's stack +
  the crafting grid + the armor worn, Minecraft's click rules) is shared: the server keeps it (saved in the player's state), the
  client predicts clicks on its copy. `DroppedItem`s fall, rest, float on water; the server pulls
  them into players nearby (from a level under the feet) and sends ITEM_SPAWN/MOVE/REMOVE; they
  are saved in world.cfg. Client: ItemLibrary (block items are cubes wearing the block's top
  texture, others ItemModels voxel models), ItemIcons renders every icon off screen at start,
  Hotbar, InventoryScreen (Tab; closed by Tab, E or Esc), DroppedItemsView, the item in hand (body and first person). With
  empty hands, the name of the item under the mouse shows beside it (ItemSlot.draw_name; the
  inventory screen and the book follow the mouse from its own events, `make_input_local`;
  BookScreen records the items it draws in `_named`). Drags with a stack in hand
  (InventoryScreen._input; the bag, hotbar, crafting grid, chest and furnace input/fuel), as in
  Minecraft: the right button puts one item into each slot crossed, once per drag (right clicks,
  sent like any click); the left one shares the stack evenly between the slots crossed
  (`Inventory.spread`, targets Vector2i(Inventory.Holder, index), no more slots than items, each
  share as much as fits): the client shows each new share from a snapshot of the slots
  (`snapshot`/`restore`) and sends Msg.SLOT_SPREAD when the button comes up; down and up on one
  slot is a plain click. A double click gathers on the cursor's stack the same items lying in
  the crafting grid, the open chest or furnace, the bag and the hotbar (`Inventory.collect`, part
  stacks first; Msg.SLOT_COLLECT). What the screen's clicks and drags do, opening a workbench,
  a chest or a furnace and closing, lives in InventoryActions (GameClient.actions). Wheel
  and 1-9 pick the slot (the wheel zooms with its button held down in the top-down view, or with
  Ctrl: InputBindings.wheel_zooms), Q throws (Ctrl: the stack), shoulders on a gamepad.
- Tools (`Items.TOOLS`: pickaxe, axe, shovel and sword in 6 materials, `Items.Tier`; they do not stack):
  `Mining.break_seconds(voxel, held)` divides the hand's time (`hand_seconds`, the voxel's
  hardness) by `Items.TIER_SPEED` when the tool is the one `Mining.tool_for(voxel)` names; real
  seconds (a player's action, not paced by the day), `Mining.BREAK_PAUSE` between two breaks.
  Tools wear (`Items.durability`: TIER_DURABILITY uses, Minecraft's; gold the shortest): every
  block that does not break at once (`Mining.wears`) uses the tool in hand once; worn out, it
  breaks. `Inventory.wear` keeps each slot's wear and moves it with the tool (clicks, shift,
  add/put back, saves); DroppedItem.wear keeps it on the ground. Msg.BLOCK_BREAK carries the
  hotbar slot in hand (-1: the player's book); the client wears its copy at once
  (BlockInteraction._wear_tool: bits of the head and "broke" over the hotbar), the server sends
  the inventory. ItemSlot draws a worn tool's bar (green to red).
  Models lie on the diagonal of a 16x16 grid like block-game icons (ItemModels; flat items' icons
  face the camera); hands hold them by `ItemModels.TOOL_GRIP` through `ItemLibrary.held_tool`,
  upright and turned about the handle (`roll`; the body: PlayerModel.TOOL_ROLL 45°, readable from
  the front, a side and the back, the wrist following `PlayerModel.strike_phase`; first person:
  bottom right of the view, turned to show its depth, the body's copy only casts its shadow).
  What is in hand is on PlayerModel.PLAYER_LAYER like the body: the lantern (left hand in first
  person, LANTERN_IN_HAND) throws no shadow of it, the sun and the moon do. F7 (creative) asks the server
  for the next material's tools (Msg.DEBUG_GIVE_TOOLS, announced over the hotbar); the F3 screen
  shows what is aimed at, its breaking time with what is in hand and the tool made for it.
- The player's book (`Settings.guide_book`, on by default, in the pause menu): a 10th slot set
  apart beside the hotbar (Hotbar keeps the 9 centered; InventoryScreen shows it too, where a
  click opens the book: it never moves). Client only: `GameClient.book_in_hand`, `held_item()`,
  `select_hand(BOOK_SLOT)` (the server keeps the hotbar slot chosen before); 0 takes it (again:
  opens it), the wheel and the shoulders go through it, Q does nothing, a right click
  (BlockInteraction.place) opens BookScreen: two pages drawn in UI units (tabs, title page and
  contents, arrows; `BookScreen.paginate`), turned by the arrows, the wheel or the movement keys,
  closed by Esc, Tab, E, 0 or a right click. Its text comes from GuideBook (chapters of translated
  entries; the controls named by InputNames as they are bound, in the player's keyboard layout:
  ZQSD on AZERTY). `Items.Id.GUIDE_BOOK` gives it a model and an icon; never in inventories.
- Crafting (`src/sim/items/recipes.gd`, shared): shaped recipes (a pattern placed anywhere in the
  grid, mirrored too) and shapeless ones; an ingredient is an item or a group (`Recipes.PLANKS`);
  `"workbench": true` keeps a recipe to the 5x5 grid (the tools: Minecraft's shapes,
  `TOOL_PATTERNS`, made of `TOOL_MATERIALS`: planks, any stone, copper/iron/gold ingots,
  diamonds; the 5x5 grid waits for bigger recipes). The grid lives in the `Inventory`
  (GRID x GRID cells from `Inventory.CRAFT`; the inventory's own grid is its top left OWN_GRID,
  3x3; a workbench's all 5x5) and is clicked like slots; `craft(width, shift)` takes the
  result (shift: as many as fit, into the slots), `put_back_all()` empties the cursor and the
  grid when the screen closes (the server throws what does not fit). Msg.CRAFT; the server uses
  `PlayerSession.craft_width`: OWN_GRID, or GRID once Msg.OPEN_WORKBENCH names a workbench
  within reach, until the screen closes. E on a workbench (`Mining.opens`,
  BlockInteraction.use_target) opens it: `GameClient.open_workbench`, InventoryScreen.open(width)
  showing the grid that wide (titled Workbench), an arrow and the result; the book's Crafting
  chapter draws every recipe (GuideBook Kind.RECIPE, groups and each kind of tool going through
  their items). `--grid=ROW/ROW` fills the grid for screenshots; `--place` aimed at a workbench
  opens it.
- New cube blocks (planks, stone/deepslate bricks, smooth stone, bricks, cut sandstone, glass):
  append to Tiles.Block and CUBE_BLOCKS, give them a TileAtlas.WALL_KINDS row (below
  TileAtlas.MAX_WALL_KINDS, 256: ChunkMesher.bed_code packs a wall kind in 8 bits, the shaders'
  see_through_walls arrays are that long) and a `tools/gen_art.py` WALLS entry (walls from
  FIRST_OWN_SEED_WALL draw from random generators of their own, `wall_tile`, so the older
  textures stay the same; restore the ground atlases from git when their pixels did not
  change), then Items (PLACES_BLOCK, BLOCK_DROPS) and Mining (time, tool). Block items are cubes
  wearing their top texture above and below and their face texture around (ItemLibrary._cube;
  alpha scissor for glass). Glass is a cube for physics and mining but one sees through it
  (TileAtlas.CLEAR_WALLS): ChunkMesher gives it CLEAR_CUBE instead of CUBE, so it does not hide
  its neighbors' faces (two panes hide each other's, and what stands under or behind glass is
  meshed as seen from the sky, `_sky_through`), and the terrain shaders cut out its texture's
  clear pixels (alpha < 0.5, shadows too) and draw its backs as panes, not rock sections
  (`see_through_walls`). Placing aimed at a small plant puts the block in its place (Minecraft's).
- The workbench is a voxel model two tiles long (WorkbenchModel: a carpenter's bench with a
  vise, drawers, a cupboard, and an iron anvil, hammer and saw on top) standing in two object
  voxels: its left end seen from its front (WORKBENCH, _WEST, _NORTH, _EAST: the way it faces,
  ObjectShapes.FACING_KINDS) holds the model, drawn turned and centered on both tiles
  (ChunkMesher._add_prop), and its right end (WORKBENCH_END_X / _Z, no model:
  ObjectShapes.model_block -1) lies on its right. `Mining.placement` gives the cells a placed
  voxel takes (a bench faces the player, `front_towards`, and takes the cell aimed at and the
  next on its right, else on its left; both free and on cubes); `Mining.object_cells` the cells
  of the object in a cell (breaking either end breaks both, one workbench drops). Msg.BLOCK_PLACE
  carries the way it faces. Bodies are kept out of both tiles end to end
  (ObjectShapes.footprint_rect); the aiming frame covers the whole bench. The item's icon, the one
  in hand and on the ground use the same model (ItemModels).
- Objects placed facing the player: ObjectShapes.FACING_KINDS gives each kind (its first block,
  whose model the others share) its four blocks in WAYS order (S, W, N, E); `kind_of`, `front_of`,
  `facing(kind, front)`, `turn_of`, `model_block`. One-tile ones (chests, furnaces) are BOX_SIZE
  voxels square and a level high; `Mining.placement` puts them in the cell aimed at.
- Houses and gardens (phase 6, step 0; DecorModels, all in one file: front +z, what hangs on a
  wall 16 deep with its back at z = 0): items TORCH_BRACKET, CURTAINS, GLASS_PANE, WINDOW (a clear
  cube block: wall kind 25, CLEAR_WALLS, a framed `window` in gen_art), SINK, TOILET, TABLE,
  CHAIR, FENCE, GATE (wicket), BIG_GATE (two tiles), CAMPFIRE; recipes in Recipes.SHAPED (sink,
  toilet, big gate at the workbench; Recipes.LOGS). ObjectShapes: facing kinds (FACING_KINDS),
  wide objects two tiles long generalized from the workbench (WIDE_KINDS: kind -> right end per
  axis, WIDE_DEPTH, `wide_kind`/`is_wide_left`/`is_wide_end`/`end_axis`/`wide_right`/`wide_end`,
  `base_kind` = a block's kind whatever way it faces or end it is), TOPS (furniture stood on),
  FOOTPRINTS, BARRIERS (fences and shut gates block two levels: nobody jumps over, animals stay
  in), OPENS (gate -> open kind, `is_gate`, `is_open`, `swung`; open ones are NON_SOLID),
  WALL_MOUNTED (bracket, curtains: hung on the side of a cube aimed at, facing away from it:
  BlockInteraction.place takes `front` from the face's normal; Mining.placement wants a cube
  behind; Mining.hung_on / Fixtures.drop_hung: they fall with that cube, not with the floor,
  Mining.needs_support), fences joining fences, gates and cubes (`fence_joins`; their model
  version is the sides joined, FENCE_SIDES bits, 16 versions, ChunkMesher._fence_sides; no
  random turn for Mining.FLOOR_OBJECTS), the campfire `is_lit` (light, glowing flames,
  Light.near_fire). Gates swing with E (Mining.swings / swung_cells; BlockInteraction predicts,
  Msg.SWING_GATE, Fixtures.swing_gate refuses shutting on a body). Items.drops: what players
  place gives its item back (Items._placed_by, open gates too); Mining seconds and tools by
  base kind. ChunkData.raised (column -> 1 + the highest object rising more than a row over its
  terrain: hung high on a wall), kept by set_voxel, found by recompute_tops, sent in to_dict:
  ChunkMesher walks a column up to it (columns stop at `tops` otherwise). The book's "Home and
  garden" chapter (GuideBook._home; chapters' titles are named, not indexed).
- Chests (ChestModel, one tile, CHEST/_WEST/_NORTH/_EAST): placed facing the player, opened with
  E (`Mining.opens`). What a chest holds is its own Inventory (first
  Inventory.CHEST = 27 slots) kept by the server in ChunkData.chests (WorldState.chest_at, made
  empty the first time; `contents_changed` marks the chunk to save; saved in the region with the
  chunk, never sent with it). Msg.OPEN_CHEST (in reach) sets PlayerSession.chest and answers
  Msg.CHEST (its contents; sent again to everyone who has it open when it changes);
  Msg.CHEST_CLICK runs Inventory.click_chest (the player's cursor, Minecraft's rules), and with a
  chest open shift-clicks in the bag move into it (Inventory.click's `chest`). Broken, a chest
  spills its stacks (GameServer._spill_contents). Client: GameClient.chest (its copy, predicted),
  InventoryScreen.open_chest (its 27 slots over the bag instead of the crafting grid); the screen
  closes when what it shows is broken (GameClient._close_if_gone).
- Furnaces (`src/sim/items/smelting.gd`, `furnace.gd`; FurnaceModels): the food furnace (a bread
  oven) only cooks food (Smelting.FOOD: berries -> dried berries, mushrooms -> stew); ore put in it
  (Smelting.BREAKS) breaks it when it melts: BROKEN_FURNACE (same facing, no use, gives stones),
  the ore is lost, the rest spills. The factory furnace smelts ores into ingots and logs into
  charcoal; food comes out CHARRED_FOOD. Each facing kind has an unlit and a lit kind
  (ObjectShapes.LIT, `furnace_kind`, `is_lit`). A Furnace (kind, slots INPUT/FUEL/OUTPUT in an
  Inventory, `fire` 1 -> 0 over `fire_seconds`, `progress` 0 -> 1) is kept per cell in
  ChunkData.furnaces (WorldState.furnace_at / take_furnace, saved with the region); `step(delta,
  clock)` lights fuel (Smelting.FUEL_SECONDS) while something can cook, cooks
  Smelting.COOK_SECONDS, both through `clock.scale_duration()`; progress cools back without fire
  and restarts when another item goes in. The server steps the loaded chunks' furnaces every
  FURNACE_TICKS, swaps the voxel lit/unlit (`_show_fire`), sends Msg.FURNACE to who opened one
  (Msg.OPEN_FURNACE, FURNACE_CLICK: Inventory.click_furnace, where items only go where they fit,
  `Furnace.fits`, and the output only gives; shift from the bag: input, else fuel). Client:
  GameClient.furnace (shown, not stepped), InventoryScreen.open_furnace (input, a flame burning
  down, fuel, an arrow filling up, output, a hint); lit furnaces add a light (ChunkMesher, with the
  lava lights) and glowing voxels; a food furnace breaking near the player is announced
  (`furnace_broke`). Recipes: food furnace 8 stones; factory furnace 8 stones around coal or
  charcoal, at the workbench. The book's Furnaces chapter lists what each makes and the fuels.
- Vitality (`src/sim/survival/`; phase 5 must not copy Minecraft's style: its own HUD, words
  and monsters): `Vitals` holds the rules (MAX_HEALTH 20 points, falls over FALL_SAFE 3 levels
  cost a point a level unless the player lands on water, lava burns LAVA_DAMAGE every
  LAVA_SECONDS real seconds, a short immunity after a hurt, a point back every REGEN_SECONDS
  once nothing hurt for REGEN_DELAY and the player is fed at least FED, both paced by
  `WorldClock.scale_duration()`). Satiety: MAX_FOOD points, one spent per point of effort (time:
  FOOD_SECONDS paced; WALK_EFFORT per tile; BREAK_EFFORT per block; HEAL_EFFORT per point
  healed); at 0 starving costs a point of vitality every STARVE_SECONDS; under WEAK no running
  (LocalPlayer.can_sprint). Food: Items.FOOD (satiety per item), Vitals.POISONS (raw red
  mushroom: sick). The server keeps PlayerSession.health and .food (saved with the player;
  health 0 = passed out) and runs `Survival` (stateless, given the server): falls reported by
  the client (Msg.player_move's `fell`, from PlayerBody.take_fall), lava the feet are in, air
  (MAX_AIR seconds with the eye under water, AIR_REFILL faster back; then DROWN_DAMAGE every
  DROWN_SECONDS; told in AIR_STEP steps, Msg.VITALS `air`; a breath gauge over the satiety's),
  effort (`spend`), eating (Msg.EAT: a hotbar slot's food, not past full), starving, healing,
  `GameServer.hurt` (no hurt nor hunger in creative mode);
  at 0 the player passes out: what they carried (bag, cursor, grid) falls where they are, open
  screens close, their moves and actions are ignored and they pick nothing up until Msg.RESPAWN
  (back at the spawn, full). Msg.VITALS (health, food, hurt, Vitals.Cause), Msg.DIED. Client:
  VitalsView (VitalsBar over the hotbar: vitality on the left half, a life crystal, a notch every
  2 points, a pale trail melting after a hurt, throbbing when low; satiety on the right half, a
  loaf, amber, throbbing hungry; the body reddens, voxel.gdshader `hurt`; DeathScreen pulses the
  screen's edges, and when passed out darkens the world, says why and offers "Get up"; the body
  lies down, PlayerModel.set_down; eating: GameClient.wants_to_eat, food in hand and the right
  button or the left trigger held, one eaten every EAT_SECONDS, predicted, the arm at the mouth,
  crumbs, the first-person hand at the mouth). The book's Survival chapter lists what feeds.
- Game modes (`WorldSettings.GameMode`, the world's; rules in `GameModes`, static, given the
  server): creative players fly (`PlayerBody.fly`, `flying`: two presses of jump within
  LocalPlayer.DOUBLE_JUMP_SECONDS, jump rises, sprint sinks, landing ends it, falls only count from
  where a flight ended), place without using up (server and prediction), break at once
  (BlockInteraction: Mining.BREAK_PAUSE between two) with no drops nor wear, are never hurt nor
  hungry (Survival), see no gauges and take any item from the catalog shown instead of the
  inventory's crafting grid (CreativeCatalog; `GameModes.take_from_catalog`, shared, Msg.CATALOG_CLICK).
  Debug commands (map, Page Up/Down, F4, F6, F7: GameModeView.debug_key) are refused out of
  creative (`GameModes.cheats`; `GameServer.cheats_anywhere` for dev options). Msg.SET_GAME_MODE
  (pause menu) swaps survival and creative (creative makes players well again); a hardcore world
  stays hardcore. Hardcore: passing out makes the player a spectator (`PlayerSession.spectator`,
  saved; RESPAWN refused, moves still accepted); Msg.GAME_MODE tells the mode and that; the death
  screen's button then watches (GameModeView.watch: LocalPlayer.ghost flies through everything,
  PlayerModel.set_ghost, no hotbar, a banner).
- Creatures (`src/sim/creatures/`): `Species` (ids saved: only append; size BOX/TALL, HEALTH,
  WALK/FLEE_SPEED, DROPS; animals BIOMES, HERD; monsters MONSTERS, FLIERS, CHASE_SPEED, DAMAGE,
  CAUSE, HOW_KEYS), `Creature` (server; the base: its body a PlayerBody with its own `box`/`tall`,
  `flying` for fliers; Creature.State IDLE/GRAZE/WANDER/FLEE/CHASE/STRIKE/DORMANT/FROZEN, seen by
  clients; `move` walks its way, jumps up a level, swims; `hurt_by` throws it back, then
  `_on_hurt`; resting ones only move every REST_CHECK; `Creatures.make`/`from_dict`), `Animal`
  (grazes, wanders, flees with its herd), `Monster` (given its prey by `Monsters.sense`, `lit`
  for the lurker; the moth circles and dives, the wisp keeps WISP_NEAR..FAR away and darts,
  fliers through PlayerBody.fly; the lurker walks up in the dark and freezes lit; the mimic lies
  DORMANT until WAKE_RANGE or a blow, lunges, settles after CALM_SECONDS; `strike` set when a
  blow lands), `Monsters` (static: `come_and_go` every Creatures.MONSTER_TICKS: COME_CHANCE, at
  SPAWN_DISTANCE around players it `hunts` (never creative players nor spectators), MAX_NEAR /
  MAX_OF, dark spots (`Light`: daylight under the open sky, lava and lit furnaces within
  Light.REACH): surface at night, caves CAVE_DEPTH down by day too; gone past GONE_DISTANCE,
  NIGHT_ONLY ones melt in daylight under the sky; `land_blow`: Survival.hurt with the species'
  cause, Msg.PUSH, the moth's Msg.LANTERN_OUT; monsters are never saved), `Pathfinder` (A* over tiles, 8 ways without cutting corners, up one level, down
  MAX_DROP, room for `tall`, never into liquids or solid objects' tiles; `ground_at`),
  `Creatures` (held by GameServer, never holding it: populates each chunk once per seed,
  `populated`, skipping modified chunks; animals within ACTIVE_RADIUS chunks of a player think and
  move, half of them each tick; `sync` sends Msg.ENTITY_SPAWN/MOVE/REMOVE per player from its
  sent chunks, `PlayerSession.seen_animals`; `attack` (Msg.ATTACK: Combat.REACH, BLOW_SECONDS
  per session `last_blow`, `Combat.damage_of`, tool wear, herd panic, drops); saved in
  creatures.cfg; `voxel_at` is WorldState.loaded_voxel_at: never makes chunks). Blocks are not
  placed on creatures. Client: CreaturesView (in the world root: one CreatureBody per creature,
  parts from CreatureModels / MonsterModels built at runtime: body, head, legs, arms, wings,
  antlers, a mimic's face on joints; trot, grazing, flapping, the lurker paling frozen, the mimic
  sitting dormant, the wisp pulsing with an OmniLight in world space (`light_parent`), hurt glow,
  tipping over and fading, a burst of bits; `pick` for aiming, `bounds_of`, `name_of`);
  BlockInteraction aims at a creature nearer than the block (`target_creature`, the frame around
  its box) and the break button hits it. LocalPlayer.push (Msg.PUSH), LightingController.lantern_out. Meat roasts in the food furnace (raw
  chicken makes sick: Vitals.POISONS); the WOOL cube block. `--animals=sheep:3,...` brings
  animals around the player.
- Combat: blows by `Combat` (damage_of: HAND_DAMAGE, TOOL_DAMAGE by Items.Tool and Tier; swords,
  Items.Tool.SWORD, hit hardest, made at the workbench like the tools, TOOL_PATTERNS); what is
  hit is thrown back and immune for a moment (Creature.hurt_by). Bow and arrows
  (`src/sim/combat/archery.gd`, held by GameServer): Msg.SHOOT (hotbar slot of the bow, direction,
  power 0..1) after SHOT_PAUSE, an arrow from the slots used up (`arrow_slot`; none in creative,
  where the bow does not wear and arrows are not kept); arrows fly `Archery.fly` (origin, launch
  velocity, GRAVITY: the same on every client), sub-stepped by STEP: through a creature's
  `bounds()` they hurt it (DAMAGE times the speed's share), into a solid block they fall there
  as an ARROW item; Msg.ARROW_SPAWN / ARROW_REMOVE. Client: `Archer` (src/client/combat: the
  right button or the left trigger held with a bow in hand draws, FULL_DRAW seconds, MIN_DRAW;
  the release shoots along the crosshair in first person, ahead with a gamepad, else the low
  ballistic arc (`Archer.ballistic`) landing on BlockInteraction.aim_point (a creature under the
  mouse: its middle); a gauge over the head, PlayerModel.aiming raises the arms and brings the
  bow across the chest (BOW_AT), the first-person bow comes upright; the arrow is taken at once,
  predicted), `ArrowsView` (world root: flies them, stuck when they meet a block). Recipes:
  wool -> 4 string, stone point + stick + feather -> 4 arrows, the bow (sticks and string) at
  the workbench. Armor (`Armor`, shared: helmet, chestplate, leggings, boots of hide, copper,
  iron, gold, diamond; Armor.ITEMS, DEFENSE points (Minecraft's, copper between), durability
  BASE_DURABILITY x MATERIAL_DURABILITY, PATTERNS at the workbench): worn in Inventory.ARMOR..SIZE
  (after the crafting grid: old saves load), each slot taking its own piece (`Armor.click`;
  shift from the slots puts on, `put_on`; shift on a piece worn takes it off); Survival.hurt
  takes REDUCTION_PER_POINT per point off the causes in Vitals.ARMORED (monsters' blows, not
  falls, lava, drowning, hunger; MAX_REDUCTION), keeps the fraction in PlayerSession.hurt_carry
  and wears every piece once (`wear_out`); passing out drops it too. Client: ArmorModels (worn:
  shells a voxel off the body parts, `worn(item)` -> [part, grid, offset], PlayerModel.set_armor
  from GameClient._worn(); icons: flat front outlines, ICON_SHAPES), InventoryScreen's armor
  column under the title (ItemSlot.hint draws the empty slot's piece, a shield with the points;
  hidden beside a chest or a furnace), VitalsBar's steel gauge over the vitality
  (`set_defense`, MAX_DEFENSE 20, `draw_shield`). The book's Combat chapter
  (GuideBook._combat) and Crafting (armor grouped by piece); the book's tabs run down its right
  edge (BookScreen._draw_tabs: TAB_HEIGHT, TAB_REACH).
- Saves (`src/sim/save/world_storage.gd`, server side only): `user://worlds/<folder>/` holds
  world.cfg (settings, clock, weather), players/<name>.cfg and regions/r.<x>.<z>.bin (the chunks
  players changed, 32x32 per file, zstd voxels; the others are generated again). Change voxels
  through WorldState.set_voxel: the chunk is then saved, and loaded instead of generated (also
  after being unloaded). Files are written aside then swapped in (a .bak survives a save cut
  short). The server saves every 2 min of play, when the player pauses (Msg.save_request) and
  on quit. A dev `--seed` alone plays a throwaway world that is never saved (screenshots never
  touch the owner's world); `--new-world` starts the saved world over, `--world=NAME` picks
  another one.
- generate_chunk() must stay thread-safe (read-only shared state): the server runs it on the
  WorkerThreadPool via ChunkGenerationQueue. Tests use `GameServer.new(settings, null, false)`.
- GDScript on worker threads: plain GDScript scales over the cores, but calls on native objects
  (FastNoiseLite...) and allocations barely do. Sample noises in bulk (`get_image_3d`, see
  CaveGenerator._rows), keep hot loops free of allocations and calls, read static tables into
  locals first. `threading/worker_pool/low_priority_thread_ratio` is 0.75 (generation and meshing
  run as low-priority tasks; high priority starves the engine's own work).
- Add tests in `tests/unit/test_*.gd` (extend `TestCase`, methods named `test_*`).
