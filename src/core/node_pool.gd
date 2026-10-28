class_name NodePool
extends RefCounted
## Nodes kept to be used again instead of freed and made again (docs/performance.md "Pools"):
## shots and damage numbers come and go by the dozen in a fight, and making one (a scene, its
## shape, its script's setup) is the costly part. A node done with is taken out of the tree (at
## the end of the frame: it may be in a physics callback) and kept, out of every group and of the
## physics; take() hands it back to be set up and added again. Its owner (WorldSpawner) frees
## the nodes kept when it goes (clear()).

## Nodes kept at most; one more done with is freed.
var limit := 48

var _idle: Array = []  # (untyped: one may be freed with its floor while kept)
## Given back but not out of the tree yet (the end of the frame).
var _parking := 0


## A node kept, out of the tree, or null: none.
func take() -> Node:
	while not _idle.is_empty():
		var node: Variant = _idle.pop_back()
		if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			return node as Node
	return null


## `node` is done with: out of the tree at the end of the frame, then kept (freed when the pool
## is full).
func give(node: Node) -> void:
	if _idle.size() + _parking >= limit:
		node.queue_free()
		return
	_parking += 1
	_park.call_deferred(node)


func _park(given: Variant) -> void:
	_parking -= 1
	if not is_instance_valid(given) or (given as Node).is_queued_for_deletion():
		return  # (freed with its floor meanwhile)
	var node := given as Node
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	_idle.append(node)


## Nodes kept now.
func idle_count() -> int:
	return _idle.size()


## Frees every node kept (their world is going).
func clear() -> void:
	for node: Variant in _idle:
		if is_instance_valid(node):
			(node as Node).free()
	_idle.clear()
