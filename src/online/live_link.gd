class_name LiveLink
extends RefCounted
## The live connection to the server (Presence; docs/online.md "Sessions and presence"): a
## WebSocket carrying text messages, polled every frame while it lives (WebSocketPeer answers the
## server's pings there). BoardBackend.open_live() makes it; the tests use a server in memory
## instead (FakeLiveLink), never the network.

enum State { CONNECTING, OPEN, CLOSING, CLOSED }

## Room for a message each way (the size Talo's own Godot plugin uses; its messages are small).
const BUFFER := 256 * 1024

var _peer := WebSocketPeer.new()


## Starts connecting to `url` (ws:// or wss://).
func open(url: String) -> Error:
	_peer.inbound_buffer_size = BUFFER
	_peer.outbound_buffer_size = BUFFER
	return _peer.connect_to_url(url)


## What came is read, the pings answered: every frame while it lives.
func poll() -> void:
	_peer.poll()


func state() -> LiveLink.State:
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return State.CONNECTING
		WebSocketPeer.STATE_OPEN:
			return State.OPEN
		WebSocketPeer.STATE_CLOSING:
			return State.CLOSING
	return State.CLOSED


## The next message that came, oldest first ("" none waiting).
func receive() -> String:
	if _peer.get_available_packet_count() == 0:
		return ""
	return _peer.get_packet().get_string_from_utf8()


func send(text: String) -> Error:
	return _peer.send_text(text)


## Closed (the server ends the session when the connection goes, cleanly or not).
func close() -> void:
	_peer.close(1000, "")
