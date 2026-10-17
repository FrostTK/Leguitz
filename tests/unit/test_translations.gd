extends TestCase
## The translations file: every line a key, its English and its French (a
## comma left out of quotes would cut a text short), no key twice.

const FILE := "res://i18n/strings.csv"


func test_every_line_has_its_three_columns() -> void:
	var file := FileAccess.open(FILE, FileAccess.READ)
	assert_true(file != null, "readable")
	var header := file.get_csv_line()
	assert_eq(Array(header), ["keys", "en", "fr"])
	var seen := {}
	var line := 1
	while not file.eof_reached():
		var row := file.get_csv_line()
		line += 1
		if row.size() == 1 and row[0].is_empty():
			continue
		assert_eq(row.size(), 3, "line %d (%s)" % [line, row[0]])
		if row.size() == 3:
			assert_false(row[1].is_empty() or row[2].is_empty(), "line %d translated" % line)
		assert_false(seen.has(row[0]), "%s once" % row[0])
		seen[row[0]] = true
