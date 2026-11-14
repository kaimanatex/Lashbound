-- Shared balancing configuration. Customize prices and combat here.
local Config = {}
Config.Order = {"Rope", "Ember", "Frost", "Volt", "Gravity", "Phantom", "Judgement", "Echo", "Legend"}
Config.Whips = {
    Rope = {
        Name = "ROOKIE ROPE", Price = 0, Damage = 13, Range = 18,
        AttackCooldown = 0.70, PowerCooldown = 7.5, PowerName = "LASH DASH",
        Color = Color3.fromRGB(240, 212, 122), Description = "Dash forward and strike enemies in your path."
    },
    Ember = {
        Name = "INFERNO", Price = 90, Damage = 15, Range = 19,
        AttackCooldown = 0.83, PowerCooldown = 11.25, PowerName = "BURNING HALO",
        Color = Color3.fromRGB(255, 103, 59), Description = "Scorch nearby rivals with a ring of fire."
    },
    Frost = {
        Name = "PERMAFROST", Price = 190, Damage = 12, Range = 22,
        AttackCooldown = 0.76, PowerCooldown = 12, PowerName = "COLD FRONT",
        Color = Color3.fromRGB(100, 236, 255), Description = "Freeze nearby enemies to a crawl."
    },
    Volt = {
        Name = "THUNDERLASH", Price = 340, Damage = 15, Range = 21,
        AttackCooldown = 0.70, PowerCooldown = 12.75, PowerName = "CHAIN STORM",
        Color = Color3.fromRGB(255, 236, 75), Description = "Zap up to four enemies in rapid succession."
    },
    Gravity = {
        Name = "SINGULARITY", Price = 520, Damage = 13, Range = 23,
        AttackCooldown = 0.83, PowerCooldown = 15, PowerName = "GRAVITY WELL",
        Color = Color3.fromRGB(173, 119, 255), Description = "Pull enemies toward the center, then detonate."
    },
    Phantom = {
        Name = "PHANTOM THREAD", Price = 800, Damage = 16, Range = 22,
        AttackCooldown = 0.76, PowerCooldown = 14.25, PowerName = "SHADOW RECALL",
        Color = Color3.fromRGB(255, 100, 215), Description = "Blink through an enemy and attack from behind."
    },
    Judgement = {
        Name = "STORM JUDGEMENT", Price = 1350, Damage = 15, Range = 22,
        AttackCooldown = .84, PowerCooldown = 37.5, PowerName = "THUNDER VERDICT",
        Color = Color3.fromRGB(244,238,116),
        Description = "Lock one forward foe within 30 studs, launch them, then thunderstrike. Bosses resist the finisher."
    },
    Echo = {
        Name = "MIRRORBOUND", Price = 1080, Damage = 17, Range = 23,
        AttackCooldown = .78, PowerCooldown = 24, PowerName = "MIRROR COMPANION",
        Color = Color3.fromRGB(112, 222, 210),
        Description = "Summons your mirrored double for 22 seconds. It follows and attacks nearby foes for 25% of your whip's damage."
    },
    Legend = {
        Name = "SOVEREIGN'S GRASP", Price = -1, Legendary = true,
        Damage = 18, Range = 25, AttackCooldown = .80,
        PowerCooldown = 15, PowerName = "ROYAL BIND",
        Color = Color3.fromRGB(255, 185, 53),
        Description = "Grapple, pull and stun; third combo strike launches enemies. WHEEL EXCLUSIVE."
    }
}
-- This entry is NOT in Config.Order; it cannot be purchased, spun, or saved as an unlock.
-- The owner-only server script grants access after checking the actual Roblox UserId.
Config.Whips.Owner = {
    Name = "FOUNDER'S TEMPEST", Price = -1, OwnerOnly = true,
    Damage = 10000, Range = 42, AttackCooldown = 0,
    PowerCooldown = 0.75, PowerName = "FLIGHT (F / Q)",
    Color = Color3.fromRGB(253, 240, 176),
    Description = "Owner-only • 10,000 damage • instant strikes • unrestricted flight"
}
Config.ComboCooldowns = {0.69,0.76,1.06} -- intentional weight and counterplay
Config.ComboReset = 2.45
Config.DodgeCooldown = 3.4
Config.BotReward = 15 -- training dummies; sentinels drop 10-coin pickups
Config.PlayerKOReward = 50
Config.WheelPrice = 200 -- earned coins only. Never purchased with Robux.
Config.WheelOdds = { {Prize="20 COINS",Weight=50,Coins=20}, {Prize="50 COINS",Weight=30,Coins=50}, {Prize="100 COINS",Weight=14,Coins=100}, {Prize="200 COINS",Weight=5,Coins=200}, {Prize="LEGENDARY WHIP",Weight=1,Legend=true} }
Config.PlayfieldRadius = 228
return Config
