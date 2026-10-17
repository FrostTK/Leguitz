class_name Backups
extends RefCounted
## A dedicated server's backups of its world (multiplayer, step 4): zip
## files in <data>/backups/ named <world>_<date>_<time>[_note].zip, made when
## it starts (ServerConfig.backup_on_start: `make_now`, before the world
## loads), every `hours` (backup_hours; 0: never), when asked (the console's
## or an admin's backup: `make`); the newest `kept` stay (backups_kept). A
## backup saves the world first, then zips its folder on a worker thread
## (its files are written aside and swapped in: each one is whole), one at
## a time; `update` tells the console and the admins playing when it is
## done. `restore` (the console's only, the server stopped: nothing saves
## over it) puts a backup back in place of the world after a backup of the
## world as it was (noted "before_restore").

const FOLDER := "backups"

var folder := ""
var world_dir := ""
var world := ""
var hours := 6.0
var kept := 10
## Prints a line (print; tests keep them).
var out := func(line: String) -> void: print(line)

var _task := -1
var _target := ""
var _error := OK
var _since := 0.0


func _init(data_dir: String, world_folder: String, world_name: String) -> void:
	folder = data_dir.path_join(FOLDER)
	world_dir = world_folder
	world = world_name


## Whether a backup is being made.
func busy() -> bool:
	return _task >= 0


## Starts a backup (the world saved first, `server` given): false if one
## is being made.
func make(server: GameServer = null, note := "") -> bool:
	if busy():
		return false
	if server != null:
		server.save()
	_target = folder.path_join(_file_name(note))
	DirAccess.make_dir_recursive_absolute(folder)
	_task = WorkerThreadPool.add_task(_zip.bind(world_dir, _target))
	return true


## Makes a backup at once, on this thread (at start, before a restore).
func make_now(note := "") -> Error:
	DirAccess.make_dir_recursive_absolute(folder)
	var target := folder.path_join(_file_name(note))
	var error := zip_folder(world_dir, target)
	_told(target, error)
	_prune()
	return error


## Every frame: a backup done is told; one is started when due.
func update(server: GameServer, delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_told(_target, _error)
		_prune()
		if _error == OK:
			for session in server.sessions:
				if session.joined and Chat.is_admin(server, session):
					Chat.tell(session, "CMD_BACKUP_DONE", [_target.get_file()], Chat.Tone.DONE)
	if hours <= 0.0:
		return
	_since += delta
	if _since >= hours * 3600.0:
		_since = 0.0
		make(server)


## The world's backups, newest first (file names).
func list() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.begins_with(world + "_") and file.ends_with(".zip"):
			files.append(file)
	files.sort()
	files.reverse()
	return files


## The backup `which` names: its file's name (or the start of it), or its
## number in `list` (1: the newest). "" when none.
func find(which: String) -> String:
	var files := list()
	if which.is_valid_int() and int(which) >= 1 and int(which) <= files.size():
		return files[int(which) - 1]
	for file in files:
		if file == which or file.begins_with(which):
			return file
	return ""


## Puts the backup `file` back in place of the world (the server must not
## run it: stopped, nothing saving). Returns what went wrong ("": nothing).
func restore(file: String) -> String:
	var path := folder.path_join(file)
	if not FileAccess.file_exists(path):
		return "No backup %s." % file
	if make_now("before_restore") != OK:
		return "The world as it is could not be backed up: nothing was changed."
	_empty(world_dir)
	var error := unzip(path, world_dir)
	if error != OK:
		return "%s could not be unpacked (%s)." % [file, error_string(error)]
	return ""


## Zips every file under `source` (their paths from it) into `target`.
static func zip_folder(source: String, target: String) -> Error:
	var zip := ZIPPacker.new()
	var error := zip.open(target)
	if error != OK:
		return error
	for relative in _files_under(source, ""):
		zip.start_file(relative)
		zip.write_file(FileAccess.get_file_as_bytes(source.path_join(relative)))
		zip.close_file()
	return zip.close()


## Unpacks the zip `path` into `target` (folders made as needed).
static func unzip(path: String, target: String) -> Error:
	var zip := ZIPReader.new()
	var error := zip.open(path)
	if error != OK:
		return error
	for relative in zip.get_files():
		if relative.ends_with("/"):
			continue
		var to := target.path_join(relative)
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		var file := FileAccess.open(to, FileAccess.WRITE)
		if file == null:
			zip.close()
			return FileAccess.get_open_error()
		file.store_buffer(zip.read_file(relative))
		file.close()
	zip.close()
	return OK


func _zip(source: String, target: String) -> void:
	_error = zip_folder(source, target)


func _file_name(note: String) -> String:
	var time := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	return "%s_%s%s.zip" % [world, time, "_" + note if note != "" else ""]


func _told(target: String, error: Error) -> void:
	if error == OK:
		var size := FileAccess.get_file_as_bytes(target).size()
		var told := (
			"%.1f MB" % (size / 1048576.0) if size >= 1048576 else "%d KB" % ceili(size / 1024.0)
		)
		out.call("Backup made: %s (%s)." % [target.get_file(), told])
	else:
		out.call("The backup %s failed (%s)." % [target.get_file(), error_string(error)])


## Only the newest `kept` stay.
func _prune() -> void:
	var files := list()
	for i in range(kept, files.size()):
		DirAccess.remove_absolute(folder.path_join(files[i]))


static func _files_under(root: String, relative: String) -> PackedStringArray:
	var found := PackedStringArray()
	var here := root.path_join(relative)
	for file in DirAccess.get_files_at(here):
		found.append(relative.path_join(file) if relative != "" else file)
	for dir in DirAccess.get_directories_at(here):
		found.append_array(_files_under(root, relative.path_join(dir) if relative != "" else dir))
	return found


## Removes everything in `dir` (it stays, empty).
static func _empty(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_empty(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
