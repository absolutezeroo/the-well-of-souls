class_name PresenceTests
extends TestSuite
## The live session and presence (Presence, LiveLink) on a fake server (FakeBoardBackend,
## FakeLiveLink): never the network. run_unit(): its data; no connection without consent; with
## it, a session started (the ticket's address, the player and token sent on "v1.connected", the
## player shown online); the app in the background ends it and back starts a new one; a lost
## connection opened again after the wait; a server that never answers backs off; the consent
## taken back, the online data deleted, the kill switch: closed.

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_data()
	await _test_no_consent()
	await _test_session()
	await _test_background()
	await _test_lost()
	await _test_backoff()
	await _test_withdrawn()
	await _test_status()
	_restore()


func _test_data() -> void:
	var config := Presence.config
	check(config != null and config.enabled, "the live sessions are on in this build's data")
	check(config.check_seconds > 0.0 and config.retry_seconds >= config.check_seconds and config.connect_timeout > 0.0, "its delays make sense (%.1f, %.1f, %.1f)" % [config.check_seconds, config.retry_seconds, config.connect_timeout])


## A fake server; `consent`: the statistics accepted by a player old enough.
func _use_fake(consent: bool) -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	Presence.use_for_tests()
	if consent:
		Privacy.answer_age(true)
		Privacy.grant()
	return _fake


func _restore() -> void:
	Presence.use_for_tests()
	Leaderboards.use_for_tests()
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	_fake = null


## `seconds` of the game passing for Presence, in steps (its own frames run too).
func _run(seconds: float, step: float = 0.5) -> void:
	var left := seconds
	while left > 0.0:
		Presence._process(step)
		left -= step
		await get_tree().process_frame


func _test_no_consent() -> void:
	var fake := _use_fake(false)
	await _run(10.0)
	check(Presence.phase == Presence.Phase.OFF and fake.live_asks == 0 and fake.live_links.is_empty() and fake.calls == 0, "without the statistics' consent: no connection, no call")


func _test_session() -> void:
	var fake := _use_fake(true)
	var went := [0]
	var on_live := func() -> void: went[0] += 1
	Presence.went_live.connect(on_live)
	await _run(3.0)
	Presence.went_live.disconnect(on_live)
	check(Presence.is_live() and Presence.sessions == 1 and went[0] == 1, "consent given: a live session starts (%s)" % Presence.Phase.keys()[Presence.phase])
	check(fake.live_started == 1 and fake.live_online, "the server started a session and shows the player online")
	var link: FakeLiveLink = fake.live_links.back() if not fake.live_links.is_empty() else null
	check(link != null and link.url.contains("ticket="), "opened with its one-use ticket")
	var identify: Variant = JSON.parse_string(link.sent[0]) if link and not link.sent.is_empty() else null
	var data: Dictionary = (identify as Dictionary).get("data", {}) if identify is Dictionary else {}
	check(identify is Dictionary and (identify as Dictionary).get("req") == "v1.players.identify" and int(data.get("playerAliasId", 0)) == fake.alias_id() and data.get("socketToken") == fake.live_token, "on \"v1.connected\" the player and their socket token are sent")
	await _run(30.0)
	check(fake.live_links.size() == 1 and fake.live_started == 1, "one connection while it lasts (no new session every check)")


func _test_background() -> void:
	var fake := _use_fake(true)
	await _run(3.0)
	Presence._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not Presence.is_live() and fake.live_ended == 1 and not fake.live_online, "the app in the background: the session ends, the player offline")
	await _run(10.0)
	check(fake.live_started == 1, "no session while in the background")
	Presence._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _run(1.0)
	check(Presence.is_live() and fake.live_started == 2 and fake.live_online, "back: a new session at once")


func _test_lost() -> void:
	var fake := _use_fake(true)
	await _run(3.0)
	(fake.live_links.back() as FakeLiveLink).drop()
	await _run(1.0)
	check(Presence.phase == Presence.Phase.OFF and fake.live_ended == 1, "the connection lost: the session ended")
	await _run(Presence.config.retry_seconds * 0.5)
	check(fake.live_started == 1, "not opened again before the wait")
	await _run(Presence.config.retry_seconds)
	check(Presence.is_live() and fake.live_started == 2, "opened again after %.0f s" % Presence.config.retry_seconds)


func _test_backoff() -> void:
	var fake := _use_fake(true)
	fake.live_answers = false  # (a firewall: the connection never opens)
	await _run(Presence.config.connect_timeout + 3.0)
	check(Presence.phase == Presence.Phase.OFF and Presence._failures == 1 and fake.live_started == 0, "a connection that never opens fails after %.0f s" % Presence.config.connect_timeout)
	check(is_equal_approx(Presence._wait, Presence.config.retry_seconds) or Presence._wait < Presence.config.retry_seconds, "the first wait: retry_seconds")
	await _run(Presence.config.retry_seconds + Presence.config.connect_timeout + 3.0)
	check(Presence._failures == 2 and Presence._wait > Presence.config.retry_seconds, "the next one waits twice as long (%.0f s)" % Presence._wait)
	fake.live_answers = true
	await _run(Presence.config.retry_seconds * 2.0 + 3.0)
	check(Presence.is_live() and Presence._failures == 0, "the server back: live, the backoff reset")


func _test_withdrawn() -> void:
	var fake := _use_fake(true)
	await _run(3.0)
	Privacy.refuse()
	await _run(Presence.config.check_seconds + 0.5)
	check(not Presence.is_live() and fake.live_ended == 1 and not fake.live_online, "the consent taken back: closed")
	await _run(10.0)
	check(fake.live_started == 1, "and not opened again")
	fake = _use_fake(true)
	await _run(3.0)
	Privacy.forget_online()
	check(not Presence.is_live() and fake.live_ended == 1, "the online data deleted: closed at once")
	fake = _use_fake(true)
	RemoteConfig.use_for_tests()
	await _run(3.0)
	check(Presence.is_live(), "live before the kill switch")
	fake.config = { "statistics_off": "1" }
	await RemoteConfig.fetch(true)
	await _run(Presence.config.check_seconds + 0.5)
	check(not Presence.is_live() and fake.live_ended == 1, "the remote kill switch: closed")
	RemoteConfig.use_for_tests()


## Where the player is: sent once live, again when it changes, at most every status_min_seconds
## (only the last change goes), again for a new session; none without consent.
func _test_status() -> void:
	var fake := _use_fake(true)
	var config := Presence.config
	await _run(3.0)
	check(fake.live_statuses == PackedStringArray([config.menus_status]), "live: the status says the menus (%s)" % [fake.live_statuses])
	await _run(config.status_min_seconds + 1.0)
	Presence.set_status(config.floor_status.format({ "depth": 3 }))
	Presence.set_status(config.floor_status.format({ "depth": 4 }))
	await _run(1.0)
	check(fake.live_statuses.size() == 2 and fake.live_statuses[1] == "Floor 4", "a change sent once, the last one (%s)" % [fake.live_statuses])
	Presence.set_status(config.floor_status.format({ "depth": 5 }))
	await _run(1.0)
	check(fake.live_statuses.size() == 2, "not again before %.0f s" % config.status_min_seconds)
	await _run(config.status_min_seconds)
	check(fake.live_statuses.size() == 3 and fake.live_statuses[2] == "Floor 5", "then the last one goes")
	await _run(config.status_min_seconds + 1.0)
	check(fake.live_statuses.size() == 3, "nothing sent while it doesn't change")
	Presence._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	Presence._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _run(config.status_min_seconds + 1.0)
	check(fake.live_statuses.size() == 4 and fake.live_statuses[3] == "Floor 5", "a new session: its status sent again")
	check(config.daily_status.format({ "depth": 2 }) == "Dawn Knell, floor 2" and not config.menus_status.is_empty(), "the statuses' words (plain English, the dashboard's)")
	var world := World.new()
	world.depth = 6
	Presence._on_floor_entered(world)
	var plain := Presence.status
	Presence._daily = true
	Presence._on_floor_entered(world)
	check(plain == "Floor 6" and Presence.status == "Dawn Knell, floor 6", "a floor entered names it, a Dawn Knell's too (%s / %s)" % [plain, Presence.status])
	world.free()
	Events.run_ended.emit(RunSummary.new())
	check(Presence.status == config.menus_status, "a run over: back to the menus")
	fake = _use_fake(false)
	Presence.set_status("Floor 9")
	await _run(10.0)
	check(fake.live_statuses.is_empty(), "without consent: no status")
