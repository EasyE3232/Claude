--[[
	EconomyService
	- Pays every plot owner once per second for the influencers on their rack.
	- Owns active boosters (timed buffs) and all multiplier math.

	income/sec = sum(placed influencer income)
	             * clothing multiplier   (1 + sum of equipped clothing bonuses)
	             * rebirth multiplier    (Constants.RebirthMultiplier)
	             * active Income boosters
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)

local EconomyService = {}

local activeBoosters = {} -- [userId] = { [boosterId] = expiresAt (os.time) }

-- ----------------------------------------------------------------------
-- Multipliers
-- ----------------------------------------------------------------------
function EconomyService.ClothingMultiplier(profile)
	local bonus = 0
	for _, id in pairs(profile.Equipped) do
		local item = Constants.GetClothing(id)
		if item and profile.OwnedClothing[id] then
			bonus += item.Bonus
		end
	end
	return 1 + bonus
end

function EconomyService.BoosterMultiplier(userId, effect)
	local mult = 1
	local list = activeBoosters[userId]
	if not list then
		return mult
	end
	local now = os.time()
	for id, expires in pairs(list) do
		if expires > now then
			local b = Constants.GetBooster(id)
			if b and b.Effect == effect then
				mult *= b.Multiplier
			end
		end
	end
	return mult
end

function EconomyService.IncomeMultiplier(player)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return 1
	end
	return EconomyService.ClothingMultiplier(profile)
		* Constants.RebirthMultiplier(profile.Rebirths)
		* EconomyService.BoosterMultiplier(player.UserId, "Income")
end

function EconomyService.BaseIncome(plot)
	local total = 0
	for _, rec in pairs(plot.Slots) do
		if rec and rec.State == "Placed" then
			total += rec.Income
		end
	end
	return total
end

-- ----------------------------------------------------------------------
-- Boosters
-- ----------------------------------------------------------------------
local function syncBoosterAttr(player)
	local list = activeBoosters[player.UserId] or {}
	local out = {}
	local now = os.time()
	for id, expires in pairs(list) do
		if expires > now then
			out[id] = expires
		end
	end
	player:SetAttribute("Boosters", HttpService:JSONEncode(out))
end

function EconomyService.ActivateBooster(player, booster)
	activeBoosters[player.UserId] = activeBoosters[player.UserId] or {}
	local now = os.time()
	local current = activeBoosters[player.UserId][booster.Id]
	-- buying again while active refreshes (does not stack duration past one full timer from now)
	local base = (current and current > now) and current or now
	activeBoosters[player.UserId][booster.Id] = math.min(base + booster.Duration, now + booster.Duration * 2)
	syncBoosterAttr(player)
end

function EconomyService.ClearPlayer(player)
	activeBoosters[player.UserId] = nil
end

-- ----------------------------------------------------------------------
-- Tick
-- ----------------------------------------------------------------------
function EconomyService.Init()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in ipairs(Players:GetPlayers()) do
				local plot = PlotService.GetPlotByOwner(player.UserId)
				if plot then
					local base = EconomyService.BaseIncome(plot)
					local mult = EconomyService.IncomeMultiplier(player)
					local perSec = base * mult
					if perSec > 0 then
						PlayerDataService.AddCash(player, perSec)
					end
					player:SetAttribute("IncomePerSec", perSec)
					player:SetAttribute("IncomeMultiplier", mult)
				end

				-- expire boosters
				local list = activeBoosters[player.UserId]
				if list then
					local changed = false
					for id, expires in pairs(list) do
						if expires <= now then
							list[id] = nil
							changed = true
						end
					end
					if changed then
						syncBoosterAttr(player)
					end
				end
			end
		end
	end)
end

return EconomyService
