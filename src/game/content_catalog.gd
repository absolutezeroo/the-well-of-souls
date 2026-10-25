class_name ContentCatalog
extends Resource
## Stable, namespaced ids for saved content. The generated data resource lists current
## targets and every historical path. Moving a target never changes the saved id or alias.
## No filesystem scan or ContentDB load is needed at runtime.

@export var entries: Dictionary[String, Resource] = {}
@export var legacy_paths: Dictionary[String, String] = {}
var _by_path: Dictionary[String, String] = {}


func encode(resource: Resource) -> String:
	if resource == null:
		return ""
	if _by_path.is_empty():
		for key in entries:
			if entries[key]:
				_by_path[entries[key].resource_path] = key
	var key: String = _by_path.get(resource.resource_path, "")
	if key.is_empty():
		push_warning("Content is missing a stable save reference: %s" % resource.resource_path)
		return ""
	return "@" + key


## Legacy paths are resolved through aliases first, including paths that no longer exist.
func resolve(saved: Variant) -> Resource:
	if not (saved is String or saved is StringName):
		return null
	var value := String(saved)
	if value.begins_with("@"):
		return entries.get(value.substr(1))
	var key: String = legacy_paths.get(value, "")
	return entries.get(key) if not key.is_empty() else null


## Migrate known reference strings without interpreting unrelated saved text as a path.
func migrate(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = migrate(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(migrate(entry))
		return result
	if (value is String or value is StringName) and legacy_paths.has(String(value)):
		return "@" + legacy_paths[String(value)]
	return value
