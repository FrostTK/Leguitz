class_name GameConst
extends RefCounted
## Engine-wide constants shared by the simulation and the client.

## Size of one tile in world pixels (art is authored at this resolution).
const TILE_SIZE := 16
## Chunk edge length in tiles (same as Minecraft).
const CHUNK_SIZE := 16
const CHUNK_SHIFT := 4
const CHUNK_MASK := CHUNK_SIZE - 1
const CHUNK_AREA := CHUNK_SIZE * CHUNK_SIZE
const CHUNK_PIXELS := CHUNK_SIZE * TILE_SIZE
## World height in voxels. A voxel is one tile wide and one level tall.
const WORLD_HEIGHT := 128
## Voxel row of sea level: terrain at level L is solid up to row
## SEA_LEVEL + L - 1, so heights in levels are rows minus SEA_LEVEL.
const SEA_LEVEL := 64

## Simulation ticks per second (same as Minecraft).
const TICKS_PER_SECOND := 20
const TICK_DELTA := 1.0 / TICKS_PER_SECOND

## Radius (in chunks) streamed around each player: the client asks for
## what its view needs (zoom, window size, camera angle) within limits.
const DEFAULT_VIEW_DISTANCE := 4
const MIN_VIEW_DISTANCE := 2
const MAX_VIEW_DISTANCE := 16
