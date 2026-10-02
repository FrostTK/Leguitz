class_name DisplayModes
extends RefCounted
## The game's window and screen, from the settings (Settings.apply_display):
## windowed at a chosen size (centered), fullscreen (a borderless window
## over the whole screen, at the screen's own resolution) or exclusive
## fullscreen; on which screen; vertical sync; the frame rate limit. A game
## cannot change a screen's resolution or refresh rate (the system does):
## the frame limit can follow the screen's rate.

enum Mode { WINDOWED, FULLSCREEN, EXCLUSIVE }
enum Sync { OFF, ON, ADAPTIVE }

## Window sizes offered (the ones that fit the screen).
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3200, 1800),
	Vector2i(3840, 2160),
]
## A screen whose rate is unknown.
const DEFAULT_RATE := 60.0


## The window sizes that fit on a screen this big (at least the smallest).
static func sizes_fitting(screen_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for size in SIZES:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			result.append(size)
	if result.is_empty():
		result.append(SIZES[0])
	return result


## The frame rate limit for Engine.max_fps: a number, the screen's rate
## (`max_fps` 0) or none (-1, Engine's 0).
static func fps_cap(max_fps: int, screen_rate: float) -> int:
	if max_fps > 0:
		return max_fps
	if max_fps == 0:
		return roundi(screen_rate if screen_rate > 0.0 else DEFAULT_RATE)
	return 0


## How many screens there are (1 without a display: tests).
static func screen_count() -> int:
	return 1 if _headless() else DisplayServer.get_screen_count()


## The screen the window is on, or `screen` if it is one.
static func screen_of(screen: int) -> int:
	if _headless():
		return 0
	if screen >= 0 and screen < DisplayServer.get_screen_count():
		return screen
	return DisplayServer.window_get_current_screen()


static func screen_size(screen: int) -> Vector2i:
	return Vector2i(1920, 1080) if _headless() else DisplayServer.screen_get_size(screen_of(screen))


static func refresh_rate(screen: int) -> float:
	if _headless():
		return DEFAULT_RATE
	var rate := DisplayServer.screen_get_refresh_rate(screen_of(screen))
	return rate if rate > 0.0 else DEFAULT_RATE


## Sets the window (mode, screen, size), the vertical sync and the frame
## limit.
static func apply(window: int, screen: int, size: Vector2i, sync: int, max_fps: int) -> void:
	Engine.max_fps = fps_cap(max_fps, refresh_rate(screen))
	if _headless():
		return
	var vsync := DisplayServer.VSYNC_ENABLED
	if sync == Sync.OFF:
		vsync = DisplayServer.VSYNC_DISABLED
	elif sync == Sync.ADAPTIVE:
		vsync = DisplayServer.VSYNC_ADAPTIVE
	DisplayServer.window_set_vsync_mode(vsync)
	var on := screen_of(screen)
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if window == Mode.FULLSCREEN:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif window == Mode.EXCLUSIVE:
		mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_current_screen(on)
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		return
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_current_screen(on)
	if size != Vector2i.ZERO:
		var room := DisplayServer.screen_get_usable_rect(on)
		var fitting := Vector2i(mini(size.x, room.size.x), mini(size.y, room.size.y))
		DisplayServer.window_set_size(fitting)
		DisplayServer.window_set_position(room.position + (room.size - fitting) / 2)


static func _headless() -> bool:
	return DisplayServer.get_name() == "headless"
