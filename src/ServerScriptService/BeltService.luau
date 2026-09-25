--[[
	BeltService
	The shared conveyor down the middle of the map. The BeltTrack part is a real
	physics conveyor (its AssemblyLinearVelocity carries anything standing on
	it), so characters ride it as physical R15 models and replicate smoothly.

	Every few seconds it rolls the next character from ReplicatedStorage.Modules
	.Characters (rarity by Odds, then character by SpawnWeight) and drops it at
	the tunnel. Rarity events (sounds, conveyor color, banners, G.O.A.T. server
	events) are broadcast to clients through Remotes.CharacterFx; server-side
	spectacle (spotlights, gold particles) is created here. Unsold characters
	leave at BeltEnd.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local Characters = require(RS.Modules.Characters)
local InfluencerService = require(SSS.InfluencerService)
local Notify = require(SSS.Notify)

local BeltService = {}

local FxRemote = RS:WaitForChild("Remotes"):WaitForChild("CharacterFx")

-- A light that follows a character around for a few seconds (spawn spectacle).
local function followSpotlight(model, color, duration)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local rig = Instance.new("Part")
	rig.Name = "SpawnSpotlight"
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.Transparency = 1
	rig.Size = Vector3.new(1, 1, 1)
	rig.Parent = workspace
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 38
	spot.Range = 45
	spot.Brightness = 10
	spot.Color = color
	spot.Shadows = true
	spot.Parent = rig
	local beam = Instance.new("Part")
	beam.Name = "LightBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.82
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(30, 7, 7)
	beam.CastShadow = false
	beam.Parent = workspace
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local alive = root.Parent and os.clock() - t0 < duration
		if not alive then
			conn:Disconnect()
			rig:Destroy()
			beam:Destroy()
			return
		end
		local p = root.Position
		rig.CFrame = CFrame.new(p + Vector3.new(0, 30, 0))
		beam.CFrame = CFrame.new(p + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local fade = math.clamp((duration - (os.clock() - t0)) / 1.5, 0, 1)
		beam.Transparency = 1 - 0.18 * fade
		spot.Brightness = 10 * fade
	end)
end

local function goldBurst(model, duration)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 180, 20))
	pe.LightEmission = 1
	pe.Rate = 80
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(4, 10)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Acceleration = Vector3.new(0, 3, 0)
	pe.Parent = att
	task.delay(duration, function()
		pe.Enabled = false
		task.delay(3, function()
			att:Destroy()
		end)
	end)
end

local function announce(char, rarity, model)
	local fx = char.SpawnFx
	if fx == "GoldSpotlight" then
		followSpotlight(model, Color3.fromRGB(255, 205, 70), 9)
	elseif fx == "Cinematic" then
		followSpotlight(model, Color3.fromRGB(235, 240, 255), 6)
	elseif fx == "GoldenEra" then
		followSpotlight(model, Color3.fromRGB(255, 215, 90), 10)
		goldBurst(model, 8)
	elseif rarity.Index >= 7 then
		goldBurst(model, 5)
	end

	FxRemote:FireAllClients("Spawn", {
		Model = model,
		Id = char.Name,
		Name = char.DisplayName,
		Rarity = char.Rarity,
		SpawnFx = fx,
	})

	if rarity.Announce then
		local text
		if rarity.Index >= 7 then
			text = "A G.O.A.T. HAS ENTERED THE GYM: " .. char.DisplayName:upper() .. "!"
		elseif rarity.Index >= 6 then
			text = "MYTHIC " .. char.DisplayName:upper() .. " just walked onto the conveyor!"
		else
			text = rarity.DisplayName .. " " .. char.DisplayName .. " just hit the red carpet!"
		end
		for _, player in ipairs(Players:GetPlayers()) do
			Notify(player, text, "info")
		end
	end
end

function BeltService.OnPurchased(rec, buyer)
	FxRemote:FireAllClients("Purchase", {
		Model = rec.Model,
		Id = rec.Id,
		Rarity = rec.Char.Rarity,
		Buyer = buyer,
	})
end

local rng = Random.new()
local spawnTimer = 0
local track, startPart, endPart
local direction = Vector3.new(0, 0, 1)
local dropPoints = {}
local dropQueue = {}

-- Shuffled round-robin: each chute gets one drop per cycle (fair to every gym).
local function nextDropPoint()
	if #dropQueue == 0 then
		for _, p in ipairs(dropPoints) do
			table.insert(dropQueue, p)
		end
		for i = #dropQueue, 2, -1 do
			local j = rng:NextInteger(1, i)
			dropQueue[i], dropQueue[j] = dropQueue[j], dropQueue[i]
		end
	end
	return table.remove(dropQueue)
end

function BeltService.Init()
	local belt = workspace:WaitForChild("GymWarsMap"):WaitForChild("Belt")
	track = belt:WaitForChild("BeltTrack")
	startPart = belt:WaitForChild("BeltStart")
	endPart = belt:WaitForChild("BeltEnd")
	direction = (endPart.Position - startPart.Position) * Vector3.new(1, 0, 1)
	direction = direction.Unit
	track.AssemblyLinearVelocity = direction * Constants.BELT.Speed
	for _, d in ipairs(belt:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("DropPoint") then
			table.insert(dropPoints, d)
		end
	end
	if #dropPoints == 0 then
		table.insert(dropPoints, startPart)
	end
	track:SetAttribute("Speed", Constants.BELT.Speed)
	InfluencerService.OnPurchased = BeltService.OnPurchased
	workspace:SetAttribute("BeltSpeed", Constants.BELT.Speed)

	RunService.Heartbeat:Connect(function(dt)
		BeltService.Step(dt)
	end)
end

local checkAccum = 0
local lastPreviewEvent = -math.huge
function BeltService.Step(dt)
	local cfg = Constants.BELT
	-- keep the conveyor running (in case something reset it)
	if track.AssemblyLinearVelocity.Magnitude < 0.1 then
		track.AssemblyLinearVelocity = direction * cfg.Speed
	end

	checkAccum += dt
	if checkAccum >= 0.25 then
		checkAccum = 0
		local endDist = (endPart.Position - startPart.Position):Dot(direction)
		for _, rec in ipairs(InfluencerService.GetAllOnBelt()) do
			local rel = rec.Root.Position - startPart.Position
			local along = rel:Dot(direction)
			local lateral = (rel - direction * along) * Vector3.new(1, 0, 1)
			if along >= endDist then
				InfluencerService.Destroy(rec)
			elseif lateral.Magnitude > track.Size.X / 2 + 2 then
				InfluencerService.DropFromBelt(rec) -- fell off the side
			end
		end
	end

	spawnTimer += dt
	if spawnTimer >= cfg.SpawnInterval then
		spawnTimer = 0
		if InfluencerService.CountOnBelt() < cfg.MaxOnBelt then
			local char = Characters.Roll(rng)
			local rarity = Characters.GetRarity(char.Rarity)
			local drop = nextDropPoint()
			local pos = drop.Position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, 0)
			if char.SpawnFx == "HeavyLanding" then
				pos += Vector3.new(0, 22, 14) -- drops from high up (clear of the tunnel roof) and slams onto the belt
			end
			-- avatar creation can yield (asset loading), so don't block Heartbeat
			task.spawn(function()
				local rec = InfluencerService.Spawn(char, CFrame.new(pos))
				if rec and rec.Model then
					local now = os.clock()
					if not Characters.PREVIEW or now - lastPreviewEvent >= Characters.PREVIEW_EVENT_COOLDOWN then
						lastPreviewEvent = now
						announce(char, rarity, rec.Model)
					end
				end
			end)
		end
	end
end

return BeltService
