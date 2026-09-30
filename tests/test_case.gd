class_name TestCase
extends RefCounted
## Minimal unit-test base class. Test methods are named test_*; assertions
## record failures instead of stopping, so one run reports everything.

var failures: Array[String] = []


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_fail("expected true. %s" % message)


func assert_false(condition: bool, message := "") -> void:
	if condition:
		_fail("expected false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected <%s> but got <%s>. %s" % [expected, actual, message])


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("did not expect <%s>. %s" % [unexpected, message])


func assert_almost(actual: float, expected: float, tolerance := 0.0001, message := "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f (+/- %f) but got %f. %s" % [expected, tolerance, actual, message])


func _fail(text: String) -> void:
	var stack := get_stack()
	var where := ""
	if stack.size() > 2:
		where = " (%s:%d)" % [stack[2]["source"].get_file(), stack[2]["line"]]
	failures.append(text + where)
