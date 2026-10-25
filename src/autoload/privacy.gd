extends OnlineService
## The player's choices about their data (autoload "Privacy"; docs/privacy-ops.md, design/
## interface.md "Privacy"): whether the gameplay statistics may be sent (Telemetry), the neutral
## age question asked before them, when a refusal lets the question come back, and "delete my
## online data". The leaderboards' own choice ("publish my scores online") is the Leaderboards
## autoload's; this one only resets it on a deletion.
##
## Its own small file, user://privacy.json: never the run's save, never the Profile. It holds
## "old enough: yes / no" (never an age), the statistics' answer, when it was given and for which
## consent and policy version, and a short history of the answers (to show consent was asked:
## GDPR art. 7(1)). Nothing here leaves the device.
##
## The rules (data/online/privacy.tres, PrivacyDef): statistics are off until accepted; under the
## age threshold they are never offered; a refusal (or closing the question) is kept reask_days
## (6 months) before the question comes back; a consent given to an older consent_version no
## longer counts. The tests give it no file and turn the question on the title screen off.

## A choice changed (the Options page and the title screen follow).
signal changed

const PATH := "user://privacy.json"
const DEFS := "res://data/online/privacy.tres"
const VERSION := 1
const SECONDS_PER_DAY := 86400

## The statistics' answer.
enum Answer { NONE, GRANTED, REFUSED }

var def: PrivacyDef
## Its file (versioned, atomic).
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## The age question was answered, and how ("old enough" = at least def.age_threshold).
var age_answered := false
var old_enough := false
var analytics: Answer = Answer.NONE
## When the statistics' answer was given (Unix seconds), and for which consent version.
var answered_at := 0
var answered_version := 0
## The last answers: {at, choice, consent, policy}.
var history: Array[Dictionary] = []
## The title screen asks the questions the first time it shows (off in the tests, but in theirs).
var ask_on_title := true


func _init() -> void:
	add_child(store)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order").
func boot() -> void:
	def = load(DEFS) as PrivacyDef
	load_state()


func _ready() -> void:
	OnlineSession.register(self)


## The tests: no file, no question on the title screen, every choice forgotten, the real clock
## (OnlineSession.fake_now).
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	ask_on_title = false
	OnlineSession.fake_now = -1
	reset()


func reset() -> void:
	age_answered = false
	old_enough = false
	analytics = Answer.NONE
	answered_at = 0
	answered_version = 0
	history.clear()


## Now, in Unix seconds (the online layer's one clock: OnlineSession.now(), the tests' if set).
func now() -> int:
	return OnlineSession.now()


## The statistics may be collected and sent: accepted, for this consent version, by a player old
## enough. (The services ask OnlineSession.statistics_allowed(), which adds the server, the build
## and the kill switch.)
func analytics_allowed() -> bool:
	return def != null and analytics == Answer.GRANTED and old_enough and answered_version == def.consent_version


## The questions should be asked now (the title screen, once it shows): there is a server, the
## player isn't known to be too young, and the statistics were never answered, were refused more
## than reask_days ago, or were accepted for an older consent version.
func should_ask() -> bool:
	if not OnlineSession.is_available():
		return false
	if age_answered and not old_enough:
		return false
	match analytics:
		Answer.NONE:
			return true
		Answer.GRANTED:
			return answered_version != def.consent_version
	return now() - answered_at >= def.reask_days * SECONDS_PER_DAY or answered_version != def.consent_version


## The age question needs asking before the statistics' (never answered, or "too young").
func needs_age() -> bool:
	return not age_answered or not old_enough


## The answer to "how old are you": only whether it reaches the threshold is kept. Too young: the
## statistics are off and never offered (what waited is dropped).
func answer_age(is_old_enough: bool) -> void:
	age_answered = true
	old_enough = is_old_enough
	if not is_old_enough and analytics == Answer.GRANTED:
		_answer(Answer.REFUSED, "too_young")
	save_state()
	changed.emit()


## "Accept": the statistics go from the next run's end.
func grant() -> void:
	if not old_enough:
		return
	_answer(Answer.GRANTED, "granted")


## "Decline", closing the question, or the Options switch turned off: nothing more is sent, what
## waited is dropped, the question waits reask_days before coming back.
func refuse() -> void:
	_answer(Answer.REFUSED, "refused")


func _answer(answer: Answer, choice: String) -> void:
	analytics = answer
	answered_at = now()
	answered_version = def.consent_version
	history.append({ "at": answered_at, "choice": choice, "consent": def.consent_version, "policy": def.policy_version })
	while history.size() > def.history_size:
		history.pop_front()
	if answer != Answer.GRANTED:
		Telemetry.drop_queue()
	save_state()
	changed.emit()


## What "Delete my online data" asks for, before it forgets: {id, player, name, email, mailto}
## (`mailto` empty while the contact address is still a placeholder).
func deletion_request() -> Dictionary:
	var device := OnlineSession.device_id
	var player := OnlineSession.player_id
	# The name with its tag as the boards show it (the tag only once the device has its id).
	var shown_name := Leaderboards.tagged_name() if not device.is_empty() else Leaderboards.pseudonym
	var body := "Please delete the data of this player of Le Puits des Âmes (GDPR art. 17).\n\nOnline ID (alias identifier): %s\nTalo player ID: %s\nPseudonym: %s\n" % [
		device if not device.is_empty() else "-", player if not player.is_empty() else "-", shown_name if not shown_name.is_empty() else "-"]
	var mailto := ""
	if not PrivacyDef.is_placeholder(def.contact_email):
		mailto = "mailto:%s?subject=%s&body=%s" % [def.contact_email, "Delete my data - Le Puits des Ames".uri_encode(), body.uri_encode()]
	return { "id": device, "player": player, "name": shown_name, "email": def.contact_email, "mailto": mailto, "body": body }


## After the request is written: every online feature off, the device's online id, its Talo
## player id, the pseudonym and every queue forgotten. A new random id is made only if the player
## turns a feature on again, so this device is no longer linked to the old record.
func forget_online() -> void:
	OnlineSession.forget()
	Leaderboards.forget()
	Telemetry.drop_queue()
	WorldStats.forget()
	Feedback.forget()
	if analytics == Answer.GRANTED:
		_answer(Answer.REFUSED, "deleted")
	changed.emit()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({
		"age_answered": age_answered,
		"old_enough": old_enough,
		"analytics": ["none", "granted", "refused"][analytics],
		"answered_at": answered_at,
		"answered_version": answered_version,
		"history": history,
	})


func load_state() -> void:
	reset()
	var data := store.read()  # (a newer game's file is not read: every choice off, asked again)
	if data.is_empty():
		return
	age_answered = bool(data.get("age_answered", false))
	old_enough = bool(data.get("old_enough", false))
	analytics = { "granted": Answer.GRANTED, "refused": Answer.REFUSED }.get(str(data.get("analytics", "")), Answer.NONE)
	answered_at = int(data.get("answered_at", 0))
	answered_version = int(data.get("answered_version", 0))
	var saved: Variant = data.get("history", [])
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary:
				history.append(item)
