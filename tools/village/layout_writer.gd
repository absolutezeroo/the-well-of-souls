@tool
class_name VillageLayoutWriter
extends RefCounted
## Saves authoring resources via a temporary file, with the repository's path-only references.
## Failed serialization/writes leave the previous file intact; callers retain edits for retry.


static func save(resource: Resource, path: String) -> Error:
	var temporary := path.get_basename() + ".layout-tmp.tres"
	var error := ResourceSaver.save(resource, temporary)
	if error != OK: return error
	var pattern := RegEx.new()
	pattern.compile(' uid="[^"]*"')
	var text := pattern.sub(FileAccess.get_file_as_string(temporary), "", true)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(temporary, path)
