class_name ChunkGenerationQueue
extends RefCounted
## Generates chunks in parallel on Godot's WorkerThreadPool.
##
## request() schedules a chunk; collect() returns the chunks finished since
## the last call. With `threaded = false` generation happens immediately
## on the calling thread (tests, tools).

const MAX_IN_FLIGHT := 64

var threaded := true
var _generator: WorldGenerator
var _mutex := Mutex.new()
var _tasks: Dictionary[Vector3i, int] = {}
var _done: Array[ChunkData] = []


func _init(generator: WorldGenerator, use_threads := true) -> void:
	_generator = generator
	threaded = use_threads


func is_pending(key: Vector3i) -> bool:
	return _tasks.has(key)


func pending_count() -> int:
	return _tasks.size()


## Returns false if the queue is full (try again next tick).
func request(key: Vector3i) -> bool:
	if _tasks.has(key):
		return true
	if not threaded:
		_tasks[key] = -1
		_finish(_generator.generate_chunk(Vector2i(key.x, key.y), key.z))
		return true
	if _tasks.size() >= MAX_IN_FLIGHT:
		return false
	_tasks[key] = WorkerThreadPool.add_task(_generate.bind(key), false, "Chunk generation")
	return true


func collect() -> Array[ChunkData]:
	_mutex.lock()
	var finished := _done
	_done = []
	_mutex.unlock()
	for chunk in finished:
		var task: int = _tasks.get(chunk.key(), -1)
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
		_tasks.erase(chunk.key())
	return finished


## Blocks until every scheduled chunk is generated (shutdown, tests).
func wait_all() -> void:
	for key: Vector3i in _tasks:
		var task: int = _tasks[key]
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
			_tasks[key] = -1


func _generate(key: Vector3i) -> void:
	_finish(_generator.generate_chunk(Vector2i(key.x, key.y), key.z))


func _finish(chunk: ChunkData) -> void:
	_mutex.lock()
	_done.append(chunk)
	_mutex.unlock()
