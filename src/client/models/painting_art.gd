class_name PaintingArt
extends RefCounted
## The pictures in the paintings (phase 8, step 8; WallDecorModels): little
## pixel-art paintings of our own, drawn by hand rules, each the same every
## time. Landscapes (LANDSCAPE wide): a summer meadow, mountains, the sea and
## a sail, a sunset, a night and its moon, a forest and its river, autumn
## fields, winter. Portraits (PORTRAIT tall): a head and shoulders, their
## skin, hair, clothes and background each of their own. Rows of colors,
## the top first.

const LANDSCAPE := Vector2i(14, 10)
const PORTRAIT := Vector2i(10, 14)
const SKINS := ["#f1c9a5", "#e0a986", "#b97a56", "#7a4a32"]
const HAIRS := ["#2a1e1a", "#5a3a24", "#c9a04a", "#a8442a", "#a8a6a8"]
const CLOTHES := ["#2e4a7a", "#7e2a38", "#3e6a58", "#5a3a5e", "#3a3a40", "#8a6a2a"]
const BACKS := ["#3a3028", "#2a3a34", "#4a2e2e", "#2e3346", "#5a4a32"]


## Landscape `index` (8 kinds, the same each time).
static func landscape(index: int) -> Array:
	var image := _canvas(LANDSCAPE, Color("8cbcdc"))
	match posmod(index, 8):
		0:
			_sky(image, Color("6aa6dc"), Color("bfe0f2"), 6)
			_disc(image, Vector2(11.0, 1.8), 1.3, Color("ffe680"))
			_hills(image, 5.5, 1.2, 0.6, Color("6aa84a"))
			_hills(image, 7.0, 1.0, 1.3, Color("4f8a3a"))
			_tree(image, 3, 6, Color("2f6a2e"))
		1:
			_sky(image, Color("7aaee0"), Color("d4e8f4"), 5)
			_peaks(image, [Vector2(3, 1), Vector2(8, 0), Vector2(12, 2)], Color("7a7e90"))
			_hills(image, 7.5, 0.8, 0.9, Color("5a9a48"))
		2:
			_sky(image, Color("74b0e4"), Color("cfe6f4"), 5)
			_disc(image, Vector2(2.5, 1.5), 1.2, Color("fff2b0"))
			for y in range(5, 9):
				for x in LANDSCAPE.x:
					var wave := (x + y * 3) % 5 == 0
					image[y][x] = (
						Color("e8f4fa") if wave else Color("3e7ab8").darkened((y - 5) * 0.06)
					)
			for x in LANDSCAPE.x:
				image[9][x] = Color("e6d6a0")
			_sail(image, 9, 5)
		3:
			_sky(image, Color("5a3a7a"), Color("f08a4a"), 7)
			_disc(image, Vector2(7.0, 6.5), 1.8, Color("e8442a"))
			_hills(image, 6.5, 1.2, 1.1, Color("3a2438"))
			_hills(image, 8.0, 0.8, 0.7, Color("24182a"))
		4:
			_sky(image, Color("0e1430"), Color("2a3466"), 7)
			for star: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(9, 1), Vector2i(12, 4)]:
				image[star.y][star.x] = Color("f2f2d8")
			_disc(image, Vector2(10.5, 2.2), 1.4, Color("f4ecc4"))
			_disc(image, Vector2(11.3, 1.8), 1.2, Color("1a2246"))
			_hills(image, 6.5, 1.0, 0.8, Color("1a2a24"))
			image[6][4] = Color("3a2a24")
			image[6][5] = Color("3a2a24")
			image[7][4] = Color("ffd04a")
			image[7][5] = Color("3a2a24")
		5:
			_sky(image, Color("8cc0e0"), Color("d8ecf2"), 4)
			_hills(image, 4.5, 0.5, 0.4, Color("3a7a3a"))
			for x: int in [1, 4, 9, 12]:
				_tree(image, x, 5, Color("24502a"))
			for y in range(6, 10):
				var middle := 6 + int(round(sin(y * 1.3) * 2.0))
				for x in range(middle, middle + 3):
					image[y][x] = Color("4a8ac8")
		6:
			_sky(image, Color("a8c8e0"), Color("f2e2c4"), 5)
			_hills(image, 6.0, 0.6, 0.5, Color("c8a040"))
			for x: int in [2, 11]:
				_tree(image, x, 5, Color("d0702a"))
			_disc(image, Vector2(7.0, 7.0), 1.5, Color("d8b85a"))
		_:
			_sky(image, Color("9aa8b8"), Color("dce4ec"), 5)
			_hills(image, 6.0, 0.8, 0.7, Color("f4f6f8"))
			for x: int in [2, 6, 11]:
				_tree(image, x, 6, Color("2a4a3a"))
				image[maxi(6 - 3, 0)][x] = Color("f4f6f8")
	return image


## Portrait `index` (its skin, hair, clothes, background, the same each
## time).
static func portrait(index: int) -> Array:
	var h := HashUtil.hash2(0x9047, index, index * 7 + 3)
	var back := Color(BACKS[h % BACKS.size()])
	var skin := Color(SKINS[(h >> 4) % SKINS.size()])
	var hair := Color(HAIRS[(h >> 8) % HAIRS.size()])
	var cloth := Color(CLOTHES[(h >> 12) % CLOTHES.size()])
	var style := (h >> 16) % 3
	var image := _canvas(PORTRAIT, back)
	for y in PORTRAIT.y:
		for x in PORTRAIT.x:
			image[y][x] = back.lightened(0.08 * (1.0 - absf(x - 4.5) / 5.0))
	# Shoulders and clothes, a collar.
	for y in range(10, 14):
		for x in range(1 + maxi(0, 11 - y), 9 - maxi(0, 11 - y)):
			image[y][x] = cloth
	image[10][4] = Color("efe6d4")
	image[10][5] = Color("efe6d4")
	image[9][4] = skin.darkened(0.15)
	image[9][5] = skin.darkened(0.15)
	# The head.
	for y in range(3, 9):
		var half := 2.0 if y in [3, 8] else 2.6
		for x in PORTRAIT.x:
			if absf(x + 0.5 - 5.0) <= half:
				image[y][x] = skin
	image[5][3] = Color("2a2024")
	image[5][6] = Color("2a2024")
	image[7][4] = skin.darkened(0.3)
	image[7][5] = skin.darkened(0.3)
	image[6][2] = skin.darkened(0.1)
	image[6][7] = skin.darkened(0.1)
	# The hair: short, long, or a hat.
	for x in range(2, 8):
		image[2][x] = hair
		image[3][x] = hair if x in [2, 3, 6, 7] or style != 2 else image[3][x]
	if style == 1:
		for y in range(3, 10):
			image[y][2] = hair
			image[y][7] = hair
	elif style == 2:
		var hat := cloth.darkened(0.35)
		for x in range(1, 9):
			image[2][x] = hat
		for x in range(3, 7):
			image[1][x] = hat
			image[0][x] = hat
	return image


static func _canvas(size: Vector2i, color: Color) -> Array:
	var rows := []
	for y in size.y:
		var row := []
		row.resize(size.x)
		row.fill(color)
		rows.append(row)
	return rows


## A sky from `top` down to `low` at row `horizon`.
static func _sky(image: Array, top: Color, low: Color, horizon: int) -> void:
	for y in image.size():
		var row: Array = image[y]
		for x in row.size():
			row[x] = top.lerp(low, clampf(float(y) / horizon, 0.0, 1.0))


static func _disc(image: Array, center: Vector2, radius: float, color: Color) -> void:
	for y in image.size():
		var row: Array = image[y]
		for x in row.size():
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				row[x] = color


## Hills rolling at `level` (row), so high, so many waves across.
static func _hills(image: Array, level: float, height: float, waves: float, color: Color) -> void:
	for x in (image[0] as Array).size():
		var top := level - height * (0.5 + 0.5 * sin(x * waves * 0.7 + level))
		for y in image.size():
			if y >= top:
				image[y][x] = color.darkened(clampf((y - top) * 0.05, 0.0, 0.25))


## Mountains: their peaks (column, row), snow on their tops.
static func _peaks(image: Array, peaks: Array, color: Color) -> void:
	for peak: Vector2 in peaks:
		for y in range(int(peak.y), image.size()):
			var half := (y - peak.y) * 0.9
			for x in range(int(peak.x - half), int(peak.x + half) + 1):
				if x >= 0 and x < (image[0] as Array).size():
					var snow := y <= peak.y + 1
					image[y][x] = Color("f2f4f8") if snow else color.lightened((x - peak.x) * 0.03)


## A tree: a trunk and a round crown, its foot at (x, row).
static func _tree(image: Array, x: int, foot: int, crown: Color) -> void:
	var height := image.size()
	for y in range(foot - 1, mini(foot + 2, height)):
		image[y][x] = Color("5a3a24")
	for dy in range(-3, 0):
		for dx in range(-1, 2):
			var y := foot + dy
			if y >= 0 and x + dx >= 0 and x + dx < (image[0] as Array).size():
				image[y][x + dx] = crown if absi(dx) + absi(dy + 2) < 3 else image[y][x + dx]


## A white sail on a little hull.
static func _sail(image: Array, x: int, row: int) -> void:
	for y in range(row - 3, row):
		for dx in y - row + 4:
			image[y][x - dx] = Color("f4f2ea")
	image[row][x - 2] = Color("6a3a24")
	image[row][x - 1] = Color("6a3a24")
	image[row][x] = Color("6a3a24")
