--[[
	GYM WARS — server bootstrap
	Wires every service together and handles join / leave / respawn.
]]

local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)
local InfluencerService = require(SSS.InfluencerService)
local BeltService = require(SSS.BeltService)
local EconomyService = require(SSS.EconomyService)
local WorkoutService = require(SSS.WorkoutService)
local ShopService = require(SSS.ShopService)
local DefenseService = require(SSS.DefenseService)
local NpcService = require(SSS.NpcService)
local Notify = require(SSS.Notify)

-- ----------------------------------------------------------------------
-- Init order matters: plots first (everything hangs off them)
-- ----------------------------------------------------------------------
NpcService.Init()
PlotService.Init()
InfluencerService.Init()
DefenseService.Init()
BeltService.Init()
EconomyService.Init()
WorkoutService.Init()
ShopService.Init()

-- ----------------------------------------------------------------------
local function onCharacterAdded(player, character)
	-- players never collide with NPCs (influencers / front desk) so nobody gets body-blocked
	NpcService.SetGroup(character, NpcService.GROUP_PLAYERS)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = NpcService.GROUP_PLAYERS
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Constants.NORMAL_WALKSPEED
		humanoid.Died:Connect(function()
			InfluencerService.DropCarried(player)
		end)
	end
	player:SetAttribute("Stunned", false)
	player:SetAttribute("Carrying", "")

	local plot = PlotService.GetPlotByOwner(player.UserId)
	if plot then
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait() -- let the default spawn finish before moving
		PlotService.TeleportToPlot(player, plot)
	end
end

local function onPlayerAdded(player)
	local profile = PlayerDataService.LoadPlayer(player)
	local plot = PlotService.AssignPlot(player)

	if plot then
		local rackLevel = profile.Equipment.RackSlots or 1
		local slots = Constants.EQUIPMENT.RackSlots.Values[rackLevel]
		PlotService.RefreshSlots(plot.Id, slots)
		PlotService.ApplyColor(plot.Id, profile.GymColor or 3)
		local restored = InfluencerService.RestorePlaced(player, plot)
		player:SetAttribute("RackSlots", slots)
		player:SetAttribute("RackUsed", PlotService.CountPlaced(plot.Id))
		task.delay(3, function()
			if restored > 0 then
				Notify(player, "Welcome back! " .. restored .. " influencers are still training at your gym.", "success")
			else
				Notify(player, "Claim influencers off the red carpet and lead them to your gym!", "info")
			end
		end)
	else
		task.delay(3, function()
			Notify(player, "Server is full of gyms — you can still explore, but you need a gym to earn.", "fail")
		end)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	InfluencerService.DropCarried(player)

	local plot = PlotService.GetPlotByOwner(player.UserId)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if plot and profile then
		-- anything being lured out of this gym right now is gone for good
		for slot, rec in pairs(plot.Slots) do
			if rec and rec.State == "Following" then
				for i = #profile.Placed, 1, -1 do
					if profile.Placed[i].Slot == slot then
						table.remove(profile.Placed, i)
					end
				end
			end
		end
	end

	PlayerDataService.SaveData(player)

	if plot then
		InfluencerService.ClearPlot(plot)
		DefenseService.ResetPlot(plot)
		PlotService.ReleasePlot(player)
	end

	EconomyService.ClearPlayer(player)
	WorkoutService.ClearPlayer(player)
	ShopService.ClearPlayer(player)
	PlayerDataService.Cleanup(player)
end

RS.Remotes.DismissFollower.OnServerEvent:Connect(function(player)
	InfluencerService.DropCarried(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ----------------------------------------------------------------------
-- Autosave + shutdown save
-- ----------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Constants.AUTOSAVE_INTERVAL)
		PlayerDataService.SaveAll()
	end
end)

game:BindToClose(function()
	PlayerDataService.SaveAll()
	task.wait(1)
end)

print("[GymWars] Server ready — " .. Constants.PLOT_COUNT .. " gyms, red carpet conveyor running.")
