--[[
	Geo — tiny helpers for building anchored geometry in the map builder.
	All helpers take a parent, a name and a WORLD CFrame.
]]

local Geo = {}

local C = Color3.fromRGB
Geo.Palette = {
	Frame = C(34, 35, 40),
	FrameDark = C(22, 22, 26),
	Chrome = C(186, 189, 196),
	Steel = C(120, 124, 132),
	Pad = C(50, 52, 58),
	Accent = C(40, 140, 255),
	Plate = C(26, 26, 29),
	PlateRim = C(55, 55, 60),
	Stack = C(62, 64, 70),
	Belt = C(22, 22, 24),
	Slat = C(46, 46, 50),
	Screen = C(24, 70, 140),
	RubberFloor = C(46, 48, 53),
	Wood = C(150, 112, 74),
	Wall = C(26, 27, 31),
	Ceiling = C(18, 18, 20),
	Duct = C(150, 154, 160),
	LED = C(245, 248, 255),
	Concrete = C(70, 72, 76),
	White = C(235, 236, 238),
	Black = C(12, 12, 14),
	Skin = C(234, 184, 146),
}

local function apply(p, opts)
	if not opts then
		return
	end
	for k, v in pairs(opts) do
		if k == "Role" then
			p:SetAttribute("ColorRole", v)
		elseif k == "Attrs" then
			for ak, av in pairs(v) do
				p:SetAttribute(ak, av)
			end
		else
			p[k] = v
		end
	end
end

function Geo.part(parent, name, size, cf, color, material, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or Geo.Palette.Frame
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	apply(p, opts)
	p.Parent = parent
	return p
end

-- Cylinder whose axis runs along the CFrame's X axis.
function Geo.cyl(parent, name, length, diameter, cf, color, material, opts)
	local p = Geo.part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Geo.ball(parent, name, diameter, cf, color, material, opts)
	local p = Geo.part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material, opts)
	p.Shape = Enum.PartType.Ball
	return p
end

-- CFrame whose X axis points from a to b, centered between them.
function Geo.axisCF(a, b)
	local mid = (a + b) / 2
	local dir = (b - a).Unit
	local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local z = dir:Cross(up).Unit
	local y = z:Cross(dir).Unit
	return CFrame.fromMatrix(mid, dir, y, z)
end

-- Cylinder tube from a to b.
function Geo.tube(parent, name, a, b, diameter, color, material, opts)
	return Geo.cyl(parent, name, (b - a).Magnitude, diameter, Geo.axisCF(a, b), color, material, opts)
end

-- Square beam from a to b.
function Geo.beam(parent, name, a, b, thickness, color, material, opts)
	local len = (b - a).Magnitude
	return Geo.part(parent, name, Vector3.new(len, thickness, thickness), Geo.axisCF(a, b), color, material, opts)
end

function Geo.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Geo.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Geo.decorate(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end

function Geo.surfaceText(part, face, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = opts.Name or "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.PPS or 40
	gui.LightInfluence = opts.LightInfluence or 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = opts.Background and 0 or 1
	label.BackgroundColor3 = opts.Background or Color3.new(0, 0, 0)
	label.Font = opts.Font or Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = opts.Color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return gui, label
end

return Geo
