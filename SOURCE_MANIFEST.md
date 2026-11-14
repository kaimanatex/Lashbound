# Lashbound V28 source inventory

Baseline: `Lashbound_V28_Combat_Safety_Patch.rbxlx`.

The extracted source package contains **40 Luau scripts** (20 server scripts, 17 client scripts, 3 shared modules), plus README and inventory. The full package has **not yet been pushed to GitHub**.

## Proposed source directories

- `src/ServerScriptService/Combat/` — server combat, bots, hit reactions
- `src/ServerScriptService/Boss/` — boss attack and phase service
- `src/ServerScriptService/Minigames/` — chess and game room services
- `src/ServerScriptService/World/` — world, portals, raids, multiplayer
- `src/StarterPlayer/StarterPlayerScripts/Combat/` — whip visuals, sound, client combat
- `src/StarterPlayer/StarterPlayerScripts/Boss/` — boss FX, music, motion
- `src/StarterPlayer/StarterPlayerScripts/Minigames/` — chess and game room clients
- `src/StarterPlayer/StarterPlayerScripts/World/` — world and enemy visuals
- `src/ReplicatedStorage/Shared/` — WhipConfig, LashboundSoundIds, LashboundChessPieceFactory

**Important:** These extracted paths are organizational; they are not yet configured as a working Rojo project. Roblox Studio gameplay testing remains necessary.
