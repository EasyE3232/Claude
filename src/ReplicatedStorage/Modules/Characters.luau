--[[
	Characters — THE single source of truth for every collectible character.

	Nothing about a character (price, income, rarity, spawn chance, look, special
	effects) is hard-coded anywhere else. To add a character, add one entry to
	Characters.LIST. To add a rarity, add one entry to Characters.RARITIES.

	All characters are parody-inspired Roblox takes, not replicas: no real logos,
	tattoos, branded clothing or merchandise.

	SPAWNING
	  1. Roll a rarity using RARITIES[i].Odds (percent of all conveyor spawns).
	  2. Pick a character inside that rarity using each character's SpawnWeight
	     (relative to the other characters of the same rarity; independent of rarity).

	MONEY
	  Luau numbers are 64-bit floats: exact to ~9 quadrillion and representable
	  up to ~1e308, so prices/income well past trillions are fine. Always display
	  them with Constants.FormatNumber (1K, 1M, 1B, 1T, 1Qa, ...).

	MUTATIONS (future)
	  Every owned character stores an optional Mutation id. Income is
	  Characters.GetIncome(id, mutation) = base income * MUTATIONS[mutation].Multiplier,
	  so mutations can be switched on later without touching the economy code.
]]

local Characters = {}

local C = Color3.fromRGB

-- ----------------------------------------------------------------------
-- RARITIES (order = rank). Sound ids are placeholders using sounds that ship
-- with every Roblox client; swap in your own uploaded/licensed sounds.
-- ----------------------------------------------------------------------
Characters.RARITIES = {
	{
		Id = "Common", DisplayName = "COMMON", Odds = 70,
		Color = C(200, 202, 208), Glow = C(150, 155, 165),
		SpawnSound = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.25, Pitch = 1.2 },
		PurchaseSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Pitch = 1.1 },
		Particles = 8, Outline = false, Aura = 0, Light = 0,
		Announce = nil, -- nil | "Chat" | "Banner" | "Event"
		TagScale = 1,
	},
	{
		Id = "Uncommon", DisplayName = "UNCOMMON", Odds = 22,
		Color = C(86, 214, 112), Glow = C(60, 200, 90),
		SpawnSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.3 },
		PurchaseSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.25 },
		Particles = 14, Outline = false, Aura = 0, Light = 0,
		TagScale = 1.05,
	},
	{
		Id = "Rare", DisplayName = "RARE", Odds = 6,
		Color = C(72, 156, 255), Glow = C(50, 130, 255),
		SpawnSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1 },
		PurchaseSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 0.9 },
		Particles = 24, Outline = true, Aura = 0, Light = 0,
		TagScale = 1.1,
	},
	{
		Id = "Epic", DisplayName = "EPIC", Odds = 1.6,
		Color = C(182, 96, 255), Glow = C(160, 70, 255),
		SpawnSound = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.6, Pitch = 0.9 },
		PurchaseSound = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 0.75 },
		Particles = 40, Outline = true, Aura = 3, Light = 0.8,
		Gradient = { C(210, 140, 255), C(140, 60, 255) },
		TagScale = 1.18,
	},
	{
		Id = "Legendary", DisplayName = "LEGENDARY", Odds = 0.32,
		Color = C(255, 176, 46), Glow = C(255, 150, 20),
		SpawnSound = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, Pitch = 0.7 },
		PurchaseSound = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.8, Pitch = 0.7 },
		Particles = 70, Outline = true, Aura = 8, Light = 1.4,
		Gradient = { C(255, 230, 120), C(255, 130, 20) },
		Announce = "Chat", ConveyorFlash = 4,
		TagScale = 1.28,
	},
	{
		Id = "Mythic", DisplayName = "MYTHIC", Odds = 0.075,
		Color = C(255, 56, 120), Glow = C(255, 30, 110),
		SpawnSound = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 1, Pitch = 0.45 },
		PurchaseSound = { Id = "rbxasset://sounds/unsheath.wav", Volume = 1, Pitch = 0.5 },
		Particles = 110, Outline = true, Aura = 16, Light = 2,
		Gradient = { C(255, 120, 200), C(255, 40, 80), C(170, 60, 255) },
		Announce = "Banner", ConveyorFlash = 10, ConveyorColor = C(255, 40, 110),
		TagScale = 1.4,
	},
	{
		Id = "GOAT", DisplayName = "G.O.A.T.", Odds = 0.005,
		Color = C(255, 214, 64), Glow = C(255, 200, 40),
		SpawnSound = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 1, Pitch = 0.3 },
		PurchaseSound = { Id = "rbxasset://sounds/unsheath.wav", Volume = 1, Pitch = 0.35 },
		Particles = 180, Outline = true, Aura = 28, Light = 3,
		Gradient = { C(255, 250, 200), C(255, 200, 40), C(255, 150, 0) },
		Announce = "Event", ConveyorFlash = 14, ConveyorColor = C(255, 200, 40),
		TagScale = 1.6,
	},
}

-- ----------------------------------------------------------------------
-- MUTATIONS (structure only — the mutation economy isn't live yet)
-- ----------------------------------------------------------------------
Characters.MUTATIONS = {
	None = { DisplayName = "", Multiplier = 1 },
	-- Gold = { DisplayName = "GOLD", Multiplier = 1.5, Color = C(255, 210, 60) },
	-- Diamond = { DisplayName = "DIAMOND", Multiplier = 2, Color = C(150, 230, 255) },
	-- Radioactive = { DisplayName = "RADIOACTIVE", Multiplier = 3, Color = C(120, 255, 60) },
	-- Galaxy = { DisplayName = "GALAXY", Multiplier = 5, Color = C(140, 80, 255) },
	-- Secret = { DisplayName = "SECRET", Multiplier = 10, Color = C(20, 20, 20) },
}

-- ----------------------------------------------------------------------
-- Look vocabulary (built by ServerScriptService.CharacterLooks):
--   Skin        Color3
--   Hair        { Style, Color }  Style: Fringe Shaggy Short Curly Wavy Fluffy Styled
--               Pompadour Floppy LongCurly SweptBack Spiky Buzz Tied Bald
--   Beard       nil | "Stubble" | "Full" | "Large";   Mustache = true
--   Top         { Style, Color }  Style: Tee Oversized Tank Stringer Hoodie SleevelessHoodie Sleeveless
--   Bottom      { Style, Color }  Style: Joggers Sweatpants Shorts LongShorts PosingShorts FlowingPants
--   Socks       Color3 (high socks, shows with shorts)
--   Shoes       Color3
--   Props       { "Duffel" | "WaterJug" | "Clipboard" | "Tripod" | "WristStraps" | "WristWraps" | "Cap" }
--   CapColor    Color3 (when Props has "Cap")
--   Build       { Height, Width, Depth, Shoulders, Arms, Forearms, Chest, Traps, Legs }  (0 = normal)
-- Special:
--   Glow = true            soft "perfect gym lighting" light
--   Chart = true           floating progress chart now and then
--   IdleSpeed = n          energetic idle
--   Emote = "Point"        favorite belt emote
--   Poses = { ... }        belt posing idles: DoubleBiceps Vacuum MostMuscular LatSpread
--   SpawnFx = "Cinematic" | "Milestone" | "GoldSpotlight" | "HeavyLanding" | "GoldenEra"
--   Tags = { "Meta", "Value", "Collector", "Flex", "Jackpot", ... } (for UI / future filters)
-- ----------------------------------------------------------------------

-- palette shorthands
local SKIN = {
	Fair = C(246, 214, 186), Light = C(234, 190, 152), Tan = C(214, 164, 118),
	Olive = C(196, 146, 100), Brown = C(150, 100, 64), Dark = C(104, 68, 44),
}
local HAIR = {
	Brown = C(96, 64, 40), DarkBrown = C(56, 38, 26), Black = C(24, 22, 22), Blond = C(226, 198, 124),
	Gray = C(168, 168, 170), Sandy = C(176, 136, 84), Chestnut = C(120, 78, 46),
}
local WHITE, BLACK = C(236, 236, 238), C(24, 24, 27)

Characters.LIST = {
	-- ================================ COMMON ================================
	{
		Name = "JoeFlexer", DisplayName = "Joe Flexer", InspiredBy = "Joe Fazer",
		Rarity = "Common", Price = 75, IncomePerSecond = 1, SpawnWeight = 40, ModelName = "JoeFlexer",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Fringe", Color = HAIR.Brown },
			Top = { Style = "Tee", Color = BLACK }, Bottom = { Style = "Joggers", Color = C(118, 118, 124) },
			Shoes = WHITE, Props = { "Duffel" }, Build = { Width = 0.95 } },
		Tags = { "Starter" },
	},
	{
		Name = "BrownieBulk", DisplayName = "Brownie Bulk", InspiredBy = "Browney",
		Rarity = "Common", Price = 325, IncomePerSecond = 5, SpawnWeight = 28, ModelName = "BrownieBulk",
		Look = { Skin = SKIN.Light, Hair = { Style = "Shaggy", Color = HAIR.Chestnut },
			Top = { Style = "Hoodie", Color = C(64, 74, 96) }, Bottom = { Style = "Shorts", Color = BLACK },
			Socks = WHITE, Shoes = C(52, 52, 58), Build = { Width = 1.02, Shoulders = 0.1 } },
		IdleSpeed = 1.25,
	},
	{
		Name = "SeanNaliftanyj", DisplayName = "Sean Naliftanyj", InspiredBy = "Sean Nalewanyj",
		Rarity = "Common", Price = 1100, IncomePerSecond = 18, SpawnWeight = 18, ModelName = "SeanNaliftanyj",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Short", Color = HAIR.DarkBrown },
			Top = { Style = "Tee", Color = C(72, 82, 98) }, Bottom = { Style = "Shorts", Color = C(36, 36, 42) },
			Shoes = C(70, 70, 76), Build = { Arms = 0.1 } },
	},
	{
		Name = "OmarIswole", DisplayName = "Omar Iswole", InspiredBy = "Omar Isuf",
		Rarity = "Common", Price = 4250, IncomePerSecond = 55, SpawnWeight = 10, ModelName = "OmarIswole",
		Look = { Skin = SKIN.Olive, Hair = { Style = "Curly", Color = HAIR.Black }, Beard = "Full",
			Top = { Style = "Tee", Color = C(40, 40, 48) }, Bottom = { Style = "Joggers", Color = C(52, 52, 58) },
			Shoes = C(40, 40, 44), Props = { "WristStraps" },
			Build = { Width = 1.08, Depth = 1.08, Chest = 0.3, Arms = 0.25, Shoulders = 0.2 } },
	},
	{
		Name = "ZacPumperna", DisplayName = "Zac Pumperna", InspiredBy = "Zac Perna",
		Rarity = "Common", Price = 13500, IncomePerSecond = 130, SpawnWeight = 4, ModelName = "ZacPumperna",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Wavy", Color = HAIR.Sandy },
			Top = { Style = "Sleeveless", Color = C(196, 198, 204) }, Bottom = { Style = "Shorts", Color = C(40, 62, 96) },
			Socks = WHITE, Shoes = WHITE, Build = { Height = 1.08, Shoulders = 0.3, Arms = 0.2 } },
		Tags = { "BestCommon" },
	},

	-- =============================== UNCOMMON ===============================
	{
		Name = "WillTension", DisplayName = "Will Tension", InspiredBy = "Will Tennyson",
		Rarity = "Uncommon", Price = 28000, IncomePerSecond = 240, SpawnWeight = 30, ModelName = "WillTension",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Curly", Color = HAIR.Brown },
			Top = { Style = "Oversized", Color = C(124, 144, 166) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = C(214, 214, 218), Build = { Arms = 0.15 } },
		Emote = "Cheer",
	},
	{
		Name = "AlexEubanked", DisplayName = "Alex Eubanked", InspiredBy = "Alex Eubank",
		Rarity = "Uncommon", Price = 72000, IncomePerSecond = 650, SpawnWeight = 22, ModelName = "AlexEubanked",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Fluffy", Color = HAIR.Chestnut },
			Top = { Style = "Stringer", Color = BLACK }, Bottom = { Style = "Joggers", Color = C(42, 42, 48) },
			Shoes = WHITE, Build = { Shoulders = 0.25, Arms = 0.15 } },
		Glow = true,
	},
	{
		Name = "JesseGainsWest", DisplayName = "Jesse Gains West", InspiredBy = "Jesse James West",
		Rarity = "Uncommon", Price = 190000, IncomePerSecond = 1400, SpawnWeight = 18, ModelName = "JesseGainsWest",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Styled", Color = HAIR.Brown },
			Top = { Style = "Oversized", Color = C(232, 232, 234) }, Bottom = { Style = "Shorts", Color = C(40, 40, 46) },
			Shoes = WHITE, Props = { "Tripod" }, Build = { Shoulders = 0.2, Arms = 0.2 } },
		IdleSpeed = 1.6, Emote = "Dance",
	},
	{
		Name = "LexxLarge", DisplayName = "Lexx Large", InspiredBy = "Lexx Little",
		Rarity = "Uncommon", Price = 390000, IncomePerSecond = 4000, SpawnWeight = 12, ModelName = "LexxLarge",
		Look = { Skin = SKIN.Light, Hair = { Style = "Fluffy", Color = HAIR.Sandy },
			Top = { Style = "Stringer", Color = C(206, 206, 212) }, Bottom = { Style = "Joggers", Color = C(30, 30, 34) },
			Shoes = WHITE, Build = { Shoulders = 0.6, Arms = 0.25 } },
		Tags = { "Value" },
	},
	{
		Name = "MattDoesGains", DisplayName = "MattDoesGains", InspiredBy = "MattDoesFitness",
		Rarity = "Uncommon", Price = 1.25e6, IncomePerSecond = 8500, SpawnWeight = 12, ModelName = "MattDoesGains",
		Look = { Skin = SKIN.Light, Hair = { Style = "Short", Color = HAIR.Brown }, Beard = "Full",
			Top = { Style = "Oversized", Color = C(84, 112, 84) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = C(60, 60, 66), Build = { Width = 1.12, Depth = 1.1, Chest = 0.3, Arms = 0.3 } },
		Emote = "Dance",
	},
	{
		Name = "ChristianGainzman", DisplayName = "Christian Gainzman", InspiredBy = "Christian Guzman",
		Rarity = "Uncommon", Price = 2.8e6, IncomePerSecond = 16000, SpawnWeight = 9, ModelName = "ChristianGainzman",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Styled", Color = HAIR.Black },
			Top = { Style = "Tee", Color = C(22, 22, 26) }, Bottom = { Style = "Joggers", Color = C(46, 46, 52) },
			Shoes = WHITE, Build = { Shoulders = 0.3, Chest = 0.25, Arms = 0.25 } },
	},
	{
		Name = "SamSwolek", DisplayName = "Sam Swolek", InspiredBy = "Sam Sulek",
		Rarity = "Uncommon", Price = 7.5e6, IncomePerSecond = 55000, SpawnWeight = 10, ModelName = "SamSwolek",
		Look = { Skin = SKIN.Light, Hair = { Style = "Shaggy", Color = HAIR.Brown },
			Top = { Style = "Oversized", Color = C(46, 46, 50) }, Bottom = { Style = "Sweatpants", Color = C(124, 124, 130) },
			Shoes = C(60, 60, 62), Props = { "Cap", "WaterJug" }, CapColor = C(30, 30, 34),
			Build = { Width = 1.15, Depth = 1.12, Shoulders = 0.7, Traps = 0.7, Arms = 0.35 } },
		Tags = { "Jackpot", "Meta" },
	},

	-- ================================= RARE =================================
	{
		Name = "JeffRippedard", DisplayName = "Jeff Rippedard", InspiredBy = "Jeff Nippard",
		Rarity = "Rare", Price = 18e6, IncomePerSecond = 95000, SpawnWeight = 30, ModelName = "JeffRippedard",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Short", Color = HAIR.Brown },
			Top = { Style = "Tee", Color = C(62, 92, 142) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = C(64, 64, 70), Build = { Height = 0.96, Width = 1.05, Arms = 0.25, Chest = 0.2 } },
		Chart = true,
	},
	{
		Name = "DrMikeGains", DisplayName = "Dr. Mike Gains", InspiredBy = "Mike Israetel",
		Rarity = "Rare", Price = 42e6, IncomePerSecond = 250000, SpawnWeight = 26, ModelName = "DrMikeGains",
		Look = { Skin = SKIN.Light, Hair = { Style = "Bald", Color = HAIR.DarkBrown }, Beard = "Full",
			Top = { Style = "Tee", Color = C(32, 32, 36) }, Bottom = { Style = "Joggers", Color = BLACK },
			Shoes = C(40, 40, 44), Props = { "Clipboard" },
			Build = { Height = 0.96, Width = 1.15, Depth = 1.15, Chest = 0.35, Arms = 0.3 } },
	},
	{
		Name = "DavidLifted", DisplayName = "David Lifted", InspiredBy = "David Laid",
		Rarity = "Rare", Price = 95e6, IncomePerSecond = 900000, SpawnWeight = 9, ModelName = "DavidLifted",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Floppy", Color = HAIR.Black },
			Top = { Style = "Tank", Color = BLACK }, Bottom = { Style = "Joggers", Color = C(42, 42, 48) },
			Shoes = C(36, 36, 40), Build = { Height = 1.12, Shoulders = 0.35, Arms = 0.25 } },
		SpawnFx = "Cinematic", Tags = { "Meta" },
	},
	{
		Name = "JoeySwollen", DisplayName = "Joey Swollen", InspiredBy = "Joey Swoll",
		Rarity = "Rare", Price = 210e6, IncomePerSecond = 1.45e6, SpawnWeight = 16, ModelName = "JoeySwollen",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Short", Color = HAIR.Black }, Beard = "Full",
			Top = { Style = "Tee", Color = BLACK }, Bottom = { Style = "Joggers", Color = BLACK },
			Shoes = C(36, 36, 40), Build = { Width = 1.15, Depth = 1.15, Chest = 0.45, Arms = 0.35, Shoulders = 0.3 } },
		Emote = "Point",
	},
	{
		Name = "NoelDiesel", DisplayName = "Noel Diesel", InspiredBy = "Noel Deyzel",
		Rarity = "Rare", Price = 425e6, IncomePerSecond = 4.5e6, SpawnWeight = 12, ModelName = "NoelDiesel",
		Look = { Skin = SKIN.Light, Hair = { Style = "Buzz", Color = HAIR.Brown }, Beard = "Large",
			Top = { Style = "SleevelessHoodie", Color = C(40, 40, 46) }, Bottom = { Style = "Joggers", Color = C(30, 30, 34) },
			Shoes = BLACK, Build = { Height = 1.12, Width = 1.3, Depth = 1.2, Shoulders = 0.8, Chest = 0.5, Arms = 0.55, Traps = 0.6 } },
	},
	{
		Name = "BradleyBarbell", DisplayName = "Bradley Barbell", InspiredBy = "Bradley Martyn",
		Rarity = "Rare", Price = 1.2e9, IncomePerSecond = 7.5e6, SpawnWeight = 10, ModelName = "BradleyBarbell",
		Look = { Skin = SKIN.Light, Hair = { Style = "Short", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(30, 30, 34) }, Bottom = { Style = "LongShorts", Color = C(42, 42, 48) },
			Shoes = BLACK, Build = { Width = 1.22, Depth = 1.15, Chest = 0.55, Arms = 0.75, Shoulders = 0.55 } },
	},
	{
		Name = "MikeOGain", DisplayName = "Mike O'Gain", InspiredBy = "Mike O'Hearn",
		Rarity = "Rare", Price = 2.75e9, IncomePerSecond = 22e6, SpawnWeight = 6, ModelName = "MikeOGain",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Pompadour", Color = HAIR.Black },
			Top = { Style = "Tee", Color = C(0, 150, 255) }, Bottom = { Style = "Joggers", Color = C(30, 30, 40) },
			Shoes = WHITE, Build = { Height = 1.08, Width = 1.2, Shoulders = 0.65, Chest = 0.6, Arms = 0.55 } },
		Poses = { "DoubleBiceps", "LatSpread" }, Tags = { "Flex" },
	},

	-- ================================= EPIC =================================
	{
		Name = "GregHugecette", DisplayName = "Greg Hugecette", InspiredBy = "Greg Doucette",
		Rarity = "Epic", Price = 6e9, IncomePerSecond = 35e6, SpawnWeight = 30, ModelName = "GregHugecette",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Short", Color = HAIR.Gray },
			Top = { Style = "Tee", Color = C(40, 92, 160) }, Bottom = { Style = "Joggers", Color = BLACK },
			Shoes = WHITE, Build = { Width = 1.1, Arms = 0.35, Chest = 0.3 } },
		Emote = "Point",
	},
	{
		Name = "RamonDyno", DisplayName = "Ramon Dyno", InspiredBy = "Ramon Dino",
		Rarity = "Epic", Price = 11e9, IncomePerSecond = 85e6, SpawnWeight = 22, ModelName = "RamonDyno",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Styled", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(28, 28, 32) }, Bottom = { Style = "PosingShorts", Color = C(24, 64, 170) },
			Shoes = BLACK, Build = { Shoulders = 0.85, Arms = 0.55, Chest = 0.45, Legs = 0.3 } },
		Poses = { "DoubleBiceps", "Vacuum" },
	},
	{
		Name = "AndrewJackedUp", DisplayName = "Andrew Jacked Up", InspiredBy = "Andrew Jacked",
		Rarity = "Epic", Price = 27e9, IncomePerSecond = 145e6, SpawnWeight = 16, ModelName = "AndrewJackedUp",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Buzz", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(26, 26, 30) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Build = { Height = 1.22, Shoulders = 0.95, Arms = 0.55, Chest = 0.4 } },
		Poses = { "LatSpread" },
	},
	{
		Name = "UrsCalvesinski", DisplayName = "Urs Calvesinski", InspiredBy = "Urs Kalecinski",
		Rarity = "Epic", Price = 55e9, IncomePerSecond = 310e6, SpawnWeight = 13, ModelName = "UrsCalvesinski",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Styled", Color = HAIR.Blond },
			Top = { Style = "Tank", Color = C(232, 232, 236) }, Bottom = { Style = "PosingShorts", Color = C(30, 30, 34) },
			Shoes = BLACK, Build = { Shoulders = 0.45, Arms = 0.4, Legs = 1.2 } },
	},
	{
		Name = "EddieHaul", DisplayName = "Eddie Haul", InspiredBy = "Eddie Hall",
		Rarity = "Epic", Price = 95e9, IncomePerSecond = 450e6, SpawnWeight = 10, ModelName = "EddieHaul",
		Look = { Skin = SKIN.Light, Hair = { Style = "Bald", Color = HAIR.Brown }, Beard = "Full",
			Top = { Style = "Oversized", Color = C(62, 62, 68) }, Bottom = { Style = "Shorts", Color = C(30, 30, 36) },
			Shoes = BLACK, Build = { Width = 1.35, Depth = 1.45, Chest = 0.8, Arms = 0.5, Traps = 0.5 } },
	},
	{
		Name = "NickHulker", DisplayName = "Nick Hulker", InspiredBy = "Nick Walker",
		Rarity = "Epic", Price = 175e9, IncomePerSecond = 800e6, SpawnWeight = 6, ModelName = "NickHulker",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Buzz", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(20, 20, 24) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Build = { Height = 1.08, Width = 1.35, Depth = 1.25, Shoulders = 1.1, Arms = 1.1, Chest = 0.85, Traps = 0.9 } },
		Poses = { "MostMuscular" },
	},
	{
		Name = "HalfthorBoulderson", DisplayName = "Halfthor Boulderson", InspiredBy = "Hafthor Bjornsson",
		Rarity = "Epic", Price = 310e9, IncomePerSecond = 1.05e9, SpawnWeight = 3, ModelName = "HalfthorBoulderson",
		Look = { Skin = SKIN.Fair, Hair = { Style = "Tied", Color = HAIR.Brown }, Beard = "Full",
			Top = { Style = "Tee", Color = C(72, 72, 78) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Build = { Height = 1.38, Width = 1.3, Depth = 1.3, Chest = 0.65, Traps = 0.7, Arms = 0.5 } },
		SpawnFx = "Milestone", Tags = { "FirstBillion" },
	},

	-- =============================== LEGENDARY ==============================
	{
		Name = "BigRammy", DisplayName = "Big Rammy", InspiredBy = "Big Ramy",
		Rarity = "Legendary", Price = 480e9, IncomePerSecond = 1.15e9, SpawnWeight = 24, ModelName = "BigRammy",
		Look = { Skin = SKIN.Brown, Hair = { Style = "Bald", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(30, 30, 34) }, Bottom = { Style = "Shorts", Color = C(30, 30, 36) },
			Shoes = BLACK, Build = { Width = 1.38, Depth = 1.3, Shoulders = 1.1, Arms = 0.95, Chest = 0.7 } },
		Tags = { "Collector", "PoorValue" },
	},
	{
		Name = "DexterJackedson", DisplayName = "Dexter Jackedson", InspiredBy = "Dexter Jackson",
		Rarity = "Legendary", Price = 625e9, IncomePerSecond = 1.35e9, SpawnWeight = 18, ModelName = "DexterJackedson",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Buzz", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(238, 238, 240) }, Bottom = { Style = "PosingShorts", Color = BLACK },
			Shoes = BLACK, Build = { Shoulders = 0.65, Arms = 0.55, Chest = 0.55, Legs = 0.4 } },
		Poses = { "LatSpread", "DoubleBiceps" },
	},
	{
		Name = "LarrySteels", DisplayName = "Larry Steels", InspiredBy = "Larry Wheels",
		Rarity = "Legendary", Price = 825e9, IncomePerSecond = 1.75e9, SpawnWeight = 12, ModelName = "LarrySteels",
		Look = { Skin = SKIN.Tan, Hair = { Style = "Short", Color = HAIR.Black }, Beard = "Stubble",
			Top = { Style = "Oversized", Color = C(52, 52, 58) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Props = { "WristWraps" },
			Build = { Width = 1.25, Shoulders = 0.75, Forearms = 1.1, Arms = 0.6 } },
		Tags = { "Value", "Meta" },
	},
	{
		Name = "KevinLeSwole", DisplayName = "Kevin LeSwole", InspiredBy = "Kevin Levrone",
		Rarity = "Legendary", Price = 1.05e12, IncomePerSecond = 1.9e9, SpawnWeight = 16, ModelName = "KevinLeSwole",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Buzz", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(224, 224, 228) }, Bottom = { Style = "Shorts", Color = C(30, 30, 40) },
			Shoes = BLACK, Build = { Width = 1.2, Chest = 1.0, Shoulders = 0.75, Arms = 0.65 } },
		Poses = { "MostMuscular" },
	},
	{
		Name = "KaiGains", DisplayName = "Kai Gains", InspiredBy = "Kai Greene",
		Rarity = "Legendary", Price = 1.45e12, IncomePerSecond = 2.2e9, SpawnWeight = 12, ModelName = "KaiGains",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Bald", Color = HAIR.Black }, Beard = "Full",
			Top = { Style = "Tank", Color = C(30, 30, 34) }, Bottom = { Style = "FlowingPants", Color = C(64, 42, 96) },
			Shoes = BLACK, Build = { Width = 1.3, Shoulders = 0.95, Arms = 0.85, Chest = 0.75 } },
		Poses = { "DoubleBiceps", "MostMuscular", "LatSpread", "Vacuum" }, Tags = { "Showman" },
	},
	{
		Name = "DorianWeights", DisplayName = "Dorian Weights", InspiredBy = "Dorian Yates",
		Rarity = "Legendary", Price = 1.8e12, IncomePerSecond = 2.05e9, SpawnWeight = 12, ModelName = "DorianWeights",
		Look = { Skin = SKIN.Light, Hair = { Style = "Buzz", Color = HAIR.DarkBrown },
			Top = { Style = "Tee", Color = C(20, 20, 22) }, Bottom = { Style = "Joggers", Color = C(24, 24, 28) },
			Shoes = BLACK, Build = { Width = 1.3, Depth = 1.3, Traps = 1.1, Chest = 0.65, Arms = 0.65 } },
		Tags = { "Collector", "PoorValue" },
	},
	{
		Name = "PhilBeef", DisplayName = "Phil Beef", InspiredBy = "Phil Heath",
		Rarity = "Legendary", Price = 2.4e12, IncomePerSecond = 2.45e9, SpawnWeight = 8, ModelName = "PhilBeef",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Bald", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(232, 232, 236) }, Bottom = { Style = "PosingShorts", Color = BLACK },
			Shoes = BLACK, Build = { Shoulders = 1.1, Arms = 0.95, Chest = 0.65, Legs = 0.4 } },
		Poses = { "MostMuscular", "DoubleBiceps" },
	},

	-- ================================ MYTHIC ================================
	{
		Name = "TomSquatz", DisplayName = "Tom Squatz", InspiredBy = "Tom Platz",
		Rarity = "Mythic", Price = 3.25e12, IncomePerSecond = 2.55e9, SpawnWeight = 34, ModelName = "TomSquatz",
		Look = { Skin = SKIN.Fair, Hair = { Style = "LongCurly", Color = HAIR.Chestnut },
			Top = { Style = "Tank", Color = C(200, 40, 44) }, Bottom = { Style = "PosingShorts", Color = C(24, 44, 160) },
			Shoes = WHITE, Build = { Shoulders = 0.3, Arms = 0.25, Legs = 2.2 } },
		Tags = { "Legs" },
	},
	{
		Name = "FlexWheelie", DisplayName = "Flex Wheelie", InspiredBy = "Flex Wheeler",
		Rarity = "Mythic", Price = 4.5e12, IncomePerSecond = 2.8e9, SpawnWeight = 28, ModelName = "FlexWheelie",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Short", Color = HAIR.Black },
			Top = { Style = "Stringer", Color = C(30, 30, 34) }, Bottom = { Style = "PosingShorts", Color = C(160, 20, 44) },
			Shoes = BLACK, Build = { Shoulders = 0.75, Arms = 0.6, Chest = 0.45, Legs = 0.45 } },
		Poses = { "LatSpread", "DoubleBiceps" },
	},
	{
		Name = "FrankGain", DisplayName = "Frank Gain", InspiredBy = "Frank Zane",
		Rarity = "Mythic", Price = 6.25e12, IncomePerSecond = 2.7e9, SpawnWeight = 26, ModelName = "FrankGain",
		Look = { Skin = SKIN.Tan, Hair = { Style = "SweptBack", Color = HAIR.Chestnut },
			Top = { Style = "Stringer", Color = C(222, 200, 122) }, Bottom = { Style = "PosingShorts", Color = C(22, 22, 26) },
			Shoes = BLACK, Build = { Height = 1.05, Shoulders = 0.6, Arms = 0.35 } },
		Poses = { "Vacuum", "DoubleBiceps" }, Tags = { "Collector", "Prestige" },
	},
	{
		Name = "CBulk", DisplayName = "C-Bulk", InspiredBy = "Chris Bumstead",
		Rarity = "Mythic", Price = 8.5e12, IncomePerSecond = 3.05e9, SpawnWeight = 12, ModelName = "CBulk",
		Look = { Skin = SKIN.Fair, Hair = { Style = "SweptBack", Color = HAIR.Brown }, Mustache = true,
			Top = { Style = "Tank", Color = C(26, 26, 30) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Build = { Width = 1.25, Shoulders = 1.05, Arms = 0.75, Chest = 0.55 } },
		Poses = { "Vacuum" }, Tags = { "Meta", "MostWanted" },
	},

	-- ================================ G.O.A.T. ==============================
	{
		Name = "JayCuttler", DisplayName = "Jay Cuttler", InspiredBy = "Jay Cutler",
		Rarity = "GOAT", Price = 12e12, IncomePerSecond = 3.1e9, SpawnWeight = 65, ModelName = "JayCuttler",
		Look = { Skin = SKIN.Light, Hair = { Style = "Spiky", Color = HAIR.Blond },
			Top = { Style = "Tank", Color = C(40, 40, 46) }, Bottom = { Style = "Shorts", Color = C(30, 30, 40) },
			Shoes = BLACK, Build = { Width = 1.35, Depth = 1.3, Shoulders = 1.05, Chest = 0.8, Arms = 0.8, Legs = 1.0 } },
		SpawnFx = "GoldSpotlight", Poses = { "LatSpread", "DoubleBiceps" },
	},
	{
		Name = "RonnieCurlman", DisplayName = "Ronnie Curlman", InspiredBy = "Ronnie Coleman",
		Rarity = "GOAT", Price = 20e12, IncomePerSecond = 3.35e9, SpawnWeight = 27, ModelName = "RonnieCurlman",
		Look = { Skin = SKIN.Dark, Hair = { Style = "Bald", Color = HAIR.Black },
			Top = { Style = "Tank", Color = C(20, 20, 24) }, Bottom = { Style = "Shorts", Color = BLACK },
			Shoes = BLACK, Build = { Height = 1.18, Width = 1.5, Depth = 1.45, Shoulders = 1.25, Arms = 1.25, Chest = 1.0, Traps = 1.0, Legs = 1.2 } },
		SpawnFx = "HeavyLanding", Poses = { "MostMuscular", "DoubleBiceps" }, Tags = { "Biggest" },
	},
	{
		Name = "ArnieIronberg", DisplayName = "Arnie Ironberg", InspiredBy = "Arnold Schwarzenegger",
		Rarity = "GOAT", Price = 35e12, IncomePerSecond = 3.5e9, SpawnWeight = 8, ModelName = "ArnieIronberg",
		Look = { Skin = SKIN.Tan, Hair = { Style = "SweptBack", Color = HAIR.DarkBrown },
			Top = { Style = "Tank", Color = C(184, 152, 96) }, Bottom = { Style = "Shorts", Color = C(30, 30, 40) },
			Shoes = C(60, 44, 32), Build = { Height = 1.1, Width = 1.3, Chest = 1.2, Arms = 1.0, Shoulders = 0.85 } },
		SpawnFx = "GoldenEra", Poses = { "DoubleBiceps", "MostMuscular" }, Tags = { "Rarest", "Prestige" },
	},
}

-- ----------------------------------------------------------------------
-- Lookups & helpers
-- ----------------------------------------------------------------------
Characters.BY_NAME = {}
Characters.RARITY_BY_ID = {}
Characters.RARITY_INDEX = {}
Characters.BY_RARITY = {}

for i, r in ipairs(Characters.RARITIES) do
	Characters.RARITY_BY_ID[r.Id] = r
	Characters.RARITY_INDEX[r.Id] = i
	r.Index = i
	Characters.BY_RARITY[r.Id] = {}
end
for _, c in ipairs(Characters.LIST) do
	assert(Characters.RARITY_BY_ID[c.Rarity], "Unknown rarity " .. tostring(c.Rarity) .. " for " .. c.Name)
	assert(not Characters.BY_NAME[c.Name], "Duplicate character " .. c.Name)
	Characters.BY_NAME[c.Name] = c
	table.insert(Characters.BY_RARITY[c.Rarity], c)
end

function Characters.Get(name)
	return Characters.BY_NAME[name]
end

function Characters.GetRarity(rarityId)
	return Characters.RARITY_BY_ID[rarityId]
end

function Characters.RarityIndex(rarityId)
	return Characters.RARITY_INDEX[rarityId] or 1
end

-- Income for an owned character (mutation-aware).
function Characters.GetIncome(name, mutation)
	local c = Characters.BY_NAME[name]
	if not c then
		return 0
	end
	local m = Characters.MUTATIONS[mutation or "None"] or Characters.MUTATIONS.None
	return c.IncomePerSecond * m.Multiplier
end

local function weightedPick(list, weightOf, rng)
	local total = 0
	for _, item in ipairs(list) do
		total += weightOf(item)
	end
	local roll = (rng and rng:NextNumber(0, total)) or (math.random() * total)
	local acc = 0
	for _, item in ipairs(list) do
		acc += weightOf(item)
		if roll <= acc then
			return item
		end
	end
	return list[#list]
end

-- Roll the next conveyor character: rarity by Odds, then character by SpawnWeight.
function Characters.Roll(rng)
	local candidates = {}
	for _, r in ipairs(Characters.RARITIES) do
		if #Characters.BY_RARITY[r.Id] > 0 then
			table.insert(candidates, r)
		end
	end
	local rarity = weightedPick(candidates, function(r)
		return r.Odds
	end, rng)
	return weightedPick(Characters.BY_RARITY[rarity.Id], function(c)
		return c.SpawnWeight
	end, rng)
end

-- Effective chance (0..1) of a character per conveyor spawn (for UI / balancing).
function Characters.EffectiveOdds(name)
	local c = Characters.BY_NAME[name]
	if not c then
		return 0
	end
	local r = Characters.RARITY_BY_ID[c.Rarity]
	local total = 0
	for _, other in ipairs(Characters.BY_RARITY[c.Rarity]) do
		total += other.SpawnWeight
	end
	return (r.Odds / 100) * (c.SpawnWeight / total)
end

-- For old saves: pick a stand-in character for a legacy rarity index.
function Characters.DefaultForRarityIndex(index)
	local r = Characters.RARITIES[math.clamp(index or 1, 1, #Characters.RARITIES)]
	return Characters.BY_RARITY[r.Id][1]
end

return Characters
