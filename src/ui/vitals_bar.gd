class_name VitalsBar
extends Control
## The player's vitality over the hotbar's left half (a life crystal and a
## gauge framed in wood, a notch every two points; what a hurt took shows
## pale for a moment and melts away; nearly empty, it throbs) and their
## satiety over the right half (a loaf and an amber gauge, throbbing when
## hungry); over it, while the eye is under water, the air left (a bubble
## and a slim pale blue gauge, blinking when nearly out).

## Gauge and crystal sizes (UI units).
const HEIGHT := 15.0
## The gauges' row (the air's is over it).
const ROW := 6.0
const BAR_HEIGHT := 5.0
const CRYSTAL := ["#5e0e1a", "#a01e2c", "#d8404a", "#ff9a8a"]
const FILL := ["#7c1622", "#b82634", "#e2524e"]
const FOOD_FILL := ["#9a5512", "#d0861e", "#f2b84a"]
const LOAF := ["#5c3412", "#a8641e", "#d89a40", "#f2c878"]
const TRACK := Color("2a1410")
const AIR_FILL := Color("bfe8f6")
const AIR_DARK := Color("5aa8cc")
const BUBBLE := ["#2a6a8c", "#8fd0ec", "#ecfbff"]
const TRAIL := Color("f2d6a6")
## How fast the pale trail of a hurt melts (points per second), after
## TRAIL_HOLD seconds.
const TRAIL_SPEED := 14.0
const TRAIL_HOLD := 0.35
## Throbs under this many points.
const LOW := 5

var health := Vitals.MAX_HEALTH
var food := Vitals.MAX_FOOD
var air := Vitals.MAX_AIR

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
	var width := floorf(slots * 0.5) - 2.0
	var top := ROW + floorf((HEIGHT - ROW - BAR_HEIGHT) * 0.5)
	# The frame and the track, from the crystal's middle on.
	var bar := Rect2(left + 4.0, top, width - 4.0, BAR_HEIGHT)
	_draw_health(bar)
	_draw_crystal(Vector2(left, ROW))
	var food_left := left + slots - width
	_draw_food(Rect2(food_left + 4.0, top, width - 4.0, BAR_HEIGHT))
	_draw_loaf(Vector2(food_left, ROW + 1.0))
	if air < Vitals.MAX_AIR:
		_draw_air(Rect2(food_left + 7.0, 1.0, width - 7.0, 3.0))
		_draw_bubble(Vector2(food_left + 1.0, 0.0))


func _draw_health(bar: Rect2) -> void:
	draw_rect(bar.grow(1.0), UiTheme.WOOD_DARK)
	draw_rect(bar, TRACK)
	var inner := bar.grow(-1.0)
	var per_point := inner.size.x / Vitals.MAX_HEALTH
	var filled := roundf(per_point * health)
	var trail := roundf(per_point * _trail)
	if trail > filled:
		draw_rect(Rect2(inner.position.x + filled, inner.position.y, trail - filled, 3.0), TRAIL)
	var throb := 1.0
	if health <= LOW and health > 0:
		throb = 0.75 + 0.25 * sin(_time * 7.0)
	for row in 3:
		var color := Color(FILL[row]) * throb
		color.a = 1.0
		draw_rect(Rect2(inner.position.x, inner.position.y + row, filled, 1.0), color)
	# A notch every two points.
	for point in range(2, Vitals.MAX_HEALTH, 2):
		var x := inner.position.x + roundf(per_point * point)
		draw_rect(Rect2(x, inner.position.y, 1.0, 3.0), Color(0, 0, 0, 0.25))


## The satiety gauge: amber, a notch every two points, throbbing hungry.
func _draw_food(bar: Rect2) -> void:
	draw_rect(bar.grow(1.0), UiTheme.WOOD_DARK)
	draw_rect(bar, TRACK)
	var inner := bar.grow(-1.0)
	var per_point := inner.size.x / Vitals.MAX_FOOD
	var filled := roundf(per_point * food)
	var throb := 1.0
	if food < Vitals.HUNGRY:
		throb = 0.75 + 0.25 * sin(_time * 5.0)
	for row in 3:
		var color := Color(FOOD_FILL[row]) * throb
		color.a = 1.0
		draw_rect(Rect2(inner.position.x, inner.position.y + row, filled, 1.0), color)
	for point in range(2, Vitals.MAX_FOOD, 2):
		var x := inner.position.x + roundf(per_point * point)
		draw_rect(Rect2(x, inner.position.y, 1.0, 3.0), Color(0, 0, 0, 0.25))


## The air left: a slim pale blue gauge, blinking when nearly out.
func _draw_air(bar: Rect2) -> void:
	draw_rect(bar.grow(1.0), UiTheme.WOOD_DARK)
	draw_rect(bar, TRACK)
	var filled := roundf(bar.size.x * air / Vitals.MAX_AIR)
	if air < Vitals.MAX_AIR * 0.25 and fmod(_time, 0.5) < 0.25:
		return
	draw_rect(Rect2(bar.position, Vector2(filled, 2.0)), AIR_FILL)
	draw_rect(Rect2(bar.position + Vector2(0.0, 2.0), Vector2(filled, 1.0)), AIR_DARK)


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
