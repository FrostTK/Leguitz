class_name Transport
extends RefCounted
## One end of a bidirectional message channel between a client and a server.
## Solo play uses LocalTransport; multiplayer NetTransport (ENet, UDP), the
## server's end of a player's connection, and NetClient, the player's: the
## same interface. Messages are Dictionaries of plain values (no objects:
## they cross the network as bytes, var_to_bytes).


func send(_message: Dictionary) -> void:
	push_error("Transport.send() not implemented")


## Returns and clears the messages received since the last call.
func poll() -> Array[Dictionary]:
	push_error("Transport.poll() not implemented")
	return []


func is_open() -> bool:
	return true


## Ends the connection (what was sent goes first): the other end sees it
## closed.
func close() -> void:
	pass


## The other end's IP address ("": not over the network).
func ip() -> String:
	return ""


## How long a message takes there and back (milliseconds; 0: no network).
func latency() -> int:
	return 0
