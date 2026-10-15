extends Node
## Entry point. Launched as a dedicated server (DedicatedServer.wanted) it
## runs that alone: nothing of the client is ever loaded (a light, quick
## server). Else the game (Game: solo, or joining a dedicated server with
## --connect).

## The game, loaded by its path (never on a dedicated server).
const GAME := "res://src/game.gd"

## What runs: the DedicatedServer or the Game.
var running: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DedicatedServer.wanted():
		running = DedicatedServer.new()
	else:
		running = (load(GAME) as GDScript).new()
	add_child(running)
