# Lashbound V47 Studio Build

The six text segments in `builds/.staging/` reconstruct the complete `Lashbound_V47_Boss_Recovery_Whip_Impact.rbxlx` without ZIP extraction.

The GitHub Actions workflow automatically runs `python3 tools/rebuild_v47.py`, validates the 4,200,167-byte file against SHA-256, uploads a build artifact and attempts to commit the assembled `.rbxlx` into `builds/` (if GitHub Actions is allowed to write to the branch).

Direct Studio files are versioned snapshots. Source script changes in `src/` don't auto-deploy to Roblox; publish the tested `.rbxlx` through Roblox Studio yourself.
