--[[
	DefenseService
	One Front Desk Worker per gym (a real R15 humanoid in a staff shirt). When
	someone lures an influencer out of that gym, the worker runs after the
	STOLEN INFLUENCER anywhere on the map, pathfinding around walls. On catch:
	the influencer walks back to its machine. A thief standing close by when
	the catch happens gets knocked down and stunned.

	Worker speed = Constants.EQUIPMENT.DeskSpeed.Values[owner's DeskSpeed level]

	States: Idle -> Chase -> Return -> Idle
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)
local InfluencerService = require(SSS.InfluencerService)
local NpcService = require(SSS.NpcService)
local Notify = require(SSS.Notify)

local DefenseService = {}

local workers = {} -- [plotId] = worker record

-- ----------------------------------------------------------------------
local function homeCFrame(plot)
	local spawnPart = plot.Model:FindFirstChild("DeskSpawn")
	local desk = plot.Model:FindFirstChild("FrontDesk")
	local pos = spawnPart and spawnPart.Position or plot.Model:GetPivot().Position
	local face = desk and Vector3.new(desk.Position.X, pos.Y, desk.Position.Z) or pos + Vector3.new(0, 0, -1)
	return CFrame.lookAt(pos, face)
end

local function buildWorker(plot)
	local model = NpcService.CreateRig({
		Name = "FrontDeskWorker",
		Skin = Constants.SKIN_TONES[(plot.Id % #Constants.SKIN_TONES) + 1],
		Shirt = Color3.fromRGB(220, 50, 55),
		Pants = Color3.fromRGB(30, 30, 34),
	})
	local head = model:FindFirstChild("Head") or model.PrimaryPart

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.new(0, 150, 0, 28)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	tag.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "FRONT DESK"
	label.Parent = tag

	local home = homeCFrame(plot)
	model:PivotTo(home + Vector3.new(0, 0.5, 0))
	model.Parent = plot.Model
	NpcService.Activate(model)

	local w = {
		Plot = plot,
		Model = model,
		Root = model:FindFirstChild("HumanoidRootPart"),
		Label = label,
		Home = home,
		State = "Idle",
		Thefts = {}, -- list of { Rec = rec, ThiefUserId = id }
	}
	workers[plot.Id] = w
	return w
end

local function deskSpeed(plot)
	local owner = PlotService.GetOwnerPlayer(plot)
	local profile = owner and PlayerDataService.GetProfile(owner.UserId)
	local level = profile and profile.Equipment.DeskSpeed or 1
	return Constants.EQUIPMENT.DeskSpeed.Values[level] or Constants.EQUIPMENT.DeskSpeed.Values[1]
end

local function setLabel(w, text, color)
	w.Label.Text = text
	w.Label.TextColor3 = color or Color3.new(1, 1, 1)
end

local function goHome(w)
	w.State = "Return"
	setLabel(w, "FRONT DESK")
	NpcService.WalkTo(w.Model, w.Home.Position, Constants.DEFENSE.ReturnHomeSpeed, function()
		if w.State == "Return" then
			w.State = "Idle"
			w.Model:PivotTo(w.Home)
		end
	end, 40, function()
		w.State = "Idle"
		w.Model:PivotTo(w.Home)
	end)
end

-- ----------------------------------------------------------------------
-- Stun / knockdown
-- ----------------------------------------------------------------------
local function knockDown(player, fromPos)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return
	end
	player:SetAttribute("Stunned", true)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.PlatformStand = true
	-- shove away from the worker so it reads as a tackle
	local away = (hrp.Position - fromPos) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 0.1 and away.Unit or -hrp.CFrame.LookVector
	hrp.AssemblyLinearVelocity = away * 28 + Vector3.new(0, 18, 0)

	task.delay(Constants.DEFENSE.StunSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid.WalkSpeed = Constants.NORMAL_WALKSPEED
			humanoid.JumpPower = 50
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		player:SetAttribute("Stunned", false)
	end)
end

-- ----------------------------------------------------------------------
-- Theft hooks (called from InfluencerService)
-- ----------------------------------------------------------------------
local function onTheftStarted(rec, thief, victimPlot)
	local w = workers[victimPlot.Id]
	if not w then
		return
	end
	table.insert(w.Thefts, { Rec = rec, ThiefUserId = thief.UserId })
	w.State = "Chase"
	setLabel(w, "STOP! THIEF!", Color3.fromRGB(255, 90, 90))
	NpcService.ChaseModel(w.Model, rec.Model, deskSpeed(victimPlot))
end

local function onTheftEnded(rec, victimPlot)
	local w = workers[victimPlot.Id]
	if not w then
		return
	end
	for i = #w.Thefts, 1, -1 do
		if w.Thefts[i].Rec == rec then
			table.remove(w.Thefts, i)
		end
	end
	if #w.Thefts == 0 and w.State == "Chase" then
		goHome(w)
	end
end

-- ----------------------------------------------------------------------
-- Heartbeat
-- ----------------------------------------------------------------------
local function currentTarget(w)
	for i = #w.Thefts, 1, -1 do
		local t = w.Thefts[i]
		local stillStolen = t.Rec.Model and t.Rec.State == "Stolen" and t.Rec.CarrierUserId == t.ThiefUserId
		if not stillStolen then
			table.remove(w.Thefts, i)
		end
	end
	return w.Thefts[1]
end

local accum = 0
local function step(dt)
	accum += dt
	if accum < 0.1 then
		return
	end
	accum = 0
	for _, w in pairs(workers) do
		if w.State == "Chase" then
			local t = currentTarget(w)
			if not t then
				goHome(w)
			else
				local rec = t.Rec
				local target = rec.Root
				NpcService.ChaseModel(w.Model, rec.Model, deskSpeed(w.Plot))
				local d = (target.Position - w.Root.Position) * Vector3.new(1, 0, 1)
				if d.Magnitude <= Constants.DEFENSE.CatchRadius + 1 then
					-- CAUGHT
					local thief = Players:GetPlayerByUserId(t.ThiefUserId)
					InfluencerService.ReturnToOrigin(rec) -- fires onTheftEnded
					if thief then
						local hrp = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
						if hrp and (hrp.Position - w.Root.Position).Magnitude < 12 then
							knockDown(thief, w.Root.Position)
						end
						Notify(thief, "The Front Desk caught " .. rec.Name .. " and walked them back!", "fail")
					end
					local owner = PlotService.GetOwnerPlayer(w.Plot)
					if owner then
						Notify(owner, "Your Front Desk saved " .. rec.Name .. "!", "success")
					end
				end
			end
		end
	end
end

-- ----------------------------------------------------------------------
function DefenseService.Init()
	for _, plot in pairs(PlotService.GetAllPlots()) do
		buildWorker(plot)
	end
	InfluencerService.OnTheftStarted = onTheftStarted
	InfluencerService.OnTheftEnded = onTheftEnded
	RunService.Heartbeat:Connect(step)
end

-- Called when a plot is released (owner left)
function DefenseService.ResetPlot(plot)
	local w = workers[plot.Id]
	if not w then
		return
	end
	w.Thefts = {}
	w.State = "Idle"
	setLabel(w, "FRONT DESK")
	NpcService.Stop(w.Model)
	w.Model:PivotTo(w.Home)
end

return DefenseService
