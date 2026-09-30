extends TestCase

const HOUR := 3600.0
const DAY := 86400.0


func test_pace_factor_follows_the_agreed_curve() -> void:
	assert_almost(WorldClock.pace_for_day_minutes(5.0), 0.7071, 0.001)
	assert_almost(WorldClock.pace_for_day_minutes(20.0), 1.0)
	assert_almost(WorldClock.pace_for_day_minutes(60.0), 1.3161, 0.001)
	assert_almost(WorldClock.pace_for_day_minutes(120.0), 1.5651, 0.001)
	assert_almost(WorldClock.pace_for_day_minutes(1440.0), 2.5, 0.0001, "capped at x2.5")


func test_pace_factor_per_mode() -> void:
	var clock := WorldClock.new()
	clock.set_normal(60.0)
	assert_almost(clock.pace_factor(), 1.3161, 0.001)
	clock.set_synced(0.0)
	assert_almost(clock.pace_factor(), 2.5)
	assert_almost(clock.scale_duration(10.0), 25.0, 0.001, "10 s smelting in synced mode")
	clock.set_frozen(WorldClock.FROZEN_NOON)
	assert_almost(clock.pace_factor(), 1.0)


func test_day_length_is_clamped() -> void:
	var clock := WorldClock.new()
	clock.set_normal(1.0)
	assert_almost(clock.day_minutes, WorldClock.MIN_DAY_MINUTES)
	clock.set_normal(9999.0)
	assert_almost(clock.day_minutes, WorldClock.MAX_DAY_MINUTES)


func test_normal_mode_advances_one_day_per_day_length() -> void:
	var clock := WorldClock.new()
	clock.total_game_seconds = 0.0
	clock.set_normal(20.0)
	clock.advance(60.0)
	assert_almost(clock.total_game_seconds, 4320.0, 0.01, "one real minute = 72 game minutes")
	clock.advance(20.0 * 60.0 - 60.0)
	assert_eq(clock.day_index(), 1)
	assert_almost(clock.time_of_day(), 0.0, 0.01)


func test_frozen_mode_stops_time_and_moves_forward_only() -> void:
	var clock := WorldClock.new()
	clock.total_game_seconds = 6.5 * HOUR
	clock.set_frozen(WorldClock.FROZEN_NOON)
	assert_almost(clock.total_game_seconds, 12.0 * HOUR, 0.01, "same day noon")
	clock.advance(500.0)
	assert_almost(clock.total_game_seconds, 12.0 * HOUR, 0.01, "no time passes")
	clock.total_game_seconds = 18.0 * HOUR
	clock.set_frozen(WorldClock.FROZEN_NOON)
	assert_eq(clock.day_index(), 1, "noon already passed: next day")
	assert_almost(clock.time_of_day(), 12.0 * HOUR, 0.01)


func test_synced_mode_uses_device_time_of_day() -> void:
	var clock := WorldClock.new()
	clock.total_game_seconds = 6.5 * HOUR
	var local_now := 1_700_000_000.0 + 15.25 * HOUR - fposmod(1_700_000_000.0, DAY)
	clock.set_synced(local_now)
	assert_almost(clock.time_of_day(), 15.25 * HOUR, 0.01)
	assert_eq(clock.day_index(), 0)
	clock.sync_to_device(local_now + 100.0)
	assert_almost(clock.time_of_day(), 15.25 * HOUR + 100.0, 0.01)
	assert_almost(clock.game_rate(), 1.0)


func test_synced_mode_never_goes_backwards() -> void:
	var clock := WorldClock.new()
	var local_now := 10.0 * DAY + 20.0 * HOUR
	clock.set_synced(local_now)
	var before := clock.total_game_seconds
	# The user moves the device clock back by 3 hours.
	clock.sync_to_device(local_now - 3.0 * HOUR)
	assert_true(clock.total_game_seconds >= before, "time must not go back")
	assert_almost(clock.time_of_day(), 17.0 * HOUR, 0.01, "matches the device again")


func test_offline_catchup_only_in_synced_mode_and_capped_to_one_day() -> void:
	var clock := WorldClock.new()
	assert_almost(clock.offline_catchup_seconds(1000.0, 1000.0 + 3.0 * HOUR), 0.0)
	clock.set_synced(0.0)
	assert_almost(clock.offline_catchup_seconds(1000.0, 1000.0 + 3.0 * HOUR), 3.0 * HOUR)
	assert_almost(clock.offline_catchup_seconds(0.0, 3.0 * DAY), DAY, 0.01, "capped")
	assert_almost(clock.offline_catchup_seconds(5000.0, 1000.0), 0.0, 0.0, "clock went back")


func test_formatted_time_and_night() -> void:
	var clock := WorldClock.new()
	clock.total_game_seconds = DAY * 2.0 + 7.0 * HOUR + 5.0 * 60.0
	assert_eq(clock.formatted_time(), "07:05")
	assert_eq(clock.day_index(), 2)
	assert_false(clock.is_night())
	clock.total_game_seconds = 23.0 * HOUR
	assert_true(clock.is_night())


func test_moon_phases() -> void:
	var clock := WorldClock.new()
	clock.total_game_seconds = 0.0
	assert_eq(clock.moon_phase(), 0, "worlds start at full moon")
	clock.total_game_seconds = 4.0 * DAY
	assert_eq(clock.moon_phase(), 4)
	assert_eq(WorldClock.real_moon_phase(WorldClock.REFERENCE_NEW_MOON_UNIX), 4, "new moon")
	var full := WorldClock.REFERENCE_NEW_MOON_UNIX + WorldClock.SYNODIC_MONTH_DAYS * 0.5 * DAY
	assert_eq(WorldClock.real_moon_phase(full), 0, "full moon")


func test_serialization_round_trip() -> void:
	var clock := WorldClock.new()
	clock.set_normal(45.0)
	clock.total_game_seconds = 123456.0
	var copy := WorldClock.new()
	copy.load_dict(clock.to_dict())
	assert_eq(copy.mode, WorldClock.Mode.NORMAL)
	assert_almost(copy.day_minutes, 45.0)
	assert_almost(copy.total_game_seconds, 123456.0)
