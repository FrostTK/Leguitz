class_name Transport
extends RefCounted
## One end of a bidirectional message channel between a client and a server.
## Solo play uses LocalTransport; multiplayer will add a network transport
## (ENet / Steam) with the same interface.


func send(_message: Dictionary) -> void:
	push_error("Transport.send() not implemented")


## Returns and clears the messages received since the last call.
func poll() -> Array[Dictionary]:
	push_error("Transport.poll() not implemented")
	return []


func is_open() -> bool:
	return true
