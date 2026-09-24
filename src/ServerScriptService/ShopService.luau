--[[
	ShopService
	Server-authoritative purchases. The client only ever asks; the server
	validates Strength gates, Cash, and levels before changing anything.

	Remotes (RemoteFunction):
	  Purchase:InvokeServer(kind, id)   kind = "Clothing" | "Equipment" | "Booster"
	  Equip:InvokeServer(clothingId)    equips an OWNED clothing item into its slot
	  Rebirth:InvokeServer()
	Remote (RemoteEvent):
	  SetGymColor:FireServer(presetIndex)
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)
local EconomyService = require(SSS.EconomyService)
local InfluencerService = require(SSS.InfluencerService)
local Notify = require(SSS.Notify)

local ShopService = {}

local Remotes = RS:WaitForChild("Remotes")
local colorCooldown = {} -- [userId] = os.clock()

-- ----------------------------------------------------------------------
-- Clothing: Strength unlocks the RIGHT to buy. Cash is still required.
-- ----------------------------------------------------------------------
local function buyClothing(player, profile, id)
	local item = Constants.GetClothing(id)
	if not item then
		return false, "Unknown item."
	end
	if profile.OwnedClothing[id] then
		return false, "You already own " .. item.Name .. "."
	end
	if profile.Strength < item.Strength then
		return false, "Need " .. Constants.FormatNumber(item.Strength) .. " Strength to unlock " .. item.Name .. "."
	end
	if profile.Cash < item.Price then
		return false, "Need $" .. Constants.FormatNumber(item.Price) .. " for " .. item.Name .. "."
	end

	PlayerDataService.AddCash(player, -item.Price)
	profile.OwnedClothing[id] = true
	-- auto-equip if it beats (or fills) the current slot
	local currentId = profile.Equipped[item.Slot]
	local current = currentId and Constants.GetClothing(currentId)
	if not current or item.Bonus > current.Bonus then
		profile.Equipped[item.Slot] = id
	end
	PlayerDataService.SyncAttributes(player)
	return true, "Bought " .. item.Name .. "! +" .. math.floor(item.Bonus * 100) .. "% income"
end

local function equipClothing(player, profile, id)
	local item = Constants.GetClothing(id)
	if not item or not profile.OwnedClothing[id] then
		return false, "You don't own that."
	end
	profile.Equipped[item.Slot] = id
	PlayerDataService.SyncAttributes(player)
	return true, "Equipped " .. item.Name .. "."
end

-- ----------------------------------------------------------------------
-- Equipment: permanent, Cash-only
-- ----------------------------------------------------------------------
local function buyEquipment(player, profile, id)
	local def = Constants.EQUIPMENT[id]
	if not def then
		return false, "Unknown upgrade."
	end
	local level = profile.Equipment[id] or 1
	if level >= #def.Values then
		return false, def.Name .. " is maxed out."
	end
	local cost = def.Costs[level + 1]
	if profile.Cash < cost then
		return false, "Need $" .. Constants.FormatNumber(cost) .. " for the next " .. def.Name .. " level."
	end

	PlayerDataService.AddCash(player, -cost)
	profile.Equipment[id] = level + 1
	PlayerDataService.SyncAttributes(player)

	-- apply side effects immediately
	local plot = PlotService.GetPlotByOwner(player.UserId)
	if plot then
		if id == "Floors" then
			PlotService.RefreshSlots(plot.Id, def.Values[level + 1])
			player:SetAttribute("RackSlots", def.Values[level + 1])
		end
	end
	if ShopService.OnEquipmentChanged then
		ShopService.OnEquipmentChanged(player, id, level + 1)
	end
	return true, def.Name .. " upgraded to level " .. (level + 1) .. "!"
end

-- ----------------------------------------------------------------------
-- Boosters: temporary, Cash-only
-- ----------------------------------------------------------------------
local function buyBooster(player, profile, id)
	local b = Constants.GetBooster(id)
	if not b then
		return false, "Unknown booster."
	end
	if profile.Cash < b.Price then
		return false, "Need $" .. Constants.FormatNumber(b.Price) .. " for " .. b.Name .. "."
	end
	PlayerDataService.AddCash(player, -b.Price)
	EconomyService.ActivateBooster(player, b)
	return true, b.Name .. " active! " .. b.Desc
end

-- ----------------------------------------------------------------------
-- Rebirth: resets Cash + placed influencers ONLY.
-- Strength, clothing, equipment, gym color are permanent.
-- ----------------------------------------------------------------------
function ShopService.DoRebirth(player)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return false, "Profile not loaded."
	end
	local threshold = Constants.RebirthThreshold(profile.Rebirths)
	if profile.Cash < threshold then
		return false, "Need $" .. Constants.FormatNumber(threshold) .. " to rebirth."
	end

	-- drop anything in hand so nothing gets lost mid-carry
	InfluencerService.DropCarried(player)

	-- RESETS
	PlayerDataService.SetCash(player, 0)
	profile.Placed = {}
	local plot = PlotService.GetPlotByOwner(player.UserId)
	if plot then
		InfluencerService.ClearPlot(plot)
	end

	-- PERMANENT GAIN
	profile.Rebirths += 1
	PlayerDataService.SyncLeaderstats(player)
	PlayerDataService.SyncAttributes(player)

	local mult = Constants.RebirthMultiplier(profile.Rebirths)
	return true, string.format("REBIRTH %d! Permanent income x%.2f", profile.Rebirths, mult)
end

-- ----------------------------------------------------------------------
function ShopService.Init()
	Remotes.Purchase.OnServerInvoke = function(player, kind, id)
		local profile = PlayerDataService.GetProfile(player.UserId)
		if not profile or type(kind) ~= "string" or type(id) ~= "string" then
			return false, "Invalid request."
		end
		local ok, msg
		if kind == "Clothing" then
			ok, msg = buyClothing(player, profile, id)
		elseif kind == "Equipment" then
			ok, msg = buyEquipment(player, profile, id)
		elseif kind == "Booster" then
			ok, msg = buyBooster(player, profile, id)
		else
			ok, msg = false, "Invalid shop category."
		end
		Notify(player, msg, ok and "success" or "fail")
		return ok, msg
	end

	Remotes.Equip.OnServerInvoke = function(player, id)
		local profile = PlayerDataService.GetProfile(player.UserId)
		if not profile or type(id) ~= "string" then
			return false, "Invalid request."
		end
		local ok, msg = equipClothing(player, profile, id)
		Notify(player, msg, ok and "success" or "fail")
		return ok, msg
	end

	Remotes.Rebirth.OnServerInvoke = function(player)
		local ok, msg = ShopService.DoRebirth(player)
		Notify(player, msg, ok and "success" or "fail")
		return ok, msg
	end

	Remotes.SetGymColor.OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" or not Constants.GYM_COLORS[index] then
			return
		end
		local now = os.clock()
		if colorCooldown[player.UserId] and now - colorCooldown[player.UserId] < 0.5 then
			return
		end
		colorCooldown[player.UserId] = now
		local profile = PlayerDataService.GetProfile(player.UserId)
		local plot = PlotService.GetPlotByOwner(player.UserId)
		if not profile or not plot then
			return
		end
		profile.GymColor = index
		PlotService.ApplyColor(plot.Id, index)
		PlayerDataService.SyncAttributes(player)
	end)
end

function ShopService.ClearPlayer(player)
	colorCooldown[player.UserId] = nil
end

return ShopService
