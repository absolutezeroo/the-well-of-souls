class_name BoardBackend
extends Node
## Where the online leaderboards (and the gameplay statistics, the world counters, the remote
## settings and the feedback) live, as the OnlineSession autoload holds it for every online
## service. This base is the
## offline one: no server, every call answers UNAVAILABLE at once. The game uses it when no
## access key was built in (docs/online.md) and the tests always do (or a fake one,
## tests/support/fake_board_backend.gd); TaloBackend talks to Talo.
##
## Every call may wait for the network: always `await` it. One player at a time: identify()
## first, then the other calls act for that player.

## OK: done. OFFLINE: no answer (no network, server down, too many requests): try again later.
## REJECTED: the server refused it for good (unknown board, bad key, refused props): never retry.
## UNAVAILABLE: no server at all.
enum Status { OK, OFFLINE, REJECTED, UNAVAILABLE }

## Entries in a page of a board (Talo's, fixed on its side).
const PAGE_SIZE := 50


## One line of a board.
class Entry:
	extends RefCounted
	## 1 for the first.
	var rank := 0
	var name := ""
	var score := 0.0
	## The server's id for the player's alias (the page finds the player's own line by it).
	var alias_id := 0
	## The alias's identifier on the server: the player's device id (OnlineSession.device_id),
	## public in Talo's answer. The tag comes from it ("" when the server gave none).
	var identifier := ""
	var props := {}

	## The player's tag (PlayerName.tag_of()), from their alias's identifier, so an entry from
	## before the tags gets one too and nobody can type someone else's: the device's id, the same
	## as the player's own tag (Leaderboards.tag()). Without an identifier, from the alias id.
	func tag() -> String:
		if not identifier.is_empty():
			return PlayerName.tag_of(identifier)
		return PlayerName.tag_of("alias:%d" % alias_id) if alias_id > 0 else ""

	## The line's name as it is drawn: made safe (PlayerName.readable()), with its tag.
	func shown_name(config: LeaderboardsConfig) -> String:
		return PlayerName.tagged(PlayerName.readable(name, config), tag())


## A page of a board, or the player's own entry (`entries` empty: none).
class Page:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	var entries: Array[Entry] = []
	## Entries on the whole board (that period's).
	var total := 0
	var last_page := true
	## The entries' ranks are their place on this period's board (false: the server counted other
	## periods' entries too, and the rank must be found by reading the pages).
	var ranks_reliable := true


## What a sent score became.
class Sent:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## Its place on the board now (0: unknown).
	var rank := 0


## Counters as the server has them (the world counters: WorldStats).
class StatValues:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## Talo's internal name -> its value (the world's, or the player's own).
	var values := {}


## The game's live config as the server has it (the remote settings: RemoteConfig).
class ConfigValues:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## Key -> value, both texts as the server keeps them (validated by RemoteConfig, never here).
	var values := {}


## A signed-in account (Account; docs/online.md "Accounts"): its own player on the server (not
## the device's), the session token that proves it, its name and the email the server holds.
class AccountAuth:
	extends RefCounted
	var alias_id := 0
	var player_id := ""
	var token := ""
	var identifier := ""
	## The recovery email the server holds ("" none: the password can't be reset).
	var email := ""

	func is_valid() -> bool:
		return alias_id > 0 and not player_id.is_empty() and not token.is_empty()


## An account call's answer: its status, the server's reason when refused (Talo's errorCode:
## "IDENTIFIER_TAKEN", "INVALID_CREDENTIALS", "EMAIL_TAKEN"...; "" none), and the account signed
## in (register, login).
class AccountAnswer:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	var error := ""
	var auth: AccountAuth


## One online save of an account (Talo's game save): its id, name, content (a Dictionary) and
## when the server last changed it (ISO text).
class CloudSlot:
	extends RefCounted
	var id := 0
	var name := ""
	var content := {}
	var updated_at := ""


## The account's online saves (saves_list()), or the one made or changed (`slot`).
class SaveAnswer:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## The server's reason when refused (Talo's errorCode: "INVALID_SESSION"...; "" none).
	var error := ""
	var saves: Array[CloudSlot] = []
	var slot: CloudSlot


## What opening a live session needs (Presence): the connection's address with its one-use
## ticket, and the player's socket token (the proof, on that connection, that it is them).
class LiveAccess:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	var url := ""
	var token := ""


## There is a server to talk to (an access key).
func is_configured() -> bool:
	return false


## The player behind this device (`device_id`, made once and kept on it): created on the
## server the first time. Must be OK before the other calls.
func identify(_device_id: String) -> Status:
	return Status.UNAVAILABLE


## The player's alias id once identified (0 before).
func alias_id() -> int:
	return 0


## The server's id for the player once identified ("" before): a deletion request names it.
func player_id() -> String:
	return ""


## Forgets the player identified ("delete my online data"): the next call must identify() again.
func forget() -> void:
	pass


## Sends gameplay statistics events for the identified player: each {name, props (String ->
## String), timestamp (Unix milliseconds)}. OK: the server took them (or refused some for good:
## never resent). See Telemetry.
func send_events(_events: Array[Dictionary]) -> Status:
	return Status.UNAVAILABLE


## Adds `change` to the world counter `internal_name` for the identified player (their own total
## and the world's). One call per counter: the server takes at most the stat's max change at once.
func add_to_stat(_internal_name: String, _change: int) -> Status:
	return Status.UNAVAILABLE


## Every world counter's value, the whole world's (no player needed).
func fetch_world_stats() -> StatValues:
	return StatValues.new()


## The identified player's own totals of the world counters.
func fetch_my_stats() -> StatValues:
	return StatValues.new()


## The game's live config (the remote settings), read **without any player**: no id goes with it.
func fetch_config() -> ConfigValues:
	return ConfigValues.new()


## Shows the player under `pseudonym` on every board.
func set_pseudonym(_pseudonym: String) -> Status:
	return Status.UNAVAILABLE


## Sends a score to `board` for the period `period_key` ("" for all time), with the run's props.
func submit(_board: LeaderboardDef, _score: float, _period_key: String, _props: Dictionary) -> Sent:
	return Sent.new()


## The page `page` (0 first, 50 a page) of `board` for the period `period_key`. `past`: a period
## that is over (the server keeps its entries archived).
func fetch(_board: LeaderboardDef, _period_key: String, _past: bool, _page: int) -> Page:
	return Page.new()


## The player's own entry on `board` for that period (a Page of one entry, or none).
func fetch_mine(_board: LeaderboardDef, _period_key: String, _past: bool) -> Page:
	return Page.new()


## Sends the player's message `comment` to the feedback category `internal_name` (Talo's game
## feedback), with `props` (String -> String: the game's details, the pseudonym, only what the
## player ticked). OK: taken. REJECTED: refused for good (a prop too long): never resent.
## OFFLINE: try again later. See Feedback.
func send_feedback(_internal_name: String, _comment: String, _props: Dictionary) -> Status:
	return Status.UNAVAILABLE


## What the identified player's live connection needs (Presence): asked again before each one
## (the ticket serves once).
func live_access(_allowed: Callable = Callable()) -> LiveAccess:
	return LiveAccess.new()


## Shows `text` as the identified player's custom status with their presence (Talo's
## customStatus: where they are in the game).
func set_presence_status(_text: String) -> Status:
	return Status.UNAVAILABLE


## A new live connection, not opened yet (the tests' fake server gives its own).
func open_live() -> LiveLink:
	return LiveLink.new()


# --- Accounts (Talo player auth) and their online saves ----------------------------------
# Every call answers at once here (no server); TaloBackend talks to /v1/players/auth and
# /v1/game-saves for the account's own player, never the device's.

## A new account named `identifier` (its password, an optional recovery `email`: "" none),
## signed in.
func account_register(_identifier: String, _password: String, _email: String) -> AccountAnswer:
	return AccountAnswer.new()


func account_login(_identifier: String, _password: String) -> AccountAnswer:
	return AccountAnswer.new()


## Signed out on the server (its session token no longer valid).
func account_logout(_auth: AccountAuth) -> Status:
	return Status.UNAVAILABLE


## A reset code sent to `email` (answered OK whether an account has it or not: the server
## never says).
func account_forgot_password(_email: String) -> Status:
	return Status.UNAVAILABLE


## The password set to `password` with the code from the email.
func account_reset_password(_code: String, _password: String) -> AccountAnswer:
	return AccountAnswer.new()


func account_change_password(_auth: AccountAuth, _current: String, _new_password: String) -> AccountAnswer:
	return AccountAnswer.new()


## The account deleted on the server (its name, password and email; its saves are deleted
## first by the caller: Account.delete_account()).
func account_delete(_auth: AccountAuth, _password: String) -> AccountAnswer:
	return AccountAnswer.new()


func saves_list(_auth: AccountAuth) -> SaveAnswer:
	return SaveAnswer.new()


func save_create(_auth: AccountAuth, _save_name: String, _content: Dictionary) -> SaveAnswer:
	return SaveAnswer.new()


func save_update(_auth: AccountAuth, _id: int, _content: Dictionary) -> SaveAnswer:
	return SaveAnswer.new()


func save_delete(_auth: AccountAuth, _id: int) -> Status:
	return Status.UNAVAILABLE
