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

## Simulation ticks per second (same as Minecraft).
const TICKS_PER_SECOND := 20
const TICK_DELTA := 1.0 / TICKS_PER_SECOND

## Default radius (in chunks) streamed around each player.
const DEFAULT_VIEW_DISTANCE := 4
