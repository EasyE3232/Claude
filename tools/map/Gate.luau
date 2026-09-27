--[[
	Gate — minimalist teleporter set into the world wall.

	  Gate.Build(parent, name, faceCF, color, label, width, height, depth) -> Model

	faceCF: ground center of the doorway on the wall's inner face; -Z points
	out into the world. The wall itself leaves the opening (Walls.Build with an
	opening); the gate lines it: matte black surround, one thin neon outline,
	black reveals, a glowing portal plane recessed in the wall with a light bar
	that sweeps up and down, and a clean label.

	Pure Roblox API: the same code builds the map offline and patches a live
	place. "PortalFx" parts are animated by StarterPlayerScripts.PortalFx
	(Pulse = portal plane, Scan = light bar). Neon lines are named
	"TunnelGlow" so rarity spawns flash them.
]]

local Gate = {}

local MATTE = Color3.fromRGB(16, 16, 19)
local SATIN = Color3.fromRGB(28, 28, 33)

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

function Gate.Build(parent, name, faceCF, color, label, width, height, depth)
	local W, H, D = width or 12, height or 18, depth or 4
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Portal", true)
	local function at(x, y, z)
		return faceCF * CFrame.new(x, y, z)
	end

	-- matte surround, slightly proud of the stone
	local J = 2.2 -- jamb width
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Surround", Vector3.new(J, H + J, 1), at(s * (W / 2 + J / 2), (H + J) / 2, -0.5), MATTE, Enum.Material.SmoothPlastic, { Reflectance = 0.04 })
	end
	local header = part(m, "Surround", Vector3.new(W + J * 2, J, 1), at(0, H + J / 2, -0.5), MATTE, Enum.Material.SmoothPlastic, { Reflectance = 0.04 })

	-- one thin neon outline around the opening, plus the threshold line
	local g = 0.22
	for _, s in ipairs({ -1, 1 }) do
		part(m, "TunnelGlow", Vector3.new(g, H, g), at(s * (W / 2 + g / 2), H / 2, -1.02), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
	end
	part(m, "TunnelGlow", Vector3.new(W + g * 2, g, g), at(0, H + g / 2, -1.02), color, Enum.Material.Neon, { Decor = true, NoShadow = true })
	part(m, "TunnelGlow", Vector3.new(W, 0.06, g), at(0, 0.15, -1.1), color, Enum.Material.Neon, { Decor = true, NoShadow = true })

	-- black reveals lining the doorway through the wall + a satin floor plate
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Reveal", Vector3.new(0.3, H, D), at(s * (W / 2 - 0.15), H / 2, D / 2), SATIN, Enum.Material.SmoothPlastic, { Decor = true })
	end
	part(m, "Reveal", Vector3.new(W, 0.3, D), at(0, H - 0.15, D / 2), SATIN, Enum.Material.SmoothPlastic, { Decor = true })
	part(m, "FloorPlate", Vector3.new(W, 0.14, D + 2), at(0, 0.07, D / 2 - 1), SATIN, Enum.Material.SmoothPlastic, { Reflectance = 0.12 })

	-- the portal plane, recessed in the wall, and the scanning light bar
	local plane = part(m, "PortalPlane", Vector3.new(W - 0.6, H - 0.6, 0.2), at(0, H / 2, D * 0.45), color, Enum.Material.Neon, { Decor = true, Transparency = 0.2, NoShadow = true, Fx = "Pulse" })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 2.5
	light.Parent = plane
	local shimmer = Instance.new("ParticleEmitter")
	shimmer.Name = "Shimmer"
	shimmer.EmissionDirection = Enum.NormalId.Front
	shimmer.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	shimmer.LightEmission = 1
	shimmer.Rate = 10
	shimmer.Lifetime = NumberRange.new(1.5, 2.5)
	shimmer.Speed = NumberRange.new(0.6, 1.6)
	shimmer.SpreadAngle = Vector2.new(20, 20)
	shimmer.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	shimmer.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	shimmer.Parent = plane
	local bar = part(m, "ScanBar", Vector3.new(W - 0.6, 0.12, 0.1), at(0, H / 2, D * 0.45 - 0.2), Color3.new(1, 1, 1), Enum.Material.Neon, { Decor = true, Transparency = 0.25, NoShadow = true, Fx = "Scan" })
	bar:SetAttribute("Low", 0.6)
	bar:SetAttribute("High", H - 0.6)
	-- solid back so nothing outside the wall shows through the portal
	part(m, "Backstop", Vector3.new(W + 2, H + 2, 1), at(0, H / 2, D + 0.5), MATTE, Enum.Material.SmoothPlastic)

	-- clean label on the header
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.Parent = header
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(0.8, 0, 0.42, 0)
	text.Position = UDim2.new(0.1, 0, 0.29, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(240, 242, 248)
	text.Text = label
	text.Parent = gui

	m.Parent = parent
	return m
end

return Gate
