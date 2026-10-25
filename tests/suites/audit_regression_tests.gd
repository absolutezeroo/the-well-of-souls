class_name AuditRegressionTests
extends TestSuite
## Regressions from the save/privacy audit. Network steps are released by signals, not by
## wall-clock delays: the same interleaving is tested even on a slow or heavily loaded machine.

class HeldBackend:
	extends FakeBoardBackend
	signal release_write
	signal release_read
	signal release_identity
	var hold_write := false
	var hold_read := false
	var hold_identity := false
	var writing := false
	var reading := false
	var identifying := false

	func save_update(auth: BoardBackend.AccountAuth, id: int, content: Dictionary) -> BoardBackend.SaveAnswer:
		if hold_write:
			hold_write = false
			writing = true
			await release_write
		return await super.save_update(auth, id, content)

	func saves_list(auth: BoardBackend.AccountAuth) -> BoardBackend.SaveAnswer:
		var answer := await super.saves_list(auth)
		if hold_read:
			hold_read = false
			reading = true
			await release_read
		return answer

	func identify(device_id: String) -> Status:
		if hold_identity:
			hold_identity = false
			identifying = true
			await release_identity
		return await super.identify(device_id)


class HeldTalo:
	extends TaloBackend
	signal release_identity
	signal release_ticket
	var hold_identity := true
	var hold_ticket := false
	var identities := 0
	var token_requests := 0

	func _init() -> void:
		super("test-key", "https://talo.test")

	func _send(_method: HTTPClient.Method, url: String, _headers: PackedStringArray, _body: String) -> Array:
		var body := {}
		if url.contains("/identify?"):
			identities += 1
			body = {"alias": {"id": identities, "player": {"id": "player-%d" % identities}}}
			if hold_identity:
				hold_identity = false
				await release_identity
		elif url.ends_with("/socket-tickets"):
			body = {"ticket": "ticket"}
			if hold_ticket:
				hold_ticket = false
				await release_ticket
		elif url.ends_with("/socket-token"):
			token_requests += 1
			body = {"socketToken": "token"}
		return [HTTPRequest.RESULT_SUCCESS, 200, JSON.stringify(body).to_utf8_buffer()]


class ClearingActor:
	extends Actor
	var hits := 0
	func take_hit(_hit: HitInfo) -> void:
		hits += 1
		if hits == 1:
			statuses.clear()
			statuses.apply_dot(&"haunt", 1, 0.1, 1.0, null, Color.WHITE)


func run_unit() -> void:
	var profile := Profile.to_data().duplicate(true)
	var path := Profile.save_path
	var run_path := RunSave.path
	_test_storage()
	await _test_upload_changes()
	await _test_stale_cloud()
	await _test_debug_and_disk()
	await _test_withdrawal()
	await _test_identity_and_ticket()
	_test_status_buffers()
	_test_shard_cache()
	_test_offers_and_tuning()
	OnlineSession.use_all_for_tests()
	CloudSave.set_process(true)
	Presence.set_process(true)
	Profile.save_path = ""
	Profile.from_data(profile)
	Profile.save_path = path
	RunSave.path = run_path


func _fresh() -> HeldBackend:
	var fake := HeldBackend.new()
	OnlineSession.use_all_for_tests(fake)
	CloudSave.set_process(false)
	Presence.set_process(false)
	Profile.save_path = ""
	Profile.reset()
	Profile.runs = 2
	Profile.souls = 100
	return fake


func _test_storage() -> void:
	Profile.reset()
	Profile.souls = 100
	Profile.achievements = {"kept": 1}
	var before := Profile.to_data().duplicate(true)
	check(not Profile.from_data({"souls": 123, "runs": 2, "difficulty": {}}) and Profile.to_data() == before, "a malformed cloud profile is rejected without resetting progress")
	check(not Profile.from_data({"souls": 123, "runs": 2, "stats": {"kills": []}}) and Profile.to_data() == before, "nested malformed profile counters are rejected too")
	var clean := RunSave.parse({"version": RunSave.VERSION, "player": {"equipment": null, "hp": null, "perks": null}})
	check(clean.player.is_empty(), "null non-nullable run fields are dropped, so restoration uses defaults")
	var file := "user://test_audit_run_%d.json" % OS.get_process_id()
	RunSave.path = file
	RunSave.erase()
	SafeFile.write_json(file + ".tmp", {"version": RunSave.VERSION, "player": {"hp": 5}})
	check(RunSave.exists() and RunSave.read().player.hp == 5, "a complete temporary run is recovered even without the main file")
	RunSave.erase()
	check(not RunSave.exists(), "erasing a run also erases its recovery copy")
	var bad := FileAccess.open(file, FileAccess.WRITE)
	bad.store_string("{truncated")
	bad.close()
	check(SafeFile.read_json(file) == null, "damaged JSON is handled without an engine error")
	RunSave.erase()


func _test_upload_changes() -> void:
	var fake := _fresh()
	await Account.register("AuditHero", "example-password", "", false)
	Profile.souls = 200
	Profile.stats["kills"] = 2
	CloudSave.mark_dirty()
	fake.hold_write = true
	CloudSave.sync()
	check(fake.writing, "the upload is suspended after taking its snapshot")
	Profile.souls = 300
	Profile.stats["kills"] = 3
	CloudSave.mark_dirty()
	fake.release_write.emit()
	var online := fake.online_profile("AuditHero")
	check(online.profile.souls == 200 and online.profile.stats.kills == 2 and CloudSave.dirty, "changes during an upload stay dirty; nested snapshot fields do not change")
	await CloudSave.sync()
	check(fake.online_profile("AuditHero").profile.souls == 300 and not CloudSave.dirty, "the next sync sends the changes made during the previous upload")


func _test_stale_cloud() -> void:
	var fake := _fresh()
	await Account.register("AuditHero", "example-password", "", false)
	var remote := Profile.to_data().duplicate(true)
	remote.souls = 900
	fake.put_online("AuditHero", 2, remote)
	fake.hold_read = true
	CloudSave.sync()
	check(fake.reading, "the old account's cloud read is suspended")
	await Account.sign_out()
	fake.release_read.emit()
	check(not Account.is_signed_in() and Profile.souls == 100 and CloudSave.state == CloudSave.Step.OFF, "a cloud response after sign-out cannot replace the local profile")
	await Account.sign_in("AuditHero", "example-password", false)
	var kept := Profile.souls
	remote.souls = 950
	fake.put_online("AuditHero", 3, remote)
	fake.hold_read = true
	CloudSave.sync()
	await Account.sign_out()
	await Account.register("AuditOther", "example-password", "", false)
	var revision := CloudSave.base_rev
	fake.release_read.emit()
	check(Account.account_name() == "AuditOther" and CloudSave.account_player == Account.auth.player_id and CloudSave.base_rev == revision and Profile.souls == kept, "an old account's response cannot change the new account or its profile")
	CloudSave.in_run = true
	var victory := RunSummary.new()
	victory.won = true
	Events.run_ended.emit(victory)
	check(CloudSave.in_run, "a victory report does not end the cloud guard: endless play can follow")
	Events.run_closed.emit()
	check(not CloudSave.in_run, "closing the gameplay scene ends the cloud guard")


func _test_debug_and_disk() -> void:
	var fake := _fresh()
	await Account.register("AuditHero", "example-password", "", false)
	Profile.save_path = "user://test_audit_missing_%d/profile.json" % OS.get_process_id()
	var writes := [0]
	var on_saved := func() -> void: writes[0] += 1
	Profile.saved.connect(on_saved)
	check(not Profile.save_profile() and writes[0] == 0, "a failed profile write emits no successful-save signal")
	var remote := Profile.to_data().duplicate(true)
	remote.souls = 888
	fake.put_online("AuditHero", 2, remote)
	await CloudSave.sync()
	check(Profile.souls == 100 and CloudSave.base_rev == 1 and CloudSave.state == CloudSave.Step.REFUSED and writes[0] == 0, "a failed cloud download write leaves memory and the base revision unchanged")
	Profile.saved.disconnect(on_saved)
	Profile.save_path = "user://test_audit_debug_%d.json" % OS.get_process_id()
	fake.put_online("AuditHero", 1, Profile.to_data())
	DebugCheats.mark_run()
	Profile.souls = 999
	await CloudSave.sync()
	check(fake.online_profile("AuditHero").profile.souls == 100, "a held debug profile never uploads its temporary rewards")
	DebugCheats.end_run()
	await CloudSave.sync()
	check(Profile.souls == 100 and fake.online_profile("AuditHero").profile.souls == 100, "ending debug restores and syncs only the legitimate profile")
	DirAccess.remove_absolute(Profile.save_path)
	Profile.save_path = ""


func _test_withdrawal() -> void:
	var fake := _fresh()
	Privacy.answer_age(true)
	Privacy.grant()
	await Presence.start()
	for i in 4:
		Presence._process(0.1)
	check(Presence.is_live(), "the consent regression starts with a live presence link")
	Presence._check = 1.5
	Presence._status_wait = 0.0
	var sent := fake.live_statuses.size()
	Privacy.refuse()
	Presence.set_status("Floor 7")
	Presence._process(0.01)
	check(not Presence.is_live() and fake.live_statuses.size() == sent, "withdrawing consent closes presence immediately and sends no new status")
	fake = _fresh()
	fake.hold_identity = true
	Leaderboards.pseudonym = "PrivateAuditName"
	Leaderboards.name_chosen = true
	Leaderboards.set_shown(true)
	Leaderboards.flush()
	check(fake.identifying, "the pseudonym's identification is suspended")
	Leaderboards.set_shown(false)
	fake.release_identity.emit()
	check(fake.names.is_empty() and Leaderboards.synced_name.is_empty(), "disabling score publication during identify prevents the subsequent pseudonym request")


func _old_identity(talo: HeldTalo, result: Array) -> void:
	result[0] = await talo.identify("old-device")


func _live_ticket(talo: HeldTalo, allowed: Array, result: Array) -> void:
	result[0] = await talo.live_access(func() -> bool: return allowed[0])


func _test_identity_and_ticket() -> void:
	var talo := HeldTalo.new()
	add_child(talo)
	var old := [-1]
	_old_identity(talo, old)
	talo.forget()
	check(await talo.identify("new-device") == BoardBackend.Status.OK and talo.alias_id() == 2, "a new identification finishes before the forgotten one")
	talo.release_identity.emit()
	check(old[0] == BoardBackend.Status.UNAVAILABLE and talo.alias_id() == 2 and talo.player_id() == "player-2", "Talo ignores a late identification at the backend as well as at the session")
	var allowed := [true]
	var result: Array = [null]
	talo.hold_ticket = true
	_live_ticket(talo, allowed, result)
	allowed[0] = false
	talo.release_ticket.emit()
	check(result[0] != null and result[0].status == BoardBackend.Status.UNAVAILABLE and talo.token_requests == 0, "withdrawal between the live ticket and token prevents the second request")
	talo.free()


func _test_status_buffers() -> void:
	var actor := ClearingActor.new()
	actor.statuses.apply_dot(&"burn", 1, 0.1, 1.0, null, Color.WHITE)
	actor.statuses.apply_dot(&"poison", 1, 0.1, 1.0, null, Color.WHITE)
	actor.statuses.tick(actor, 0.1)
	check(actor.hits == 2 and actor.statuses.has(&"haunt"), "the reused tick snapshot survives clear/add callbacks and never ticks a newly added status early")
	check(actor.statuses.active_ids() == [&"haunt"], "cached status ids refresh after reentrant changes")
	actor.statuses.apply_slow(0.5, 0.1)
	check(actor.statuses.active_ids().has(&"slow"), "cached status looks include a newly applied slow")
	actor.statuses.tick(actor, 0.2)
	check(not actor.statuses.active_ids().has(&"slow"), "the cached slow look disappears when its last source expires")
	actor.free()


func _test_offers_and_tuning() -> void:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	var offers := OfferQueue.new()
	var offer := offers.add(PerkDef.Rarity.COMMON, CONTENT.player.perk_choices, "Level %d!", "Choose an upgrade", true, 2)
	var saved := offer.to_data()
	var legacy := saved.duplicate(true)
	legacy.erase("level")
	legacy.title = offer.shown_title()
	legacy.subtitle = tr(offer.subtitle)
	TranslationServer.set_locale("en")
	check(OfferQueue.Offer.from_data(saved).shown_title() == "Level 2!", "an offer saved in French renders in the new language")
	var migrated := OfferQueue.Offer.from_data(legacy)
	check(migrated.shown_title() == "Level 2!" and migrated.subtitle == "Choose an upgrade", "older rendered French offers recover their message keys and level")
	TranslationServer.set_locale(locale)
	var rules: BeltRules = Belt.rules
	var limit := rules.max_stack
	rules.max_stack = 2
	var belt := Belt.new()
	var potion: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	if potion == null:
		for item in CONTENT.player.starting_items:
			if item is ConsumableDef:
				potion = item
	for i in 3:
		belt.add(potion)
	check(belt.count_at(0) == 2 and belt.count_at(1) == 1, "belt stacking follows its data resource (%d, %d; rule %d)" % [belt.count_at(0), belt.count_at(1), rules.max_stack])
	rules.max_stack = limit


func _test_shard_cache() -> void:
	var frames := CONTENT.dungeon.acts[0].monsters[0].frames.duplicate(true) as SpriteFrames
	var frame: Texture2D
	for animation in frames.get_animation_names():
		if String(animation).begins_with("dead") and frames.get_frame_count(animation) > 0:
			frame = frames.get_frame_texture(animation, 0)
			break
	if frame == null:
		var animation := frames.get_animation_names()[0]
		frame = frames.get_frame_texture(animation, 0)
	check(frame != null, "the shard cache regression has a body frame")
	if frame == null:
		return
	seed(77123)
	var expected := randi()
	seed(77123)
	DeathPiecesVfx.warm(frames)
	check(randi() == expected, "preparing frost fragments does not consume the gameplay random stream")
	var cached := DeathPiecesVfx._fragments.size()
	var first := DeathPiecesVfx.new()
	first.element = VfxElementDef.named(&"frost")
	first._break(frame, Vector2.ZERO, false)
	var second := DeathPiecesVfx.new()
	second.element = first.element
	second._break(frame, Vector2.ZERO, false)
	check(not first._pieces.is_empty() and first._texture == second._texture and DeathPiecesVfx._fragments.size() == cached, "repeated frozen deaths reuse their prepared atlas, without a new texture")
	first.free()
	second.free()
