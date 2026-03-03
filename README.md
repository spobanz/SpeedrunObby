# Speedrun Obby (Roblox) Starter Project

This repository contains a **ship-fast baseline** for a Roblox speedrun obby with:

- Checkpoints that save respawn position
- Coins with leaderstats tracking
- Run finish timing + personal best
- DataStore persistence for coins and best time
- Client HUD for timer + coins + messages

## Repository Layout

- `ServerScriptService/RunServer.lua` — server gameplay logic and DataStore save/load
- `StarterPlayer/StarterPlayerScripts/RunClient.lua` — local UI timer + notifications
- `ReplicatedStorage/Remotes/` — create a `RemoteEvent` named `RunEvent` in Studio
- `docs/14-day-blueprint.md` — day-by-day build plan

## Roblox Studio Setup

1. Create a place.
2. In `ReplicatedStorage`, create a `Folder` named `Remotes`.
3. Inside `Remotes`, create a `RemoteEvent` named `RunEvent`.
4. In `Workspace`, create a `Folder` named `Map`.
5. Inside `Map`, create:
   - `Part` named `StartPad`
   - `Part` named `FinishPad`
   - `Folder` named `Checkpoints` with parts named `CP1`, `CP2`, ...
   - `Folder` named `Coins` with parts named `Coin1`, `Coin2`, ...
6. Copy `ServerScriptService/RunServer.lua` into `ServerScriptService`.
7. Copy `StarterPlayer/StarterPlayerScripts/RunClient.lua` into `StarterPlayerScripts`.
8. Press Play and test the full loop.

## Recommended Part Settings

- `StartPad`, `FinishPad`, checkpoint parts: `Anchored = true`, `CanCollide = true`
- coin parts: `Anchored = true`, `CanCollide = false`, `CanTouch = true`
- checkpoints: bright colors + signs for readability

## Definition of Done (Version 1)

- 1 playable map (30–60 seconds average completion)
- 5–10 checkpoints
- 20–40 coins
- finish pad records completion time
- best time persists between sessions
- coins persist between sessions

## Notes

- DataStore calls are wrapped with `pcall` and fail gracefully.
- Coins currently respawn globally after a short cooldown.
- For production polish, add anti-cheat and per-player coin visibility.
