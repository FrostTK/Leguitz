class_name VitalsBar
extends Control
## The player's vitality and satiety over the hotbar, two compact gauges
## facing each other: on the left the vitality (a life crystal, red; what
## a hurt took shows pale for a moment and melts away; nearly empty, it
## throbs), on the right the satiety (a loaf, amber, emptying towards it;
## throbbing when hungry); both in dark rounded tracks, in segments of two
## points. Over them, slim gauges show only when they count: the armor's
## protection over the vitality (a shield, steel, Armor.defense out of
## MAX_DEFENSE) and the air left over the satiety while the eye is under
## water (a bubble, blue, blinking when nearly out).

const HEIGHT := 16.0
## The slim gauges' row and the main ones' (UI units from the top).
const SLIM_TOP := 2.0
const SLIM_HEIGHT := 2.0
const BAR_TOP := 10.0
const BAR_HEIGHT := 5.0
## Room for an icon beside its gauge, and between the two gauges.
const ICON_ROOM := 11.0
const MIDDLE_GAP := 6.0
## A notch every this many points.
const SEGMENT := 2
const CRYSTAL := ["#5e0e1a", "#a01e2c", "#d8404a", "#ff9a8a"]
const LOAF := ["#5c3412", "#a8641e", "#d89a40", "#f2c878"]
const BUBBLE := ["#2a6a8c", "#8fd0ec", "#ecfbff"]
const SHIELD := ["#3a4652", "#8a9aa8", "#d4e0ea"]
## The pale trail of a hurt.
const TRAIL := Color(UiTheme.TEXT, 0.7)
## The gauge's full (a whole diamond armor).
const MAX_DEFENSE := 20
## How fast the pale trail of a hurt melts (points per second), after
## TRAIL_HOLD seconds.
const TRAIL_SPEED := 14.0
const TRAIL_HOLD := 0.35
## Throbs under this many points.
const LOW := 5

var health := Vitals.MAX_HEALTH
var food := Vitals.MAX_FOOD
var air := Vitals.MAX_AIR
var defense := 0

var _trail := float(Vitals.MAX_HEALTH)
var _hold := 0.0
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `points`; a drop leaves a pale trail.
func set_health(points: int) -> void:
	if points < health:
		_trail = maxf(_trail, health)
		_hold = TRAIL_HOLD
	else:
		_trail = points
	health = points
	queue_redraw()


func set_food(points: int) -> void:
	food = points
	queue_redraw()


func set_air(seconds: float) -> void:
	air = seconds
	queue_redraw()


func set_defense(points: int) -> void:
	if points != defense:
		defense = points
		queue_redraw()


## A small steel shield (7 x 7) at `at` on any control; dim when `lit` is
## false (nothing worn).
static func draw_shield(canvas: CanvasItem, at: Vector2, lit := true) -> void:
	var rows := [[0, 7], [0, 7], [0, 7], [0, 7], [1, 5], [2, 3], [3, 1]]
	for y in rows.size():
		var start: int = rows[y][0]
		var run: int = rows[y][1]
		for x in run:
			var shade := 1
			if x == 0 or x == run - 1 or y == 0 or y == rows.size() - 1:
				shade = 0
			elif start + x == 3 or y == 2:
				shade = 2
			var color := Color(SHIELD[shade])
			if not lit:
				color = Color(color, 0.35)
			canvas.draw_rect(Rect2(at + Vector2(start + x, y), Vector2.ONE), color)


func _process(delta: float) -> void:
	_time += delta
	if _hold > 0.0:
		_hold -= delta
	elif _trail > health:
		_trail = maxf(_trail - TRAIL_SPEED * delta, health)
	if _trail > health or health <= LOW or food < Vitals.HUNGRY or air < Vitals.MAX_AIR:
		queue_redraw()


func _draw() -> void:
	var slots := Inventory.HOTBAR * ItemSlot.SIZE + (Inventory.HOTBAR - 1)
	var left := floorf((size.x - slots) * 0.5)
	var right := left + slots
	var half := floorf((slots - MIDDLE_GAP) * 0.5)
	var length := half - ICON_ROOM
	var life := Rect2(left + ICON_ROOM, BAR_TOP, length, BAR_HEIGHT)
	var satiety := Rect2(right - half, BAR_TOP, length, BAR_HEIGHT)
	var throb := 1.0
	if health <= LOW and health > 0:
		throb = 0.75 + 0.25 * sin(_time * 7.0)
	_gauge(life, health, _trail, Vitals.MAX_HEALTH, UiTheme.LIFE * throb, false)
	_draw_crystal(Vector2(left, BAR_TOP - 2.0))
	throb = 0.75 + 0.25 * sin(_time * 5.0) if food < Vitals.HUNGRY else 1.0
	_gauge(satiety, food, food, Vitals.MAX_FOOD, UiTheme.FOOD * throb, true)
	_draw_loaf(Vector2(right - 9.0, BAR_TOP - 0.5))
	if defense > 0:
		var worn := mini(defense, MAX_DEFENSE)
		_slim(Rect2(life.position.x, SLIM_TOP, length, SLIM_HEIGHT), worn, MAX_DEFENSE, false)
		draw_shield(self, Vector2(left, 0.0))
	if air < Vitals.MAX_AIR:
		var out := air < Vitals.MAX_AIR * 0.25 and fmod(_time, 0.5) < 0.25
		var breath := Rect2(satiety.position.x, SLIM_TOP, length, SLIM_HEIGHT)
		_slim(breath, 0.0 if out else air, Vitals.MAX_AIR, true)
		_draw_bubble(Vector2(right - 6.0, 0.5))


## A main gauge: its track, `points` of `most` filled in `color` (from the
## right when `mirrored`), what a hurt took (`trail`) pale, a lighter top
## row, a notch every SEGMENT points.
func _gauge(
	bar: Rect2, points: float, trail: float, most: float, color: Color, mirrored: bool
) -> void:
	color.a = 1.0
	UiTheme.draw_box(self, bar, UiTheme.TRACK, UiTheme.LINE_STRONG, 2)
	var inner := bar.grow(-1.0)
	var trail_rect := _part(inner, trail / most, mirrored)
	var filled := _part(inner, points / most, mirrored)
	if trail_rect.size.x > filled.size.x:
		UiTheme.draw_box(self, trail_rect, TRAIL, Color.TRANSPARENT, 1)
	if filled.size.x >= 1.0:
		UiTheme.draw_box(self, filled, color, Color.TRANSPARENT, 1)
		var top := Rect2(filled.position + Vector2(1.0, 0.0), Vector2(filled.size.x - 2.0, 1.0))
		draw_rect(top, color.lightened(0.3))
	for point in range(SEGMENT, int(most), SEGMENT):
		var x := inner.position.x + roundf(inner.size.x * point / most)
		draw_rect(Rect2(x, inner.position.y, 1.0, inner.size.y), Color(UiTheme.TRACK, 0.85))


## A slim gauge: armor (steel) or air (blue, `mirrored`).
func _slim(bar: Rect2, points: float, most: float, mirrored: bool) -> void:
	UiTheme.draw_box(self, bar.grow(1.0), UiTheme.TRACK, UiTheme.LINE_STRONG, 2)
	var filled := _part(bar, points / most, mirrored)
	if filled.size.x >= 1.0:
		var color := UiTheme.AIR if mirrored else UiTheme.STEEL
		UiTheme.draw_box(self, filled, color, Color.TRANSPARENT, 1)


## The share `fraction` of `rect`, from its left (its right: `mirrored`).
static func _part(rect: Rect2, fraction: float, mirrored: bool) -> Rect2:
	var width := roundf(rect.size.x * clampf(fraction, 0.0, 1.0))
	var x := rect.end.x - width if mirrored else rect.position.x
	return Rect2(x, rect.position.y, width, rect.size.y)


## A bubble, lit from the top left.
func _draw_bubble(at: Vector2) -> void:
	var rows := [[1, 3], [0, 5], [0, 5], [0, 5], [1, 3]]
	for y in rows.size():
		var start: int = rows[y][0]
		var run: int = rows[y][1]
		for x in run:
			var edge := x == 0 or x == run - 1 or y == 0 or y == rows.size() - 1
			draw_rect(
				Rect2(at + Vector2(start + x, y), Vector2.ONE), Color(BUBBLE[0 if edge else 1])
			)
	draw_rect(Rect2(at + Vector2(1, 1), Vector2.ONE), Color(BUBBLE[2]))


## A small golden loaf, scored on top.
func _draw_loaf(at: Vector2) -> void:
	var rows := [[2, 5], [1, 7], [0, 9], [0, 9], [0, 9], [1, 7]]
	for y in rows.size():
		var start: int = rows[y][0]
		var run: int = rows[y][1]
		for x in run:
			var shade := 2
			if y == 0 or (y == 1 and (x == 0 or x == run - 1)):
				shade = 3
			if y >= 4:
				shade = 1
			if x == 0 or x == run - 1 or y == rows.size() - 1:
				shade = mini(shade, 1) if y < 4 else 0
			draw_rect(Rect2(at + Vector2(start + x, y), Vector2.ONE), Color(LOAF[shade]))
	for x: int in [3, 5]:
		draw_rect(Rect2(at + Vector2(x, 1), Vector2.ONE), Color(LOAF[1]))


## The life crystal: a faceted red gem, lit from the top left.
func _draw_crystal(at: Vector2) -> void:
	var rows := [[3, 2], [2, 4], [1, 6], [0, 8], [0, 8], [1, 6], [2, 4], [3, 2], [4, 0]]
	for y in rows.size():
		var start: int = rows[y][0]
		var run: int = rows[y][1]
		for x in run:
			var shade := 2 if x < run / 2 else 1
			if y >= 5:
				shade -= 1
			if x == 0 or x == run - 1:
				shade = 0
			draw_rect(Rect2(at + Vector2(start + x, y), Vector2.ONE), Color(CRYSTAL[shade]))
	draw_rect(Rect2(at + Vector2(3, 2), Vector2.ONE), Color(CRYSTAL[3]))
	draw_rect(Rect2(at + Vector2(2, 3), Vector2.ONE), Color(CRYSTAL[3]))
