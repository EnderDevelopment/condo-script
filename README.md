# Condo Script (Private Residence System)

A family-friendly "condo" / private residence manager for Roblox Studio.

Players can claim a condo unit, lock and unlock their door, invite friends, redecorate (paint walls / swap furniture), and clean their space. Everything is safe, coop and roleplay friendly.

## Install

### Files to create in your Roblox place

| File | Where to put it in the place hierarchy |
|------|----------------------------------------|
| `ServerScriptService.CondoManager.server.lua` | A `Script` inside **ServerScriptService** |
| `ReplicatedStorage.RemoteEvents` (5 events) | **RemoteEvents** inside **ReplicatedStorage** |
| `ReplicatedStorage.RemoteFunctions` (1 function) | **RemoteFunction** inside **ReplicatedStorage** |
| `StarterPlayerScripts.CondoClient.client.lua` | A `LocalScript` inside **StarterPlayerScripts** |

### Remotes to create in ReplicatedStorage

Name them exactly as shown (parent them under ReplicatedStorage):

- `CondoLockToggle` (RemoteEvent)
- `CondoInvite` (RemoteEvent)
- `CondoPaint` (RemoteEvent)
- `CondoSelectCharacter` (RemoteEvent) — select a character preset
- `CondoState` (RemoteEvent) — server pushes state to all clients
- `CondoRequestState` (RemoteFunction)

### Parts to build in your place

Build one or more condo units. For each unit create a folder in Workspace named `CondoUnit<Number>` (e.g. `CondoUnit1`). Inside that folder place:

- `Door` (a Part) — the door that locks/unlocks.
- `Rooms` (a Folder) — optional, holds `Room1`, `Room2`, ... each a Folder. Give each room folder a part with a surface that gets painted, e.g. a Part named `Wall`.

## Use

### Configuration

All settings are at the top of `CondoManager.server.lua`:

- `PRICE` — robux price to claim a unit.
- `MAX_UNITS` — how many units exist.
- `PAINT_COLORS` — list of allowed wall colors.
- `CHARACTERS` — the selectable character presets (name + outfit accents).

### Characters

Open the condo panel (E) and press **Choose Character** to pick between the safe, fully-clothed presets defined in `CHARACTERS` (Collegiate, Athlete, Scholar, Explorer). The server tints each player's limbs via `BodyColors` and can add a simple hat or glasses accessory. To change the available characters, edit the `CHARACTERS` table on the server **and** the matching `CHARACTER_NAMES` list near the top of `CondoClient.client.lua`.

For nicer-looking hats/glasses, replace the placeholder `Part` handle meshes in `applyCharacter` with your own mesh asset IDs.

### Notes on safety

This script contains NO inappropriate content. It manages ownership, locks, invites, decoration of private rooms, and selectable outfits. The term "condo" is used strictly in the "private apartment / condo building" sense.

---

More Roblox script projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/af1b530e-ea5a-45f5-b625-497f70d4b383?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=af1b530e-ea5a-45f5-b625-497f70d4b383
