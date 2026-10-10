# Leguitz — notes for Claude

Top-down pixel-art open-world sandbox (Stardew visuals, Minecraft mechanics), rendered in full 3D:
a true voxel world (16x16x128 chunks, cubes textured in pixel art), voxel models for everything else
(trees, plants, player), orbit camera, cut-away view underground, first person in caves (and with
V). Godot 4.7.
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
- First person (`ViewMode`: automatic when entering a cave, setting `cave_first_person`; V any
  time): WorldViewport.dive_frame blends the ortho top-down camera into a perspective one at the
  eye (a 1° perspective from far away opening to 70°), the world root stretch fades to identity
  (`Render3D.root_basis(yaw, pitch, amount)`), the body dithers away (shadow kept), the lantern is
  carried in the left hand. C held (InputBindings.ZOOM_VIEW, letter keys) zooms in:
  WorldViewport.zoom eases to ZOOM_FOV (zoom_towards), looking turns slower (look_scale), the
  arm and the item in hand go down (HeldView, drawn with a field of view of its own). No cut, no see-through hole (globals `cut_height`, `see_through_on`); during the
  dive the backs of faces vanish (`section_on`) so the camera sees through the rock it crosses.
  In first person: caves always shown, props' detail by distance, haze, split sun shadows, a
  procedural sky, 6 chunks loaded; the mouse is captured (released by the pause menu).
- The sky (seen in first person only: top-down, the ortho camera never sees it; the cloud
  shadows are its part there): `sky.gdshader` (shader_type sky), set every frame by
  LightingController._update_sky: a gradient from the horizon (the fog's color, so the haze
  melts into it) to the top, glows at sunrise and sunset (orange towards the sun, pink around, a
  pink band opposite), the sun (a disk, halos in steps, orange and larger low), the moon in its
  phase (WorldClock.moon_phase: full at 0; `moon_light` the angle of its light; seas, the dark
  side faint, a halo; under the glow threshold so no blur hides its phase), stars on a grid of
  directions turning with the night (`star_turn`; about a pixel wide whatever the zoom, through
  fwidth; twinkling; a milky way band), and clouds: CloudShadows3D's noise, CLOUD_SCALE and
  `drift` (public now) on a layer at CLOUD_LEVEL, lit from the sun's (moon's) side, in flat
  steps. Its colors are written in sRGB and made linear (`lin`). LightingController
  .sky_body_direction puts the sun and the moon on their true arc (on the horizon at
  SUNRISE/SUNSET, under it after), while sky_direction keeps the light higher for readable
  shadows. No radiance is made from the sky (ambient light is a color, reflections off): it
  costs ~0.07 ms in HD. Mind pow() of a value a hair under 0 (clamp it): NaN pixels, spread by
  the glow into big white blots. Weather particles fade out closer to the eye than
  WeatherEffects.NEAR_FADE (distance fade, dithered): leaves lit by the lantern or fireflies
  right in front of a first-person eye filled the view.
- Trees, plants, rocks and the player are voxel models (1 voxel = 1 art pixel = 1/16 tile):
  generators in `src/client/models/voxel_models.gd` (trees: `tree_models.gd`, detailed procedural
  trees: tapering, leaning trunks on roots, forking limbs, lit leaf clusters, bark grooves and
  moss), meshed by VoxelMesher (greedy faces + AO) and saved by
  `godot --headless --path . -s res://tools/gen_models.gd [-- --only=oak]` into `assets/models/`
  (commit the .res files; rerun after changing a model; all of them take ~15 min). Every non-cube
  block needs a model (tested). `voxel.gdshader` (its code in voxel.gdshaderinc, shared with
  voxel_view.gdshader, what is in hand in first person) handles wind, wetness and leaf backlight;
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
- Player settings (Settings autoload, user://settings.cfg; the pause menu's SettingsPanel, in
  sections Display, Graphics, Game, each choice applied and saved at once through
  `Settings.choose(key, value)`; new display keys in Settings.DISPLAY_KEYS): window mode
  (DisplayModes.Mode: windowed at `resolution`, centered, ZERO keeps the window's size;
  FULLSCREEN a borderless window at the screen's own resolution; EXCLUSIVE), `screen` (shown
  when there are several), `vsync` (DisplayModes.Sync), `max_fps` (Settings.FPS_CHOICES; 0 the
  screen's refresh rate, -1 no limit: DisplayModes.fps_cap), `show_fps` (DebugOverlay shows only
  the frame rate when F3 is off), `far_view` (chunks loaded in first person; the haze follows:
  LightingController.FIRST_PERSON_HAZE_PER_CHUNK), `brightness` (Environment adjustment),
  `ui_scale`, `first_person_fov` (WorldViewport.first_person_fov, dive_frame's `end_fov`),
  `mouse_sensitivity`, `extreme` (asked by the owner: every graphics setting at its most,
  EXTREME_QUALITY Ultra, HD, EXTREME_FAR_VIEW 12, EXTREME_DETAIL props' reach, and none of the
  savings below; read the graphics through Settings.effective_quality / effective_hd /
  effective_far_view, the player's own choices are kept; SettingsPanel shows the row first in
  Graphics with a WarningSign, a dark red "!" triangle whose tooltip tells the pros and cons,
  and greys EXTREME_KEYS out at their most; ZOOM_CHOICES has x1). A game cannot change a
  screen's resolution or refresh rate (the system does). DisplayModes does nothing under the
  headless display server (tests). Never call Settings.choose or save_settings in tests: they
  write the user's real settings file (tests set Settings.extreme and put it back).
- Savings (measured on the owner's world: the game is held back by the main thread, the
  graphics card waits): in first person, chunks farther than the haze are hidden
  (WorldView3D.set_far_reach, (effective_far_view + 1) chunks; the top-down view at zoom 1
  keeps ~360 loaded); while thrifty (off: extreme) small props (PropLibrary.is_small, no
  taller than SMALL_HEIGHT) in their coarser copies cast no shadow (PropLibrary.casts_shadow,
  ChunkView3D.refresh_shadows), CreaturesView does not animate creatures out of the camera's
  view (they catch up, CreatureBody.waited) and animates those small on screen (zoomed out to
  x2 or less, or FAR_ANIMATION from a first-person eye) every other frame, small kinds then
  without shadow (CreatureBody.set_shadow). Always: CreatureBody sets its shader parameters only
  when they change; Growth.update runs each tick on a slice of the chunks (Growth.slice_of,
  each chunk once every CHECK_TICKS: no more 100 ms hitch every 5 s); Apiary.flowers_near reads
  the chunks' voxels straight (it takes the WorldState).
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
  and with tools, what can be placed; liquids then flow in: Fluids), aiming by `VoxelRay` (DDA in
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
  BlockInteraction.use_target); the right click does the same on them and on gates (asked by
  the owner: BlockInteraction.usable_here, first thing in `place`, also in `tends_here` and
  keeping the bow from drawing, Archer._may_draw); Shift + right click places against them.
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
- Tools (`Items.TOOLS`: pickaxe, axe, shovel, sword and hoe in 6 materials, `Items.Tier`; they do not stack):
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
  Tools, swords and the bow (asked by the owner, more lifelike): `ToolModels` draws each once as
  a profile (`_paint(kind, u, v)`: u along the handle, v across towards the side that strikes,
  in model voxels of ToolModels.SCALE, half a body voxel; a thickness each: grained wood, a
  leather-wrapped grip, the head in TOOL_HEADS' colors with darker eyes and bright sharpened
  edges and points) built straight for the hands (`held`: handle along y, striking side +z,
  pivot on the grip, `grip`) and on the diagonal of a 16x16 grid for icons and items on the
  ground (`icon`, fitted inside the grid's diamond by `_fit`; ItemModels.build hands it the
  tools and the bow). The bow has DRAW_STAGES models (limbs bending, `stage_of(draw)`), its
  string and arrow thin boxes (`bow_lines`, ItemLibrary._add_lines), not voxels.
  `ItemLibrary.held_mesh`, `in_hand(handle, front, grip, size, fist)` (a model by its grip at a
  fist). Third person (PlayerModel; the right arm is `_right` = _arms[0], at -x: the body faces
  +z): `holding` (Holding: ITEM, TOOL, SWORD, BOW), tools held at FIST (a little outwards) in the
  arm's plane, the wrist's angle in the arm's pose; strokes (`stroke` -1 raised .. 0 .. 1
  struck, `stroke_kind`: MINE, SLASH, JAB; `stroke_curve`: raised, struck fast, back;
  STROKE_SECONDS) follow one another while `swinging`, one per `swing()` (a tool strikes, a
  sword slashes, else a jab, the bow none); `arm_pose` (MINE/SLASH/HAND/JAB_POSES); tested to
  never go through the head; the bow upright at rest (BOW_LIMBS), across the chest drawn.
  First person: `HeldView` (child of the camera; GameClient._hold / _update_held) shows the
  right arm (the body's arm model, armor sleeves) and what it holds, drawn with its own field of
  view (VIEW_FOV 70°, whatever Settings.first_person_fov) and in front of the world
  (`view_model.gdshaderinc`: voxel_view.gdshader, held_block.gdshader for blocks' cubes; a
  shader writing POSITION must write it for every vertex, so voxel.gdshader never does), so it
  never cuts into a wall nor changes with the field of view; poses [fist, handle, front] at
  rest, raised and struck (TOOL_POSES: down onto the crosshair; SWORD_POSES: across to the left;
  HAND_POSES: a jab), bobbing with the walk, lagging behind the look, rising when what is in
  hand changes, lowered by the zoom, food to the mouth, the bow drawn in front leaning right
  (the arm hidden), trembling at full draw; never culled (extra_cull_margin), no shadow (the
  body's copy casts it).
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
  LightField.SHINE). Gates swing with E (Mining.swings / swung_cells; BlockInteraction predicts,
  Msg.SWING_GATE, Fixtures.swing_gate refuses shutting on a body). Items.drops: what players
  place gives its item back (Items._placed_by, open gates too); Mining seconds and tools by
  base kind. ChunkData.raised (column -> 1 + the highest object rising more than a row over its
  terrain: hung high on a wall), kept by set_voxel, found by recompute_tops, sent in to_dict:
  ChunkMesher walks a column up to it (columns stop at `tops` otherwise). The book's "Home and
  garden" chapter (GuideBook._home; chapters' titles are named, not indexed).
- Lights (phase 6, step 1): items TORCH (coal or charcoal over a stick: 4) and LANTERN (a torch
  between two iron ingots); blocks TORCH (on the ground), TORCH_BRACKET_LIT (a torch in a
  bracket: aimed at an empty bracket with a torch in hand, Mining.fills; never straight against a
  wall), LANTERN (ground), LANTERN_HANGING (ObjectShapes.HANGING: from the cube above, falls with
  it, Mining.hung_on, not with the floor, needs_support), LANTERN_WALL (wall-mounted); the
  item's other shapes in ObjectShapes.SHAPE_OF (they give the lantern back; a lit bracket gives
  the bracket and the torch). Msg.BLOCK_PLACE carries `face`, the side of the cube aimed at
  (Mining.placement's `face`: UP top, DOWN underside, sides; Mining.minds_the_side); top-down the
  camera never sees an underside, so Shift (InputBindings.SPRINT) with a lantern aimed at a floor
  hangs it under the ceiling over it (Mining.under_ceiling, CEILING_SEARCH rows). They do not
  block bodies; placing what does not block is allowed where a body stands (server and client
  check only solid voxels; Fixtures.someone_in). What players placed is no longer replaceable
  like a plant (Mining.is_replaceable: Items.item_placing). ObjectShapes.LIGHTS: is_lit (with lit
  furnaces): their light (LightField.SHINE) keeps monsters away, ChunkMesher._add_flame lights them
  (ChunkMesher.FLAMES: where the flame is, energy, color, flicker; lava keeps LAVA_COLOR), and
  ChunkView3D.flicker (driven by WorldView3D) makes flames waver (lanterns hardly). Models in
  DecorModels (`_torch`, `_lantern`; their flames and glass are GLOW voxels). Small aiming bodies
  (VoxelRay.SMALL_BODIES; a wall lantern deeper, LANTERN_SLICE).
- Sky light (phase 6, step 2; `src/sim/world/light_field.gd`, shared): levels 0 to 15
  (Minecraft's). LightField.sky: per column `open`, the first row from which the sky is fully
  seen (down through CLEAR voxels: air, objects, glass and windows, CLEAR_BLOCKS), water under it
  dimming a level a cell; then it spreads into covered places a level less a cell (two through
  water; only shore water cells are queued, `_under_water`); cubes and lava are OPAQUE.
  ChunkMesher (full builds) works it out over the chunk and its 8 neighbors (a 48 x 48 region,
  missing neighbors are rock: ChunkSky.field) and bakes the level of the cell in front of each face
  (`_sky`: COLOR.b of tops, sides, undersides and water; faces only merge in the same light; caps
  get 15) and of each prop (INSTANCE_CUSTOM.a = level + wind phase); Result.sky_open /
  sky_levels are kept by ChunkView3D (WorldView3D.sky_at). The shaders (`sky_light.gdshaderinc`,
  `sky_ambient`) turn it into AO with AO_LIGHT_AFFECT 0: it only dims the ambient light, never
  the lights (voxel.gdshader keeps its occlusion on direct light through the albedo), so a
  closed cave or room is black but for lanterns, torches, fires, lava and glowing ores. Bodies
  get `sky_light` (PlayerModel.set_sky_light, CreatureBody.sky_light from CreaturesView.sky_at);
  dropped items and items in hand are not darkened. WorldView3D.voxel_changed also rebuilds the
  chunks the light around a changed voxel reaches. The ambient light no longer changes
  underground (the sun still goes out there): LightingController.sky_here (GameClient._sky_here,
  feet or head) eases into `sky_seen`, which sets `darkness` and so lights the lantern; under
  cover, top-down, the lantern hangs under the ceiling (GameClient.LANTERN_UNDER_COVER), not
  high over the head (inside the rock). Meshing costs about a quarter more (bench: 25 chunks
  ~650 ms instead of ~520). Server: `Light.level` looks REACH (LightField.MAX - LIT) cells around
  a cell (`level_at`, a search paying a level a cell, two through water): the sky's MAX by day,
  NIGHT_SKY at night, over each column's open row; LightField.shine of what shines (lava through
  its opaque body); players' lanterns never count. `is_lit` from LIT (7): Monsters._choices only
  brings monsters out where it is not lit, the lurker freezes when lit; NIGHT_ONLY ones still
  melt by `sky_open`. `near_fire` is the same without the sky. The book's contents page shrinks
  its rows, then its letters, to fit every chapter (BookScreen._draw_contents).
- Flowing liquids (phase 6, step 3; `src/sim/world/fluids.gd`, Fluids held by GameServer):
  the world's water and lava are sources and stay still until something next to them changes:
  GameServer.change_voxel calls `Fluids.touch` (the cell and its 6 neighbors settle if water or
  lava is in or around it, or was), and `update` settles them a step every WATER_TICKS (lava
  LAVA_TICKS; real time, at most MAX_PER_STEP cells a step). Flowing liquids are grounds of their
  own appended to Tiles.Ground (WATER_FLOW_1..4, WATER_FALLING, LAVA_FLOW_1..2, LAVA_FALLING;
  Tiles.WATER_GROUNDS / LAVA_GROUNDS, `liquid_source`, Voxels.is_water / is_lava: use these, never
  compare with Ground.LAVA), so physics, light, saves and messages carry them as any voxel.
  Fluids.level_of (0 source, 1 to WATER_REACH 4 / LAVA_REACH 2, FALLING), `voxel_for`,
  `surface` (how high a liquid fills its cell, by whole art pixels: PlayerBody._surface,
  DroppedItem, ChunkData.surface_height, the meshes). A cell wants FALLING under the same liquid,
  else one level more than its lowest neighbor spreading sideways (`_spreads`: standing on
  something solid, or a still one on a source; falling ones merge into liquids), at most the
  reach; two water sources around a cell standing on something make it a source; settled, a
  liquid pushes the free cells around it (`fillable`: air, small plants; never what players
  placed) to settle too; cut off, flows dry up. Lava meeting water turns into stone (both ways).
  Breaking no longer fills a hole with water at once (Mining.left_after_break is gone). Meshes:
  flowing tops lowered (their code is their own ground, drawn as the source: ChunkMesher maps it,
  and the surface map), sides of liquids open to the air or to the same liquid lower
  (LiquidFaces.sides, ChunkMesher._add_liquid_sides: in the water parts, COLOR.r = 1) drawn by
  water.gdshader as streaks running down (lava: its colors, emissive). Lava now shines by itself
  (LAVA_LIT: its albedo takes little light) so it is not white at noon. gen_art: grounds from
  FIRST_OWN_SEED_GROUND draw from their own generators (older textures unchanged). ChunkSky (the
  sky light of a build) and LiquidFaces were split from ChunkMesher (1000 lines). The book's tip
  16. Not saved: the cells waiting to settle (a flow stopped by quitting stays until touched).
- Growing plants (phase 7, step 1; `src/sim/world/growth.gd`, Growth: static, given the server):
  saplings (Tiles.Block *_SAPLING, items of the same names: a felled tree gives 1-2 of its
  species, Items.SAPLING_OF; a young tree its own back and a stick) are planted on soil
  (Growth.is_soil: grasses, dirt, podzol, mud, mycelium; Mining.placement, never in water) and
  become YOUNG_* trees (ObjectShapes.TREES entries with small trunks, modeled by TreeModels with
  their species' generator and lower leaf floors, YOUNG_LEAF_FLOOR), then trees (a spruce in a
  SNOWY_BIOMES column comes out SNOWY_SPRUCE: Growth.tree_for). Bare dirt next to grass turns
  into that grass (Growth.GRASSES; dirt under a plant counts as bare). ChunkData.growing (server
  only, saved with the region as "growing") holds the cells that may grow: Growth.note, called
  by WorldState.set_voxel (only changes, never generation), adds saplings, young trees and dirt
  (also dirt laid bare by what was over it), drops the rest. GameServer.tick runs Growth.update
  every CHECK_TICKS over the loaded chunks: each cell gets its chance (CHECK_TICKS / the mean
  duration paced by WorldClock.scale_duration: SAPLING_SECONDS, YOUNG_SECONDS, GRASS_SECONDS;
  tests pass `chance`), then needs Light.level >= LIGHT (the night stops it, a torch near makes
  it grow) and room (`_room`: the rows over it, a tree's trunk levels + CROWN_ROWS, free of
  anything solid; `_spaced`: no solid object on the 8 tiles around, as WorldGenerator._spaced).
  Models: SaplingModels (a stem and tufts of the species' bark and leaves; a spruce's cone, an
  acacia's flat tuft, a jungle tree's broad leaves, a swamp oak's moss; also the items).
  gen_models takes `--only=a,b,c`. The book's Farm chapter (GuideBook._farm). No offline growth.
  ItemSlot waits for a hint's icon in `_process` (asking a redraw from `_draw` crashed Godot when
  the inventory opened before the icons were rendered).
- Fields and crops (phase 7, step 2; `src/sim/world/farming.gd`, Farming: static, given the
  server): hoes (Items.Tool.HOE, 6 tiers, TOOL_PATTERNS "MM / S / S" at the workbench; their head
  in ItemModels._tool_head) till grass or dirt (`tilled`: the small plant over it goes, never
  under what players placed) into grounds FARMLAND / FARMLAND_WET (gen_art `farmland`, own seeds;
  TerrainRenderer.PRIORITY like dirt; they give dirt). Client: a hoe in hand makes the right click
  BlockInteraction._till (predicted, the hoe wears) and sends Msg.TILL, handled by Farming.till
  (reach, a hoe in that slot, wear unless creative). Crops are object blocks by stage (WHEAT_0..3,
  CARROTS_0..3, POTATOES_0..3; Farming.STAGES, RIPE, SOWN, `sown_of`), sown from SEEDS (now
  "wheat seeds"), CARROT, POTATO (Items.PLACES_BLOCK; Mining.placement wants farmland under
  them; never replaceable); modeled by FarmModels (rows of plants; also the farm items). Growth
  tracks crops and farmland: farmland settles every check (`settle_farmland`: wet with water
  within MOIST_REACH on its row or the one above, dry otherwise; dry with nothing sown it may
  turn back to dirt, FALLOW_SECONDS), crops go a stage on average every STAGE_SECONDS on wet
  farmland (DRY_SLOWER times longer on dry), in the light. Drops (Farming.harvest through
  Items.drops): ripe, the harvest and seeds; unripe, the seed back; tall grass gives seeds and
  now and then (Items.WILD_ROOTS) a carrot or a potato. 3 wheat (shapeless) make DOUGH; the food
  furnace bakes it into BREAD and POTATO into BAKED_POTATO (Smelting.FOOD; all of them char in the
  factory furnace). Carrots and potatoes are food too: GameClient.wants_to_eat skips them while
  BlockInteraction.tends_here (aimed at farmland: sows_here; at a composter). The book's Farm
  chapter (Fields) and Tools (the hoe).
- Watering and care (phase 7, step 3; static, given the server): `Watering`
  (`src/sim/world/watering.gd`): the WATERING_CAN (5 copper ingots, "C / CC / CC"; one per slot)
  keeps its water in its slot's wear (Inventory.wear, DroppedItem.wear: 0 empty as crafted,
  Items.CAN_WATER 20 full; `Items.wear_limit` clamps loads; ItemSlot draws a blue bar; the
  creative catalog's comes full). Filled at water, still or flowing, or a sink (`fills_from`;
  Msg.FILL_CAN; client: BlockInteraction._water_aimed casts the aiming ray again with water as
  solid, `_ray_origin/_direction/_span` kept by `_aim`), it waters a tile of farmland a right
  click (`bed_of`: aimed at a crop, the farmland under it; Msg.WATER; empty: HUD_CAN_EMPTY;
  creative uses no water): `wet` turns it FARMLAND_WET and keeps it so WATERED_SECONDS (300, a
  quarter of the default day, paced) in ChunkData.watered (server, saved with the region as
  "watered"; Growth.note drops a cell that is no farmland any more; decrements are not saved on
  their own). Growth's farmland check calls `Watering.dry_out` (the rain, Weather.is_raining,
  rewets what is `under_sky`: ChunkData.top_row at most a row over it, so glass and roofs keep
  it off) and passes `watered` to Farming.settle_farmland. Canals need nothing: flowing water
  counts in Farming.wet_near. Light is Growth's (glass lets the sun through, a lantern lights a
  cellar field: tested). `Composting` (`src/sim/world/composting.gd`): the COMPOSTER (7 planks,
  "P P / P P / PPP"; furniture: Mining.FLOOR_OBJECTS, TOPS/FOOTPRINTS 14, axe) is a block by
  level, LEVELS (COMPOSTER, _1.._6, COMPOSTER_FULL = FILL 7) then COMPOSTER_READY;
  ObjectShapes.STAGE_OF maps them to COMPOSTER (`base_kind`: drops, seconds, tops, SINGLE; each
  has a model, FarmModels.composter(level): a slatted bin, two-row gaps so they survive the
  LODs, the waste showing). `use(block, item)`: a COMPOSTABLE item goes in (a level), a ready one
  empties (a COMPOST comes out); Msg.COMPOST from the right click (BlockInteraction._tend, before
  placing) or E (use_target). Growth rots a full one (`may_grow`, ROT_SECONDS 60 paced, in the
  dark too). Broken ready, it drops its compost too (Items.drops). COMPOST spread (Msg.
  SPREAD_COMPOST, `spread_on` through Growth.next_stage, public now) makes an unripe crop, a
  sapling or a young tree (with room) grow a stage at once; the client predicts crops only
  (`guess_spread`). FarmModels: the can, the composter, compost. The book's Farm chapter
  (Watering and care).
- More crops (phase 7, step 4): Farming's tables hold every crop by stage (STAGES, RIPE, SOWN,
  SEED_OF, HARVEST; `stage_of`, `sown_of` through a lookup) and where each grows (BEDS, Farming
  .Bed: FIELD farmland, WATER rice over still water one deep over soil or sand, BANK sugar cane
  on soil or sand with water beside it or a row under, TRELLIS grapes; `sowing` is
  Mining.placement's rule for SOWN blocks, `holds` is Growth's check before a stage). New field
  crops (BEETROOTS, CABBAGES, CORN sown from a cob, TOMATOES, STRAWBERRIES and RASPBERRIES sown
  from a berry, FLAX, PUMPKIN_STEM, MELON_STEM, each _0.._3), RICE_0..3, SUGAR_CANE_0/_1 then the old
  SUGAR_CANE (ripe; the SUGAR_CANE item now plants _0), TRELLIS (a floor object, sticks) and
  GRAPES_0..3 sown into it (Mining.fills; breaking a vine gives the trellis back). Grown stems
  (Farming.FRUIT_OF, kept in ChunkData.growing) put a PUMPKIN or MELON (solid furniture you
  stand on, TOPS/FOOTPRINTS) on a free side over soil, sand or farmland (`bear_fruit`), none
  while one lies beside them; a melon breaks into slices. `Picking` (src/sim/world/picking.gd,
  Msg.PICK; client: BlockInteraction._pick, from the right click before anything else but the
  can, and E) takes what is ripe without breaking it: PICKED (tomatoes, strawberries, grapes back
  a stage, raspberries too, sugar cane cut back to _0, a fruit tree in fruit back into blossom)
  and GIVES, into
  the bag (the rest thrown). Rice in hand is sown on the water aimed at
  (BlockInteraction._sow_on_water with the can's watery ray; the server accepts sown blocks not
  touching a cube). Fruit trees: APPLE/CHERRY/ORANGE/PEACH _SAPLING (planted from their pips:
  APPLE_SEEDS, CHERRY_PITS, ORANGE_SEEDS, PEACH_PIT, crafted from the fruit), YOUNG_*_TREE, *_TREE (in
  blossom) and *_TREE_FRUIT (Growth.FRUITING, FRUIT_SECONDS; ObjectShapes.BEARING: the same
  trunk, and TreeModels seeds the crown from the blossoming block, so only the dots differ:
  TreeModels._fruit_tree, _dot_crown, colors in OrchardColors; a tree turning into another,
  picked, bearing or grown up, never shows a tree falling: BlockInteraction.fells). Generation: wild plants
  (Tiles.Block.WILD_*, Farming.WILD: what they give; SurfaceBuilder.WILD_PLANTS, never
  undergrowth) and wild fruits (SurfaceBuilder.WILD_FRUITS: pumpkins, melons, kept only with no
  solid object around them, WorldGenerator._alone, and out of the trees' spacing) come last in
  VEGETATION, so they only take tiles that had nothing; WILD_RICE floats like lily pads
  (SALT_WILD_RICE); SurfaceBuilder.orchard_tree turns some of a biome's trees into fruit trees
  after spacing (ORCHARDS, SALT_ORCHARDS: the chances of one tree add up), half in blossom, which the generator notes in
  ChunkData.growing so they bear fruit. Recipes: seeds from a pumpkin, a melon slice, a tomato,
  grapes; pips from fruit; sugar from cane or beetroot; string from flax, LINEN from four
  (curtains take wool or linen); the food furnace roasts corn and cooks rice. CropModels
  (src/client/models/crop_models.gd; FarmModels hands it every crop but wheat, carrots,
  potatoes): rows of plants, a creeping stem, the trellis and its vine, pumpkins, melons, wild
  plants (a few ripe plants where they fell), the items; VoxelModels.sugar_cane takes heights
  (the ripe one unchanged). Vines on a trellis are not turned at random (ChunkMesher._add_prop).
  The book's Farm chapter (More crops, Fruit trees).
- Husbandry (phase 7, step 5; `src/sim/creatures/husbandry.gd`, Husbandry: static, given the
  server; Creatures.update calls `update` every tick and `sense` before each animal thinks, like
  Monsters.sense): an Animal keeps its farm life (`age` left as a young one, `love`,
  `breed_rest`, `affection` 0..MAX_AFFECTION and the days it was `petted_day`, `fed_day`,
  `cared_day`, `shorn`/`wool_in`, `milk_in`, `egg_in`; saved in creatures.cfg; `leader`, the
  player leading it, is not). Msg.TEND_ANIMAL (client: BlockInteraction._tend_animal, the right
  click or E on an animal aimed at, not with a bow; tends_here keeps food in hand from being
  eaten) runs `tend`: its own lead lets it go, a LEAD (4 string make 2) takes it along, SHEARS
  (2 iron ingots, SHEARS_DURABILITY) shear a sheep (SHEARED: wool falls, more when LOVED or
  ADORED; grows back after WOOL_SECONDS), a BUCKET (3 iron ingots) milks a grown sheep
  (MILKED, MILK_SECONDS) into a MILK_BUCKET (food, Items.LEFT_AFTER gives the bucket back once
  drunk), what it eats (FEED) feeds it (grown: in love LOVE_SECONDS; young: grows FEED_GROWTH
  sooner; once a day it loves more), anything else pets it (once a day). The player is told
  how it went: Msg.ANIMAL_NOTICE (a HUD key with the species' name and the affection,
  CreaturesView.notice_text). Two of a kind in love within MATE_RANGE walk to each other
  (Animal.mate_at) and a young one is born (`_birth`: Animal.set_age, a body BABY_SIZE small,
  GROW_SECONDS paced), its parents rest. On a lead an animal follows its player
  (Animal.leader_at, `_follow`, hurrying when far); past LEAD_SNAP the lead snaps (it falls;
  so it does when the animal dies). Chickens lay every EGG_SECONDS (two eggs now and then when
  adored) into the nearest NEST_BOX with room within NEST_RANGE (NEST_BOX_1..3, Husbandry.NESTS,
  ObjectShapes.STAGE_OF; the eggs are gathered through Picking, broken it gives its eggs too),
  else on the ground; EGG fries into FRIED_EGG. A day without care (petted, fed, or a night
  under a roof) takes a point of affection (`_neglect`, Creatures.day). At night
  (Animal.night) animals sleep (Creature.State.SLEEP, appended); a loved one first looks for a
  roof (`find_shelter`: the nearest ground tile within SHELTER_RANGE with a cube over it,
  `covered`) and walks there. Entity messages carry `flags` (Animal.Flag: BABY, SHORN, LOVE)
  and `lead` (the player's id). Client: CreaturesView.spawn/move take the messages, rebuild a
  sheep's body shorn or not (CreatureModels.parts(kind, shorn)), throw pink bits over animals
  in love (`burst` with a count), draw a sagging rope (boxes) from an animal to this player's
  hand (`player`, `player_id`); CreatureBody scales the young (`size`) and lays sleepers down
  (legs folded, FOLD, LIE_SINK). RanchModels: the nest box with its eggs, shears, buckets, the
  lead, eggs. The book's Animals chapter (Husbandry).
- Farm animals (phase 7, step 6): Species COW (plains, meadows, savannas), GOAT (mountains),
  DUCK (rivers, swamps; Species.SWIMMERS: Pathfinder.find/ground_at `swims` go over water,
  FLOAT under a water cell's top; PlayerBody.float_depth, Creature.SWIMMER_FLOAT, so it rides
  on it), RABBIT (forests, taigas, snow, desert; CreatureBody hops it), PIG (no BIOMES: a
  boar's young is born a pig, Husbandry.BORN_AS) and BEE; Husbandry's FEED, MILKED (sheep,
  cows, goats), LAYS (chickens, ducks). Meats RAW_/COOKED_ BEEF, RABBIT, DUCK (raw duck makes
  sick; ItemModels.MEAT_SHAPES: rabbit and duck cut like chicken). Bees
  (`src/sim/creatures/apiary.gd`, Apiary: static, given the server; `bee.gd`, Bee extends
  Creature, not saved): a BEEHIVE (planks around honeycomb; Mining.FLOOR_OBJECTS) or a wild
  BEE_NEST (on a stump; SurfaceBuilder: plains, flower forests, meadows, among WILD_FRUITS,
  WorldGenerator gives it some honey and notes it in ChunkData.growing) is a block by its honey,
  Apiary.HIVES (0 to FULL 3, STAGE_OF). Growth gives each hive its turn (`Apiary.work`): by
  day it sends a bee out per check up to BEES (a nest one less), telling them of the flowers
  and crops within FLOWER_RANGE (`flowers_near`, again each check); it fills a level on average
  every HONEY_SECONDS (paced) divided by the flowers near (up to MOST_FLOWERS), not without
  any. A Bee flies (FLIERS, body.fly) from its hive to a flower, hovers (GRAZE), back, and so
  on; at night it flies home and goes in (Apiary.sense, Creatures.update; its hive gone, it
  goes). Crops within POLLINATION_RANGE of a hive (Growth gathers `_hives` each update) take
  POLLINATED of the time a stage. Full, a hive gives a HONEY_BOTTLE to a GLASS_BOTTLE (3 glass
  make 3; honey is food, Items.LEFT_AFTER gives the bottle back) or COMBS honeycomb to shears
  (they wear): Msg.HARVEST_HIVE, Apiary.harvest; the client predicts it
  (BlockInteraction._harvest_hive, right click or E; tends_here). A wild nest broken gives
  honeycomb. Client: CreatureModels (_cow, _goat, _duck, _rabbit, _pig, _bee), CreatureBody
  (a bee's wings always beating), ApiaryModels (the hive at each level, honey oozing down its
  front, the nest, the bottles, honeycomb). The book's Animals chapter (pigs, Bees).
- Wild animals and pests (phase 7, step 7): Species WOLF, BEAR (PREDATORS: Predator extends
  Animal, saved; CHASE_SPEED, DAMAGE, Vitals.Cause WOLF/BEAR, armored), FROG, TURTLE, BEAVER
  (swimmers), FISH (AQUATIC: Fish extends Animal, swims with body.fly, a step leaving the water
  is undone; Creatures.populate puts them in water at least 2 deep, `water_spot`), and pests
  (PESTS, no BIOMES, never saved, not summoned): MOLE (Mole), CROW (Crow), LANTERN_BUMBLEBEE (a
  Bee). `Wildlife` (static, given the server; Creatures.update calls `sense` for the animals it
  `minds` and `land_blow` when a Predator strikes): a predator hit (`provoked`) turns, with its
  pack (PACK_RANGE), on the player who struck it for ANGER_SECONDS; a bear warns a player within
  WARN_RANGE (State.ALERT, appended: it rears up) and charges after WARN_SECONDS, sleeps at
  night; at night wolves go for a player within NIGHT_RANGE who is not `Light.is_lit`; hungry, a
  predator chases the nearest Species.PREY (its pack's) for Predator.CHASE_SECONDS, eats it (no
  drops) and the eaters are fed HUNGER_SECONDS (paced); never a creative player nor a spectator
  (Monsters.hunts). Turtles lay TURTLE_EGGS on sand every EGG_SECONDS (Animal.chore_in, saved),
  not within EGG_SPACING of other eggs; Growth hatches them a stage at a time (TURTLE_EGGS, _1,
  _2: STAGE_OF, cracked models; then young turtles; HATCH_SECONDS); the TURTLE_EGG item puts them
  back on sand (Mining.placement, can_place). Beavers build BEAVER_DAM (furniture stood on, TOPS
  16, its model rising from the riverbed out of the water; gives sticks) in still water by a bank
  or the dam (`dam_spot`, MOST_DAM within DAM_RANGE) every DAM_SECONDS. Wolves, bears and fish
  are `is_wild`: tending them tells HUD_ANIMAL_WILD. `Pests` (static; Creatures runs
  `come_and_go` every PEST_TICKS, `sense` before each pest thinks) around players monsters may
  hunt with MIN_CROPS crops within FIELD_CHUNKS (`crops_near`, from ChunkData.growing): a mole
  (MOLE_CHANCE) tunnels from crop to crop out of sight (WANDER), gnaws one (GRAZE, then the crop
  becomes a MOLEHILL, gives dirt), comes up (IDLE: only then `hurt_by` lands; hurt or after
  RAVAGES it leaves); crows (by day, MAX_CROWS) fly in to the young crops (`is_young`: stages 0
  and 1) not watched by a SCARECROW within SCARE_RANGE (`scarecrows` reads the chunks' voxels
  straight; a pumpkin over wheat and sticks, two levels tall), peck one after PECK_SECONDS (it
  goes) and go on to the next, flee (FLEE, then `gone`) from a player within CROW_FLEE, the
  night, a blow or a scarecrow; lantern bumblebees (night, MAX_BUMBLEBEES) come out among the
  flowers (Apiary.flowers_near) and go at dawn: Growth gathers their middles (`Pests.glowing`)
  and crops within GLOW_RANGE (`lit_by`) grow in the dark and POLLINATED faster. Items RAW_FISH
  (roasts into COOKED_FISH), SCARECROW, TURTLE_EGG. Client: WildModels (the nine bodies, a
  fish's "tail" part, the bumblebee's GLOW tail; the blocks and items; it uses CreatureModels'
  public helpers voxel_of, leg_grid, four_legs, eyes, shaded, noise), CreatureBody (frogs hop,
  a bear rears on ALERT, wolves and bears lunge on STRIKE, a fish's tail sweeps, a mole sinks
  out of sight unless up, a crow flaps unless pecking), CreaturesView (LIGHTS: the wisp's and
  the bumblebees' lights; a digging mole throws up dirt). The book: Animals (Wild animals,
  GuideBook.WILD_ICONS, CREATURE_<KIND>_HOW) and Farm (Pests).
- Kitchen (phase 7, step 8): the KITCHEN counter (a facing kind, KITCHEN/_WEST/_NORTH/_EAST,
  ObjectShapes.is_kitchen; Mining.opens; stone over a food furnace and planks at the workbench)
  opens the inventory with its grid making the dishes only: recipes `"kitchen": true`
  (Recipes.KITCHEN, shapeless, groups COOKED_MEATS, MUSHROOMS, SOUP_GREENS, PIE_FRUITS,
  JAM_FRUITS), never anywhere else (Recipes.find/result_of `kitchen`, Inventory.craft /
  craft_result `kitchen`; PlayerSession.kitchen set by Msg.OPEN_WORKBENCH aimed at a counter,
  cleared on close or passing out; client InventoryActions.open_kitchen,
  InventoryScreen.open(width, cooking): titled KITCHEN_TITLE, KITCHEN_COOK over the grid).
  Crafting leaves what held a liquid in its cell (Inventory._use_grid, Items.LEFT_AFTER: the
  milk's bucket, the jam's jar; juices, cider and jam leave a glass bottle once eaten too).
  Dishes: BREAD from flour, VEGETABLE_SOUP, MEAT_STEW, FRUIT_PIE, OMELETTE, CAKE, CREPES, GRATIN,
  TARTINE, JAM. `Machines` (src/sim/world/machines.gd, static, given the server): MILL (grain ->
  FLOUR, 16 at once, 8 s each), BUTTER_CHURN (a milk -> 2 BUTTER, 45 s), BARREL (8 fruits ->
  APPLE_JUICE or FRUIT_JUICE, 240 s; apple juice left CIDER_SECONDS more turns into CIDER;
  taken into GLASS_BOTTLEs held in hand, as many as there are: BOTTLED), CHEESE_CELLAR (a milk
  -> 3 CHEESE, 600 s); each a block by Stage (STAGES: empty, working, ready; STAGE_OF, SINGLE,
  FLOOR_OBJECTS, never turned at random: ChunkMesher checks the base kind). Msg.USE_MACHINE
  (right click or E, BlockInteraction._use_machine / _machine_usable, predicted when it takes;
  a ready barrel without bottles in hand says HUD_BARREL_BOTTLES): an empty machine takes up to
  CAPACITY of what it makes something of (a milk's bucket back at once; not used up in
  creative), works SECONDS paced (the mill's per grain), a ready one gives what it made and
  empties. ChunkData.machines (cell -> {input, inputs, made, count, left, ferments}, saved in the
  region as "machines"); GameServer.tick runs Machines.update every TICKS; broken, `spill`
  (GameServer.spill_contents) gives back the grain or fruit while working, what it made when
  ready (not liquids). `Effects` (src/sim/survival/effects.gd, shared): OF_FOOD gives a dish's
  effects (Kind REGEN, FED, SWIFT, STRONG, HASTE: seconds, paced when eaten), kept in
  PlayerSession.effects (saved with the player, told in Msg.VITALS `effects`, cleared on
  passing out); a dish with effects is eaten even full (Survival.eat, VitalsView); REGEN heals a
  point every REGEN_EVERY whatever the satiety (Survival._mend), FED makes satiety go
  FED_SLOWER as fast (Survival.spend), STRONG adds STRONG_DAMAGE to blows (Creatures.attack),
  SWIFT walks SWIFT_SPEED faster (LocalPlayer.speed_bonus), HASTE breaks HASTE_SPEED faster
  (BlockInteraction). Client: VitalsView.effects (run out locally), Hotbar.effects (EffectsRow:
  a badge each over the vitality, a sign and a bar running out). KitchenModels: the counter, each
  machine's stages, the dishes and what the machines make. The book's Kitchen chapter
  (GuideBook._kitchen: the counter's recipes, the machines, the effects; kitchen recipes are not
  in Crafting). GameServer's furnaces moved to `Furnaces` (src/sim/items/furnaces.gd, static,
  given the server: open, click, opened, changed, update) to make room.
- Fishing (phase 7, step 9; `src/sim/fishing/`): `FishTable` (shared) holds each fish
  (SPECIES: PERCH, TROUT, CARP, PIKE, CATFISH, EEL, SALMON, SARDINE, MACKEREL, COD, SEA_BASS, TUNA,
  LANTERNFISH, CAVE_FISH: its waters, Water bits LAKE/RIVER/SWAMP/SEA/CAVE from the biome,
  `water_of`; climates, Climate bits from the biome, `climate_of`; Period bits DAY/TWILIGHT/NIGHT,
  `time_of`, a cave always NIGHT; the depth of water under the bobber; how common; its bait,
  BAIT_FAVOR; rain bringing it out at any time, RAIN_FAVOR; its size in cm), SHELLFISH (CRAYFISH,
  CRAB: traps only), JUNK (SEAWEED, DRIFTWOOD: JUNK_CHANCE, less baited, none in caves), TRAPS (a
  trap's catches per water); `weight_of`, `pick`, `trap_pick`, `size_of`. `Fishing` (static, given
  the server; real seconds, a player's action): Msg.CAST (the rod's hotbar slot and where the
  player aims; `within_reach`: CAST_RANGE tiles at most) lands the bobber (`landing`: the first
  thing under the aim, a liquid's surface; on the ground nothing bites) after `flight_of`; a Line
  per PlayerSession (`line`: FLYING, FLOATING, NIBBLE, BITE, GROUND; never saved) waits (`_wait`:
  WAIT, shorter baited, in the rain, at twilight, longer over shallow water), nibbles, then bites
  BITE_SECONDS (+ BITE_LEEWAY): Msg.REEL then lands the fish (`_bites`: FishTable.pick for
  `water_at`, Watering.under_sky or a cave, the time, the rain, `depth_at`, the bait), which leaps
  to the player (a dropped item, LEAP_SECONDS), uses the bait up and wears the rod (Items
  .ROD_DURABILITY; not in creative), Msg.CAUGHT (item, size, broke); a missed bite eats the bait
  (Msg.BOBBER `missed`). The bait is the first of BAITS (WORM, BAIT_BALL, FISH_BAIT) in the slots
  (`bait_slot`). The line goes when the rod leaves the hand, the player passes out or is LINE_SNAP
  away; a new cast takes back a line still out. Worms: Items.drops of soil (WORM_CHANCE) and
  tilling (Fishing.worm_chance, twice in the rain). FISH_TRAP (Tiles.Block FISH_TRAP, _BAITED,
  _FULL: Machines Kind.TRAP, STAGE_OF, SINGLE, NON_SOLID) is set on still water
  (Mining.ON_WATER: Mining.placement, GameServer._set_alone; BlockInteraction._sow_on_water),
  takes up to 4 baits and catches one thing per bait (Machines.EACH, 150 s each paced;
  `_catches` -> held "catches", given or spilled); its model sinks into the water
  (ObjectShapes.SUNK, ChunkMesher._add_prop). Items: raw and grilled fish (Smelting.FOOD; the
  factory furnace chars what the food furnace takes or makes, Smelting.chars), Recipes.SEAFOOD
  (fish bait, the kitchen's FISH_SOUP, SUSHI, FRIED_FISH with Effects), the rod (3 sticks, 2
  string), the trap (sticks, string), corn bait (flour, corn), driftwood (sticks, fuel), seaweed
  (compost). Client: `Angler` (src/client/fishing; GameClient.angler; BlockInteraction.place hands
  it the right click with a rod in hand; `aim_ray`): casts at the water aimed at (predicted, the
  arm swings first, CAST_DELAY), reels in, shows every player's bobber (FishingModels.bobber:
  flying in an arc, rocking, nibbling, pulled under with a splash, on the ground, reeled back),
  the local player's line (an ImmediateMesh line strip in global space, one pixel thin, sagging
  slack, taut on a bite) from the rod's tip (PlayerModel.rod_tip; first person HeldView.rod_tip,
  brought from the view's own field of view to the camera's), turns a still player towards the
  bobber (top-down), announces the bait (HUD_ROD_BAIT) and the catch (HUD_CAUGHT, HUD_FISHED_UP,
  HUD_FISH_TOOK_BAIT). The rod: ToolModels ROD (a bamboo pole, a cork grip, a reel, rings, a red
  tip; stage 0 its bobber hooked near the grip, 1 cast: PlayerModel.cast; `rod_lines`,
  `rod_tip`), PlayerModel Holding.ROD (ROD_POSES: cast from over the shoulder; never through the
  head, tested), HeldView ROD_POSES. FishingModels: the trap's stages (a wicker basket under
  SURFACE, a cork float, then red and white, a yellow flag with a catch), each fish from LOOKS
  lying on its side (patterns, tails, fins; grilled browned with grill marks), crayfish, crabs,
  baits, seaweed, driftwood, the dishes. The book's Fishing chapter (GuideBook._fishing,
  `_fish_text` from FishTable).
- Boats (phase 7, step 9A; `src/sim/boats/`, `src/client/boats/`): the SHIPYARD (a facing kind,
  SHIPYARD/_WEST/_NORTH/_EAST, ObjectShapes.is_shipyard, NON_SOLID; Mining.opens; placed on a bank
  facing the water, not the player: Mining.placement uses Boats.water_side, LAUNCH_ROOM tiles of
  water ahead a row or two down, `launch_row`; its model sinks a level, ObjectShapes.SUNK, the
  slipway going down into the water, BoatModels.shipyard). A `Boat` (shared): its parts in `slots`
  (an Inventory: BOW, SECTIONS 0 to MOST_SECTIONS, STERN, ENGINE, FUEL, NET for 9B, then a place
  each from PLACE: BOAT_BENCH or CHEST, `chests` by place), `places()` 2 + sections, `length()`
  from BOW/SECTION/STERN_LENGTH (model voxels), `at` (its middle at the water's surface), `yaw`
  (bow towards (sin, cos)), `speed`, `yard` (NO_YARD afloat), `pilot` and `seats` (place -> a
  player's id, -id an animal), `burn` (seconds of the coal burning), `seat(place)` (-1 the
  pilot's), `click` (Minecraft-like, its rules in `takes`/`holds`/`refusal`: the hull only at a
  shipyard, a section only with the last place empty, a chest only empty, a bench nobody sits on;
  no client prediction), to_dict/from_dict. `BoatBody` (shared, static): `step` (throttle -1..1,
  steer, full: ROW_SPEED, ENGINE_SPEED with Boat.powered, FULL_SPEED; pushes, DRAG, TURN slower
  the longer, reversed astern; flowing water carries it, `current_at`), `fits` (its `hull_points`
  over water on its row, nothing solid over them: land and ice stop it), `touches_lava`,
  `surface_at`, `water_row`. `Boats` (held by GameServer.boats, saved in boats.cfg by
  WorldStorage.read_boats/save_boats; messages through `handle`, GameServer's fallback):
  Msg.OPEN_YARD / OPEN_BOAT (PlayerSession.yard_open, boat_open; answered by Msg.BOAT_SCREEN),
  BOAT_CLICK (a shipyard makes a boat when a part goes on its empty slipway, lets go of an
  emptied one; `cradle` puts it along the slipway), BOAT_ACT (Act.LAUNCH: onto the water in front
  if the hull fits; DOCK: up the nearest free shipyard within DOCK_RANGE, nobody aboard;
  OPEN_CHEST: a boat's chest opened as a chest whose cell is `chest_cell`, row CHEST_ROW and
  under: GameServer._open_chest/_chest_changed), BOARD (the pilot's place, else a free bench; the
  animals the player leads, Animal.leader within LEAD_RANGE, take free benches from the bow,
  Creature.seated, skipped by Creatures.update), LEAVE_BOAT (onto the nearest standable tile
  within LANDING, else into the water; Msg.PLAYER_TELEPORT; their animals with them; passing out
  leaves too, Survival._pass_out), BOAT_STEER (the pilot's report of BoatBody's step, refused
  past 2 tiles: BOAT_MOVE `correct`), BOAT_HIT (BREAK_HITS, an axe twice; nobody aboard; breaks
  into its parts and what it carries; so does a broken shipyard's, `yard_broken`). `update`:
  riders checked and kept on their seats (PlayerSession.boat, seat; no walking effort aboard),
  coal burnt while the pilot pushes (COAL_SECONDS each, FULL_BURN), rowing tires (ROW_EFFORT),
  lava burns it (its chests' contents spill), BOAT_MOVE every MOVE_TICKS. Client: `BoatsView`
  (world root; `boats` from Msg.BOAT, `mine()`, a model per look built at runtime,
  BoatModels.key_of/boat; the pilot's boat where Helm steps it, the others eased; sliding along
  the slipway, lying on it bow down, SLIPWAY_PITCH; propeller turning, smoke puffs from the
  chimney in local units drawn outside the root, oars rowing without an engine, a wake, a shake
  when struck, `pick`/`bounds_of` for aiming), `Helm` (aboard: LocalPlayer.aboard, the body put
  on its seat, PlayerModel.seated/legs_out/rowing; the pilot's movement keys are the throttle
  and the helm, sprint full throttle, BoatBody stepped at once, Msg.BOAT_STEER; jump leaves; a
  coal gauge, or "rowing"), BlockInteraction (`target_boat`: place boards, break strikes, use
  opens; aboard, use opens its screen; `_instead_of_placing`), BoatPanel (src/ui; in
  InventoryScreen.open_boat: hull row at a shipyard, engine, coal, the net's dim place, the deck
  drawn with a slot per place and a chest's Open button, Launch / Back to the shipyard;
  InventoryActions.open_yard/open_boat/show_boat_screen). Items and recipes (at the workbench):
  SHIPYARD, BOAT_BOW, BOAT_SECTION, BOAT_STERN, BOILER, PROPELLER, COAL_ENGINE, BOAT_BENCH. The
  book's Boats chapter (GuideBook._boats).
- Nets and paint (phase 7, step 9B): the FISHING_NET (string and iron at the workbench; mended
  with three strings: a new one; Items.NET_DURABILITY) goes in Boat.NET (its wear in the slot's,
  kept by Boat.click both ways; BoatPanel shows its bar). `Nets` (src/sim/boats, static, run by
  Boats.update even with nobody aboard): Msg.NET (the NET key, R, InputBindings.NET; Helm) casts it
  or hauls it in (Boat.net_down; hauled, Boat.net_catch goes to that player); taken out of its slot
  it is hauled in. Cast it wears a point every WEAR_SECONDS (FAST_WEAR times as fast over SLOW
  tiles a second, catching nothing then) and CATCH_WEAR a catch; over DEPTH water, slow, a catch
  every CATCH_SECONDS (FishTable.pick for Fishing.water_at, no bait) goes into the first chest
  aboard with room (`_put`, the open chest screens told), else the net keeps up to HOLD; worn out
  it tears (HUD_NET_TORN, its catch lost). Real seconds. Paint: LINSEED_OIL (the mill grinds
  FLAX_SEEDS into it, Machines.BOTTLED: taken into glass bottles; a ready machine's bottles missing:
  Msg.NOTICE HUD_BOTTLES_NEEDED, Msg.notice being any HUD key) and a pigment (Recipes.REDS, BLUES,
  COALS, the flowers, cactus; mixed: orange, purple) make a pot (Items.PAINTS, durability
  PAINT_COATS: its coats; the last leaves its GLASS_BOTTLE). The right click on a boat with a pot
  (BlockInteraction._instead_of_placing; Shift: the stripe) sends Msg.BOAT_PAINT: Boat.paint
  [hull, stripe] (indices of Items.PAINTS, -1 bare; saved, kept on a shipyard, lost broken); an
  axe scrapes it. The shader paints it: VoxelGrid.Kind PAINT and STRIPE (VoxelMesher UV.y 3 and
  4; voxel.gdshaderinc `painted`/`striped`, instance uniforms paint_color and stripe_color, sRGB,
  alpha 0 bare; the plank's brightness kept, PAINT_LUMA; only with PAINTED defined, in
  voxel_painted.gdshader, BoatsView's material: instance uniforms take room in a renderer buffer
  for every instance of the shader, and first person's props ran it out): BoatModels marks the
  strakes over the water line PAINT, the top strake, gunwale and stem STRIPE, PAINT_COLORS;
  BoatsView._dress sets
  them per hull (set_instance_shader_parameter), and shows the net folded over the stern
  (BoatModels.net_bundle) or cast behind it (net_cast, its catch in it, cached by count); the
  boat screen draws the deck in its paint. The book's Boats chapter (net, paint, linseed oil).
- Companions (phase 7, step 10; `src/sim/creatures/companion.gd`, `companions.gd`): Species DOG
  (no BIOMES: a wolf tamed) and CAT (wild in plains, flower forests, savannas, jungles),
  Species.COMPANIONS; a `Companion` (extends Animal, saved) has `owner_name` (the player's name;
  "" wild or stray: it lives as animals do), `order` (Companion.Order FOLLOW, STAY, GUARD), `post`
  (where it stays or guards), `coat` (Companions.COATS: dogs 5, cats 6, WILD_COATS first; sent as
  Msg.ENTITY_SPAWN `look`, Creature.look), Flag.TAME (a collar) and BARK, State.SIT (appended).
  `Companions` (static, given the server; Creatures.update runs `sense`, `land_blow`, and `gather`
  every BRING_TICKS): Husbandry.tend hands it the right click (`tend`): a wolf given meat
  (DOG_FOOD, raw or cooked) by a player it is not after is fed and now and then (TAME_CHANCE)
  replaced by their dog (coat 0, grey); a wild cat, the same with fish (`cat_food`: every fish,
  raw or grilled); it shies from players within SHY_RANGE unless they hold a fish (it comes up:
  leader_at). Its player's food heals it (HEAL), else Husbandry.feed (public now: love, young ones;
  Companions.born gives them a parent's coat or any, and their player); anything else cycles its
  order (Companion.command; pets it once a day); someone else's says HUD_COMPANION_NOT_YOURS; its
  player's blows and arrows spare it (Creature.belongs_to: Creatures.attack, Archery). Following,
  it keeps at HEEL (sits after SIT_AFTER), is brought beside its player past BRING_RANGE (not
  while they are aboard: Animal.follows makes Boats seat it, as led animals), counts as cared
  for; it mends a point every MEND_SECONDS. Every LOOK_SECONDS a dog barks at monsters and
  hunting predators within BARK_RANGE (its player told, BARK_NOTICE) and, following or guarding,
  goes for those within DEFEND_RANGE of its player or post (LEASH): a bite hurts a monster, drives
  a predator off (Predator handles FLEE now, its hunt and anger forgotten); Wildlife._hunt_prey
  skips prey a dog `protects` (`dogs_of`); guarding, it drives back to its post the FLOCK animals
  within HERD_RANGE farther than KEEP (`_pick_stray`, `_herd`: Companion.drive_at behind the
  stray, Animal.drive towards the post until BACK_IN). A cat following or guarding (prowling
  within PROWL) hunts moles and crows within HUNT_RANGE, biting a mole once up, a crow once landed
  (`target_ready`). Client: CompanionModels (src/client/models; DOGS and CATS coats, a collar
  with a tag, `parts(kind, coat, collar)`, a "tail" part; CreatureModels.parts takes look and
  collar), CreaturesView (meshes keyed by flags and look; rebuilt when tamed; a barking dog's
  puffs, BARK_SECONDS), CreatureBody (`_animate_companion`: sitting on its haunches, the tail
  wagging or swaying, a dog's muzzle up barking, lunge and a cat's leap, a stalking crouch). The
  book's Companions chapter (GuideBook._companions).
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
  and restarts when another item goes in. The server (`Furnaces`) steps the loaded chunks' furnaces every
  FURNACE_TICKS, swaps the voxel lit/unlit (`_show_fire`), sends Msg.FURNACE to who opened one
  (Msg.OPEN_FURNACE, FURNACE_CLICK: Inventory.click_furnace, where items only go where they fit,
  `Furnace.fits`, and the output only gives; shift from the bag: input, else fuel). Client:
  GameClient.furnace (shown, not stepped), InventoryScreen.open_furnace (input, a flame burning
  down, fuel, an arrow filling up, output, a hint); lit furnaces add a light (ChunkMesher, with the
  lava lights) and glowing voxels; a food furnace breaking near the player is announced
  (`furnace_broke`). Recipes: food furnace 8 stones; factory furnace 8 stones around coal or
  charcoal, at the workbench. The book's Furnaces chapter lists what each makes and the fuels.
  The factory furnace (Furnace.is_factory; asked by the owner) cooks up to four kinds at once:
  LANES (LANE_COUNT 4, a kind each: `fits` refuses a kind another lane holds, `lane_holding`;
  filled by hand or by `_fill_lanes`, which moves a whole stack of a kind no lane holds from
  TO_COOK), one fire burning `lanes_cooking()` times faster (at least once), fuel taken from
  FUELS, what is made added to COOKED (`gives_only`), each lane its own `lane_progress`; its
  slots (FACTORY_SLOTS 64, `slot_count`) are three chests too: TO_COOK 18, FUELS 12, COOKED 30,
  CHEST_COLUMNS 6 across; `shift_places` (what cooks, else what burns) for shift-clicks from the
  bag. A factory furnace saved with the old three slots moves its fuel and what it made into the
  chests (load_dict). InventoryScreen: the lanes with bars filling up, the flame and its "xN",
  in the panel; the chests in panels beside it (`_side`: to cook and fuel on the left, cooked
  on the right; `_factory_slots` by furnace slot). The food furnace keeps its three slots.
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
- Chat and commands (asked by the owner; `src/sim/chat/`, static, given the server): Msg.CHAT
  (what a player typed) goes to Chat.receive: a line is said to every player (Msg.chat_said,
  with the name), or after "/" is a command run by the server (Commands.run) that answers in
  the chat (Chat.tell: Msg.chat_notice, a translation key and its args, a Dictionary {"key"}
  being a word the reader translates too, in a Chat.Tone). Commands.LIST: each command's name,
  French alias and whether it is the admins' (CMD_<NAME>_USAGE / _HELP in i18n); for everyone
  help, players, msg (whisper), where, seed (Commands), clear (the player's slots, armor
  and grid too, or one item: PlayerCommands); admins tp (random: RANDOM_NEAR to
  RANDOM_FAR on dry land with room to stand; spawn; a player; x z on the ground,
  `_landing`; x level z; ~ relative), time (words, 7h30, freeze, run; refused when SYNCED),
  weather, gamemode (WorldCommands), give, summon (not bees nor pests), heal (GameModes.restore), admin
  list/add/remove (PlayerCommands). Names and words are matched plainly (Chat.plain: case,
  accents, underscores; Chat.names_of: an enum's keys and the en/fr translations; Chat.lookup:
  exact, else the only one starting so, else the close ones told). WorldSettings.admins
  (saved with the world): the first player to join a world without any becomes one
  (Chat.on_join). Client: ChatBox (src/ui; T, InputBindings.CHAT, or "/" opens it; Esc, Enter,
  Up/Down through what was sent, the wheel scrolls, Tab completes: ChatCompletion, a
  command's name as the player's language writes it, its first word from its translated usage,
  items and creatures by their names, else in English; the common start first, then each in
  turn, the options listed under the lines; lines fade after LINE_SECONDS, as many as fit over
  the hotbar; the world takes no input while typing: GameClient.screen_open);
  ClientMessages handles every server message (moved out of GameClient). The book's Commands
  chapter (GuideBook._commands) and its chat key. The debug keys (F4, F6, F7, Page Up/Down, M)
  stay as they are.
- Pick block (asked by the owner; not in the book): the middle click in first person
  (GameClient._handle_block_input, BlockInteraction.pick_block) takes the item of the block
  aimed at in hand (`PickBlock`, src/sim/items, shared: `item_of` the item placing it, whatever
  way it faces, its stage or its fire, in creative else what breaking it gives; `pick`: a
  hotbar slot holding it is chosen, else a stack of it in the bag is swapped into the hotbar,
  the slot in hand if empty, else the first empty one, else the one in hand; in creative, none
  held, a stack from the catalog, what was in that slot going into the bag; in survival and
  hardcore nothing is made). The client guesses it, Msg.PICK_BLOCK (the item) has the server do
  the same.
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
  clients; `move` walks its way, jumps up a level, swims (a way point right over or under it is
  reached: never a division by a zero distance; a step leaving non-finite feet puts it back, and
  Creatures.from_dict drops creatures saved lost: a NaN body overlaps every cell, so
  Fixtures.someone_in refused placing blocks at its height anywhere); `hurt_by` throws it back, then
  `_on_hurt`; resting ones only move every REST_CHECK; `Creatures.make`/`from_dict`), `Animal`
  (grazes, wanders, flees with its herd), `Monster` (given its prey by `Monsters.sense`, `lit`
  for the lurker; the moth circles and dives, the wisp keeps WISP_NEAR..FAR away and darts,
  fliers through PlayerBody.fly; the lurker walks up in the dark and freezes lit; the mimic lies
  DORMANT until WAKE_RANGE or a blow, lunges, settles after CALM_SECONDS; `strike` set when a
  blow lands), `Monsters` (static: `come_and_go` every Creatures.MONSTER_TICKS: COME_CHANCE, at
  SPAWN_DISTANCE around players it `hunts` (never creative players nor spectators), MAX_NEAR /
  MAX_OF, dark spots (not `Light.is_lit`, see the sky light): surface at night, caves
  CAVE_DEPTH down by day too; gone past GONE_DISTANCE,
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
  bow across the chest (BOW_AT), bending as it is drawn (PlayerModel.draw, ToolModels stages),
  the first-person bow comes up in front, an arrow on the string; the arrow is taken at once,
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
