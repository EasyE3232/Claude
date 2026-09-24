--[[
	InfluencerService
	Owns every influencer NPC (a real R15 character) and its lifecycle:

	  OnBelt    -> standing on the conveyor, riding it (claimable by anyone)
	  Following -> walking behind the player who claimed them, slower than the
	               player (Constants.NPC.FollowSpeed), pathfinding around walls
	  Seating   -> inside the owner's gym, walking to their machine
	  Placed    -> training on a machine (anchored; clients animate the workout),
	               earning Cash for the plot owner
	  Returning -> walking back to their machine after the front desk caught a thief
	  Dropped   -> standing around unowned (leader died/left), claimable, leaves later

	Stealing: grabbing a Placed influencer in someone else's gym makes it follow
	the thief with OriginPlotId/OriginSlot remembered. If the thief is caught it
	walks back to its machine; if it reaches the thief's gym it becomes theirs.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local PlayerDataService = require(SSS.PlayerDataService)
local PlotService = require(SSS.PlotService)
local NpcService = require(SSS.NpcService)
local StationSpecs = require(RS.Modules.Gym.StationSpecs)
local Notify = require(SSS.Notify)

local InfluencerService = {}

-- Callbacks set by DefenseService
InfluencerService.OnTheftStarted = nil -- function(rec, thiefPlayer, victimPlot)
InfluencerService.OnTheftEnded = nil -- function(rec, victimPlot)

local records = {} -- [model] = rec
local carriedBy = {} -- [userId] = rec  (the influencer following that player)
local rackFullDebounce = {} -- [userId] = os.clock()
local folder = nil
local rng = Random.new()

-- ----------------------------------------------------------------------
-- Model construction
-- ----------------------------------------------------------------------
local function looksFor(rec)
	local r = Random.new(rec.Seed)
	local rarity = Constants.RARITIES[rec.Rarity]
	local tier = rec.Rarity - 1
	return {
		Name = rec.Name,
		Skin = Constants.SKIN_TONES[r:NextInteger(1, #Constants.SKIN_TONES)],
		Shirt = rarity.Color,
		Pants = Color3.fromRGB(28 + r:NextInteger(0, 20), 30 + r:NextInteger(0, 20), 38 + r:NextInteger(0, 24)),
		Height = 1 + r:NextNumber(0, 0.06) + tier * 0.01,
		Width = 1 + r:NextNumber(0, 0.06) + tier * 0.05,
		Depth = 1 + r:NextNumber(0, 0.05) + tier * 0.04,
		AvatarUserId = Constants.INFLUENCER_AVATARS[rec.Name],
		Scale = StationSpecs.SCALE,
	}
end

local function buildModel(rec)
	local rarity = Constants.RARITIES[rec.Rarity]
	local model = NpcService.CreateRig(looksFor(rec))
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head") or root

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.new(0, 170, 0, 46)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	tag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = rec.Name
	nameLabel.Parent = tag

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.6, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.Color
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Text = rarity.Name .. "  +$" .. Constants.FormatNumber(rec.Income) .. "/s"
	rarityLabel.Parent = tag

	if rec.Rarity >= 4 then
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = rarity.Color
		sparkle.Parent = root
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Claim"
	prompt.ObjectText = rec.Name
	prompt.HoldDuration = Constants.BELT.ClaimHold
	prompt.MaxActivationDistance = Constants.BELT.ClaimDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local stationRef = Instance.new("ObjectValue")
	stationRef.Name = "Station"
	stationRef.Parent = model

	model:SetAttribute("Rarity", rec.Rarity)
	model:SetAttribute("Income", rec.Income)
	model:SetAttribute("Seed", rec.Seed)
	model:SetAttribute("State", rec.State)
	model:SetAttribute("OwnerUserId", 0)

	rec.Model = model
	rec.Root = root
	rec.Humanoid = model:FindFirstChildOfClass("Humanoid")
	rec.Prompt = prompt
	rec.StationRef = stationRef
	records[model] = rec

	prompt.Triggered:Connect(function(player)
		InfluencerService.OnGrab(player, rec)
	end)
	return model
end

local function setState(rec, state)
	rec.State = state
	if rec.Model then
		rec.Model:SetAttribute("State", state)
		if rec.Prompt then
			rec.Prompt.Enabled = state == "OnBelt" or state == "Dropped" or state == "Placed"
			rec.Prompt.ActionText = state == "Placed" and "Steal" or "Claim"
		end
	end
end

local function setAnchored(rec, anchored)
	if rec.Root then
		rec.Root.Anchored = anchored
		if rec.Humanoid then
			rec.Humanoid.PlatformStand = anchored
		end
		if not anchored then
			NpcService.Activate(rec.Model)
		end
	end
end

-- ----------------------------------------------------------------------
-- Profile helpers (persist placed influencers)
-- ----------------------------------------------------------------------
local function removeFromProfile(player, slot)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return
	end
	for i = #profile.Placed, 1, -1 do
		if profile.Placed[i].Slot == slot then
			table.remove(profile.Placed, i)
		end
	end
end

local function addToProfile(player, rec)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return
	end
	removeFromProfile(player, rec.Slot)
	table.insert(profile.Placed, { Rarity = rec.Rarity, Name = rec.Name, Slot = rec.Slot, Seed = rec.Seed })
end

local function refreshRackAttr(plot)
	local owner = PlotService.GetOwnerPlayer(plot)
	if owner then
		owner:SetAttribute("RackUsed", PlotService.CountPlaced(plot.Id))
		owner:SetAttribute("RackSlots", plot.Unlocked)
	end
end

-- ----------------------------------------------------------------------
-- Following (the old "carry")
-- ----------------------------------------------------------------------
local function setWalkSpeed(player, speed)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and not player:GetAttribute("Stunned") then
		humanoid.WalkSpeed = speed
	end
end

local function hopOffBelt(rec)
	-- step off the conveyor rails with a little hop
	if rec.Humanoid then
		rec.Humanoid.Jump = true
	end
end

-- Get off a machine: stand upright at the machine's approach point, unanchored.
local function standUp(rec)
	local station = rec.StationRef.Value
	local approach = station and station:FindFirstChild("Approach")
	local pos = approach and approach.Position or rec.Root.Position
	local look = rec.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	rec.Model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3.2, 0), pos + Vector3.new(0, 3.2, 0) + look.Unit))
	setAnchored(rec, false)
	NpcService.SetAnimationsEnabled(rec.Model, true)
	rec.StationRef.Value = nil
end

local function startFollow(player, rec)
	local wasOnBelt = rec.State == "OnBelt"
	if rec.Root.Anchored then
		standUp(rec)
	end
	setWalkSpeed(player, Constants.CARRY_WALKSPEED)
	setState(rec, "Following")
	rec.CarrierUserId = player.UserId
	rec.Model:SetAttribute("OwnerUserId", player.UserId)
	carriedBy[player.UserId] = rec
	player:SetAttribute("Carrying", rec.Name)
	NpcService.Follow(rec.Model, player, Constants.NPC.FollowSpeed, 0)
	if wasOnBelt then
		hopOffBelt(rec)
	end
end

local function endFollow(rec)
	local uid = rec.CarrierUserId
	if uid then
		if carriedBy[uid] == rec then
			carriedBy[uid] = nil
		end
		local player = Players:GetPlayerByUserId(uid)
		if player then
			player:SetAttribute("Carrying", "")
			setWalkSpeed(player, Constants.NORMAL_WALKSPEED)
		end
	end
	rec.CarrierUserId = nil
	if rec.Model then
		NpcService.Stop(rec.Model)
	end
end

-- Anchor the NPC on its machine; clients take over and animate the workout.
local function sitOnStation(rec, plot, slot, timeOffset)
	local station = PlotService.GetStation(plot.Id, slot)
	setState(rec, "Placed")
	rec.PlotId = plot.Id
	rec.Slot = slot
	plot.Slots[slot] = rec
	NpcService.Stop(rec.Model)
	NpcService.SetAnimationsEnabled(rec.Model, false)
	if station then
		local rider = station:FindFirstChild("Rider")
		setAnchored(rec, true)
		rec.Root.CFrame = rider and rider.CFrame or station:GetPivot()
		rec.StationRef.Value = station
	end
	rec.Model:SetAttribute("OwnerUserId", plot.OwnerUserId)
	-- clients animate from this timestamp (offset = start mid-workout, e.g. after a rejoin)
	rec.Model:SetAttribute("SeatedAt", workspace:GetServerTimeNow() - (timeOffset or 0))
	refreshRackAttr(plot)
end

-- Walk to the machine's approach point, then hop on.
local function walkToStation(rec, plot, slot, speed, state)
	local station = PlotService.GetStation(plot.Id, slot)
	setState(rec, state or "Seating")
	rec.PlotId = plot.Id
	rec.Slot = slot
	plot.Slots[slot] = rec -- reserve the slot right away
	rec.Model:SetAttribute("OwnerUserId", plot.OwnerUserId)
	refreshRackAttr(plot)
	local approach = station and station:FindFirstChild("Approach")
	if not approach then
		sitOnStation(rec, plot, slot)
		return
	end
	local token = {}
	rec.SeatToken = token
	local function arrive()
		if rec.SeatToken == token and rec.Model and plot.Slots[slot] == rec then
			sitOnStation(rec, plot, slot)
		end
	end
	NpcService.WalkTo(rec.Model, approach.Position, speed or Constants.NPC.SeatSpeed, arrive, Constants.NPC.SeatTimeout, arrive)
end

local function dropHere(rec)
	setState(rec, "Dropped")
	rec.PlotId = nil
	rec.Slot = nil
	rec.DroppedAt = os.clock()
	rec.Model:SetAttribute("OwnerUserId", 0)
	if rec.Root.Anchored then
		standUp(rec)
	end
	rec.StationRef.Value = nil
	NpcService.Stop(rec.Model)
end

-- ----------------------------------------------------------------------
-- Public: spawning / destroying
-- ----------------------------------------------------------------------
function InfluencerService.Init()
	folder = workspace:FindFirstChild("Influencers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Influencers"
		folder.Parent = workspace
	end

	RunService.Heartbeat:Connect(function(dt)
		InfluencerService.Update(dt)
	end)
end

local function newRecord(rarityIdx, name, seed, state)
	local rarity = Constants.RARITIES[rarityIdx] or Constants.RARITIES[1]
	return {
		Rarity = rarityIdx,
		Name = name or rarity.Names[rng:NextInteger(1, #rarity.Names)],
		Income = rarity.Income,
		Seed = seed or rng:NextInteger(1, 2 ^ 30),
		State = state,
	}
end

-- Spawn a new influencer on the belt at `spawnCF` (facing sideways, toward the gyms).
function InfluencerService.Spawn(rarityIdx, spawnCF)
	local rec = newRecord(rarityIdx, nil, nil, "OnBelt")
	local model = buildModel(rec)
	setState(rec, "OnBelt")
	local side = rng:NextNumber() < 0.5 and 1 or -1
	local pos = spawnCF.Position
	model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(side, 0, 0)))
	model.Parent = folder
	NpcService.Activate(model)
	return rec
end

function InfluencerService.Destroy(rec)
	if not rec or not rec.Model then
		return
	end
	if rec.CarrierUserId then
		endFollow(rec)
	end
	if rec.PlotId and rec.Slot then
		local plot = PlotService.GetPlotById(rec.PlotId)
		if plot and plot.Slots[rec.Slot] == rec then
			plot.Slots[rec.Slot] = nil
			refreshRackAttr(plot)
		end
	end
	if rec.OriginPlotId and rec.OriginSlot then
		local plot = PlotService.GetPlotById(rec.OriginPlotId)
		if plot and plot.Slots[rec.OriginSlot] == rec then
			plot.Slots[rec.OriginSlot] = nil
			refreshRackAttr(plot)
		end
	end
	NpcService.Forget(rec.Model)
	records[rec.Model] = nil
	rec.Model:Destroy()
	rec.Model = nil
end

function InfluencerService.GetAllOnBelt()
	local list = {}
	for _, rec in pairs(records) do
		if rec.State == "OnBelt" then
			table.insert(list, rec)
		end
	end
	return list
end

function InfluencerService.CountOnBelt()
	local n = 0
	for _, rec in pairs(records) do
		if rec.State == "OnBelt" then
			n += 1
		end
	end
	return n
end

-- ----------------------------------------------------------------------
-- Public: grabbing (claim or steal)
-- ----------------------------------------------------------------------
function InfluencerService.OnGrab(player, rec)
	if not rec.Model then
		return
	end
	local uid = player.UserId
	if player:GetAttribute("Stunned") then
		return
	end
	-- server-side range check (prompts are client-evaluated)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - rec.Root.Position).Magnitude > Constants.BELT.ClaimDistance + 6 then
		return
	end
	if not PlotService.GetPlotByOwner(uid) then
		Notify(player, "All gyms are taken — you need a gym to hold influencers.", "fail")
		return
	end

	if rec.State == "OnBelt" or rec.State == "Dropped" then
		if carriedBy[uid] then
			Notify(player, "Someone is already following you! Get them to your gym first.", "fail")
			return
		end
		startFollow(player, rec)
		Notify(player, rec.Name .. " is following you! Lead them to your gym.", "success")
		return
	end

	if rec.State == "Placed" then
		local plot = PlotService.GetPlotById(rec.PlotId)
		if not plot then
			return
		end
		if plot.OwnerUserId == uid then
			Notify(player, rec.Name .. " is already training at your gym.", "info")
			return
		end
		if carriedBy[uid] then
			Notify(player, "Someone is already following you!", "fail")
			return
		end
		-- THEFT: keep the origin slot reserved so it can return if the thief is caught
		rec.OriginPlotId = plot.Id
		rec.OriginSlot = rec.Slot
		rec.PlotId = nil
		rec.Slot = nil
		startFollow(player, rec)
		refreshRackAttr(plot)

		local victim = PlotService.GetOwnerPlayer(plot)
		Notify(player, "You lured " .. rec.Name .. " away! Get them to YOUR gym before the front desk catches you!", "info")
		if victim then
			Notify(victim, player.DisplayName .. " is stealing your " .. rec.Name .. "!", "fail")
		end
		if InfluencerService.OnTheftStarted then
			InfluencerService.OnTheftStarted(rec, player, plot)
		end
	end
end

function InfluencerService.GetCarried(player)
	return carriedBy[player.UserId]
end

function InfluencerService.GetCarrierPlayer(rec)
	return rec.CarrierUserId and Players:GetPlayerByUserId(rec.CarrierUserId) or nil
end

-- ----------------------------------------------------------------------
-- Public: placing / dropping / returning
-- ----------------------------------------------------------------------
-- The follower walked into its leader's gym: claim a slot and walk to the machine.
function InfluencerService.Place(rec, plot, slot, ownerPlayer)
	if rec.OriginPlotId then
		local originPlot = PlotService.GetPlotById(rec.OriginPlotId)
		if originPlot then
			if originPlot.Slots[rec.OriginSlot] == rec then
				originPlot.Slots[rec.OriginSlot] = nil
			end
			local victim = PlotService.GetOwnerPlayer(originPlot)
			if victim then
				removeFromProfile(victim, rec.OriginSlot)
				Notify(victim, (ownerPlayer and ownerPlayer.DisplayName or "Someone") .. " stole your " .. rec.Name .. "!", "fail")
			end
			refreshRackAttr(originPlot)
			if InfluencerService.OnTheftEnded then
				InfluencerService.OnTheftEnded(rec, originPlot)
			end
		end
		rec.OriginPlotId = nil
		rec.OriginSlot = nil
	end

	endFollow(rec)
	walkToStation(rec, plot, slot)

	local owner = ownerPlayer or PlotService.GetOwnerPlayer(plot)
	if owner then
		addToProfile(owner, rec)
		local station = PlotService.GetStation(plot.Id, slot)
		local what = station and PlotService.StationName(station) or "a machine"
		Notify(owner, rec.Name .. " is heading to the " .. what .. "! +$" .. Constants.FormatNumber(rec.Income) .. "/s", "success")
	end
end

-- Thief caught: walk back to the original machine.
function InfluencerService.ReturnToOrigin(rec)
	local originPlot = rec.OriginPlotId and PlotService.GetPlotById(rec.OriginPlotId)
	local originSlot = rec.OriginSlot
	rec.OriginPlotId = nil
	rec.OriginSlot = nil
	endFollow(rec)

	if originPlot and originPlot.OwnerUserId ~= 0 and originPlot.Slots[originSlot] == rec then
		walkToStation(rec, originPlot, originSlot, Constants.NPC.ReturnSpeed, "Returning")
	else
		dropHere(rec)
	end
	if InfluencerService.OnTheftEnded and originPlot then
		InfluencerService.OnTheftEnded(rec, originPlot)
	end
end

-- Knocked off the conveyor: stand around (claimable) and leave after a while.
function InfluencerService.DropFromBelt(rec)
	if rec.Model and rec.State == "OnBelt" then
		dropHere(rec)
	end
end

-- Leader died / left / rebirthed / dismissed.
function InfluencerService.DropCarried(player)
	local rec = carriedBy[player.UserId]
	if not rec then
		return
	end
	if rec.OriginPlotId then
		InfluencerService.ReturnToOrigin(rec)
	else
		endFollow(rec)
		dropHere(rec)
	end
end

-- Destroys every influencer placed on / walking to a plot (does NOT touch the profile).
function InfluencerService.ClearPlot(plot)
	for slot, rec in pairs(plot.Slots) do
		if rec and rec.Model and (rec.State == "Placed" or rec.State == "Seating" or rec.State == "Returning") then
			InfluencerService.Destroy(rec)
		end
		plot.Slots[slot] = nil
	end
	refreshRackAttr(plot)
end

-- Rebuilds a player's saved gym when they join.
function InfluencerService.RestorePlaced(player, plot)
	local profile = PlayerDataService.GetProfile(player.UserId)
	if not profile then
		return 0
	end
	local restored = 0
	for _, entry in ipairs(profile.Placed) do
		local slot = entry.Slot
		if slot and slot <= plot.Unlocked and not plot.Slots[slot] and Constants.RARITIES[entry.Rarity] then
			local rec = newRecord(entry.Rarity, entry.Name or Constants.RARITIES[entry.Rarity].Names[1], entry.Seed, "Placed")
			entry.Seed = rec.Seed
			local model = buildModel(rec)
			model.Parent = folder
			sitOnStation(rec, plot, slot, rng:NextNumber(0, 30))
			restored += 1
		end
	end
	return restored
end

-- ----------------------------------------------------------------------
-- Heartbeat
-- ----------------------------------------------------------------------
local tickAccum = 0
local despawnAccum = 0
local emoteAccum = 0

local function checkArrivedHome(player, rec)
	local plot = PlotService.GetPlotByOwner(player.UserId)
	if not plot or not PlotService.IsInsideGym(plot, rec.Root.Position) then
		return
	end
	local slot = PlotService.FindOpenSlot(plot.Id)
	if not slot then
		local now = os.clock()
		if not rackFullDebounce[player.UserId] or now - rackFullDebounce[player.UserId] > 4 then
			rackFullDebounce[player.UserId] = now
			Notify(player, "Every machine on your open floors is taken! Buy another Gym Floor in the Shop.", "fail")
		end
		return
	end
	InfluencerService.Place(rec, plot, slot, player)
end

function InfluencerService.Update(dt)
	tickAccum += dt
	if tickAccum >= 0.2 then
		tickAccum = 0
		for uid, rec in pairs(carriedBy) do
			local player = Players:GetPlayerByUserId(uid)
			local character = player and player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not rec.Model then
				carriedBy[uid] = nil
			elseif player and humanoid and humanoid.Health > 0 then
				checkArrivedHome(player, rec)
			elseif player then
				InfluencerService.DropCarried(player)
			else
				endFollow(rec)
				dropHere(rec)
			end
		end
		-- fell off the world?
		for _, rec in pairs(records) do
			if rec.Root and rec.Root.Position.Y < -40 then
				if rec.State == "Following" and rec.CarrierUserId then
					local lr = NpcService.GetLeaderRoot(rec.Model)
					if lr then
						rec.Model:PivotTo(lr.CFrame * CFrame.new(0, 2, 5))
					end
				else
					task.defer(InfluencerService.Destroy, rec)
				end
			end
		end
	end

	-- belt riders show off now and then
	emoteAccum += dt
	if emoteAccum >= 1 then
		emoteAccum = 0
		for _, rec in pairs(records) do
			if rec.State == "OnBelt" and rng:NextNumber() < Constants.NPC.EmoteChance then
				NpcService.PlayEmote(rec.Model, NpcService.EMOTES[rng:NextInteger(1, #NpcService.EMOTES)])
			end
		end
	end

	-- dropped: leave after a while (checked ~once per second)
	despawnAccum += dt
	if despawnAccum >= 1 then
		despawnAccum = 0
		local now = os.clock()
		for _, rec in pairs(records) do
			if rec.State == "Dropped" and rec.DroppedAt and now - rec.DroppedAt > Constants.BELT.DroppedDespawn then
				task.defer(InfluencerService.Destroy, rec)
			end
		end
	end
end

return InfluencerService
