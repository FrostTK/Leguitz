extends TestCase
## Every script of the game compiles, the interface's too (the other tests
## never load most of it: an error there went unseen).

const ROOT := "res://src"


func test_every_script_compiles() -> void:
	var paths := _scripts(ROOT)
	assert_true(paths.size() > 100, "the scripts found")
	for path in paths:
		var script := load(path) as GDScript
		assert_true(script != null and script.can_instantiate(), "%s compiles" % path)


func _scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for inner in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(inner)))
	return found
