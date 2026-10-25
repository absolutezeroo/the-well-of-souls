class_name SafeFile
## Saves that survive the app being killed mid-write: the new content goes to a temporary file
## first, then replaces the old one in one step. A half-written file never replaces a good one.


## Writes `data` as JSON to `path`. Returns false (and warns) if it could not.
static func write_json(path: String, data: Variant) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var bytes := JSON.stringify(data, "\t").to_utf8_buffer()
	file.store_buffer(bytes)
	file.flush()
	var written := file.get_error() == OK and file.get_length() == bytes.size()
	file.close()
	# A short write must never replace the previous save, nor become the recovery copy.
	if not written or FileAccess.get_file_as_bytes(temp) != bytes:
		DirAccess.remove_absolute(temp)
		push_warning("Could not finish saving %s" % path)
		return false
	# rename replaces an existing file atomically. If the filesystem refuses, keep both
	# copies: deleting the destination first would turn a recoverable error into data loss.
	if DirAccess.rename_absolute(temp, path) != OK:
		push_warning("Could not replace %s" % path)
		return false
	return true


## The JSON in `path`, or null if it is missing or damaged. Falls back on a temporary file
## left by a write that was cut short.
static func read_json(path: String) -> Variant:
	for candidate in [path, path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(candidate)) == OK and json.data != null:
				return json.data
	return null
