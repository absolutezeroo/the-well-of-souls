class_name CampaignSave
extends RefCounted
## A bounded campaign checkpoint: hero and all world facts commit in one atomic envelope.
## The previous committed envelope is kept separately. Temporary writes are never commits.
## Explicit path only: merely instantiating this class never touches a player's files.

enum Failure { NONE, DISABLED, MISSING, IO, CORRUPT, INCOMPATIBLE, INVALID_STATE, CONFLICT, BUSY, INTERRUPTED }
enum CommitStep { BEFORE_BACKUP, AFTER_BACKUP, BEFORE_PUBLISH, AFTER_PUBLISH }

const FORMAT := "well.campaign"
const VERSION := 1
## Prototype storage bound, not a gameplay limit. Sector files/journals need a later codec.
const MAX_BYTES := 16 * 1024 * 1024

var path := ""
var last_failure := Failure.NONE
## A caller can show that it recovered an older checkpoint rather than hiding the rollback.
var recovered := false

## Inspection distinguishes a damaged file from an unsupported schema/content. The latter
## must never silently fall back to an older generation or become writable by this build.
class Inspection:
	extends RefCounted
	var failure := Failure.MISSING
	var state: CampaignState
	var envelope: Dictionary = {}


func _init(save_path: String = "") -> void:
	path = save_path


func load_state() -> CampaignState:
	last_failure = Failure.NONE
	recovered = false
	if path.is_empty():
		last_failure = Failure.DISABLED
		return null
	var primary := _inspect(path)
	if primary.failure == Failure.NONE:
		return primary.state
	if primary.failure == Failure.INCOMPATIBLE:
		last_failure = primary.failure
		return null
	var backup := _inspect(path + ".bak")
	if backup.failure == Failure.NONE:
		recovered = true
		return backup.state
	last_failure = backup.failure if backup.failure == Failure.INCOMPATIBLE else primary.failure
	if primary.failure == Failure.MISSING and backup.failure != Failure.MISSING:
		last_failure = backup.failure
	return null


## Synchronous and single-writer. A crashed writer leaves a lock and produces BUSY; do not
## guess that another process is dead or delete its lock automatically. Recovery UI is later.
func commit(state: CampaignState) -> bool:
	last_failure = Failure.NONE
	recovered = false
	if path.is_empty():
		return _fail(Failure.DISABLED)
	if state == null:
		return _fail(Failure.INVALID_STATE)
	var snapshot := CampaignState.from_data(state.to_data())
	if snapshot == null or snapshot.revision >= CampaignFormat.MAX_INTEGER:
		return _fail(Failure.INVALID_STATE)
	var lock_path := ProjectSettings.globalize_path(path + ".lock")
	var locked := DirAccess.make_dir_absolute(lock_path)
	if locked != OK:
		return _fail(Failure.BUSY if DirAccess.dir_exists_absolute(lock_path) else Failure.IO)
	var accepted := _commit_locked(state, snapshot)
	DirAccess.remove_absolute(lock_path)
	return accepted


func _commit_locked(original: CampaignState, snapshot: CampaignState) -> bool:
	var current := load_state()
	if current == null:
		if last_failure != Failure.MISSING:
			return false
		# A failed first publication may leave an uncommitted temp file. Starting again at
		# revision zero is safe; that file is never selected by load_state().
		if snapshot.revision != 0:
			return _fail(Failure.CONFLICT)
	elif snapshot.id != current.id or snapshot.revision != current.revision \
			or snapshot.hero.id != current.hero.id or snapshot.world_state.id != current.world_state.id:
		return _fail(Failure.CONFLICT)
	snapshot.revision += 1
	var payload := JSON.stringify(snapshot.to_data())
	var envelope := { "format": FORMAT, "version": VERSION,
		"payload": payload, "sha256": payload.sha256_text() }
	if JSON.stringify(envelope, "\t").to_utf8_buffer().size() > MAX_BYTES:
		return _fail(Failure.INVALID_STATE)
	if not _checkpoint(CommitStep.BEFORE_BACKUP):
		return _fail(Failure.INTERRUPTED)
	# Preserve only a validated committed primary. A recovery must not replace the good
	# backup with the damaged main file it just recovered from.
	var primary := _inspect(path)
	if primary.failure == Failure.NONE and not SafeFile.write_json(path + ".bak", primary.envelope):
		return _fail(Failure.IO)
	if not _checkpoint(CommitStep.AFTER_BACKUP) or not _checkpoint(CommitStep.BEFORE_PUBLISH):
		return _fail(Failure.INTERRUPTED)
	if not SafeFile.write_json(path, envelope):
		return _fail(Failure.IO)
	if not _checkpoint(CommitStep.AFTER_PUBLISH):
		# A lost acknowledgement may mean it committed. The stale revision prevents a
		# retry paying the same reward twice: reload and inspect its durable claim first.
		return _fail(Failure.INTERRUPTED)
	original.revision = snapshot.revision
	last_failure = Failure.NONE
	return true


## A test backend can stop at publication boundaries; production always continues.
func _checkpoint(_step: CommitStep) -> bool:
	return true


func _fail(reason: Failure) -> bool:
	last_failure = reason
	return false


func _inspect(candidate: String) -> Inspection:
	var result := Inspection.new()
	if not FileAccess.file_exists(candidate):
		return result
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		result.failure = Failure.IO
		return result
	if file.get_length() > MAX_BYTES:
		file.close()
		result.failure = Failure.INCOMPATIBLE
		return result
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	result.failure = Failure.CORRUPT
	if json.parse(text) != OK or not json.data is Dictionary:
		return result
	var data: Dictionary = json.data
	if data.get("format") != FORMAT or not CampaignFormat.integer(data.get("version"), 1) \
			or int(data.version) != VERSION:
		result.failure = Failure.INCOMPATIBLE
		return result
	if not CampaignFormat.keys(data, ["format", "version", "payload", "sha256"]) \
			or not data.payload is String or not data.sha256 is String:
		result.failure = Failure.INCOMPATIBLE
		return result
	if data.payload.sha256_text() != data.sha256:
		return result
	if json.parse(data.payload) != OK:
		return result
	result.state = CampaignState.from_data(json.data)
	if result.state == null:
		# This may be unavailable content, new fields, or an invalid ownership relation.
		# Never drop a player's objects or roll back just to make this build load it.
		result.failure = Failure.INCOMPATIBLE
		return result
	result.envelope = data
	result.failure = Failure.NONE
	return result
