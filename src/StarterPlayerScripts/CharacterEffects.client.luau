--[[
	CharacterEffects (client)
	Everything players see/hear around rarity — all data-driven from
	ReplicatedStorage.Modules.Characters:
	  - spawn sounds (3D for low rarities, server-wide for Legendary+)
	  - conveyor glow flashes in the rarity color; Mythic/G.O.A.T. recolor the belt
	  - big banners for Mythic and G.O.A.T. ("A G.O.A.T. HAS ENTERED THE GYM.")
	  - G.O.A.T.: gym lights flicker; Arnie shifts the whole world's lighting gold;
	    Ronnie slams onto the belt (camera shake + metallic impact)
	  - purchase bursts (particles, shockwave ring and flash for higher rarities)
	  - animated gradients on high-rarity name cards; Jeff's floating chart
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Characters = require(RS:WaitForChild("Modules"):WaitForChild("Characters"))
local FxRemote = RS:WaitForChild("Remotes"):WaitForChild("CharacterFx")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local map = workspace:WaitForChild("GymWarsMap")
local influencers = workspace:WaitForChild("Influencers", 30)

-- ----------------------------------------------------------------------
-- Sound
-- ----------------------------------------------------------------------
local function playSound(def, parent, volumeMul)
	if not def or not def.Id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = (def.Volume or 0.5) * (volumeMul or 1)
	s.PlaybackSpeed = def.Pitch or 1
	s.RollOffMaxDistance = 220
	s.Parent = parent or workspace
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

-- ----------------------------------------------------------------------
-- Conveyor color
-- ----------------------------------------------------------------------
local beltGlow, chevrons = {}, {}
do
	local belt = map:WaitForChild("Belt", 10)
	if belt then
		for _, d in ipairs(belt:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "BeltGlow" or d.Name == "TunnelGlow" then
					table.insert(beltGlow, { Part = d, Color = d.Color })
				elseif d.Parent and d.Parent.Name == "Chevron" then
					table.insert(chevrons, { Part = d, Color = d.Color, Material = d.Material })
				end
			end
		end
	end
end

local beltToken = 0
local function tintConveyor(color, seconds, recolorBelt)
	beltToken += 1
	local token = beltToken
	for _, g in ipairs(beltGlow) do
		g.Part.Color = color
	end
	if recolorBelt then
		for _, c in ipairs(chevrons) do
			c.Part.Color = color
			c.Part.Material = Enum.Material.Neon
		end
	end
	task.delay(seconds, function()
		if token ~= beltToken then
			return
		end
		for _, g in ipairs(beltGlow) do
			g.Part.Color = g.Color
		end
		for _, c in ipairs(chevrons) do
			c.Part.Color = c.Color
			c.Part.Material = c.Material
		end
	end)
end

-- ----------------------------------------------------------------------
-- Banner
-- ----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RarityEvents"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function banner(title, subtitle, rarity, seconds)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.12, 0)
	frame.Size = UDim2.new(0.7, 0, 0.14, 0)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 3
	stroke.Parent = frame

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -20, 0.62, 0)
	t.Position = UDim2.new(0, 10, 0.02, 0)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = frame
	if rarity.Gradient then
		local g = Instance.new("UIGradient")
		local keys = {}
		for i, c in ipairs(rarity.Gradient) do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#rarity.Gradient - 1, 1), c))
		end
		g.Color = ColorSequence.new(keys)
		g.Parent = t
		task.spawn(function()
			local t0 = os.clock()
			while g.Parent and os.clock() - t0 < seconds do
				g.Offset = Vector2.new(math.sin((os.clock() - t0) * 3) * 0.5, 0)
				task.wait()
			end
		end)
	end
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -20, 0.32, 0)
	sub.Position = UDim2.new(0, 10, 0.64, 0)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = rarity.Color
	sub.Text = subtitle
	sub.Parent = frame

	frame.Size = UDim2.new(0.2, 0, 0.04, 0)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0.14, 0) }):Play()
	task.delay(seconds, function()
		local tw = TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		tw:Play()
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		tw.Completed:Wait()
		frame:Destroy()
	end)
end

-- ----------------------------------------------------------------------
-- Big-moment effects
-- ----------------------------------------------------------------------
local function flickerGymLights(seconds)
	local lights = {}
	local plots = map:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, d in ipairs(plots:GetDescendants()) do
		if d:IsA("SurfaceLight") or d:IsA("PointLight") or d:IsA("SpotLight") then
			table.insert(lights, { L = d, B = d.Brightness })
		end
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			local on = math.random() < 0.55
			for _, l in ipairs(lights) do
				l.L.Brightness = on and l.B or l.B * 0.08
			end
			task.wait(math.random(4, 12) / 100)
		end
		for _, l in ipairs(lights) do
			l.L.Brightness = l.B
		end
	end)
end

local function goldenWorld(seconds)
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		return
	end
	local orig = { TintColor = cc.TintColor, Brightness = cc.Brightness, Saturation = cc.Saturation, Contrast = cc.Contrast }
	TweenService:Create(cc, TweenInfo.new(0.8), { TintColor = Color3.fromRGB(255, 214, 140), Brightness = 0.08, Saturation = 0.25, Contrast = 0.15 }):Play()
	task.delay(seconds, function()
		TweenService:Create(cc, TweenInfo.new(1.6), orig):Play()
	end)
end

local function shakeCamera(strength, seconds)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > seconds then
			conn:Disconnect()
			return
		end
		local k = strength * (1 - t / seconds)
		camera.CFrame = camera.CFrame * CFrame.new(math.noise(t * 20, 0) * k, math.noise(0, t * 20) * k, 0)
			* CFrame.Angles(0, 0, math.noise(t * 15, 5) * k * 0.02)
	end)
end

local function shockwave(position, color, size)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.8)
end

local function burst(root, rarity, count)
	local att = Instance.new("Attachment")
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(rarity.Color, rarity.Glow)
	pe.LightEmission = 1
	pe.Enabled = false
	pe.Lifetime = NumberRange.new(0.6, 1.4)
	pe.Speed = NumberRange.new(8, 22)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Drag = 3
	pe.Parent = att
	pe:Emit(count)
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 18
	light.Brightness = 3 + rarity.Index
	light.Parent = att
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(att, 2)
end

local function waitForLanding(root, callback)
	task.spawn(function()
		local t0 = os.clock()
		local fell = false
		while root.Parent and os.clock() - t0 < 4 do
			local vy = root.AssemblyLinearVelocity.Y
			if vy < -10 then
				fell = true
			elseif fell and vy > -2 then
				break
			end
			task.wait()
		end
		if root.Parent then
			callback()
		end
	end)
end

-- ----------------------------------------------------------------------
-- Events from the server
-- ----------------------------------------------------------------------
FxRemote.OnClientEvent:Connect(function(kind, data)
	local rarity = Characters.GetRarity(data.Rarity)
	if not rarity then
		return
	end
	local model = data.Model
	local root = model and model:FindFirstChild("HumanoidRootPart")

	if kind == "Spawn" then
		local global = rarity.Index >= 5
		playSound(rarity.SpawnSound, (not global) and root or nil)
		if rarity.ConveyorFlash then
			tintConveyor(rarity.ConveyorColor or rarity.Glow, rarity.ConveyorFlash, rarity.ConveyorColor ~= nil)
		elseif rarity.Index >= 3 then
			tintConveyor(rarity.Glow, 1.2, false)
		end
		if rarity.Index >= 7 then
			playSound(rarity.SpawnSound, nil, 1)
			task.delay(0.35, function()
				playSound({ Id = rarity.SpawnSound.Id, Volume = 1, Pitch = 0.22 })
			end)
			banner("A G.O.A.T. HAS ENTERED THE GYM.", data.Name:upper(), rarity, 7)
			flickerGymLights(2.5)
		elseif rarity.Index == 6 then
			banner("A MYTHIC HAS APPEARED!", data.Name:upper(), rarity, 5)
		elseif data.SpawnFx == "Milestone" then
			banner("FIRST $1 BILLION/SEC CHARACTER!", data.Name:upper(), rarity, 4)
		end
		if data.SpawnFx == "GoldenEra" then
			goldenWorld(6)
		elseif data.SpawnFx == "HeavyLanding" and root then
			waitForLanding(root, function()
				playSound({ Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 0.45 }, root)
				playSound({ Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 0.3 }, root)
				shockwave(root.Position - Vector3.new(0, 3, 0), rarity.Color, 30)
				local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local d = myRoot and (myRoot.Position - root.Position).Magnitude or 999
				if d < 200 then
					shakeCamera(1.6 * (1 - d / 200) + 0.3, 0.9)
				end
			end)
		end
	elseif kind == "Purchase" then
		if root then
			playSound(rarity.PurchaseSound, root)
			burst(root, rarity, rarity.Particles or 10)
			if rarity.Index >= 4 then
				shockwave(root.Position - Vector3.new(0, 2.5, 0), rarity.Color, 10 + rarity.Index * 3)
			end
		end
		if data.Buyer == player and rarity.Index >= 6 then
			banner("YOU GOT " .. (Characters.Get(data.Id) and Characters.Get(data.Id).DisplayName:upper() or "IT") .. "!", rarity.DisplayName, rarity, 3)
		end
	end
end)

-- ----------------------------------------------------------------------
-- Ambient: animated rarity gradients + Jeff's chart
-- ----------------------------------------------------------------------
local chartNext = {}
RunService.Heartbeat:Connect(function()
	if not influencers then
		return
	end
	local t = os.clock()
	for _, model in ipairs(influencers:GetChildren()) do
		local head = model:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("NameTag")
		if tag and tag:GetAttribute("AnimatedGradient") then
			for _, l in ipairs(tag:GetChildren()) do
				local g = l:FindFirstChildOfClass("UIGradient")
				if g then
					g.Offset = Vector2.new(math.sin(t * 2 + l.LayoutOrder) * 0.4, 0)
				end
			end
		end
		if model:GetAttribute("Chart") and head then
			local nextAt = chartNext[model]
			if not nextAt then
				chartNext[model] = t + math.random(3, 8)
			elseif t >= nextAt then
				chartNext[model] = t + math.random(7, 12)
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.new(0, 60, 0, 60)
				bb.StudsOffsetWorldSpace = Vector3.new(1.8, 2, 0)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.Parent = head
				local l = Instance.new("TextLabel")
				l.BackgroundTransparency = 1
				l.Size = UDim2.new(1, 0, 1, 0)
				l.Text = "📈"
				l.TextScaled = true
				l.Parent = bb
				TweenService:Create(bb, TweenInfo.new(2.2), { StudsOffsetWorldSpace = Vector3.new(1.8, 4.5, 0) }):Play()
				TweenService:Create(l, TweenInfo.new(2.2), { TextTransparency = 1 }):Play()
				Debris:AddItem(bb, 2.3)
			end
		end
	end
end)

if influencers then
	influencers.ChildRemoved:Connect(function(m)
		chartNext[m] = nil
	end)
end
