class_name AccountDef
extends Resource
## The Well's accounts and the online save (data/online/account.tres, read by the Account and
## CloudSave autoloads; docs/online.md "Accounts and the online save"): what a name, a password
## and an email may be, and how the profile goes to the server and comes back.

## Accounts can be made and used in this build (a server is needed too).
@export var enabled := true

@export_group("Name and password")
## An account's name: this many characters at least and at most (letters, digits, - _ .).
@export_range(2, 32) var name_min := 3
@export_range(3, 64) var name_max := 24
## A password: this many characters at least and at most.
@export_range(6, 64) var password_min := 8
@export_range(16, 256) var password_max := 128
## The reset code sent by email: this many digits (Talo's).
@export_range(4, 12) var reset_code_digits := 6

@export_group("Online save")
## The online save's name on the server (one per account: the profile).
@export var save_name := "profile"
## Seconds after the profile is written before it goes online (a burst of writes goes once).
@export_range(1.0, 600.0) var upload_delay := 20.0
## Seconds before trying again after a failed sync; doubled per failure up to
## OnlineSessionDef.max_backoff times.
@export_range(5.0, 3600.0) var retry_seconds := 60.0
## The most the profile may weigh online, in bytes of JSON (Talo takes 1 MB a request).
@export_range(10000, 1000000) var max_bytes := 900000
