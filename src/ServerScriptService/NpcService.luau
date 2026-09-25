--[[
	NpcService
	Real R15 humanoid NPCs for influencers and front-desk workers.

	- Rig creation: Players:CreateHumanoidModelFromDescriptionAsync (falls back
	  to the old API, then to a code-built block rig so NPCs always exist).
	- Collision groups: NPCs never collide with players or each other, so they
	  can't block doorways or be body-blocked.
	- Locomotion animation: Roblox's own default R15 idle/walk/run animations,
	  blended by actual ground speed exactly like the default Animate script.
	- Movement controller: Follow(leader) and WalkTo(point) using direct
	  MoveTo when there's line of sight and PathfindingService when there
	  isn't, with stuck detection (jump, then re-path, then teleport).
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Constants = require(RS.Modules.Constants)
local BlockRig = require(RS.Modules.Gym.BlockRig)

local NpcService = {}

NpcService.GROUP_NPC = "NPC"
NpcService.GROUP_PLAYERS = "Players"

-- Roblox default R15 animations (owned by Roblox, usable in any experience)
local ANIMS = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Wave = "rbxassetid://507770239",
	Cheer = "rbxassetid://507770677",
	Point = "rbxassetid://507770453",
	Dance = "rbxassetid://507771019",
}
NpcService.EMOTES = { "Wave", "Cheer", "Point", "Dance" }

local controllers = {} -- [model] = controller
local animSets = {} -- [model] = { tracks = {}, ... }
local descCache = {} -- [userId] = HumanoidDescription

-- ----------------------------------------------------------------------
-- Collision groups
-- ----------------------------------------------------------------------
function NpcService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(NpcService.GROUP_NPC)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(NpcService.GROUP_PLAYERS)
	end)
	PhysicsService:CollisionGroupSetCollidable(NpcService.GROUP_NPC, NpcService.GROUP_NPC, false)
	PhysicsService:CollisionGroupSetCollidable(NpcService.GROUP_NPC, NpcService.GROUP_PLAYERS, false)

	RunService.Heartbeat:Connect(NpcService._step)
end

function NpcService.SetGroup(model, group)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- ----------------------------------------------------------------------
-- Rig creation
-- ----------------------------------------------------------------------
local function buildDescription(opts)
	local desc
	local userId = opts.AvatarUserId
	if userId then
		desc = descCache[userId]
		if not desc then
			local ok, result = pcall(function()
				return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
			end)
			if not ok then
				ok, result = pcall(function()
					return Players:GetHumanoidDescriptionFromUserId(userId)
				end)
			end
			if ok and result then
				descCache[userId] = result
				desc = result
			end
		end
		if desc then
			return desc:Clone()
		end
	end

	desc = Instance.new("HumanoidDescription")
	local skin = opts.Skin or Color3.fromRGB(234, 184, 146)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.LeftLegColor = opts.Pants or Color3.fromRGB(38, 40, 48)
	desc.RightLegColor = opts.Pants or Color3.fromRGB(38, 40, 48)
	desc.TorsoColor = opts.Shirt or Color3.fromRGB(80, 80, 90)
	desc.HeightScale = opts.Height or 1
	desc.WidthScale = opts.Width or 1
	desc.DepthScale = opts.Depth or 1
	desc.HeadScale = 1
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	return desc
end

local function createModel(desc)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
	end
	if ok and model and model:FindFirstChild("HumanoidRootPart") then
		return model, false
	end
	warn("[NpcService] Avatar rig creation failed, using block rig: " .. tostring(model))
	return nil, true
end

--[[
	opts = {
		Name, Skin, Shirt, Pants, Height, Width, Depth, AvatarUserId, Scale,
		Face = true (adds the classic face decal when the head has none)
	}
]]
function NpcService.CreateRig(opts)
	opts = opts or {}
	local desc = buildDescription(opts)
	local model, isBlock = createModel(desc)
	if isBlock then
		model = BlockRig.Build({ Skin = opts.Skin, Shirt = opts.Shirt, Pants = opts.Pants, Scale = opts.Scale })
	elseif opts.Scale and opts.Scale ~= 1 then
		-- bigger-than-life influencers to match the oversized equipment
		pcall(function()
			model:ScaleTo(opts.Scale)
		end)
	end
	model.Name = opts.Name or "NPC"

	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.WalkSpeed = Constants.NPC.FollowSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 45
	for _, state in ipairs({
		Enum.HumanoidStateType.Dead,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
	}) do
		humanoid:SetStateEnabled(state, false)
	end

	local head = model:FindFirstChild("Head")
	if head and opts.Face ~= false and not head:FindFirstChildOfClass("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = Enum.NormalId.Front
		face.Parent = head
	end

	NpcService.SetGroup(model, NpcService.GROUP_NPC)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	return model
end

-- Call after parenting into workspace.
function NpcService.Activate(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and not hrp.Anchored then
		pcall(function()
			hrp:SetNetworkOwner(nil) -- server-owned: no exploit control, no ownership hand-off jitter
		end)
	end
	NpcService._ensureAnims(model)
end

-- ----------------------------------------------------------------------
-- Animation
-- ----------------------------------------------------------------------
function NpcService._ensureAnims(model)
	local set = animSets[model]
	if set then
		return set
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	set = { Tracks = {}, Animator = animator, Humanoid = humanoid, Enabled = true, Emote = nil }
	for key, id in pairs(ANIMS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			local looped = key == "Idle" or key == "Walk" or key == "Run" or key == "Dance"
			track.Looped = looped
			track.Priority = (key == "Idle" or key == "Walk" or key == "Run") and Enum.AnimationPriority.Core
				or Enum.AnimationPriority.Action
			set.Tracks[key] = track
		end
	end
	animSets[model] = set
	model.Destroying:Connect(function()
		animSets[model] = nil
		controllers[model] = nil
	end)
	return set
end

-- Locomotion blending (mirrors the default Animate script's walk/run blend)
local function updateLocomotion(set, hrp, dt)
	if not set.Enabled then
		return
	end
	local v = hrp.AssemblyLinearVelocity
	-- speed relative to what we're standing on (so riding the conveyor = idle)
	local ground = set.Humanoid.FloorMaterial ~= Enum.Material.Air
	local groundVel = Vector3.zero
	if ground then
		local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), set.RayParams)
		if ray and ray.Instance then
			groundVel = ray.Instance.AssemblyLinearVelocity
		end
	end
	local flat = (v - groundVel) * Vector3.new(1, 0, 1)
	local speed = flat.Magnitude
	local tracks = set.Tracks
	local idle, walk, run = tracks.Idle, tracks.Walk, tracks.Run
	if not (idle and walk and run) then
		return
	end
	for _, t in ipairs({ idle, walk, run }) do
		if not t.IsPlaying then
			t:Play(0.2, 0.001, 1)
		end
	end
	local heightScale = math.max(set.Humanoid.HipHeight / 2, 0.5)
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
	set.Weights = set.Weights or { 1, 0, 0 }
	local k = math.clamp(dt * 8, 0, 1)
	set.Weights[1] += (wIdle - set.Weights[1]) * k
	set.Weights[2] += (wWalk - set.Weights[2]) * k
	set.Weights[3] += (wRun - set.Weights[3]) * k
	idle:AdjustWeight(math.max(set.Weights[1], 0.001), 0.1)
	walk:AdjustWeight(math.max(set.Weights[2], 0.001), 0.1)
	run:AdjustWeight(math.max(set.Weights[3], 0.001), 0.1)
	walk:AdjustSpeed(math.max(warp, 0.1))
	run:AdjustSpeed(math.max(warp, 0.1))
end

function NpcService.PlayEmote(model, name)
	local set = NpcService._ensureAnims(model)
	local track = set and set.Tracks[name]
	if track and set.Enabled then
		if set.Emote and set.Emote.IsPlaying then
			set.Emote:Stop(0.2)
		end
		track:Play(0.2)
		set.Emote = track
		if track.Looped then
			task.delay(4, function()
				if set.Emote == track then
					track:Stop(0.4)
				end
			end)
		end
	end
end

-- Stop all server animation (the client drives the rig procedurally on machines)
function NpcService.SetAnimationsEnabled(model, enabled)
	local set = NpcService._ensureAnims(model)
	if not set then
		return
	end
	set.Enabled = enabled
	if not enabled then
		for _, t in pairs(set.Tracks) do
			t:Stop(0.1)
		end
	end
end

-- ----------------------------------------------------------------------
-- Movement controller
-- ----------------------------------------------------------------------
local AGENT = { AgentRadius = 2, AgentHeight = 7.2, AgentCanJump = true, WaypointSpacing = 6 }

local losParams = RaycastParams.new()
losParams.CollisionGroup = NpcService.GROUP_NPC
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function hasLineOfSight(from, to)
	local a = from + Vector3.new(0, 0.5, 0)
	local b = to + Vector3.new(0, 0.5, 0)
	local dir = b - a
	if dir.Magnitude < 0.5 then
		return true
	end
	-- two rays (waist + knee height) so low obstacles count too
	local hit1 = workspace:Raycast(a, dir, losParams)
	local hit2 = workspace:Raycast(a - Vector3.new(0, 1.8, 0), dir, losParams)
	return hit1 == nil and hit2 == nil
end

local function newController(model)
	local c = controllers[model]
	if c then
		return c
	end
	c = {
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Root = model:FindFirstChild("HumanoidRootPart"),
		Mode = "None",
		Path = nil,
		Waypoints = nil,
		WpIndex = 0,
		PathBusy = false,
		PathAt = 0,
		LastProgressPos = nil,
		LastProgressAt = os.clock(),
		Accum = 0,
	}
	controllers[model] = c
	return c
end

-- Follow a leader (Player). offset = sideways offset so several followers fan out.
function NpcService.Follow(model, player, speed, offset)
	local c = newController(model)
	c.Humanoid.WalkSpeed = speed or Constants.NPC.FollowSpeed
	c.Offset = offset or 0
	if c.Mode == "Follow" and c.Leader == player then
		return -- already following them; just refresh speed/offset
	end
	c.Mode = "Follow"
	c.Leader = player
	c.Waypoints = nil
	c.LastProgressAt = os.clock()
end

-- Walk to a point, then call onArrive(model). onFail after `timeout` seconds.
function NpcService.WalkTo(model, point, speed, onArrive, timeout, onFail)
	local c = newController(model)
	c.Mode = "WalkTo"
	c.Target = point
	c.OnArrive = onArrive
	c.OnFail = onFail
	c.Deadline = os.clock() + (timeout or 30)
	c.Humanoid.WalkSpeed = speed or Constants.NPC.SeatSpeed
	c.Waypoints = nil
	c.LastProgressAt = os.clock()
end

-- Chase a player's character directly (front desk).
function NpcService.Chase(model, player, speed)
	local c = newController(model)
	c.Humanoid.WalkSpeed = speed or 16
	if c.Mode == "Chase" and c.Leader == player then
		return
	end
	c.Mode = "Chase"
	c.Leader = player
	c.Offset = 0
	c.Waypoints = nil
	c.LastProgressAt = os.clock()
end

-- Chase another model (e.g. a stolen influencer).
function NpcService.ChaseModel(model, target, speed)
	local c = newController(model)
	c.Humanoid.WalkSpeed = speed or 16
	if c.Mode == "ChaseModel" and c.TargetModel == target then
		return
	end
	c.Mode = "ChaseModel"
	c.TargetModel = target
	c.Waypoints = nil
	c.LastProgressAt = os.clock()
end

function NpcService.Stop(model)
	local c = controllers[model]
	if c then
		c.Mode = "None"
		c.Waypoints = nil
		if c.Humanoid and c.Root and not c.Root.Anchored then
			c.Humanoid:MoveTo(c.Root.Position)
		end
	end
end

function NpcService.Forget(model)
	controllers[model] = nil
end

local function computePath(c, goal)
	if c.PathBusy then
		return
	end
	c.PathBusy = true
	local from = c.Root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath(AGENT)
		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		c.PathBusy = false
		c.PathAt = os.clock()
		if ok and path.Status == Enum.PathStatus.Success then
			c.Waypoints = path:GetWaypoints()
			c.WpIndex = math.min(2, #c.Waypoints)
			c.PathGoal = goal
		else
			c.Waypoints = nil
		end
	end)
end

local function followWaypoints(c)
	local wps = c.Waypoints
	if not wps or c.WpIndex > #wps then
		return false
	end
	local wp = wps[c.WpIndex]
	if flat(wp.Position - c.Root.Position).Magnitude < 2.5 then
		c.WpIndex += 1
		wp = wps[c.WpIndex]
		if not wp then
			return false
		end
	end
	if wp.Action == Enum.PathWaypointAction.Jump then
		c.Humanoid.Jump = true
	end
	c.Humanoid:MoveTo(wp.Position)
	return true
end

-- Returns true when the NPC reached `goal` (XZ within arriveDist).
local function steer(c, goal, arriveDist)
	local pos = c.Root.Position
	local d = flat(goal - pos).Magnitude
	-- same floor check: a machine directly above/below isn't "arrived"
	if d <= arriveDist and math.abs(goal.Y - pos.Y) < 6 then
		c.Humanoid:MoveTo(pos)
		c.Waypoints = nil
		return true
	end
	if math.abs(goal.Y - pos.Y) < 5 and hasLineOfSight(pos, goal) then
		c.Waypoints = nil
		c.Humanoid:MoveTo(goal)
	else
		local stale = not c.Waypoints
			or os.clock() - c.PathAt > 2
			or (c.PathGoal and (c.PathGoal - goal).Magnitude > 8)
		if stale then
			computePath(c, goal)
		end
		if not followWaypoints(c) then
			c.Humanoid:MoveTo(goal)
		end
	end

	-- stuck detection
	local now = os.clock()
	if not c.LastProgressPos or (pos - c.LastProgressPos).Magnitude > 1.2 then
		c.LastProgressPos = pos
		c.LastProgressAt = now
	elseif now - c.LastProgressAt > 1.4 then
		c.Humanoid.Jump = true
		c.Waypoints = nil
		if now - c.LastProgressAt > 5 then
			-- hopelessly stuck: hop a few studs toward the goal
			local dir = flat(goal - pos)
			if dir.Magnitude > 0.1 then
				c.Model:PivotTo(CFrame.new(pos + dir.Unit * math.min(6, dir.Magnitude) + Vector3.new(0, 2, 0)))
			end
			c.LastProgressAt = now
		end
	end
	return false
end

local function leaderRoot(c)
	local p = c.Leader
	local char = p and p.Parent and p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return hrp
	end
	return nil
end

function NpcService.GetLeaderRoot(model)
	local c = controllers[model]
	return c and leaderRoot(c)
end

function NpcService._step(dt)
	for model, set in pairs(animSets) do
		local hrp = model.Parent and model:FindFirstChild("HumanoidRootPart")
		if hrp and not hrp.Anchored then
			if not set.RayParams then
				set.RayParams = RaycastParams.new()
				set.RayParams.FilterType = Enum.RaycastFilterType.Exclude
				set.RayParams.FilterDescendantsInstances = { model }
			end
			updateLocomotion(set, hrp, dt)
		end
	end

	for model, c in pairs(controllers) do
		if not model.Parent or not c.Root or not c.Root.Parent then
			controllers[model] = nil
			continue
		end
		if c.Root.Anchored or c.Mode == "None" then
			continue
		end
		c.Accum += dt
		if c.Accum < 0.12 then
			continue
		end
		c.Accum = 0

		if c.Mode == "Follow" or c.Mode == "Chase" then
			local lr = leaderRoot(c)
			if lr then
				local look = flat(lr.CFrame.LookVector)
				look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
				local right = look:Cross(Vector3.yAxis)
				local goal
				local arrive
				if c.Mode == "Chase" then
					goal, arrive = lr.Position, 1
				else
					goal = lr.Position - look * Constants.NPC.FollowGap + right * c.Offset
					arrive = 2.2
				end
				local gap = flat(goal - c.Root.Position).Magnitude
				if gap > Constants.NPC.TeleportIfFartherThan then
					model:PivotTo(CFrame.new(goal + Vector3.new(0, 3, 0), goal + look))
					c.Waypoints = nil
				elseif steer(c, goal, arrive) and c.Mode == "Follow" then
					-- idle next to the leader: turn to face them
					local to = flat(lr.Position - c.Root.Position)
					if to.Magnitude > 0.5 then
						c.Root.CFrame = CFrame.lookAt(c.Root.Position, c.Root.Position + to)
					end
				end
			else
				c.Humanoid:MoveTo(c.Root.Position)
			end
		elseif c.Mode == "ChaseModel" then
			local tr = c.TargetModel and c.TargetModel.Parent and c.TargetModel:FindFirstChild("HumanoidRootPart")
			if tr then
				steer(c, tr.Position, 1)
			else
				c.Humanoid:MoveTo(c.Root.Position)
			end
		elseif c.Mode == "WalkTo" then
			if steer(c, c.Target, 1.6) then
				c.Mode = "None"
				local cb = c.OnArrive
				c.OnArrive, c.OnFail = nil, nil
				if cb then
					task.spawn(cb, model)
				end
			elseif os.clock() > c.Deadline then
				c.Mode = "None"
				local cb = c.OnFail
				c.OnArrive, c.OnFail = nil, nil
				if cb then
					task.spawn(cb, model)
				end
			end
		end
	end
end

return NpcService
