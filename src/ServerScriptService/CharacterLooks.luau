--[[
	CharacterLooks
	Builds a character's Roblox model from its Look spec in
	ReplicatedStorage.Modules.Characters — no per-character scripts.

	  - Base R15 avatar (body colors + proportions via HumanoidDescription)
	  - Clothing by coloring body parts + loose "cloth shells" (oversized tees,
	    stringers, hoods, baggy pants...) — no real logos or branded designs
	  - Hair / beards / mustaches built from rounded parts
	  - Props (duffel, gallon jug, clipboard, camera, straps, cap)
	  - Muscle shaping: shoulder caps, biceps, forearms, pecs, traps, quads/calves
	  - Rarity presentation: outline, aura particles, light, overhead card

	All extra parts are welded, massless and non-colliding, so they ride along
	with walking and with the procedural workout animations.
]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Constants = require(RS.Modules.Constants)
local Characters = require(RS.Modules.Characters)
local StationSpecs = require(RS.Modules.Gym.StationSpecs)
local NpcService = require(SSS.NpcService)

local CharacterLooks = {}

local LIMBS = {
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- ----------------------------------------------------------------------
-- Part helpers
-- ----------------------------------------------------------------------
local function attach(folder, host, size, offset, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = opts.Name or "Look"
	p.Size = size
	p.Color = color
	p.Material = opts.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = opts.Shadow ~= false
	p.CollisionGroup = NpcService.GROUP_NPC
	p.CFrame = host.CFrame * (opts.Rot and (CFrame.new(offset) * opts.Rot) or CFrame.new(offset))
	if opts.Round ~= false then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = opts.Cylinder and Enum.MeshType.Cylinder or Enum.MeshType.Sphere
		mesh.Parent = p
	end
	if opts.Transparency then
		p.Transparency = opts.Transparency
	end
	if opts.Prop then
		p:SetAttribute("Prop", true)
	end
	p.Parent = folder
	local w = Instance.new("WeldConstraint")
	w.Part0 = host
	w.Part1 = p
	w.Parent = p
	return p
end

-- size/offset given as fractions of the host part's size
local function shell(folder, host, sizeMul, offsetMul, color, opts)
	local s = host.Size
	return attach(folder, host, s * sizeMul, s * offsetMul, color or host.Color, opts)
end

-- ----------------------------------------------------------------------
-- Clothing (color the body, then add loose cloth where the style needs it)
-- ----------------------------------------------------------------------
local function paint(model, look)
	local skin = look.Skin
	local top = look.Top or { Style = "Tee", Color = Color3.fromRGB(60, 60, 66) }
	local bottom = look.Bottom or { Style = "Shorts", Color = Color3.fromRGB(30, 30, 34) }
	local P = {}
	for _, n in ipairs(LIMBS) do
		P[n] = model:FindFirstChild(n)
	end
	P.Head = model:FindFirstChild("Head")
	P.UpperTorso = model:FindFirstChild("UpperTorso")
	P.LowerTorso = model:FindFirstChild("LowerTorso")
	local function color(names, c)
		for _, n in ipairs(names) do
			if P[n] then
				P[n].Color = c
			end
		end
	end

	color({ "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }, skin)
	color({ "LeftFoot", "RightFoot" }, look.Shoes or Color3.fromRGB(40, 40, 44))

	-- top
	local ts = top.Style
	if ts == "Stringer" then
		color({ "UpperTorso" }, skin)
	else
		color({ "UpperTorso" }, top.Color)
	end
	if ts == "Tee" or ts == "Oversized" then
		color({ "LeftUpperArm", "RightUpperArm" }, top.Color)
	elseif ts == "Hoodie" then
		color({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }, top.Color)
	end

	-- bottom
	local bs = bottom.Style
	color({ "LowerTorso" }, bottom.Color)
	if bs == "Joggers" or bs == "Sweatpants" or bs == "FlowingPants" then
		color({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }, bottom.Color)
	elseif bs == "Shorts" or bs == "LongShorts" then
		color({ "LeftUpperLeg", "RightUpperLeg" }, bottom.Color)
		if look.Socks then
			color({ "LeftLowerLeg", "RightLowerLeg" }, look.Socks)
		end
	elseif bs == "PosingShorts" then
		if look.Socks then
			color({ "LeftLowerLeg", "RightLowerLeg" }, look.Socks)
		end
	end
	return P, top, bottom
end

local function cloth(folder, P, top, bottom, look)
	local ts, bs = top.Style, bottom.Style
	local ut = P.UpperTorso
	if ut then
		if ts == "Oversized" then
			shell(folder, ut, Vector3.new(1.14, 1.06, 1.22), Vector3.new(0, -0.02, 0), top.Color, { Name = "Cloth", Round = false })
			for _, n in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
				if P[n] then
					shell(folder, P[n], Vector3.new(1.3, 0.72, 1.3), Vector3.new(0, 0.16, 0), top.Color, { Name = "Cloth", Round = false })
				end
			end
		elseif ts == "Stringer" then
			shell(folder, ut, Vector3.new(0.5, 0.95, 1.04), Vector3.new(0, -0.02, 0), top.Color, { Name = "Cloth", Round = false })
			for _, s in ipairs({ -1, 1 }) do
				shell(folder, ut, Vector3.new(0.1, 0.35, 1.02), Vector3.new(s * 0.2, 0.35, 0), top.Color, { Name = "Cloth", Round = false })
			end
		elseif ts == "Hoodie" or ts == "SleevelessHoodie" then
			shell(folder, ut, Vector3.new(0.8, 0.32, 0.55), Vector3.new(0, 0.48, 0.42), top.Color, { Name = "Hood" })
			shell(folder, ut, Vector3.new(0.5, 0.25, 0.1), Vector3.new(0, -0.1, -0.52), top.Color:Lerp(Color3.new(0, 0, 0), 0.25), { Name = "Pocket", Round = false })
		end
	end
	for _, n in ipairs({ "LeftUpperLeg", "RightUpperLeg" }) do
		local leg = P[n]
		if leg then
			if bs == "PosingShorts" then
				shell(folder, leg, Vector3.new(1.06, 0.3, 1.06), Vector3.new(0, 0.36, 0), bottom.Color, { Name = "Cloth", Round = false })
			elseif bs == "Sweatpants" or bs == "FlowingPants" then
				local k = bs == "FlowingPants" and 1.45 or 1.18
				shell(folder, leg, Vector3.new(k, 1.02, k), Vector3.new(0, 0, 0), bottom.Color, { Name = "Cloth" })
			end
		end
	end
	for _, n in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do
		local leg = P[n]
		if leg then
			if bs == "LongShorts" then
				shell(folder, leg, Vector3.new(1.12, 0.45, 1.12), Vector3.new(0, 0.3, 0), bottom.Color, { Name = "Cloth", Round = false })
			elseif bs == "Sweatpants" or bs == "FlowingPants" then
				local k = bs == "FlowingPants" and 1.5 or 1.2
				shell(folder, leg, Vector3.new(k, 1.02, k), Vector3.new(0, 0, 0), bottom.Color, { Name = "Cloth" })
			end
		end
	end
end

-- ----------------------------------------------------------------------
-- Muscle shaping
-- ----------------------------------------------------------------------
local function bulk(folder, P, build)
	local sh, arms, fore = build.Shoulders or 0, build.Arms or 0, build.Forearms or 0
	local chest, traps, legs = build.Chest or 0, build.Traps or 0, build.Legs or 0
	for _, side in ipairs({ "Left", "Right" }) do
		local s = side == "Left" and -1 or 1
		local ua, la = P[side .. "UpperArm"], P[side .. "LowerArm"]
		if ua and sh > 0 then
			shell(folder, ua, Vector3.new(1.15 + 0.45 * sh, 0.55 + 0.25 * sh, 1.12 + 0.4 * sh), Vector3.new(s * 0.1 * sh, 0.3, 0), nil, { Name = "Delt" })
		end
		if ua and arms > 0 then
			shell(folder, ua, Vector3.new(0.95 + 0.35 * arms, 0.62, 0.8 + 0.45 * arms), Vector3.new(0, -0.05, -0.12 - 0.08 * arms), nil, { Name = "Bicep" })
			shell(folder, ua, Vector3.new(0.9 + 0.3 * arms, 0.7, 0.7 + 0.35 * arms), Vector3.new(0, 0.02, 0.14 + 0.06 * arms), nil, { Name = "Tricep" })
		end
		if la and (fore > 0 or arms > 0.4) then
			local f = math.max(fore, arms * 0.5)
			shell(folder, la, Vector3.new(1.0 + 0.4 * f, 0.7, 1.0 + 0.4 * f), Vector3.new(0, 0.15, 0), nil, { Name = "Forearm" })
		end
		local ul, ll = P[side .. "UpperLeg"], P[side .. "LowerLeg"]
		if ul and legs > 0 then
			shell(folder, ul, Vector3.new(1.08 + 0.55 * legs, 0.98, 1.1 + 0.6 * legs), Vector3.new(s * 0.04 * legs, -0.02, -0.06 * legs), nil, { Name = "Quad" })
		end
		if ll and legs > 0 then
			shell(folder, ll, Vector3.new(1.0 + 0.4 * legs, 0.66, 1.05 + 0.6 * legs), Vector3.new(0, 0.12, 0.1 * legs), nil, { Name = "Calf" })
		end
	end
	local ut = P.UpperTorso
	if ut and chest > 0 then
		shell(folder, ut, Vector3.new(0.9, 0.46, 0.3 + 0.25 * chest), Vector3.new(0, 0.16, -0.46 - 0.08 * chest), nil, { Name = "Pecs" })
	end
	if ut and traps > 0 then
		shell(folder, ut, Vector3.new(0.62 + 0.25 * traps, 0.25 + 0.2 * traps, 0.55), Vector3.new(0, 0.46 + 0.05 * traps, 0.08), nil, { Name = "Traps" })
	end
end

-- ----------------------------------------------------------------------
-- Hair & face
-- ----------------------------------------------------------------------
local function hair(folder, head, look)
	local h = look.Hair or { Style = "Short" }
	local c = h.Color or Color3.fromRGB(60, 40, 28)
	local style = h.Style
	local function blob(size, offset, opts)
		return shell(folder, head, size, offset, c, opts or { Name = "Hair" })
	end
	local function block(size, offset)
		return shell(folder, head, size, offset, c, { Name = "Hair", Round = false })
	end
	local function cap(height)
		blob(Vector3.new(1.08, height or 0.42, 1.1), Vector3.new(0, 0.34, 0.03))
		blob(Vector3.new(1.06, 0.62, 0.36), Vector3.new(0, 0.12, 0.38))
	end

	if style == "Bald" then
		return
	elseif style == "Buzz" then
		blob(Vector3.new(1.04, 0.3, 1.06), Vector3.new(0, 0.37, 0.02))
	elseif style == "Short" then
		cap(0.4)
	elseif style == "Fringe" then
		cap(0.42)
		block(Vector3.new(0.86, 0.16, 0.12), Vector3.new(0, 0.3, -0.49))
	elseif style == "Shaggy" then
		cap(0.46)
		for _, o in ipairs({
			Vector3.new(-0.36, 0.3, -0.1), Vector3.new(0.36, 0.3, -0.1), Vector3.new(-0.4, 0.18, 0.25),
			Vector3.new(0.4, 0.18, 0.25), Vector3.new(0, 0.44, 0.1), Vector3.new(0, 0.05, 0.46),
		}) do
			blob(Vector3.new(0.5, 0.42, 0.5), o)
		end
		block(Vector3.new(0.8, 0.2, 0.14), Vector3.new(0.05, 0.26, -0.49))
	elseif style == "Curly" or style == "LongCurly" then
		cap(0.4)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			blob(Vector3.new(0.34, 0.34, 0.34), Vector3.new(math.cos(a) * 0.38, 0.42 + (i % 2) * 0.05, math.sin(a) * 0.38))
		end
		if style == "LongCurly" then
			for i = 0, 8 do
				local a = (i / 8) * math.pi + math.pi * 0.0
				blob(Vector3.new(0.34, 0.4, 0.34), Vector3.new(math.cos(a) * 0.5, -0.05 - (i % 3) * 0.08, 0.1 + math.abs(math.sin(a)) * 0.38))
			end
		end
	elseif style == "Wavy" then
		cap(0.44)
		for _, s in ipairs({ -1, 1 }) do
			blob(Vector3.new(0.2, 0.55, 0.85), Vector3.new(s * 0.5, 0.12, 0.08))
		end
		blob(Vector3.new(1.02, 0.7, 0.3), Vector3.new(0, 0.02, 0.44))
		block(Vector3.new(0.7, 0.18, 0.12), Vector3.new(-0.1, 0.3, -0.49))
	elseif style == "Fluffy" then
		blob(Vector3.new(1.22, 0.66, 1.2), Vector3.new(0, 0.4, 0.02))
		blob(Vector3.new(0.7, 0.4, 0.5), Vector3.new(-0.12, 0.46, -0.32))
		blob(Vector3.new(1.06, 0.6, 0.36), Vector3.new(0, 0.12, 0.38))
	elseif style == "Styled" then
		cap(0.4)
		blob(Vector3.new(0.82, 0.34, 0.48), Vector3.new(0, 0.54, -0.22))
	elseif style == "Pompadour" then
		cap(0.4)
		blob(Vector3.new(0.92, 0.52, 0.62), Vector3.new(0, 0.62, -0.2))
		blob(Vector3.new(0.7, 0.3, 0.3), Vector3.new(0, 0.74, -0.42))
	elseif style == "Floppy" then
		cap(0.46)
		block(Vector3.new(0.95, 0.34, 0.14), Vector3.new(0.06, 0.22, -0.49))
		for _, s in ipairs({ -1, 1 }) do
			blob(Vector3.new(0.2, 0.5, 0.7), Vector3.new(s * 0.5, 0.14, 0.05))
		end
	elseif style == "SweptBack" then
		blob(Vector3.new(1.06, 0.5, 1.1), Vector3.new(0, 0.38, 0.06))
		blob(Vector3.new(0.98, 0.5, 0.55), Vector3.new(0, 0.36, 0.28))
		blob(Vector3.new(1.06, 0.62, 0.36), Vector3.new(0, 0.12, 0.38))
	elseif style == "Spiky" then
		cap(0.36)
		for i = 0, 6 do
			local x = -0.36 + i * 0.12
			block(Vector3.new(0.12, 0.3, 0.12), Vector3.new(x, 0.56 + (i % 2) * 0.05, -0.1 + (i % 3) * 0.12))
		end
	elseif style == "Tied" then
		cap(0.4)
		blob(Vector3.new(0.36, 0.36, 0.36), Vector3.new(0, 0.34, 0.58))
	else
		cap(0.4)
	end
end

local function face(folder, head, look)
	local hc = (look.Hair and look.Hair.Color) or Color3.fromRGB(40, 30, 24)
	if look.Beard == "Full" then
		shell(folder, head, Vector3.new(0.92, 0.42, 0.42), Vector3.new(0, -0.3, -0.3), hc, { Name = "Beard" })
		for _, s in ipairs({ -1, 1 }) do
			shell(folder, head, Vector3.new(0.14, 0.5, 0.55), Vector3.new(s * 0.45, -0.1, -0.08), hc, { Name = "Beard" })
		end
	elseif look.Beard == "Large" then
		shell(folder, head, Vector3.new(0.96, 0.68, 0.5), Vector3.new(0, -0.42, -0.3), hc, { Name = "Beard" })
		for _, s in ipairs({ -1, 1 }) do
			shell(folder, head, Vector3.new(0.16, 0.6, 0.6), Vector3.new(s * 0.46, -0.12, -0.06), hc, { Name = "Beard" })
		end
	elseif look.Beard == "Stubble" then
		shell(folder, head, Vector3.new(0.9, 0.34, 0.2), Vector3.new(0, -0.3, -0.42), hc, { Name = "Stubble", Transparency = 0.45 })
	end
	if look.Mustache then
		shell(folder, head, Vector3.new(0.46, 0.09, 0.1), Vector3.new(0, -0.14, -0.5), hc, { Name = "Mustache", Round = false })
	end
end

-- ----------------------------------------------------------------------
-- Props (hidden while training on a machine)
-- ----------------------------------------------------------------------
local function props(folder, P, look)
	local list = look.Props or {}
	for _, prop in ipairs(list) do
		if prop == "Duffel" and P.RightHand then
			local bag = attach(folder, P.RightHand, Vector3.new(1.3, 0.62, 0.62), Vector3.new(0, -0.55, 0), Color3.fromRGB(40, 44, 52), { Name = "Duffel", Round = false, Prop = true })
			bag.Material = Enum.Material.Fabric
			attach(folder, P.RightHand, Vector3.new(0.9, 0.08, 0.1), Vector3.new(0, -0.2, 0), Color3.fromRGB(30, 30, 34), { Name = "DuffelStrap", Round = false, Prop = true })
		elseif prop == "WaterJug" and P.RightHand then
			attach(folder, P.RightHand, Vector3.new(0.72, 1.05, 0.72), Vector3.new(0, -0.68, 0), Color3.fromRGB(215, 228, 240), { Name = "Jug", Round = false, Prop = true, Transparency = 0.25 })
			attach(folder, P.RightHand, Vector3.new(0.3, 0.14, 0.3), Vector3.new(0, -0.08, 0), Color3.fromRGB(40, 110, 200), { Name = "JugCap", Cylinder = false, Prop = true })
		elseif prop == "Clipboard" and P.LeftHand then
			attach(folder, P.LeftHand, Vector3.new(0.85, 1.15, 0.08), Vector3.new(0, -0.45, -0.25), Color3.fromRGB(120, 90, 56), { Name = "Clipboard", Round = false, Prop = true })
			attach(folder, P.LeftHand, Vector3.new(0.7, 0.9, 0.02), Vector3.new(0, -0.48, -0.3), Color3.fromRGB(245, 245, 245), { Name = "Paper", Round = false, Prop = true })
		elseif prop == "Tripod" and P.RightHand then
			attach(folder, P.RightHand, Vector3.new(0.12, 1.4, 0.12), Vector3.new(0, 0.5, 0), Color3.fromRGB(30, 30, 34), { Name = "TripodPole", Round = false, Prop = true })
			attach(folder, P.RightHand, Vector3.new(0.5, 0.34, 0.3), Vector3.new(0, 1.25, 0), Color3.fromRGB(24, 24, 28), { Name = "Camera", Round = false, Prop = true })
			attach(folder, P.RightHand, Vector3.new(0.18, 0.18, 0.12), Vector3.new(0, 1.25, -0.2), Color3.fromRGB(60, 90, 140), { Name = "Lens", Prop = true })
		elseif (prop == "WristStraps" or prop == "WristWraps") then
			local c = prop == "WristWraps" and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(30, 30, 34)
			for _, n in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
				local la = P[n]
				if la then
					shell(folder, la, Vector3.new(1.12, 0.18, 1.12), Vector3.new(0, -0.4, 0), c, { Name = "Wrap", Round = false })
				end
			end
		elseif prop == "Cap" and P.Head then
			local cc = look.CapColor or Color3.fromRGB(30, 30, 34)
			shell(folder, P.Head, Vector3.new(1.1, 0.4, 1.12), Vector3.new(0, 0.38, 0.02), cc, { Name = "Cap" })
			shell(folder, P.Head, Vector3.new(0.9, 0.06, 0.5), Vector3.new(0, 0.26, -0.6), cc, { Name = "CapBrim", Round = false })
		end
	end
end

function CharacterLooks.SetPropsVisible(model, visible)
	local folder = model:FindFirstChild("Look")
	if not folder then
		return
	end
	for _, p in ipairs(folder:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Prop") then
			p.Transparency = visible and (p:GetAttribute("BaseTransparency") or 0) or 1
		end
	end
end

-- ----------------------------------------------------------------------
-- Overhead card: NAME / RARITY / PRICE / +INCOME
-- ----------------------------------------------------------------------
function CharacterLooks.BuildTag(model, char, rarity, income)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	local k = rarity.TagScale or 1
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.new(0, 220 * k, 0, 96 * k)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = rarity.Index >= 5 and 400 or (rarity.Index >= 3 and 160 or 100)
	tag.LightInfluence = 0
	tag.Parent = head

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tag

	local function line(name, order, heightScale, text, color, font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, heightScale, 0)
		l.BackgroundTransparency = 1
		l.Font = font or Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = rarity.Index >= 4 and 2 or 1.4
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.15
		stroke.Parent = l
		l.Parent = tag
		return l
	end

	local nameLabel = line("CharName", 1, 0.32, char.DisplayName:upper(), Color3.new(1, 1, 1))
	local rarityLabel = line("Rarity", 2, 0.22, rarity.DisplayName, rarity.Color)
	local priceLabel = line("Price", 3, 0.22, "$" .. Constants.FormatNumber(char.Price), Color3.fromRGB(255, 240, 150), Enum.Font.GothamBold)
	local incomeLabel = line("Income", 4, 0.22, "+$" .. Constants.FormatNumber(income) .. "/s", Color3.fromRGB(110, 255, 140), Enum.Font.GothamBold)

	if rarity.Gradient then
		for _, l in ipairs({ nameLabel, rarityLabel }) do
			local g = Instance.new("UIGradient")
			local keys = {}
			for i, c in ipairs(rarity.Gradient) do
				table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#rarity.Gradient - 1, 1), c))
			end
			g.Color = ColorSequence.new(keys)
			g.Parent = l
			if l == nameLabel then
				l.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		tag:SetAttribute("AnimatedGradient", true)
	elseif rarity.Index >= 2 then
		nameLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(rarity.Color, 0.35)
	end
	return tag, priceLabel, incomeLabel
end

-- ----------------------------------------------------------------------
-- Rarity presentation (outline / aura / light)
-- ----------------------------------------------------------------------
local function rarityFx(model, char, rarity)
	local root = model:FindFirstChild("HumanoidRootPart")
	if rarity.Outline then
		local hl = Instance.new("Highlight")
		hl.Name = "RarityOutline"
		hl.OutlineColor = rarity.Color
		hl.FillColor = rarity.Color
		hl.FillTransparency = rarity.Index >= 6 and 0.82 or 1
		hl.OutlineTransparency = rarity.Index >= 4 and 0 or 0.35
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
	end
	if root and (rarity.Aura or 0) > 0 then
		local att = Instance.new("Attachment")
		att.Name = "AuraAttachment"
		att.Parent = root
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "RarityAura"
		aura.Color = ColorSequence.new(rarity.Color, rarity.Glow)
		aura.LightEmission = 1
		aura.Rate = rarity.Aura
		aura.Lifetime = NumberRange.new(1, 1.8)
		aura.Speed = NumberRange.new(0.5, 2)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		aura.Acceleration = Vector3.new(0, 1.5, 0)
		aura.Parent = att
	end
	local ut = model:FindFirstChild("UpperTorso") or root
	if ut and (rarity.Light or 0) > 0 then
		local light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Color = rarity.Color
		light.Brightness = rarity.Light
		light.Range = 8 + rarity.Index * 1.5
		light.Shadows = false
		light.Parent = ut
	end
	if char.Glow and ut then
		-- "always in perfect gym lighting"
		local glow = Instance.new("PointLight")
		glow.Name = "PerfectLighting"
		glow.Color = Color3.fromRGB(255, 244, 228)
		glow.Brightness = 1.2
		glow.Range = 10
		glow.Shadows = false
		glow.Parent = ut
	end
end

-- ----------------------------------------------------------------------
-- Build a character model
-- ----------------------------------------------------------------------
function CharacterLooks.Build(char, opts)
	opts = opts or {}
	local rarity = Characters.GetRarity(char.Rarity)
	local look = char.Look or {}
	local build = look.Build or {}
	local model = NpcService.CreateRig({
		Name = char.DisplayName,
		Skin = look.Skin,
		Shirt = look.Top and look.Top.Color,
		Pants = look.Bottom and look.Bottom.Color,
		Height = build.Height or 1,
		Width = build.Width or 1,
		Depth = build.Depth or 1,
		AvatarUserId = Constants.INFLUENCER_AVATARS and Constants.INFLUENCER_AVATARS[char.Name],
	})
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy()
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Accessory") then
			d:Destroy() -- a clean base; the look is built below
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Look"
	folder.Parent = model
	local P, top, bottom = paint(model, look)
	cloth(folder, P, top, bottom, look)
	bulk(folder, P, build)
	if P.Head then
		local capped = false
		for _, pr in ipairs(look.Props or {}) do
			if pr == "Cap" then
				capped = true
			end
		end
		if not capped or (look.Hair and look.Hair.Style == "Shaggy") then
			hair(folder, P.Head, look)
		end
		face(folder, P.Head, look)
	end
	props(folder, P, look)
	for _, p in ipairs(folder:GetDescendants()) do
		if p:IsA("BasePart") then
			p:SetAttribute("BaseTransparency", p.Transparency)
		end
	end

	-- everyone is built big to match the oversized equipment; very tall
	-- characters get their extra height from HumanoidDescription.HeightScale
	pcall(function()
		model:ScaleTo(StationSpecs.SCALE)
	end)

	rarityFx(model, char, rarity)

	model:SetAttribute("CharacterId", char.Name)
	model:SetAttribute("RarityId", char.Rarity)
	model:SetAttribute("Rarity", rarity.Index)
	if char.Poses then
		model:SetAttribute("Poses", table.concat(char.Poses, ","))
	end
	if char.Chart then
		model:SetAttribute("Chart", true)
	end
	if char.IdleSpeed then
		model:SetAttribute("IdleSpeed", char.IdleSpeed)
	end
	if char.Emote then
		model:SetAttribute("FavoriteEmote", char.Emote)
	end
	return model, rarity
end

return CharacterLooks
