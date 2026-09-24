--[[
	PlotService
	Assigns the 8 gym lots to players, handles sign text, gym colors,
	station unlock visuals and teleporting players home.

	Each plot model (GymWarsMap.Plots.PlotN) contains:
	  Floor, WallBack/WallLeft/WallRight, Sign, FrontDesk, DeskSpawn, PlotSpawn,
	  WorkoutStation (owner's heavy bag), GymZone (interior volume),
	  Floor1..Floor3 folders (each with Stations/StationN, see tools/map/Gym.luau),
	  Roof1..Roof3 folders (the roof on top of each possible height)
	Floors that aren't bought are kept in ServerStorage, so the building grows
	a story each time the owner buys a Gym Floor.
	Parts tagged with the "ColorRole" attribute ("Wall" / "Accent" / "AccentDim")
	are recolored by the owner's gym color preset.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(RS.Modules.Constants)
local StationSpecs = require(RS.Modules.Gym.StationSpecs)

local PlotService = {}

local plots = {} -- [plotId] = plot record
local ownerToPlot = {} -- [userId] = plotId

local hiddenRoot = ServerStorage:FindFirstChild("HiddenGymFloors")
if not hiddenRoot then
	hiddenRoot = Instance.new("Folder")
	hiddenRoot.Name = "HiddenGymFloors"
	hiddenRoot.Parent = ServerStorage
end

local DEFAULT_COLOR = 3 -- "Ice" (blue accents, like the reference gym)

-- ----------------------------------------------------------------------
local function makeSignGui(signPart)
	local gui = signPart:FindFirstChild("SignGui")
	if gui then
		return gui
	end
	gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = signPart

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "OPEN GYM"
	label.Parent = gui
	return gui
end

-- ----------------------------------------------------------------------
function PlotService.Init()
	local folder = workspace:WaitForChild("GymWarsMap"):WaitForChild("Plots")
	for i = 1, Constants.PLOT_COUNT do
		local model = folder:FindFirstChild("Plot" .. i)
		if model then
			model:SetAttribute("PlotId", i)
			model:SetAttribute("OwnerUserId", 0)
			local plot = {
				Id = i,
				Model = model,
				OwnerUserId = 0,
				Slots = {}, -- [slotIndex] = influencer record
				Unlocked = 0,
				Stations = {},
				Roles = { Wall = {}, Accent = {}, AccentDim = {} },
			}
			-- upper floors and roofs are parked in ServerStorage while not shown
			plot.Hidden = hiddenRoot:FindFirstChild("Plot" .. i)
			if not plot.Hidden then
				plot.Hidden = Instance.new("Folder")
				plot.Hidden.Name = "Plot" .. i
				plot.Hidden.Parent = hiddenRoot
			end
			plot.Floors, plot.RoofLevels = {}, {}
			for _, container in ipairs({ model, plot.Hidden }) do
				for _, child in ipairs(container:GetChildren()) do
					local f = child:GetAttribute("Floor")
					local level = child:GetAttribute("Level")
					if child:IsA("Folder") and f then
						plot.Floors[f] = child
					elseif child:IsA("Folder") and level then
						plot.RoofLevels[level] = child
					end
				end
				for _, d in ipairs(container:GetDescendants()) do
					local role = d:IsA("BasePart") and d:GetAttribute("ColorRole")
					if role and plot.Roles[role] then
						table.insert(plot.Roles[role], d)
					end
					local slot = d:IsA("Model") and d:GetAttribute("Slot")
					if slot then
						plot.Stations[slot] = d
					end
				end
			end
			local sign = model:FindFirstChild("Sign")
			if sign then
				plot.SignBase = sign.CFrame
			end
			plot.Level = 0
			plots[i] = plot
			makeSignGui(model:WaitForChild("Sign"))
			PlotService.SetSignText(i, "OPEN GYM")
			PlotService.ApplyColor(i, DEFAULT_COLOR)
			PlotService.RefreshSlots(i, 0)
		else
			warn("[PlotService] Missing Plot" .. i .. " in GymWarsMap.Plots")
		end
	end
end

function PlotService.GetPlotById(id)
	return plots[id]
end

function PlotService.GetPlotByOwner(userId)
	local id = ownerToPlot[userId]
	return id and plots[id] or nil
end

function PlotService.GetAllPlots()
	return plots
end

function PlotService.GetStation(plotId, slot)
	local plot = plots[plotId]
	return plot and plot.Stations[slot] or nil
end

function PlotService.StationName(station)
	local kind = station:GetAttribute("Exercise")
	return StationSpecs.DISPLAY_NAMES[kind] or kind or "machine"
end

-- Walk up from any instance to find which plot it belongs to.
function PlotService.GetPlotFromInstance(inst)
	local node = inst
	while node and node ~= workspace do
		local id = node:GetAttribute("PlotId")
		if id then
			return plots[id]
		end
		node = node.Parent
	end
	return nil
end

function PlotService.IsInsideGym(plot, point)
	local zone = plot and plot.Model:FindFirstChild("GymZone")
	if not zone then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- ----------------------------------------------------------------------
function PlotService.AssignPlot(player)
	if ownerToPlot[player.UserId] then
		return plots[ownerToPlot[player.UserId]]
	end
	for i = 1, Constants.PLOT_COUNT do
		local plot = plots[i]
		if plot and plot.OwnerUserId == 0 then
			plot.OwnerUserId = player.UserId
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			ownerToPlot[player.UserId] = i
			player:SetAttribute("PlotId", i)
			PlotService.SetSignText(i, player.DisplayName .. "'s Gym")
			return plot
		end
	end
	return nil
end

function PlotService.ReleasePlot(player)
	local id = ownerToPlot[player.UserId]
	if not id then
		return
	end
	local plot = plots[id]
	plot.OwnerUserId = 0
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Slots = {}
	ownerToPlot[player.UserId] = nil
	PlotService.SetSignText(id, "OPEN GYM")
	PlotService.ApplyColor(id, DEFAULT_COLOR)
	PlotService.RefreshSlots(id, 0)
end

-- ----------------------------------------------------------------------
function PlotService.SetSignText(plotId, text)
	local plot = plots[plotId]
	local sign = plot and plot.Model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("Label")
	if label then
		label.Text = text
	end
end

function PlotService.ApplyColor(plotId, presetIndex)
	local plot = plots[plotId]
	local preset = Constants.GYM_COLORS[presetIndex] or Constants.GYM_COLORS[DEFAULT_COLOR]
	if not plot or not preset then
		return
	end
	-- keep walls dark like a real gym: tint the preset wall color toward black
	local wall = preset.Wall:Lerp(Color3.fromRGB(14, 14, 16), 0.45)
	local dim = preset.Accent:Lerp(Color3.fromRGB(40, 44, 52), 0.55)
	for _, p in ipairs(plot.Roles.Wall) do
		p.Color = wall
	end
	for _, p in ipairs(plot.Roles.Accent) do
		p.Color = preset.Accent
	end
	for _, p in ipairs(plot.Roles.AccentDim) do
		p.Color = dim
	end
	plot.Model:SetAttribute("AccentColor", preset.Accent)
end

-- `unlockedCount` machines are usable; shows the floors that contain them.
function PlotService.RefreshSlots(plotId, unlockedCount)
	local plot = plots[plotId]
	if not plot then
		return
	end
	plot.Unlocked = unlockedCount
	PlotService.SetFloorLevel(plotId, PlotService.FloorsForSlots(unlockedCount))
end

-- How many floors are open for a given machine count.
function PlotService.FloorsForSlots(unlockedCount)
	local floors = 1
	for f, first in ipairs(StationSpecs.FLOOR_FIRST_SLOT) do
		if unlockedCount >= first then
			floors = f
		end
	end
	return floors
end

-- Show floors 1..level (+ the roof on top of `level`); park the rest in
-- ServerStorage so nobody can see or enter floors that aren't bought.
function PlotService.SetFloorLevel(plotId, level)
	local plot = plots[plotId]
	if not plot or plot.Level == level then
		return
	end
	plot.Level = level
	for f, folder in pairs(plot.Floors) do
		folder.Parent = (f <= level) and plot.Model or plot.Hidden
	end
	for l, folder in pairs(plot.RoofLevels) do
		folder.Parent = (l == level) and plot.Model or plot.Hidden
	end
	local sign = plot.Model:FindFirstChild("Sign")
	if sign and plot.SignBase then
		local up = (sign:GetAttribute("FloorHeight") or 16) * (level - 1)
		sign.CFrame = plot.SignBase + Vector3.new(0, up, 0)
	end
end

function PlotService.GetSlotPart(plotId, k)
	local station = PlotService.GetStation(plotId, k)
	return station and station:FindFirstChild("Approach") or nil
end

function PlotService.FindOpenSlot(plotId)
	local plot = plots[plotId]
	if not plot then
		return nil
	end
	for k = 1, plot.Unlocked do
		if not plot.Slots[k] and plot.Stations[k] then
			return k
		end
	end
	return nil
end

function PlotService.CountPlaced(plotId)
	local plot = plots[plotId]
	if not plot then
		return 0
	end
	local n = 0
	for _ in pairs(plot.Slots) do
		n += 1
	end
	return n
end

-- ----------------------------------------------------------------------
function PlotService.TeleportToPlot(player, plot)
	local character = player.Character
	local spawnPart = plot and plot.Model:FindFirstChild("PlotSpawn")
	if not character or not spawnPart then
		return
	end
	if not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	-- face out the front door toward the red carpet
	local from = spawnPart.Position + Vector3.new(0, 1, 0)
	local lookAt = Vector3.new(0, from.Y, from.Z)
	character:PivotTo(CFrame.lookAt(from, lookAt))
end

function PlotService.GetOwnerPlayer(plot)
	if not plot or plot.OwnerUserId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(plot.OwnerUserId)
end

return PlotService
