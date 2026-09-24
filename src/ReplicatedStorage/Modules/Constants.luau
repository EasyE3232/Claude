--[[
	GYM WARS — Constants
	Every tunable number and catalog in the game lives here.
	Change values in this file to rebalance without touching game logic.
]]

local Constants = {}

-- ======================================================================
-- SAVE DATA
-- ======================================================================
Constants.DATASTORE_NAME = "GymWars_v1"
Constants.AUTOSAVE_INTERVAL = 60 -- seconds

-- ======================================================================
-- MAP  (linear map: 5 gyms on each side of a long red-carpet conveyor)
-- ======================================================================
Constants.PLOT_COUNT = 10
Constants.RACK_SLOT_MAX = 12 -- equipment stations per gym (Station1..Station12)

-- ======================================================================
-- SHARED CONVEYOR (runs down the middle of the map along +Z)
-- Start/end points come from the BeltStart / BeltEnd parts in the map.
-- ======================================================================
Constants.BELT = {
	SpawnInterval = 4, -- seconds between spawns
	MaxOnBelt = 18, -- cap on how many ride the belt at once
	Speed = 7, -- studs per second (the belt part's conveyor velocity)
	ClaimDistance = 11, -- ProximityPrompt activation range
	ClaimHold = 0.3, -- seconds to hold the prompt
	DroppedDespawn = 60, -- seconds a dropped, unowned influencer waits before leaving
}

-- ======================================================================
-- INFLUENCER NPCs (real R15 characters)
-- ======================================================================
Constants.NPC = {
	FollowSpeed = 11, -- they walk WITH you, slower than you (NORMAL_WALKSPEED)
	FollowGap = 5, -- studs they trail behind you
	SeatSpeed = 9, -- walking pace from your door to their machine
	ReturnSpeed = 12, -- walking back to their gym after the front desk saves them
	TeleportIfFartherThan = 160, -- rubber-band if they get hopelessly separated
	SeatTimeout = 25, -- seconds before we just put them on the machine
	EmoteChance = 0.12, -- per second, while riding the belt
}

-- Optional: make an influencer wear a real Roblox avatar.
-- [Influencer name] = Roblox UserId (their avatar is loaded at spawn).
Constants.INFLUENCER_AVATARS = {
	-- ["Joey Swool"] = 123456789,
}

Constants.SKIN_TONES = {
	Color3.fromRGB(255, 219, 172),
	Color3.fromRGB(241, 194, 125),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(95, 58, 30),
}

-- ======================================================================
-- RARITIES  (Common -> Legendary). Income is Cash per second while placed.
-- Names are parody gym-bro archetypes. Rename freely.
-- ======================================================================
Constants.RARITIES = {
	{
		Name = "Common",
		Weight = 60,
		Income = 1,
		Color = Color3.fromRGB(154, 163, 176),
		Names = { "Edgar", "Tank Top Tyler", "Leg Day Larry", "One Set Sam" },
	},
	{
		Name = "Uncommon",
		Weight = 25,
		Income = 3,
		Color = Color3.fromRGB(79, 209, 124),
		Names = { "Preworkout Pete", "Bulk Season Brody", "Cardio Carl" },
	},
	{
		Name = "Rare",
		Weight = 10,
		Income = 10,
		Color = Color3.fromRGB(79, 157, 251),
		Names = { "Shredded Shane", "Deadlift Dante", "Protein Paul" },
	},
	{
		Name = "Epic",
		Weight = 4,
		Income = 30,
		Color = Color3.fromRGB(176, 107, 240),
		Names = { "The Pump God", "Macro Mike" },
	},
	{
		Name = "Legendary",
		Weight = 1,
		Income = 120,
		Color = Color3.fromRGB(244, 201, 58),
		Names = { "Joey Swool" },
	},
}

-- ======================================================================
-- WORKOUT (personal Strength — permanent, never reset)
-- ======================================================================
Constants.WORKOUT = {
	BaseGain = 1, -- strength per rep, multiplied by the WorkoutGain equipment value
	RepCooldown = 0.6, -- seconds between reps (divided by workout-speed boosters)
	PromptDistance = 8,
}

-- ======================================================================
-- CLOTHING  (Strength gates the RIGHT TO BUY. Cash is still required.)
-- Bonus is added to the income multiplier: total = 1 + sum(equipped bonuses)
-- ======================================================================
Constants.CLOTHING_SLOTS = { "Top", "Bottom", "Accessory" }

Constants.CLOTHING = {
	-- Top
	{ Id = "GrayTee", Name = "Gray Tee", Slot = "Top", Strength = 0, Price = 100, Bonus = 0.10 },
	{ Id = "TankTop", Name = "Tank Top", Slot = "Top", Strength = 50, Price = 500, Bonus = 0.25 },
	{ Id = "Stringer", Name = "Stringer", Slot = "Top", Strength = 200, Price = 2500, Bonus = 0.50 },
	{ Id = "PumpCover", Name = "Pump Cover", Slot = "Top", Strength = 600, Price = 10000, Bonus = 1.00 },
	-- Bottom
	{ Id = "GymShorts", Name = "Gym Shorts", Slot = "Bottom", Strength = 25, Price = 300, Bonus = 0.15 },
	{ Id = "Joggers", Name = "Joggers", Slot = "Bottom", Strength = 150, Price = 2000, Bonus = 0.40 },
	{ Id = "Tights", Name = "Compression Tights", Slot = "Bottom", Strength = 500, Price = 8000, Bonus = 0.80 },
	-- Accessory
	{ Id = "WristWraps", Name = "Wrist Wraps", Slot = "Accessory", Strength = 75, Price = 800, Bonus = 0.20 },
	{ Id = "LiftingBelt", Name = "Lifting Belt", Slot = "Accessory", Strength = 300, Price = 4000, Bonus = 0.60 },
	{ Id = "GoldChain", Name = "Gold Chain", Slot = "Accessory", Strength = 1000, Price = 25000, Bonus = 1.50 },
}

-- ======================================================================
-- EQUIPMENT  (permanent gym upgrades, Cash only, survive rebirth)
-- Level 1 is the starting level. Costs[n] is the price to go from level n-1 to n.
-- ======================================================================
Constants.EQUIPMENT_ORDER = { "RackSlots", "WorkoutGain", "DeskSpeed" }

Constants.EQUIPMENT = {
	RackSlots = {
		Name = "Rack Slots",
		Desc = "How many influencers your gym can hold",
		Values = { 4, 6, 8, 10, 12 },
		Costs = { 0, 1500, 6000, 20000, 60000 },
		Unit = " slots",
	},
	WorkoutGain = {
		Name = "Heavier Weights",
		Desc = "Strength gained per rep",
		Values = { 1, 2, 4, 8, 16 },
		Costs = { 0, 800, 3000, 12000, 40000 },
		Unit = "x per rep",
	},
	DeskSpeed = {
		Name = "Front Desk Speed",
		Desc = "How fast your front desk worker chases thieves",
		Values = { 16, 19, 22, 26, 32 },
		Costs = { 0, 1000, 4000, 15000, 50000 },
		Unit = " speed",
	},
}

-- ======================================================================
-- BOOSTERS  (temporary, Cash-purchased consumables)
-- Effect = "Income" multiplies Cash income; "WorkoutSpeed" multiplies rep speed.
-- Buying the same booster again while active refreshes its timer.
-- ======================================================================
Constants.BOOSTERS = {
	{ Id = "ProteinShake", Name = "Protein Shake", Price = 250, Effect = "Income", Multiplier = 1.5, Duration = 300, Desc = "x1.5 Cash for 5 min" },
	{ Id = "Creatine", Name = "Creatine", Price = 600, Effect = "WorkoutSpeed", Multiplier = 2, Duration = 600, Desc = "2x workout speed for 10 min" },
	{ Id = "Steroids", Name = "Steroids", Price = 2000, Effect = "Income", Multiplier = 3, Duration = 300, Desc = "x3 Cash for 5 min" },
}

-- ======================================================================
-- REBIRTH
-- threshold(n)  = BaseThreshold * ThresholdGrowth ^ n
-- multiplier(n) = 1 + MaxBonus * (1 - Curve ^ n)   -> tapers toward 1 + MaxBonus
-- ======================================================================
Constants.REBIRTH = {
	BaseThreshold = 10000,
	ThresholdGrowth = 2.0,
	MaxBonus = 9, -- soft cap of 10x total
	Curve = 0.93,
}

-- ======================================================================
-- DEFENSE (Front Desk Worker)
-- ======================================================================
Constants.DEFENSE = {
	CatchRadius = 4.5,
	StunSeconds = 2,
	ReturnHomeSpeed = 12,
}

-- ======================================================================
-- MOVEMENT
-- ======================================================================
Constants.NORMAL_WALKSPEED = 18
-- influencers now WALK behind you (at NPC.FollowSpeed) instead of being carried,
-- so escorting no longer slows you down
Constants.CARRY_WALKSPEED = 18

-- ======================================================================
-- GYM COLOR PRESETS (owner-selectable, cosmetic only). Saved as preset index.
-- ======================================================================
Constants.GYM_COLORS = {
	{ Name = "Slate", Wall = Color3.fromRGB(52, 58, 70), Accent = Color3.fromRGB(200, 205, 215) },
	{ Name = "Crimson", Wall = Color3.fromRGB(60, 24, 28), Accent = Color3.fromRGB(226, 81, 90) },
	{ Name = "Ice", Wall = Color3.fromRGB(22, 36, 52), Accent = Color3.fromRGB(79, 157, 251) },
	{ Name = "Void", Wall = Color3.fromRGB(36, 24, 50), Accent = Color3.fromRGB(176, 107, 240) },
	{ Name = "Teal", Wall = Color3.fromRGB(18, 48, 44), Accent = Color3.fromRGB(47, 207, 180) },
	{ Name = "Furnace", Wall = Color3.fromRGB(56, 32, 12), Accent = Color3.fromRGB(240, 152, 60) },
	{ Name = "Glow", Wall = Color3.fromRGB(56, 22, 42), Accent = Color3.fromRGB(240, 107, 176) },
	{ Name = "Gold", Wall = Color3.fromRGB(50, 42, 14), Accent = Color3.fromRGB(244, 201, 58) },
}

-- ======================================================================
-- HELPERS
-- ======================================================================
function Constants.RebirthThreshold(rebirths)
	return math.floor(Constants.REBIRTH.BaseThreshold * (Constants.REBIRTH.ThresholdGrowth ^ rebirths))
end

function Constants.RebirthMultiplier(rebirths)
	return 1 + Constants.REBIRTH.MaxBonus * (1 - (Constants.REBIRTH.Curve ^ rebirths))
end

function Constants.GetClothing(id)
	for _, item in ipairs(Constants.CLOTHING) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Constants.GetBooster(id)
	for _, item in ipairs(Constants.BOOSTERS) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Constants.GetRarity(index)
	return Constants.RARITIES[index]
end

-- Weighted random rarity index
function Constants.RollRarity(rng)
	local total = 0
	for _, r in ipairs(Constants.RARITIES) do
		total += r.Weight
	end
	local roll = (rng and rng:NextNumber(0, total)) or (math.random() * total)
	local acc = 0
	for i, r in ipairs(Constants.RARITIES) do
		acc += r.Weight
		if roll <= acc then
			return i
		end
	end
	return 1
end

function Constants.FormatNumber(n)
	n = math.floor(n)
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(n)
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		out = s:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return out
end

return Constants
