# Lashbound V28 — Development Source

This repository is being prepared to track the Roblox game source independently from the `.rbxlx` place file.

## Planned source layout

- `src/ReplicatedStorage/` — shared whip configuration, sound IDs, and chess pieces
- `src/ServerScriptService/Combat/` — authoritative attacks, damage, hit reactions, and bot combat
- `src/ServerScriptService/Boss/` — boss phases, attacks, and revival
- `src/ServerScriptService/Minigames/` — chess and game-room services
- `src/ServerScriptService/World/` — portal, terrain, map, raids, and player services
- `src/StarterPlayer/StarterPlayerScripts/Combat/` — client combat effects and reactions
- `src/StarterPlayer/StarterPlayerScripts/Boss/` — boss motion, phase FX, and music
- `src/StarterPlayer/StarterPlayerScripts/Minigames/` — chess and game-room clients
- `src/StarterPlayer/StarterPlayerScripts/World/` — other gameplay and world effects

## Source provenance

Source baseline: `Lashbound_V28_Combat_Safety_Patch.rbxlx` (partial V28 implementation). The original place file remains the authoritative game until extracted scripts are committed and Studio playtests pass. Do not treat this README as evidence that scripts have been uploaded or tested.

## Pending verification

Unified server attack timeline, boss warning/damage geometry parity, full minigame multiplayer testing, audio asset IDs, persistence and mobile profiling remain unfinished.
