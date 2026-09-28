--[[
	NpcLocomotion
	Walk / run / idle for every NPC (influencers, front desk), played on this
	client so it's smooth every frame (the server only moves them). Models are
	flagged by the server with the "Loco" attribute (false while working out).

	  - Rthro idle / walk / run (heavier, more natural gait), falling back to
	    the classic R15 set if those don't load
	  - Walk/run blended and speed-matched to how fast they move
	  - Bodybuilder swagger: arms carried out from the body (more for bigger
	    rarities) so big arms don't clip through the lats and thighs
]]

local RunService = game:GetService("RunService")

local SETS = {
	Rthro = { Idle = "rbxassetid://2510196951", Walk = "rbxassetid://2510202577", Run = "rbxassetid://2510198475" },
	Classic = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://507777826", Run = "rbxassetid://507767714" },
}

local rigs = {} -- [model] = state

local function loadSet(animator, ids)
	local tracks = {}
	for key, id in pairs(ids) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok or not track then
			return nil
		end
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Core
		tracks[key] = track
	end
	return tracks
end

local function loaded(tracks)
	for _, t in pairs(tracks) do
		if t.Length <= 0 then
			return false
		end
	end
	return true
end

local function stopAll(state)
	if state.Tracks then
		for _, t in pairs(state.Tracks) do
			t:Stop(0.25)
		end
	end
end

local function findJoint(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == name and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then
			return d
		end
	end
	return nil
end

local function track(model)
	if rigs[model] then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and animator and root) then
		return
	end
	local state = { Model = model, Humanoid = hum, Root = root, Weights = { 1, 0, 0 } }
	rigs[model] = state
	task.spawn(function()
		-- prefer Rthro; use the classic clips if those never load
		local tracks = loadSet(animator, SETS.Rthro)
		local t0 = os.clock()
		while tracks and not loaded(tracks) and os.clock() - t0 < 4 do
			task.wait(0.2)
		end
		if not (tracks and loaded(tracks)) then
			if tracks then
				for _, t in pairs(tracks) do
					t:Destroy()
				end
			end
			tracks = loadSet(animator, SETS.Classic)
		end
		if rigs[model] == state then
			state.Tracks = tracks
		end
	end)
	state.LeftShoulder = findJoint(model, "LeftShoulder")
	state.RightShoulder = findJoint(model, "RightShoulder")
	-- arms out a little for regular guys, a lot for the mass monsters
	local rarity = model:GetAttribute("Rarity") or 1
	state.Spread = math.rad(4 + 2 * rarity)
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

local function consider(inst)
	if inst:IsA("Model") and inst:GetAttribute("Loco") ~= nil then
		track(inst)
	end
end

for _, d in ipairs(workspace:GetDescendants()) do
	consider(d)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		task.defer(consider, d)
	end
end)
-- the flag can arrive after the model does
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Humanoid") and d.Parent then
		task.defer(consider, d.Parent)
	end
end)

-- Blend walk/run by ground speed (mirrors Roblox's Animate script)
RunService.Heartbeat:Connect(function(dt)
	for model, state in pairs(rigs) do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local tracks = state.Tracks
		if not tracks then
			continue
		end
		local active = model:GetAttribute("Loco") ~= false and not state.Root.Anchored
		if not active then
			if state.Playing then
				stopAll(state)
				state.Playing = false
			end
			continue
		end
		if not state.Playing then
			for _, t in pairs(tracks) do
				t:Play(0.25, 0.001, 1)
			end
			state.Playing = true
		end
		local v = state.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = v.Magnitude
		local heightScale = math.max(state.Humanoid.HipHeight / 2, 0.5)
		local rs = speed * 1.25 / 16 / heightScale
		local wIdle, wWalk, wRun, warp = 0, 0, 0, 1
		if speed < 0.6 then
			wIdle = 1
		elseif rs <= 0.5 then
			wWalk, warp = 1, rs / 0.5
		elseif rs < 1 then
			local f = (rs - 0.5) / 0.5
			wWalk, wRun = 1 - f, f
		else
			wRun, warp = 1, rs
		end
		local k = math.clamp(dt * 8, 0, 1)
		local w = state.Weights
		w[1] += (wIdle - w[1]) * k
		w[2] += (wWalk - w[2]) * k
		w[3] += (wRun - w[3]) * k
		tracks.Idle:AdjustWeight(math.max(w[1], 0.001), 0.1)
		tracks.Walk:AdjustWeight(math.max(w[2], 0.001), 0.1)
		tracks.Run:AdjustWeight(math.max(w[3], 0.001), 0.1)
		tracks.Idle:AdjustSpeed(model:GetAttribute("IdleSpeed") or 1)
		tracks.Walk:AdjustSpeed(math.max(warp, 0.1))
		tracks.Run:AdjustSpeed(math.max(warp, 0.1))
	end
end)

-- Swagger layer: after the Animator has posed the rig, carry the arms out.
RunService.PreSimulation:Connect(function()
	for model, state in pairs(rigs) do
		if state.Playing and model:GetAttribute("Loco") ~= false then
			local a = state.Spread
			if state.LeftShoulder then
				state.LeftShoulder.Transform = state.LeftShoulder.Transform * CFrame.Angles(0, 0, -a)
			end
			if state.RightShoulder then
				state.RightShoulder.Transform = state.RightShoulder.Transform * CFrame.Angles(0, 0, a)
			end
		end
	end
end)
