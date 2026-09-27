--[[
	ClockBoard — the guaranteed-drop clocks set into the wall above the drop gate.

	  ClockBoard.Build(parent, faceCF, gateTop) -> Model "DropClock"

	faceCF: ground center of the gate on the wall's inner face (-Z = out into
	the world), same frame Gate.Build uses. A matte black panel with two rows:
	"LEGENDARY  4:32" and "MYTHIC  12:10"; only the rarity word is colored
	(RichText). StarterPlayerScripts.DropClocks fills in the times from the
	workspace attributes GuaranteeLegendaryAt / GuaranteeMythicAt.
	Pure Roblox API (shared by the map builder and the live patch).
]]

local ClockBoard = {}

local MATTE = Color3.fromRGB(16, 16, 19)

local function part(parent, name, size, cf, color, material, decor)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if decor then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

ClockBoard.ROWS = {
	{ Name = "Legendary", Word = "LEGENDARY", Hex = "#FFB02E" },
	{ Name = "Mythic", Word = "MYTHIC", Hex = "#FF3878" },
}

function ClockBoard.Build(parent, faceCF, gateTop)
	local m = Instance.new("Model")
	m.Name = "DropClock"
	local y = (gateTop or 20.2) + 1 + 3.5
	local face = part(m, "ClockFace", Vector3.new(22, 7, 0.6), faceCF * CFrame.new(0, y, -0.3), MATTE, Enum.Material.SmoothPlastic)
	face.Reflectance = 0.04
	-- hairline between the rows
	part(m, "ClockRule", Vector3.new(18, 0.06, 0.05), faceCF * CFrame.new(0, y, -0.63), Color3.fromRGB(70, 70, 78), Enum.Material.SmoothPlastic, true)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Clock"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = face
	for i, row in ipairs(ClockBoard.ROWS) do
		local label = Instance.new("TextLabel")
		label.Name = row.Name
		label.Size = UDim2.new(0.84, 0, 0.3, 0)
		label.Position = UDim2.new(0.08, 0, i == 1 and 0.12 or 0.58, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(240, 242, 248)
		label.Text = ('<font color="%s">%s</font>   --:--'):format(row.Hex, row.Word)
		label.Parent = gui
	end

	m.Parent = parent
	return m
end

return ClockBoard
