class_name HashUtil
extends RefCounted
## Deterministic, engine-independent integer hashing.
##
## World generation must give the same result for a seed on every platform
## and every engine version, so we never rely on Godot's built-in hash().
## All math stays in 32 bits; multiplications are split to avoid 64-bit
## signed overflow in GDScript.

const MASK32 := 0xFFFFFFFF


static func mul32(a: int, b: int) -> int:
	a &= MASK32
	b &= MASK32
	var lo := (a * (b & 0xFFFF)) & MASK32
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & MASK32


## MurmurHash3 finalizer: good avalanche for 32-bit values.
static func fmix32(h: int) -> int:
	h &= MASK32
	h ^= h >> 16
	h = mul32(h, 0x85ebca6b)
	h ^= h >> 13
	h = mul32(h, 0xc2b2ae35)
	h ^= h >> 16
	return h


## Derives an independent 32-bit seed from a 64-bit world seed and a salt.
static func derive_seed(world_seed: int, salt: int) -> int:
	var lo := world_seed & MASK32
	var hi := (world_seed >> 32) & MASK32
	return fmix32(lo ^ fmix32(hi ^ mul32(salt, 0x9E3779B1)))


## Hash of a 2D integer position under a seed, in [0, 2^32).
static func hash2(seed: int, x: int, y: int) -> int:
	var h := fmix32(seed ^ mul32(x, 0x27D4EB2D))
	return fmix32(h ^ mul32(y, 0x165667B1))


## Hash of a 2D integer position mapped to [0, 1).
static func unit2(seed: int, x: int, y: int) -> float:
	return hash2(seed, x, y) / 4294967296.0


## Converts a user-typed seed into a 64-bit world seed.
## Numeric text is used as-is (like Minecraft); any other text is hashed.
static func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	var a := 0x811C9DC5
	var b := 0x01000193
	for byte in trimmed.to_utf8_buffer():
		a = mul32(a ^ byte, 0x01000193)
		b = mul32(b ^ byte, 0x5BD1E995)
	return (fmix32(a) << 31) ^ fmix32(b)
