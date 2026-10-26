class_name PlayerCommandSource
extends RefCounted
## Supplies intentions to one hero. The base stays idle; subclasses read local input or a
## buffered producer. sample() returns a reused read-only view, valid until the next sample.

var _sample := PlayerCommand.new()


func sample() -> PlayerCommand:
	return _sample
