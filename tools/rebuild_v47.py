#!/usr/bin/env python3
"""Assemble the verified Lashbound V47 Roblox Studio project (no ZIP needed)."""
from pathlib import Path
from hashlib import sha256
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
PARTS = [ROOT / "builds" / ".staging" / f"v47_part_{i:02d}.txt" for i in range(1, 7)]
OUTPUT = ROOT / "builds" / "Lashbound_V47_Boss_Recovery_Whip_Impact.rbxlx"
EXPECTED_BYTES = 4_200_167
EXPECTED_SHA256 = "4920634533b43ccbc6c4ecf9e5eca1bffb6f3df995aa5cdde00584d4f7805488"

def main():
    data = b"\n".join(path.read_bytes() for path in PARTS)
    digest = sha256(data).hexdigest()
    if len(data) != EXPECTED_BYTES or digest != EXPECTED_SHA256:
        raise SystemExit(f"V47 integrity check failed: {len(data)} bytes, sha256={digest}")
    root = ElementTree.fromstring(data)
    if root.tag != "roblox":
        raise SystemExit("Not a Roblox place XML.")
    OUTPUT.write_bytes(data)
    print(f"Verified {OUTPUT.name} ({len(data)} bytes, sha256 {digest})")

if __name__ == "__main__":
    main()
