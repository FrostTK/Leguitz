class_name WorldClock
extends RefCounted
## World time: the day/night cycle and the pace of time-based gameplay.
##
## Game time is counted in "game seconds". A game day is always 86 400 game
## seconds (24 h on the in-game clock); the world setting only changes how
## many real seconds one game day lasts.
##
## Modes (chosen per world, editable during play):
## - NORMAL: one game day lasts `day_minutes` real minutes (5 to 120).
## - SYNCED: the in-game clock follows the device clock (1 game day = 24 h).
## - FROZEN: the clock is stopped at a chosen time of day.
##
## Timed gameplay (hunger, smelting, crop growth...) is defined in real
## seconds for the default 20-minute day and scaled "slightly" by
## `pace_factor()` so that longer days feel slower without becoming tedious.

enum Mode { NORMAL, SYNCED, FROZEN }

const GAME_SECONDS_PER_DAY := 86400.0
const DEFAULT_DAY_MINUTES := 20.0
const MIN_DAY_MINUTES := 5.0
const MAX_DAY_MINUTES := 120.0
const SYNCED_DAY_MINUTES := 1440.0
const DAY_MINUTES_PRESETS: Array[float] = [5.0, 10.0, 15.0, 20.0, 30.0, 45.0, 60.0, 90.0, 120.0]

## pace = clamp((day_minutes / DEFAULT_DAY_MINUTES) ^ PACE_EXPONENT, PACE_MIN, PACE_MAX)
const PACE_EXPONENT := 0.25
const PACE_MIN := 0.7
const PACE_MAX := 2.5

## In SYNCED mode, passive processes catch up while the game is closed,
## capped to this many game days.
const OFFLINE_CATCHUP_MAX_DAYS := 1.0

## Times of day (in game seconds) offered when freezing the clock.
const FROZEN_SUNRISE := 6.5 * 3600.0
const FROZEN_NOON := 12.0 * 3600.0
const FROZEN_SUNSET := 18.5 * 3600.0
const FROZEN_MIDNIGHT := 0.0

const NEW_WORLD_TIME := 6.5 * 3600.0
const NIGHT_START := 19.5 * 3600.0
const NIGHT_END := 5.5 * 3600.0

## Moon: 8 phases, 0 = full moon, 4 = new moon.
const MOON_PHASES := 8
const SYNODIC_MONTH_DAYS := 29.530588853
## A known new moon: 2000-01-06 18:14 UTC.
const REFERENCE_NEW_MOON_UNIX := 947182440.0

## If the device clock goes back by more than this, re-anchor forward.
const SYNC_BACKWARD_TOLERANCE := 60.0

var mode: Mode = Mode.NORMAL
var day_minutes: float = DEFAULT_DAY_MINUTES
## Game seconds elapsed since the world's day 0 at 00:00.
var total_game_seconds: float = NEW_WORLD_TIME

var _sync_anchor_game := 0.0
var _sync_anchor_local := 0.0


## Advances the clock by a real-time delta. In SYNCED mode this only
## extrapolates; the authority calls `sync_to_device()` every tick.
func advance(real_delta: float) -> void:
	total_game_seconds += real_delta * game_rate()


## Game seconds that elapse per real second.
func game_rate() -> float:
	match mode:
		Mode.NORMAL:
			return GAME_SECONDS_PER_DAY / (day_minutes * 60.0)
		Mode.SYNCED:
			return 1.0
		_:
			return 0.0


## Real minutes per game day for the current mode (0 when frozen).
func effective_day_minutes() -> float:
	match mode:
		Mode.NORMAL:
			return day_minutes
		Mode.SYNCED:
			return SYNCED_DAY_MINUTES
		_:
			return 0.0


func set_normal(minutes: float) -> void:
	mode = Mode.NORMAL
	day_minutes = clampf(minutes, MIN_DAY_MINUTES, MAX_DAY_MINUTES)


func set_frozen(time_of_day_seconds: float) -> void:
	mode = Mode.FROZEN
	_advance_to_time_of_day(time_of_day_seconds)


func set_synced(local_unix: float = local_unix_now()) -> void:
	mode = Mode.SYNCED
	_anchor_sync(local_unix)


## Aligns the clock with the device's local time (SYNCED mode only).
## Game time never goes backwards: if the device clock is moved back, the
## clock jumps forward to the next matching time of day instead.
func sync_to_device(local_unix: float = local_unix_now()) -> void:
	if mode != Mode.SYNCED:
		return
	var computed := _sync_anchor_game + (local_unix - _sync_anchor_local)
	if computed < total_game_seconds - SYNC_BACKWARD_TOLERANCE:
		_anchor_sync(local_unix)
	else:
		total_game_seconds = maxf(total_game_seconds, computed)


## Multiplier applied to the durations of timed gameplay processes.
func pace_factor() -> float:
	match mode:
		Mode.NORMAL:
			return pace_for_day_minutes(day_minutes)
		Mode.SYNCED:
			return pace_for_day_minutes(SYNCED_DAY_MINUTES)
		_:
			return 1.0


static func pace_for_day_minutes(minutes: float) -> float:
	return clampf(pow(minutes / DEFAULT_DAY_MINUTES, PACE_EXPONENT), PACE_MIN, PACE_MAX)


## Real duration of a process whose base duration is given for a 20 min day.
func scale_duration(base_seconds: float) -> float:
	return base_seconds * pace_factor()


## Real seconds of offline progress to apply when a world is loaded.
## Only SYNCED worlds keep living while the game is closed.
func offline_catchup_seconds(last_seen_unix: float, now_unix: float) -> float:
	if mode != Mode.SYNCED:
		return 0.0
	var cap := OFFLINE_CATCHUP_MAX_DAYS * SYNCED_DAY_MINUTES * 60.0
	return clampf(now_unix - last_seen_unix, 0.0, cap)


func time_of_day() -> float:
	return fposmod(total_game_seconds, GAME_SECONDS_PER_DAY)


## Fraction of the day in [0, 1), 0 = midnight, 0.5 = noon.
func day_fraction() -> float:
	return time_of_day() / GAME_SECONDS_PER_DAY


func day_index() -> int:
	return floori(total_game_seconds / GAME_SECONDS_PER_DAY)


func hour() -> int:
	return int(time_of_day() / 3600.0)


func minute() -> int:
	return int(fmod(time_of_day(), 3600.0) / 60.0)


func formatted_time() -> String:
	return "%02d:%02d" % [hour(), minute()]


func is_night() -> bool:
	var t := time_of_day()
	return t >= NIGHT_START or t < NIGHT_END


## Moon phase in [0, 8): 0 = full moon, 4 = new moon.
## Synced worlds show the real moon; others cycle every 8 game days.
func moon_phase(utc_unix: float = Time.get_unix_time_from_system()) -> int:
	if mode == Mode.SYNCED:
		return real_moon_phase(utc_unix)
	return posmod(day_index(), MOON_PHASES)


static func real_moon_phase(utc_unix: float) -> int:
	var age_days := fposmod((utc_unix - REFERENCE_NEW_MOON_UNIX) / 86400.0, SYNODIC_MONTH_DAYS)
	var from_new := roundi(age_days / SYNODIC_MONTH_DAYS * MOON_PHASES) % MOON_PHASES
	return (from_new + MOON_PHASES / 2) % MOON_PHASES


## Current device time in seconds since the Unix epoch, in local time.
static func local_unix_now() -> float:
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	return Time.get_unix_time_from_system() + bias_minutes * 60.0


func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"day_minutes": day_minutes,
		"total_game_seconds": total_game_seconds,
		"sync_anchor_game": _sync_anchor_game,
		"sync_anchor_local": _sync_anchor_local,
	}


func load_dict(data: Dictionary) -> void:
	mode = data.get("mode", Mode.NORMAL) as Mode
	day_minutes = clampf(
		data.get("day_minutes", DEFAULT_DAY_MINUTES), MIN_DAY_MINUTES, MAX_DAY_MINUTES
	)
	total_game_seconds = data.get("total_game_seconds", NEW_WORLD_TIME)
	_sync_anchor_game = data.get("sync_anchor_game", 0.0)
	_sync_anchor_local = data.get("sync_anchor_local", 0.0)


func _anchor_sync(local_unix: float) -> void:
	_advance_to_time_of_day(fposmod(local_unix, GAME_SECONDS_PER_DAY))
	_sync_anchor_game = total_game_seconds
	_sync_anchor_local = local_unix


## Moves the clock forward (never backwards) to the next occurrence of a
## time of day.
func _advance_to_time_of_day(target_seconds: float) -> void:
	var target := fposmod(target_seconds, GAME_SECONDS_PER_DAY)
	var candidate := day_index() * GAME_SECONDS_PER_DAY + target
	if candidate < total_game_seconds:
		candidate += GAME_SECONDS_PER_DAY
	total_game_seconds = candidate
