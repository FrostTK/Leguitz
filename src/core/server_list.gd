class_name ServerList
extends RefCounted
## The servers this player joined lately (multiplayer, step 2), newest
## first, at most MOST: their address, port and the name played under,
## kept in `path` (user://servers.cfg; never the password). The join screen
## lists them (JoinScreen); Game remembers a server once it welcomed the
## player. Tests use a path of their own.

const PATH := "user://servers.cfg"
const MOST := 8

var path := PATH
## {"address": String, "port": int, "name": String}, newest first.
var servers: Array[Dictionary] = []


## Reads the list (empty when there is none).
func load_list() -> void:
	servers.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for entry: Variant in file.get_value("servers", "list", []):
		if entry is Dictionary and str(entry.get("address", "")) != "":
			var address := str(entry["address"])
			var port := int(entry.get("port", ServerConfig.DEFAULT_PORT))
			servers.append({"address": address, "port": port, "name": str(entry.get("name", ""))})
	servers = servers.slice(0, MOST)


## A server joined: first in the list (once).
func remember(address: String, port: int, player_name: String) -> void:
	_drop(address, port)
	servers.push_front({"address": address, "port": port, "name": player_name})
	servers = servers.slice(0, MOST)
	save_list()


## Takes a server out of the list.
func forget(address: String, port: int) -> void:
	_drop(address, port)
	save_list()


## The name played under last ("" never).
func last_name() -> String:
	return servers[0]["name"] if not servers.is_empty() else ""


func save_list() -> bool:
	var file := ConfigFile.new()
	file.set_value("servers", "list", servers)
	return file.save(path) == OK


func _drop(address: String, port: int) -> void:
	for i in range(servers.size() - 1, -1, -1):
		if servers[i]["address"] == address and servers[i]["port"] == port:
			servers.remove_at(i)
