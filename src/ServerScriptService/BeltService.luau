--[[
	BeltService
	The shared conveyor down the middle of the map. The BeltTrack part is a real
	physics conveyor (its AssemblyLinearVelocity carries anything standing on
	it), so influencers ride it as physical characters and replicate smoothly.
	Spawns rarity-weighted influencers at BeltStart and removes whoever nobody
	claimed once they reach BeltEnd. Claiming is InfluencerService's prompt.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local InfluencerService = require(SSS.InfluencerService)
local Notify = require(SSS.Notify)

local BeltService = {}

local rng = Random.new()
local spawnTimer = 0
local track, startPart, endPart
local direction = Vector3.new(0, 0, 1)

function BeltService.Init()
	local belt = workspace:WaitForChild("GymWarsMap"):WaitForChild("Belt")
	track = belt:WaitForChild("BeltTrack")
	startPart = belt:WaitForChild("BeltStart")
	endPart = belt:WaitForChild("BeltEnd")
	direction = (endPart.Position - startPart.Position) * Vector3.new(1, 0, 1)
	direction = direction.Unit
	track.AssemblyLinearVelocity = direction * Constants.BELT.Speed
	track:SetAttribute("Speed", Constants.BELT.Speed)
	workspace:SetAttribute("BeltSpeed", Constants.BELT.Speed)

	RunService.Heartbeat:Connect(function(dt)
		BeltService.Step(dt)
	end)
end

local checkAccum = 0
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
			local rarityIdx = Constants.RollRarity(rng)
			local spawnCF = CFrame.new(startPart.Position + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, 0))
			-- avatar creation can yield (asset loading), so don't block Heartbeat
			task.spawn(function()
				local rec = InfluencerService.Spawn(rarityIdx, spawnCF)
				if rarityIdx >= 4 then
					-- Epic / Legendary: let the whole server know
					local rarity = Constants.RARITIES[rarityIdx]
					for _, player in ipairs(Players:GetPlayers()) do
						Notify(player, rarity.Name:upper() .. " " .. rec.Name .. " just hit the red carpet!", "info")
					end
				end
			end)
		end
	end
end

return BeltService
