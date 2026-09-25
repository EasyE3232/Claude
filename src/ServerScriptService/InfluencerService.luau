--[[
	InfluencerService
	Owns every influencer NPC (a real R15 character) and its lifecycle:

	  OnBelt    -> standing on the conveyor, riding it (claimable by anyone)
	  Seating   -> claimed: walking on their own, straight to a machine in the
	               claimer's gym (the machine is reserved the moment they're claimed)
	  Placed    -> training on a machine (anchored; clients animate the workout),
	               earning Cash for the plot owner
	  Stolen    -> lured out of someone else's gym, walking to a machine in the
	               thief's gym; the victim's front desk worker chases them
	  Returning -> walking back to their machine after the front desk caught them
	  Dropped   -> standing around unowned (knocked off the belt), claimable, leaves later

	Stealing keeps OriginPlotId/OriginSlot reserved so a caught influencer can
	walk back; if they reach the thief's machine first, they're the thief's.
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
-- Getting to a machine
-- ----------------------------------------------------------------------
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
	rec.Model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + look.Unit))
	setAnchored(rec, false)
	NpcService.SetAnimationsEnabled(rec.Model, true)
	rec.StationRef.Value = nil
end

-- Anchor the NPC on its machine; clients take over and animate the workout.
local function sitOnStation(rec, plot, slot, timeOffset)
	local station = PlotService.GetStation(plot.Id, slot)
	setState(rec, "Placed")
	rec.PlotId = plot.Id
	rec.Slot = slot
	rec.Arrive = nil
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

-- Walk (on their own) to a machine's approach point; `onArrive` runs when
-- they get there, or after the timeout if they got stuck (they then just hop on).
local function walkTo(rec, plot, slot, speed, onArrive)
	local station = PlotService.GetStation(plot.Id, slot)
	local approach = station and station:FindFirstChild("Approach")
	local token = {}
	rec.SeatToken = token
	local function arrive()
		if rec.SeatToken == token and rec.Model then
			rec.SeatToken = nil
			onArrive()
		end
	end
	rec.Arrive = arrive
	if rec.Root.Anchored then
		standUp(rec)
	end
	if not approach then
		task.defer(arrive)
		return
	end
	NpcService.WalkTo(rec.Model, approach.Position, speed, arrive, Constants.NPC.SeatTimeout, arrive)
end

-- Reserve `slot` in `plot` for rec and send them there.
local function sendToOwnMachine(rec, plot, slot, speed, state)
	setState(rec, state or "Seating")
	rec.PlotId = plot.Id
	rec.Slot = slot
	plot.Slots[slot] = rec -- reserved right away
	rec.Model:SetAttribute("OwnerUserId", plot.OwnerUserId)
	refreshRackAttr(plot)
	walkTo(rec, plot, slot, speed, function()
		if plot.Slots[slot] == rec then
			sitOnStation(rec, plot, slot)
			local owner = PlotService.GetOwnerPlayer(plot)
			if owner and state ~= "Returning" then
				addToProfile(owner, rec)
			end
		end
	end)
end

local function dropHere(rec)
	setState(rec, "Dropped")
	rec.PlotId = nil
	rec.Slot = nil
	rec.SeatToken = nil
	rec.Arrive = nil
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
	rec.SeatToken = nil
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
local function fullNotice(player)
	local now = os.clock()
	if not rackFullDebounce[player.UserId] or now - rackFullDebounce[player.UserId] > 2 then
		rackFullDebounce[player.UserId] = now
		Notify(player, "Every machine on your open floors is taken! Buy another Gym Floor in the Shop.", "fail")
	end
end

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
	if not hrp or (hrp.Position - rec.Root.Position).Magnitude > Constants.BELT.ClaimDistance + 8 then
		return
	end
	local myPlot = PlotService.GetPlotByOwner(uid)
	if not myPlot then
		Notify(player, "All gyms are taken — you need a gym to hold influencers.", "fail")
		return
	end

	if rec.State == "OnBelt" or rec.State == "Dropped" then
		local slot = PlotService.FindOpenSlot(myPlot.Id)
		if not slot then
			fullNotice(player)
			return
		end
		local wasOnBelt = rec.State == "OnBelt"
		rec.CarrierUserId = uid
		sendToOwnMachine(rec, myPlot, slot, Constants.NPC.TravelSpeed)
		if wasOnBelt then
			hopOffBelt(rec)
		end
		local station = PlotService.GetStation(myPlot.Id, slot)
		Notify(player, rec.Name .. " is heading to your " .. (station and PlotService.StationName(station) or "gym") .. "! +$" .. Constants.FormatNumber(rec.Income) .. "/s", "success")
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
		local slot = PlotService.FindOpenSlot(myPlot.Id)
		if not slot then
			fullNotice(player)
			return
		end
		-- THEFT: keep the origin slot reserved so it can return if the front desk catches them
		rec.OriginPlotId = plot.Id
		rec.OriginSlot = rec.Slot
		rec.CarrierUserId = uid
		myPlot.Slots[slot] = rec
		rec.PlotId = myPlot.Id
		rec.Slot = slot
		setState(rec, "Stolen")
		rec.Model:SetAttribute("OwnerUserId", uid)
		refreshRackAttr(plot)
		refreshRackAttr(myPlot)
		walkTo(rec, myPlot, slot, Constants.NPC.TravelSpeed, function()
			InfluencerService.FinishTheft(rec)
		end)

		local victim = PlotService.GetOwnerPlayer(plot)
		Notify(player, "You lured " .. rec.Name .. " away! They're heading to your gym — hope the front desk doesn't catch them!", "info")
		if victim then
			Notify(victim, player.DisplayName .. " is stealing your " .. rec.Name .. "! Your front desk is on it!", "fail")
		end
		if InfluencerService.OnTheftStarted then
			InfluencerService.OnTheftStarted(rec, player, plot)
		end
	end
end

function InfluencerService.GetCarried(player)
	return nil
end

function InfluencerService.GetCarrierPlayer(rec)
	return rec.CarrierUserId and Players:GetPlayerByUserId(rec.CarrierUserId) or nil
end

-- ----------------------------------------------------------------------
-- Public: theft outcomes
-- ----------------------------------------------------------------------
-- The stolen influencer reached the thief's machine: it's theirs now.
function InfluencerService.FinishTheft(rec)
	local plot = rec.PlotId and PlotService.GetPlotById(rec.PlotId)
	local slot = rec.Slot
	if not plot or plot.Slots[slot] ~= rec then
		InfluencerService.ReturnToOrigin(rec)
		return
	end
	local originPlot = rec.OriginPlotId and PlotService.GetPlotById(rec.OriginPlotId)
	if originPlot then
		if originPlot.Slots[rec.OriginSlot] == rec then
			originPlot.Slots[rec.OriginSlot] = nil
		end
		local victim = PlotService.GetOwnerPlayer(originPlot)
		local thief = PlotService.GetOwnerPlayer(plot)
		if victim then
			removeFromProfile(victim, rec.OriginSlot)
			Notify(victim, (thief and thief.DisplayName or "Someone") .. " stole your " .. rec.Name .. "!", "fail")
		end
		refreshRackAttr(originPlot)
		if InfluencerService.OnTheftEnded then
			InfluencerService.OnTheftEnded(rec, originPlot)
		end
	end
	rec.OriginPlotId = nil
	rec.OriginSlot = nil
	sitOnStation(rec, plot, slot)
	local owner = PlotService.GetOwnerPlayer(plot)
	if owner then
		addToProfile(owner, rec)
		Notify(owner, rec.Name .. " joined your gym! +$" .. Constants.FormatNumber(rec.Income) .. "/s", "success")
	end
end

-- Front desk caught them (or the thief left): walk back to the original machine.
function InfluencerService.ReturnToOrigin(rec)
	local originPlot = rec.OriginPlotId and PlotService.GetPlotById(rec.OriginPlotId)
	local originSlot = rec.OriginSlot
	-- free the thief's reserved machine
	if rec.PlotId and rec.Slot then
		local plot = PlotService.GetPlotById(rec.PlotId)
		if plot and plot.Slots[rec.Slot] == rec and plot ~= originPlot then
			plot.Slots[rec.Slot] = nil
			refreshRackAttr(plot)
		end
	end
	rec.OriginPlotId = nil
	rec.OriginSlot = nil
	rec.CarrierUserId = nil
	NpcService.Stop(rec.Model)

	if originPlot and originPlot.OwnerUserId ~= 0 and originPlot.Slots[originSlot] == rec then
		sendToOwnMachine(rec, originPlot, originSlot, Constants.NPC.ReturnSpeed, "Returning")
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

-- The player left / rebirthed: anything they were stealing goes back home.
function InfluencerService.DropCarried(player)
	for _, rec in pairs(records) do
		if rec.State == "Stolen" and rec.CarrierUserId == player.UserId then
			InfluencerService.ReturnToOrigin(rec)
		end
	end
end

-- Destroys every influencer placed on / walking to a plot (does NOT touch the profile).
function InfluencerService.ClearPlot(plot)
	for slot, rec in pairs(plot.Slots) do
		if rec and rec.Model then
			if rec.State == "Stolen" and rec.OriginPlotId == plot.Id then
				-- being stolen FROM this plot: it's gone for good, the thief keeps walking
				rec.OriginPlotId, rec.OriginSlot = nil, nil
			elseif rec.State == "Stolen" then
				InfluencerService.ReturnToOrigin(rec) -- was being stolen BY this plot's owner
			else
				InfluencerService.Destroy(rec)
			end
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

function InfluencerService.Update(dt)
	tickAccum += dt
	if tickAccum >= 0.25 then
		tickAccum = 0
		-- fell off the world while walking? just finish the trip
		for _, rec in pairs(records) do
			if rec.Root and rec.Root.Position.Y < -40 then
				if rec.Arrive then
					task.defer(rec.Arrive)
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
