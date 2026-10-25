class_name PresenceDef
extends Resource
## The live session and presence (data/online/presence.tres, read by the Presence autoload;
## docs/online.md "Sessions and presence"): whether the game opens Talo's live connection, how
## often it looks whether it should, and how it tries again.

## The game opens a live connection while the statistics are allowed (false: never, in this build).
@export var enabled := true
## Seconds between two looks at whether a connection should be open (consent given or taken
## back, the remote kill switch, the network back).
@export_range(0.5, 60.0) var check_seconds := 2.0
## Seconds before trying again after a connection failed or was lost; doubled per failure, up
## to OnlineSessionDef.max_backoff times.
@export_range(5.0, 600.0) var retry_seconds := 30.0
## Seconds a connection may take to open and to be answered (the player identified) before it
## counts as failed.
@export_range(5.0, 120.0) var connect_timeout := 20.0
