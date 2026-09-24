--[[
	GymAnimator (client)
	Brings the gyms to life locally:
	  - Influencers sitting on a machine are posed every frame by the procedural
	    exercise library (RigSolver + Exercises). Time comes from
	    workspace:GetServerTimeNow(), so every player sees the same rep.
	  - Machine parts (bars, weight stacks, cables, pedals, treadmill belts)
	    move with the athlete.
	  - When an athlete hops on, the pose blends in from how they were standing.
	  - The conveyor's chevrons scroll so the belt visibly runs.
	  - Your own placed influencers don't show a "Steal" prompt to you.
	  - [X] lets go of the influencer following you.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Modules = RS:WaitForChild("Modules")
local GymModules = Modules:WaitForChild("Gym")
local Constants = require(Modules:WaitForChild("Constants"))
local RigSolver = require(GymModules:WaitForChild("RigSolver"))
local Exercises = require(GymModules:WaitForChild("Exercises"))
local Specs = require(GymModules:WaitForChild("StationSpecs"))
local Remotes = RS:WaitForChild("Remotes")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ANIM_RANGE = 230 -- only animate athletes this close to the camera
local BLEND_TIME = 0.9

local influencers = workspace:WaitForChild("Influencers", 30)
local mapFolder = workspace:WaitForChild("GymWarsMap")

local bulkParts, bulkCFs = {}, {}
local function queue(part, cf)
	local n = #bulkParts + 1
	bulkParts[n] = part
	bulkCFs[n] = cf
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function axisCF(a, b)
	local mid = (a + b) / 2
	local dir = (b - a).Unit
	local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local z = dir:Cross(up).Unit
	return CFrame.fromMatrix(mid, dir, z:Cross(dir).Unit, z)
end

-- ----------------------------------------------------------------------
-- Station contexts (rest poses of every moving part, captured once)
-- ----------------------------------------------------------------------
local stationCtx = {}

local function buildCtx(station)
	local base = station:FindFirstChild("Base")
	local kind = station:GetAttribute("Exercise")
	if not base or not kind then
		return nil
	end
	local ctx = {
		Station = station,
		Kind = kind,
		Base = base.CFrame,
		Spec = Specs[kind],
		RestLocal = {},
		Groups = {},
		Cables = {},
	}
	local moving = station:FindFirstChild("Moving")
	if moving then
		for _, m in ipairs(moving:GetChildren()) do
			local prim = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"))
			if prim then
				local primRest = prim.CFrame
				ctx.RestLocal[m.Name] = ctx.Base:ToObjectSpace(primRest)
				local g = { Parts = {}, Rel = {}, Rest = {}, Tier = {}, Order = {} }
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						table.insert(g.Parts, p)
						table.insert(g.Rel, primRest:ToObjectSpace(p.CFrame))
						table.insert(g.Rest, p.CFrame)
						g.Tier[#g.Parts] = p:GetAttribute("Tier")
						g.Order[#g.Parts] = p:GetAttribute("StackOrder")
					end
				end
				ctx.Groups[m.Name] = g
			end
		end
	end
	local cables = station:FindFirstChild("Cables")
	if cables then
		for _, c in ipairs(cables:GetChildren()) do
			if c:IsA("BasePart") then
				ctx.Cables[c.Name] = { Part = c, RestCF = c.CFrame, RestSize = c.Size }
			end
		end
	end
	stationCtx[station] = ctx
	return ctx
end

local function getCtx(station)
	return stationCtx[station] or buildCtx(station)
end

-- Heavier weight for rarer athletes: rarity index = plates per side on bars and
-- dumbbells (Common 1 ... Legendary 5), and more of the weight stack gets lifted.
local IDLE_PLATES = 2
local function plateCount(rarity)
	return math.clamp(rarity or 1, 1, 5)
end
local function stackCount(rarity)
	return 2 + 2 * math.clamp(rarity or 1, 1, 5)
end

local function setPlates(ctx, count)
	if ctx.PlatesShown == count then
		return
	end
	ctx.PlatesShown = count
	for _, g in pairs(ctx.Groups) do
		for i, p in ipairs(g.Parts) do
			local tier = g.Tier[i]
			if tier then
				p.Transparency = tier <= count and 0 or 1
			end
		end
	end
end

local function applyEquipment(ctx, e, rarity)
	setPlates(ctx, plateCount(rarity))
	local lift = stackCount(rarity)
	for name, cf in pairs(e.Moves) do
		local g = ctx.Groups[name]
		if g then
			for i, p in ipairs(g.Parts) do
				local order = g.Order[i]
				if order and order > lift then
					queue(p, g.Rest[i]) -- below the pin: stays down
				else
					queue(p, cf * g.Rel[i])
				end
			end
		end
	end
	for name, ab in pairs(e.Cables) do
		local c = ctx.Cables[name]
		if c then
			local len = (ab[2] - ab[1]).Magnitude
			if len > 0.05 then
				c.Part.Size = Vector3.new(len, c.RestSize.Y, c.RestSize.Z)
				queue(c.Part, axisCF(ab[1], ab[2]))
			end
		end
	end
end

local function restoreEquipment(ctx)
	setPlates(ctx, IDLE_PLATES)
	for _, g in pairs(ctx.Groups) do
		for i, p in ipairs(g.Parts) do
			queue(p, g.Rest[i])
		end
	end
	for _, c in pairs(ctx.Cables) do
		c.Part.Size = c.RestSize
		queue(c.Part, c.RestCF)
	end
end

-- ----------------------------------------------------------------------
-- Athletes
-- ----------------------------------------------------------------------
local active = {} -- [model] = state
local lastPelvis = {} -- [model] = LowerTorso CFrame while walking (for blend-in)
local warned = {}

local function activate(model, station)
	local ctx = getCtx(station)
	if not ctx then
		return nil
	end
	local ok, rig = pcall(RigSolver.new, model)
	if not ok then
		return nil -- rig still streaming in; try again next frame
	end
	return {
		Model = model,
		Rig = rig,
		Ctx = ctx,
		Station = station,
		SeatedAt = model:GetAttribute("SeatedAt"),
		Rarity = model:GetAttribute("Rarity") or 1,
		P = Exercises.Params(model:GetAttribute("Seed") or 1, model:GetAttribute("Rarity") or 1),
		StartClock = os.clock(),
		StartPelvis = lastPelvis[model],
	}
end

local function deactivate(a)
	if a.Ctx then
		restoreEquipment(a.Ctx)
	end
	if a.Rig and a.Model.Parent then
		a.Rig:reset()
		pcall(function()
			a.Rig:apply()
		end)
	end
end

local function animate(a, now)
	local rig = a.Rig
	rig:reset()
	rig:setRootCFrame(nil)
	local t = now - (a.SeatedAt or now)
	local fn = Exercises[a.Ctx.Kind] or Exercises.Idle
	local ok, e = pcall(fn, rig, a.Ctx, math.max(t, 0), a.P)
	if not ok then
		if not warned[a.Ctx.Kind] then
			warned[a.Ctx.Kind] = true
			warn("[GymAnimator] " .. tostring(a.Ctx.Kind) .. ": " .. tostring(e))
		end
		return
	end

	local k = (os.clock() - a.StartClock) / BLEND_TIME
	if k < 1 and a.StartPelvis then
		if not a.Snap then
			a.Snap = {}
			for name in pairs(rig.T) do
				a.Snap[name] = CFrame.new()
			end
			local j = rig.J.Root
			local hrpCF = rig.Parts.HumanoidRootPart.CFrame
			a.Snap.Root = (hrpCF * j.C0):Inverse() * a.StartPelvis * j.C1
		end
		rig:blendFrom(a.Snap, smooth(k))
	end
	rig:apply()
	applyEquipment(a.Ctx, e, a.Rarity)
end

-- ----------------------------------------------------------------------
-- Conveyor chevrons
-- ----------------------------------------------------------------------
local chevrons = {}
local chevSpacing = 8
do
	local belt = mapFolder:WaitForChild("Belt", 10)
	local folder = belt and belt:FindFirstChild("Chevrons")
	if folder then
		chevSpacing = folder:GetAttribute("Spacing") or chevSpacing
		for _, m in ipairs(folder:GetChildren()) do
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					table.insert(chevrons, { Part = p, Rest = p.CFrame })
				end
			end
		end
	end
end

-- ----------------------------------------------------------------------
-- Main loop (PreSimulation runs after the Animator, so our joint transforms win)
-- ----------------------------------------------------------------------
local promptAccum = 0

RunService.PreSimulation:Connect(function(dt)
	table.clear(bulkParts)
	table.clear(bulkCFs)
	local now = workspace:GetServerTimeNow()
	local camPos = camera.CFrame.Position

	-- belt
	local speed = workspace:GetAttribute("BeltSpeed") or Constants.BELT.Speed
	local off = (now * speed) % chevSpacing
	local dir = Vector3.new(0, 0, off)
	for _, c in ipairs(chevrons) do
		queue(c.Part, c.Rest + dir)
	end

	promptAccum += dt
	local doPrompts = promptAccum > 0.3
	if doPrompts then
		promptAccum = 0
	end

	if influencers then
		for _, model in ipairs(influencers:GetChildren()) do
			local state = model:GetAttribute("State")
			local ref = model:FindFirstChild("Station")
			local station = ref and ref.Value
			local a = active[model]
			if state == "Placed" and station then
				local seatedAt = model:GetAttribute("SeatedAt")
				if a and (a.Station ~= station or a.SeatedAt ~= seatedAt) then
					deactivate(a)
					a = nil
					active[model] = nil
				end
				if not a then
					a = activate(model, station)
					active[model] = a
				end
				local hrp = model:FindFirstChild("HumanoidRootPart")
				if a and hrp and (hrp.Position - camPos).Magnitude < ANIM_RANGE then
					animate(a, now)
				end
				if doPrompts then
					local prompt = hrp and hrp:FindFirstChild("GrabPrompt")
					if prompt then
						local mine = model:GetAttribute("OwnerUserId") == player.UserId
						if mine and prompt.Enabled then
							prompt.Enabled = false
						end
					end
				end
			else
				if a then
					deactivate(a)
					active[model] = nil
				end
				local lt = model:FindFirstChild("LowerTorso")
				if lt then
					lastPelvis[model] = lt.CFrame
				end
			end
		end
	end

	if #bulkParts > 0 then
		workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

if influencers then
	influencers.ChildRemoved:Connect(function(model)
		local a = active[model]
		active[model] = nil
		lastPelvis[model] = nil
		if a and a.Ctx then
			table.clear(bulkParts)
			table.clear(bulkCFs)
			restoreEquipment(a.Ctx)
			workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

-- [X] = let go of whoever is following you
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.X and (player:GetAttribute("Carrying") or "") ~= "" then
		Remotes.DismissFollower:FireServer()
	end
end)
