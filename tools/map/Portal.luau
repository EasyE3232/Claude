--[[
	Portal — the red-carpet stage gate characters walk out of (and vanish into).

	  Portal.Build(parent, name, originCF, color, label) -> Model

	originCF: ground center of the gate; the gate's mouth faces originCF's -Z
	(toward the carpet). Pure Roblox API (no map helpers), so the same code
	builds the map offline AND patches a live place from the command bar.

	Parts carrying a "PortalFx" attribute are animated by the client
	(StarterPlayerScripts.PortalFx): Chase = marquee bulbs, Pulse = the glowing
	portal disc, Curtain = light-curtain slats, Sweep = searchlights.
	Neon strips are named "TunnelGlow" so rarity spawns flash them.
]]

local Portal = {}

local GOLD = Color3.fromRGB(212, 175, 55)
local BLACK = Color3.fromRGB(14, 14, 17)
local GLOSS = Color3.fromRGB(22, 22, 27)
local VELVET = Color3.fromRGB(140, 12, 24)
local BULB = Color3.fromRGB(255, 236, 190)

local function part(parent, name, size, cf, color, material, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	opts = opts or {}
	if opts.Decor then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	if opts.Shape then
		p.Shape = opts.Shape
	end
	if opts.Transparency then
		p.Transparency = opts.Transparency
	end
	if opts.Reflectance then
		p.Reflectance = opts.Reflectance
	end
	if opts.NoShadow then
		p.CastShadow = false
	end
	if opts.Fx then
		p:SetAttribute("PortalFx", opts.Fx)
	end
	p.Parent = parent
	return p
end

function Portal.Build(parent, name, originCF, color, label, tagline)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Portal", true)
	local function at(x, y, z)
		return originCF * CFrame.new(x, y, z)
	end

	-- stage plinths either side of the walkway
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Plinth", Vector3.new(6, 1.2, 18), at(s * 10.5, 0.6, 0), BLACK, Enum.Material.Marble, { Reflectance = 0.08 })
		part(m, "PlinthTrim", Vector3.new(6.2, 0.2, 18.2), at(s * 10.5, 1.25, 0), GOLD, Enum.Material.Metal, { Decor = true })
		part(m, "PlinthGlow", Vector3.new(0.25, 0.25, 18.2), at(s * 7.4, 1.1, 0), color, Enum.Material.Neon, { Decor = true, NoShadow = true }).Name = "TunnelGlow"
	end

	-- giant glossy pillars with neon piping, gold rings and caps
	for _, s in ipairs({ -1, 1 }) do
		local x = s * 10
		part(m, "Pillar", Vector3.new(5, 22, 5), at(x, 12.2, -6), GLOSS, Enum.Material.Metal, { Reflectance = 0.15 })
		part(m, "PillarBase", Vector3.new(6, 0.8, 6), at(x, 1.6, -6), GOLD, Enum.Material.Metal)
		part(m, "PillarCap", Vector3.new(6, 1, 6), at(x, 23.7, -6), GOLD, Enum.Material.Metal)
		for _, dx in ipairs({ -1.7, 1.7 }) do
			local g = part(m, "TunnelGlow", Vector3.new(0.35, 20, 0.3), at(x + dx, 12.2, -8.6), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Front
			light.Color = color
			light.Brightness = 1.2
			light.Range = 10
			light.Parent = g
		end
		-- a column of marquee bulbs up each pillar's face
		local i = 0
		for y = 3, 21, 1.5 do
			i += 1
			part(m, "Bulb", Vector3.new(0.55, 0.55, 0.55), at(x, y, -8.75), BULB, Enum.Material.Neon, { Decor = true, Shape = Enum.PartType.Ball, NoShadow = true, Fx = "Chase" }):SetAttribute("Index", i + (s > 0 and 0 or 1))
		end
	end

	-- the tunnel: glossy black walls + ceiling, neon floor lines
	for _, s in ipairs({ -1, 1 }) do
		part(m, "TunnelWall", Vector3.new(1.2, 16, 14), at(s * 7.6, 8, 1), BLACK, Enum.Material.SmoothPlastic, { Reflectance = 0.12 })
		part(m, "TunnelGlow", Vector3.new(0.3, 0.12, 14), at(s * 6.7, 0.18, 1), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
		part(m, "TunnelGlow", Vector3.new(0.3, 14, 0.3), at(s * 6.8, 8, -5.8), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
	end
	part(m, "TunnelCeiling", Vector3.new(16.4, 1.2, 14), at(0, 16.6, 1), BLACK, Enum.Material.SmoothPlastic)
	part(m, "TunnelGlow", Vector3.new(13.6, 0.3, 0.3), at(0, 15.9, -5.8), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
	part(m, "TunnelBack", Vector3.new(14.2, 16, 1), at(0, 8, 8.2), BLACK, Enum.Material.SmoothPlastic)

	-- the portal itself: gold ring + glowing disc + sparkles pouring out
	local discCF = at(0, 8, 7.4) * CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) faces out of the mouth
	part(m, "PortalRing", Vector3.new(0.4, 14.6, 14.6), discCF * CFrame.new(-0.2, 0, 0), GOLD, Enum.Material.Metal, { Decor = true, Shape = Enum.PartType.Cylinder })
	local disc = part(m, "PortalDisc", Vector3.new(0.3, 13, 13), discCF * CFrame.new(0.1, 0, 0), color, Enum.Material.Neon, { Decor = true, Shape = Enum.PartType.Cylinder, Transparency = 0.15, NoShadow = true, Fx = "Pulse" })
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 22
	glow.Brightness = 3
	glow.Parent = disc
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "PortalSparks"
	sparks.EmissionDirection = Enum.NormalId.Right -- +X of the disc = out of the mouth
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks.LightEmission = 1
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(1.2, 2.2)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Parent = disc

	-- light curtain across the mouth (walk straight through it)
	local k = 0
	for x = -6.3, 6.31, 0.9 do
		k += 1
		part(m, "CurtainSlat", Vector3.new(0.12, 15.2, 0.08), at(x, 8, -7.9), color, Enum.Material.Neon, { Decor = true, Transparency = 0.75, NoShadow = true, Fx = "Curtain" }):SetAttribute("Index", k)
	end

	-- backdrop panel filling the arch above the tunnel, with a tagline
	local panel = part(m, "Backdrop", Vector3.new(15.2, 7, 1), at(0, 20.7, -6.5), BLACK, Enum.Material.SmoothPlastic)
	part(m, "TunnelGlow", Vector3.new(15.2, 0.3, 0.3), at(0, 17.35, -7.05), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
	if tagline then
		local pg = Instance.new("SurfaceGui")
		pg.Name = "Tagline"
		pg.Face = Enum.NormalId.Front
		pg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		pg.PixelsPerStud = 40
		pg.LightInfluence = 0
		pg.Brightness = 1.4
		pg.Parent = panel
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(0.92, 0, 0.5, 0)
		tl.Position = UDim2.new(0.04, 0, 0.25, 0)
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamBold
		tl.TextScaled = true
		tl.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55)
		tl.Text = tagline
		tl.Parent = pg
	end

	-- marquee header with the sign, gold borders and chasing bulbs
	local header = part(m, "Marquee", Vector3.new(26, 5, 3), at(0, 26.7, -6), BLACK, Enum.Material.SmoothPlastic)
	part(m, "MarqueeTrim", Vector3.new(26.4, 0.4, 3.2), at(0, 29.3, -6), GOLD, Enum.Material.Metal, { Decor = true })
	part(m, "MarqueeTrim", Vector3.new(26.4, 0.4, 3.2), at(0, 24.1, -6), GOLD, Enum.Material.Metal, { Decor = true })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = header
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0.8, 0)
	text.Position = UDim2.new(0, 0, 0.1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = label
	text.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 200)),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 244, 200)),
	})
	grad.Rotation = 90
	grad.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = color
	stroke.Parent = text
	local b = 0
	for x = -12.4, 12.41, 1.2 do
		b += 1
		for _, y in ipairs({ 24.55, 28.85 }) do
			part(m, "Bulb", Vector3.new(0.45, 0.45, 0.45), at(x, y, -7.65), BULB, Enum.Material.Neon, { Decor = true, Shape = Enum.PartType.Ball, NoShadow = true, Fx = "Chase" }):SetAttribute("Index", b)
		end
	end

	-- sweeping searchlights on top of the marquee
	for i, s in ipairs({ -1, 1 }) do
		part(m, "LampBase", Vector3.new(1.8, 0.8, 1.8), at(s * 11, 29.9, -6), GOLD, Enum.Material.Metal, { Decor = true })
		local head = part(m, "Searchlight", Vector3.new(1.6, 1.6, 2.6), at(s * 11, 31.2, -6) * CFrame.Angles(math.rad(-25), 0, 0), GLOSS, Enum.Material.Metal, { Decor = true, Fx = "Sweep" })
		head:SetAttribute("Phase", i * 2.1)
		local lens = part(m, "SearchlightLens", Vector3.new(1.3, 1.3, 0.1), head.CFrame * CFrame.new(0, 0, -1.32), Color3.new(1, 1, 1), Enum.Material.Neon, { Decor = true, NoShadow = true })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = lens
		weld.Parent = lens
		lens.Anchored = false
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0, -1.3)
		a0.Parent = head
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0, -70)
		a1.Parent = head
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 1.2
		beam.Width1 = 14
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		beam.Segments = 1
		beam.Parent = head
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = 22
		spot.Range = 60
		spot.Brightness = 2.5
		spot.Color = Color3.new(1, 1, 1):Lerp(color, 0.3)
		spot.Parent = head
	end

	-- velvet ropes and gold stanchions lining the carpet out front
	for _, s in ipairs({ -1, 1 }) do
		local prev
		for _, z in ipairs({ -10, -14.5, -19, -23.5 }) do
			local base = at(s * 8, 0, z)
			part(m, "StanchionBase", Vector3.new(0.25, 1.4, 1.4), base * CFrame.new(0, 0.13, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal, { Decor = true, Shape = Enum.PartType.Cylinder })
			part(m, "Stanchion", Vector3.new(0.3, 3, 0.3), base * CFrame.new(0, 1.6, 0), GOLD, Enum.Material.Metal, { Decor = true })
			part(m, "StanchionTop", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, 3.2, 0), GOLD, Enum.Material.Metal, { Decor = true, Shape = Enum.PartType.Ball })
			local top = (base * CFrame.new(0, 2.8, 0)).Position
			if prev then
				local mid = (prev + top) / 2
				local len = (top - prev).Magnitude
				-- rope runs along the gate's Z; cylinder axis is X, so turn it 90°
				part(m, "VelvetRope", Vector3.new(len, 0.28, 0.28), CFrame.new(mid) * (originCF - originCF.Position) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, -0.25, 0), VELVET, Enum.Material.Fabric, { Decor = true, Shape = Enum.PartType.Cylinder })
			end
			prev = top
		end
	end

	-- low stage fog rolling out of the mouth
	local fogPart = part(m, "FogEmitter", Vector3.new(12, 0.2, 2), at(0, 0.3, -6.5), BLACK, Enum.Material.SmoothPlastic, { Decor = true, Transparency = 1, NoShadow = true })
	local fog = Instance.new("ParticleEmitter")
	fog.Name = "StageFog"
	fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.EmissionDirection = Enum.NormalId.Front
	fog.Color = ColorSequence.new(Color3.fromRGB(235, 235, 245), color:Lerp(Color3.new(1, 1, 1), 0.6))
	fog.Rate = 5
	fog.Lifetime = NumberRange.new(4, 6)
	fog.Speed = NumberRange.new(1, 2.5)
	fog.SpreadAngle = Vector2.new(50, 10)
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.82), NumberSequenceKeypoint.new(1, 1) })
	fog.Acceleration = Vector3.new(0, 0.2, 0)
	fog.RotSpeed = NumberRange.new(-10, 10)
	fog.Parent = fogPart

	m.Parent = parent
	return m
end

return Portal
