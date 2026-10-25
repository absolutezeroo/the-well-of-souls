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

@export_group("Status")
## The custom status shown with the player online in the dashboard (Talo's customStatus), where
## they are in the game. Plain English (the dashboard's, never shown in the game). Off: none sent.
@export var send_status := true
## Out of a run (the title, the menus).
@export var menus_status := "In the menus"
## In a run, on a floor ({depth}: the floor's number).
@export var floor_status := "Floor {depth}"
## In a Dawn Knell (the daily run), on a floor.
@export var daily_status := "Dawn Knell, floor {depth}"
## Seconds between two statuses sent (a quicker change waits, only the last one goes).
@export_range(1.0, 120.0) var status_min_seconds := 5.0
