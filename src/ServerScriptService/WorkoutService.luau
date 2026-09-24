--[[
	WorkoutService
	Each plot's WorkoutStation has a ProximityPrompt. Only the owner can use
	their own station. Each rep adds Strength (permanent, never reset):
	  gain = BaseGain * WorkoutGain equipment value
	Rep cooldown is divided by active WorkoutSpeed boosters (Creatine).
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)
local EconomyService = require(SSS.EconomyService)
local Notify = require(SSS.Notify)

local WorkoutService = {}

local lastRep = {} -- [userId] = os.clock()

local function doRep(player, plot)
	if plot.OwnerUserId ~= player.UserId then
		Notify(player, "That's not your gym! Go lift at your own station.", "fail")
		return
	end
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return
	end

	local speed = EconomyService.BoosterMultiplier(player.UserId, "WorkoutSpeed")
	local cooldown = Constants.WORKOUT.RepCooldown / speed
	local now = os.clock()
	if lastRep[player.UserId] and now - lastRep[player.UserId] < cooldown then
		return
	end
	lastRep[player.UserId] = now

	local level = profile.Equipment.WorkoutGain or 1
	local gainPerRep = Constants.EQUIPMENT.WorkoutGain.Values[level] or 1
	PlayerDataService.AddStrength(player, Constants.WORKOUT.BaseGain * gainPerRep)
end

function WorkoutService.Init()
	for _, plot in pairs(PlotService.GetAllPlots()) do
		local station = plot.Model:FindFirstChild("WorkoutStation")
		if station then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "WorkoutPrompt"
			prompt.ActionText = "Do a Rep"
			prompt.ObjectText = "Heavy Bag"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Constants.WORKOUT.PromptDistance
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = station

			prompt.Triggered:Connect(function(player)
				doRep(player, plot)
			end)
		end
	end
end

function WorkoutService.ClearPlayer(player)
	lastRep[player.UserId] = nil
end

return WorkoutService
