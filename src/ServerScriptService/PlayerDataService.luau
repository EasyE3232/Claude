--[[
	PlayerDataService
	Owns the per-player profile, its persistence, leaderstats and the
	attribute mirror the client HUD reads from.

	PROFILE SCHEMA
	  Resets on rebirth : Cash, Placed
	  Permanent          : Strength, Rebirths, OwnedClothing, Equipped, Equipment, GymColor
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local Constants = require(RS.Modules.Constants)

local PlayerDataService = {}

local cache = {} -- [userId] = profile
local store = nil

local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Constants.DATASTORE_NAME)
end)
if not storeOk then
	warn("[PlayerDataService] DataStore unavailable (unpublished place or API access off). Progress will not persist.")
end

local function key(userId)
	return "Player_" .. tostring(userId)
end

local function defaultProfile()
	return {
		Cash = 0,
		Strength = 0,
		Rebirths = 0,
		OwnedClothing = {}, -- [clothingId] = true
		Equipped = {}, -- [slotName] = clothingId
		Equipment = { Floors = 1, WorkoutGain = 1, DeskSpeed = 1 },
		GymColor = 3,
		Placed = {}, -- list of { Rarity = index, Name = string, Slot = number, Seed = number }
	}
end

local function mergeDefaults(data)
	local profile = defaultProfile()
	if type(data) ~= "table" then
		return profile
	end
	for k, v in pairs(data) do
		profile[k] = v
	end
	-- nested defaults
	for k, v in pairs(defaultProfile().Equipment) do
		if type(profile.Equipment) ~= "table" then
			profile.Equipment = {}
		end
		if profile.Equipment[k] == nil then
			profile.Equipment[k] = v
		end
	end
	if type(profile.OwnedClothing) ~= "table" then
		profile.OwnedClothing = {}
	end
	if type(profile.Equipped) ~= "table" then
		profile.Equipped = {}
	end
	if type(profile.Placed) ~= "table" then
		profile.Placed = {}
	end
	return profile
end

-- ----------------------------------------------------------------------
-- Sync helpers
-- ----------------------------------------------------------------------
function PlayerDataService.SyncLeaderstats(player)
	local profile = cache[player.UserId]
	local ls = player:FindFirstChild("leaderstats")
	if not profile or not ls then
		return
	end
	local cash = ls:FindFirstChild("Cash")
	local strength = ls:FindFirstChild("Strength")
	local rebirths = ls:FindFirstChild("Rebirths")
	if cash then
		cash.Value = math.floor(profile.Cash)
	end
	if strength then
		strength.Value = math.floor(profile.Strength)
	end
	if rebirths then
		rebirths.Value = profile.Rebirths
	end
end

function PlayerDataService.SyncAttributes(player)
	local profile = cache[player.UserId]
	if not profile then
		return
	end
	player:SetAttribute("OwnedClothing", HttpService:JSONEncode(profile.OwnedClothing))
	player:SetAttribute("Equipped", HttpService:JSONEncode(profile.Equipped))
	player:SetAttribute("Equipment", HttpService:JSONEncode(profile.Equipment))
	player:SetAttribute("GymColor", profile.GymColor)
	player:SetAttribute("RebirthThreshold", Constants.RebirthThreshold(profile.Rebirths))
	player:SetAttribute("RebirthMultiplier", Constants.RebirthMultiplier(profile.Rebirths))
end

-- ----------------------------------------------------------------------
-- Load / access
-- ----------------------------------------------------------------------
function PlayerDataService.LoadPlayer(player)
	local data = nil
	if store then
		local ok, err = pcall(function()
			data = store:GetAsync(key(player.UserId))
		end)
		if not ok then
			warn("[PlayerDataService] Load failed for " .. player.Name .. ": " .. tostring(err))
		end
	end

	local profile = mergeDefaults(data)
	cache[player.UserId] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats

	local strength = Instance.new("IntValue")
	strength.Name = "Strength"
	strength.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats

	leaderstats.Parent = player

	PlayerDataService.SyncLeaderstats(player)
	PlayerDataService.SyncAttributes(player)
	return profile
end

function PlayerDataService.GetProfile(userId)
	return cache[userId]
end

-- ----------------------------------------------------------------------
-- Mutators
-- ----------------------------------------------------------------------
function PlayerDataService.AddCash(player, delta)
	local profile = cache[player.UserId]
	if not profile then
		return 0
	end
	profile.Cash = math.max(0, profile.Cash + delta)
	PlayerDataService.SyncLeaderstats(player)
	return profile.Cash
end

function PlayerDataService.SetCash(player, value)
	local profile = cache[player.UserId]
	if not profile then
		return
	end
	profile.Cash = math.max(0, value)
	PlayerDataService.SyncLeaderstats(player)
end

function PlayerDataService.AddStrength(player, delta)
	local profile = cache[player.UserId]
	if not profile then
		return 0
	end
	profile.Strength = math.max(0, profile.Strength + delta)
	PlayerDataService.SyncLeaderstats(player)
	return profile.Strength
end

-- ----------------------------------------------------------------------
-- Save
-- ----------------------------------------------------------------------
function PlayerDataService.SaveData(player)
	local profile = cache[player.UserId]
	if not profile or not store then
		return
	end
	local snapshot = {
		Cash = profile.Cash,
		Strength = profile.Strength,
		Rebirths = profile.Rebirths,
		OwnedClothing = profile.OwnedClothing,
		Equipped = profile.Equipped,
		Equipment = profile.Equipment,
		GymColor = profile.GymColor,
		Placed = profile.Placed,
	}
	local ok, err = pcall(function()
		store:SetAsync(key(player.UserId), snapshot)
	end)
	if not ok then
		warn("[PlayerDataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerDataService.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataService.SaveData(player)
	end
end

function PlayerDataService.Cleanup(player)
	cache[player.UserId] = nil
end

return PlayerDataService
