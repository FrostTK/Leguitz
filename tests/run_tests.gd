extends SceneTree
## Headless test runner:
##   godot --headless --path . --import          (once, builds the class cache)
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method of every tests/unit/test_*.gd file.
## Exit code 0 = all tests passed.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for file in _test_files():
		var script: GDScript = load(TEST_DIR.path_join(file))
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test_case: TestCase = script.new()
			test_case.call(method_name)
			if test_case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [file, method_name])
				for failure in test_case.failures:
					print("    ", failure)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append(file)
	files.sort()
	return files
