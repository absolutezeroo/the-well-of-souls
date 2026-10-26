class_name PersistentId
extends RefCounted
## Durable identities use the OS random source, never the dungeon RNG or a node instance id.


static func create(kind: String) -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return kind + "_" + bytes.hex_encode() if bytes.size() == 16 else ""


static func valid(value: Variant, kind: String) -> bool:
	if not value is String:
		return false
	var prefix := kind + "_"
	if not value.begins_with(prefix) or value.length() != prefix.length() + 32:
		return false
	for letter in value.substr(prefix.length()):
		if not letter in "0123456789abcdef":
			return false
	return true
