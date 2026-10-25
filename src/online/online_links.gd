class_name OnlineLinks
extends RefCounted
## Composition point for cross-autoload subscriptions. Local queue and gameplay callbacks
## stay with their owning service. Called after all _init methods, before gameplay starts.
## The explicit list makes consent, identity and account dependencies reviewable together.

static func bind() -> void:
	_wire(Privacy.changed, WorldStats.reconcile_choices)
	_wire(Leaderboards.changed, WorldStats.reconcile_choices)
	_wire(Privacy.changed, RemoteConfig.reconcile_choices)
	_wire(Leaderboards.changed, RemoteConfig.reconcile_choices)
	_wire(Privacy.changed, Presence.reconcile_privacy)
	_wire(OnlineSession.identity_forgotten, Presence.on_identity_forgotten)
	_wire(Profile.saved, CloudSave.mark_dirty)
	_wire(Account.signed_in, CloudSave.on_signed_in)
	_wire(Account.signed_out, CloudSave.on_signed_out)
	_wire(Account.deleted, CloudSave.forget)


static func _wire(event: Signal, callback: Callable) -> void:
	if not event.is_connected(callback):
		event.connect(callback)
