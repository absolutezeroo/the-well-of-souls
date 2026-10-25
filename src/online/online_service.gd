class_name OnlineService
extends Node
## Typed lifecycle shared by online autoloads. boot reads only local state; settle may ask
## other services after every autoload has been initialized. Tests use the same contract.

func boot() -> void:
	pass


func settle() -> void:
	pass


## No file or live backend is used after this reset. Only the session/boards consume fake.
func use_for_tests(_fake: BoardBackend = null) -> void:
	pass
