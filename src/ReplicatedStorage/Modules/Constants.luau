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
-- MAP  (compact linear map: 4 gyms on each side of a red-carpet conveyor)
-- ======================================================================
Constants.PLOT_COUNT = 8
Constants.FLOOR_COUNT = 3 -- every gym grows up to 3 stories
Constants.RACK_SLOT_MAX = 33 -- machines per gym (3 of each): 12 + 12 + 9 across the 3 floors

-- ======================================================================
-- SHARED CONVEYOR (runs down the middle of the map along +Z)
-- Start/end points come from the BeltStart / BeltEnd parts in the map.
-- ======================================================================
Constants.BELT = {
	SpawnInterval = 3.5, -- seconds between spawns (each one drops from the next chute in turn)
	MaxOnBelt = 20, -- cap on how many ride the belt at once
	Speed = 6, -- studs per second (the belt part's conveyor velocity)
	ClaimDistance = 11, -- ProximityPrompt activation range
	ClaimHold = 0.3, -- seconds to hold the prompt
	DroppedDespawn = 60, -- seconds a dropped, unowned influencer waits before leaving
}

-- ======================================================================
-- INFLUENCER NPCs (real R15 characters)
-- ======================================================================
Constants.NPC = {
	TravelSpeed = 16, -- once claimed they walk on their own straight to their machine
	FollowSpeed = 16, -- (legacy follow mode, unused by default)
	FollowGap = 5,
	SeatSpeed = 12,
	ReturnSpeed = 16, -- walking back to their gym after the front desk saves them
	TeleportIfFartherThan = 160,
	SeatTimeout = 20, -- seconds before a stuck influencer just hops onto the machine
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
-- CHARACTERS: every collectible (price, income, rarity, odds, look) lives in
-- ReplicatedStorage.Modules.Characters. Nothing character-related is here.
-- ======================================================================
Constants.STARTING_CASH = 100 -- enough to buy your first Common off the conveyor

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
Constants.EQUIPMENT_ORDER = { "Floors", "WorkoutGain", "DeskSpeed" }

Constants.EQUIPMENT = {
	Floors = {
		Name = "Gym Floors",
		Desc = "Build another story on your gym (more machines)",
		Values = { 12, 24, 33 }, -- machines available (floor 1, floors 1-2, floors 1-3)
		Costs = { 0, 7500, 45000 },
		Unit = " machines",
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
		Desc = "How fast your front desk worker chases stolen influencers",
		Values = { 18, 21, 24, 28, 34 },
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
Constants.NORMAL_WALKSPEED = 36 -- 2x the Roblox default feel for this map
Constants.CARRY_WALKSPEED = 36

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

-- Short money/number format: 950, 1.4K, 7.5M, 3.5B, 12T, 4.2Qa ... (works far past trillions)
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid" }
function Constants.FormatNumber(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		if n == math.floor(n) or n >= 100 then
			return sign .. tostring(math.floor(n))
		end
		return sign .. (string.format("%.1f", n):gsub("%.0$", ""))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	if scaled >= 999.995 and tier < #SUFFIXES - 1 then
		tier += 1
		scaled = n / 10 ^ (tier * 3)
	end
	local text
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end
	text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
	return sign .. text .. SUFFIXES[tier + 1]
end

return Constants
