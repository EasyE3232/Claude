--[[
	Gym — builds one complete gym lot (building shell, interior, 12 stations).

	Plot-local space: origin at the building's floor center (ground level),
	-Z faces the conveyor (the entrance side), +Y up.
	  x in [-W/2, W/2], z in [-D/2, D/2]
]]

local Geo = require("tools/map/Geo")
local Stations = require("tools/map/Stations")
local Specs = require("src/ReplicatedStorage/Modules/Gym/StationSpecs")

local Gym = {}
local Pal = Geo.Palette
local M = Enum.Material
local rad = math.rad

Gym.W = 84
Gym.D = 96
Gym.H = 18
Gym.FLOOR_Y = 0.4

local W, D, H, FY = Gym.W, Gym.D, Gym.H, Gym.FLOOR_Y
local HW, HD = W / 2, D / 2

-- Station layout: slot -> { x, z, yawDegrees }
Gym.LAYOUT = {
	[1] = { -36.5, -22, 90 }, -- Treadmill (faces the window wall)
	[2] = { -12, -16, 0 }, -- Bench press
	[3] = { -6, 38, 180 }, -- Dumbbell curls (faces the mirror)
	[4] = { -37.5, -5, 90 }, -- Spin bike
	[5] = { 36, -22, -90 }, -- Lat pulldown (faces the stripe wall)
	[6] = { 12, -18, 0 }, -- Squat rack
	[7] = { 35, -9, -90 }, -- Seated cable row
	[8] = { 37, 3, 90 }, -- Leg extension (stack against the wall)
	[9] = { -36.5, -13.5, 90 }, -- Treadmill
	[10] = { -12, 8, 0 }, -- Deadlift platform
	[11] = { 8, 38, 180 }, -- Seated shoulder press
	[12] = { 38.5, 15, 90 }, -- Chin / dip assist
}

Gym.DECOR = {
	{ "Treadmill", -36.5, -30.5, 90 },
	{ "Bike", -37.5, 3.5, 90 },
	{ "Squat", 12, 10, 0 },
	{ "LatPulldown", 36, 29, -90 },
	{ "BenchPress", -2, 24, 90 },
	{ "ShoulderPress", 22, 38, 180 },
}

local function wall(parent, name, size, cf, role)
	return Geo.part(parent, name, size, cf, Pal.Wall, M.Plaster, { Role = role })
end

-- ----------------------------------------------------------------------
function Gym.Build(parent, plotId, plotCF)
	local model = Instance.new("Model")
	model.Name = "Plot" .. plotId
	model:SetAttribute("PlotId", plotId)
	model.Parent = parent

	local function L(x, y, z)
		return plotCF * CFrame.new(x, y, z)
	end
	local decor = Geo.folder(model, "Decor")

	-- ================= shell =================
	local floor = Geo.part(model, "Floor", Vector3.new(W, FY, D), L(0, FY / 2, 0), Pal.RubberFloor, M.Rubber)
	floor.PivotOffset = CFrame.new()
	model.PrimaryPart = floor

	-- zone lines on the floor (like the reference gym)
	for _, ln in ipairs({
		{ Vector3.new(0.18, 0.02, D - 4), Vector3.new(-26, 0, 0) },
		{ Vector3.new(0.18, 0.02, D - 4), Vector3.new(26, 0, 0) },
		{ Vector3.new(52, 0.02, 0.18), Vector3.new(0, 0, -30) },
		{ Vector3.new(52, 0.02, 0.18), Vector3.new(0, 0, 26) },
	}) do
		Geo.decorate(Geo.part(decor, "FloorLine", ln[1], L(ln[2].X, FY + 0.01, ln[2].Z), Color3.fromRGB(70, 100, 130), M.SmoothPlastic, { Role = "AccentDim" }))
	end
	-- cardio wood floor
	Geo.decorate(Geo.part(decor, "CardioFloor", Vector3.new(15.5, 0.04, 44), L(-HW + 8.25, FY + 0.02, -12), Pal.Wood, M.WoodPlanks))

	-- walls
	wall(model, "WallBack", Vector3.new(W, H, 1), L(0, H / 2, HD - 0.5), "Wall")
	wall(model, "WallRight", Vector3.new(1, H, D), L(HW - 0.5, H / 2, 0), "Wall")

	-- left wall with three big windows (blinds + daylight glow)
	local winZ0, winZ1 = -31, 11
	local winY0, winY1 = 4, 13
	wall(model, "WallLeft", Vector3.new(1, winY0, D), L(-HW + 0.5, winY0 / 2, 0), "Wall")
	wall(model, "WallLeftTop", Vector3.new(1, H - winY1, D), L(-HW + 0.5, (H + winY1) / 2, 0), "Wall")
	wall(model, "WallLeftFront", Vector3.new(1, winY1 - winY0, winZ0 + HD), L(-HW + 0.5, (winY0 + winY1) / 2, (-HD + winZ0) / 2), "Wall")
	wall(model, "WallLeftBack", Vector3.new(1, winY1 - winY0, HD - winZ1), L(-HW + 0.5, (winY0 + winY1) / 2, (winZ1 + HD) / 2), "Wall")
	local panes = 3
	local paneLen = (winZ1 - winZ0) / panes
	for i = 1, panes do
		local zc = winZ0 + (i - 0.5) * paneLen
		if i > 1 then
			wall(model, "Mullion", Vector3.new(1, winY1 - winY0, 1.2), L(-HW + 0.5, (winY0 + winY1) / 2, winZ0 + (i - 1) * paneLen), "Wall")
		end
		Geo.part(model, "Window", Vector3.new(0.2, winY1 - winY0, paneLen), L(-HW + 0.5, (winY0 + winY1) / 2, zc), Color3.fromRGB(210, 225, 235), M.Glass, { Transparency = 0.55 })
		Geo.decorate(Geo.part(decor, "Daylight", Vector3.new(0.1, winY1 - winY0, paneLen), L(-HW - 0.1, (winY0 + winY1) / 2, zc), Color3.fromRGB(235, 240, 245), M.Neon))
		for k = 0, 13 do
			local y = winY0 + 0.35 + k * ((winY1 - winY0 - 0.5) / 13)
			Geo.decorate(Geo.part(decor, "Blind", Vector3.new(0.06, 0.16, paneLen - 0.2), L(-HW + 1.15, y, zc) * CFrame.Angles(0, 0, rad(-20)), Pal.White, M.SmoothPlastic, { CastShadow = false }))
		end
		-- TV above each window bay
		local tv = Geo.part(decor, "TV", Vector3.new(0.3, 2.6, 4.6), L(-HW + 1.4, 14.9, zc), Pal.Black, M.SmoothPlastic, { CanCollide = false })
		local screen = Geo.decorate(Geo.part(decor, "TVScreen", Vector3.new(0.05, 2.3, 4.3), tv.CFrame * CFrame.new(0.16, 0, 0), Color3.fromRGB(16, 40, 80), M.Neon))
		Geo.surfaceText(screen, Enum.NormalId.Right, i == 2 and "GYM WARS LIVE" or (i == 1 and "LEG DAY" or "NO EXCUSES"), { Color = Color3.fromRGB(170, 215, 255), PPS = 30 })
	end

	-- front: glass storefront with open double doorway
	local doorHalf = 6
	local glassH = 11
	for _, s in ipairs({ -1, 1 }) do
		local x0, x1 = s * doorHalf, s * HW
		local cx, len = (x0 + x1) / 2, math.abs(x1 - x0)
		wall(model, "FrontBase", Vector3.new(len, 1, 1), L(cx, 0.5, -HD + 0.5), "Wall")
		Geo.part(model, "FrontGlass", Vector3.new(len, glassH - 1, 0.25), L(cx, 1 + (glassH - 1) / 2, -HD + 0.5), Color3.fromRGB(190, 210, 225), M.Glass, { Transparency = 0.6 })
		for k = 0, 4 do
			local mx = x0 + s * k * (len / 4)
			Geo.part(decor, "FrontMullion", Vector3.new(0.4, glassH, 0.45), L(mx, glassH / 2, -HD + 0.5), Pal.FrameDark, M.Metal, { CanCollide = false })
		end
	end
	wall(model, "FrontHeader", Vector3.new(W, H - glassH, 1), L(0, (H + glassH) / 2, -HD + 0.5), "Wall")
	-- parapet + sign
	wall(model, "Parapet", Vector3.new(W + 1, 2.5, D + 1), L(0, H + 1.25, 0), "Wall").Transparency = 0
	local sign = Geo.part(model, "Sign", Vector3.new(34, 4.5, 0.6), L(0, H - 3.3, -HD - 0.3), Pal.Accent, M.SmoothPlastic, { Role = "Accent", CanCollide = false })
	sign.Name = "Sign"
	Geo.decorate(Geo.part(decor, "SignGlow", Vector3.new(35, 0.3, 0.7), L(0, H - 5.75, -HD - 0.3), Pal.LED, M.Neon))
	-- entrance canopy
	Geo.part(decor, "Canopy", Vector3.new(16, 0.5, 6), L(0, glassH + 0.5, -HD - 3), Pal.FrameDark, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.part(decor, "CanopyLight", Vector3.new(15, 0.1, 0.3), L(0, glassH + 0.2, -HD - 5.8), Pal.LED, M.Neon))
	-- entry mat
	Geo.decorate(Geo.part(decor, "EntryMat", Vector3.new(10, 0.04, 5), L(0, FY + 0.02, -HD + 3.5), Color3.fromRGB(20, 20, 22), M.Carpet))

	-- ceiling + roof (the roof blocks the sky; ceiling underside is black like the reference)
	Geo.part(model, "Roof", Vector3.new(W, 1, D), L(0, H + 0.5, 0), Pal.Ceiling, M.SmoothPlastic)
	-- exposed ducts
	for _, x in ipairs({ -18, 4, 24 }) do
		local a, b = L(x, H - 2.4, -HD + 3).Position, L(x, H - 2.4, HD - 3).Position
		Geo.decorate(Geo.tube(decor, "Duct", a, b, 2.4, Pal.Duct, M.Foil))
		for z = -HD + 8, HD - 8, 12 do
			Geo.decorate(Geo.part(decor, "DuctBand", Vector3.new(2.55, 0.2, 2.55), L(x, H - 2.4, z) * CFrame.Angles(0, 0, 0), Color3.fromRGB(120, 124, 130), M.Metal, { Shape = Enum.PartType.Block }))
			Geo.decorate(Geo.part(decor, "Hanger", Vector3.new(0.08, 1.2, 0.08), L(x, H - 0.6, z), Pal.FrameDark, M.Metal))
		end
	end
	-- linear LED fixtures with real lights
	for _, x in ipairs({ -30, -8, 14, 32 }) do
		local fixture = Geo.part(decor, "LEDStrip", Vector3.new(0.5, 0.2, D - 10), L(x, H - 0.35, 0), Pal.LED, M.Neon)
		Geo.decorate(fixture)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 22
		light.Angle = 150
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(235, 242, 255)
		light.Shadows = false
		light.Parent = fixture
	end
	-- accent LED along the top of the stripe wall
	local cove = Geo.decorate(Geo.part(decor, "CoveLight", Vector3.new(0.3, 0.3, D - 4), L(HW - 1.2, 14.6, 0), Pal.Accent, M.Neon, { Role = "Accent" }))
	local coveLight = Instance.new("SurfaceLight")
	coveLight.Face = Enum.NormalId.Bottom
	coveLight.Range = 12
	coveLight.Brightness = 1.2
	coveLight.Angle = 90
	coveLight.Parent = cove

	-- stripe feature wall (right wall), like the blue striped panels in the reference
	for i = 0, 19 do
		local z = -32 + i * 3.4
		Geo.decorate(Geo.part(decor, "StripePanel", Vector3.new(0.25, 12, 1.6), L(HW - 1.1, 7.8, z), Pal.Accent, M.SmoothPlastic, { Role = "Accent" }))
		Geo.decorate(Geo.part(decor, "StripeGap", Vector3.new(0.2, 12, 1.8), L(HW - 1.05, 7.8, z + 1.7), Color3.fromRGB(16, 18, 26), M.SmoothPlastic))
	end

	-- mirror wall + dumbbell rack on the back wall
	local mirror = Geo.part(model, "Mirror", Vector3.new(50, 8, 0.15), L(0, FY + 5, HD - 1.1), Color3.fromRGB(205, 212, 220), M.Glass, { Reflectance = 0.55, Transparency = 0, CanCollide = false })
	mirror.CastShadow = false
	Geo.surfaceText(Geo.decorate(Geo.part(decor, "WallLogo", Vector3.new(30, 3, 0.1), L(0, 13.2, HD - 1.05), Pal.Black, M.SmoothPlastic, { Transparency = 1 })), Enum.NormalId.Front, "GYM WARS", { Color = Color3.fromRGB(235, 240, 255), PPS = 20, Font = Enum.Font.GothamBlack })
	local rackZ = HD - 3.2
	Geo.part(model, "DumbbellRack", Vector3.new(34, 0.25, 2.6), L(0, 2.1, rackZ), Pal.Frame, M.Metal)
	Geo.part(model, "DumbbellRackLow", Vector3.new(34, 0.25, 2.6), L(0, 0.9, rackZ + 0.2), Pal.Frame, M.Metal)
	for _, x in ipairs({ -16.5, -5.5, 5.5, 16.5 }) do
		Geo.part(decor, "RackLeg", Vector3.new(0.4, 2.2, 2.4), L(x, 1.1 + FY - 0.4, rackZ), Pal.FrameDark, M.Metal)
	end
	for i = 0, 11 do
		local x = -15.5 + i * 2.8
		for _, tier in ipairs({ { 2.55, rackZ - 0.2 }, { 1.35, rackZ + 0.3 } }) do
			local size = 0.45 + (i % 6) * 0.05
			local cf = L(x, tier[1], tier[2])
			Geo.decorate(Geo.cyl(decor, "RackBellHandle", 0.55, 0.15, cf, Pal.Steel, M.Metal))
			for _, s in ipairs({ -1, 1 }) do
				Geo.decorate(Geo.cyl(decor, "RackBellHead", 0.3, size, cf * CFrame.new(s * 0.42, 0, 0), Pal.Plate, M.Rubber))
			end
		end
	end

	-- columns (structural, like the reference)
	for _, c in ipairs({ { -22, -2 }, { 22, -2 }, { -22, 24 }, { 22, 24 } }) do
		Geo.part(model, "Column", Vector3.new(1.8, H, 1.8), L(c[1], H / 2, c[2]), Pal.Concrete, M.Concrete)
		Geo.decorate(Geo.part(decor, "ColumnWrap", Vector3.new(1.85, 1.2, 1.85), L(c[1], 3.2, c[2]), Pal.Accent, M.SmoothPlastic, { Role = "Accent" }))
	end

	-- kettlebells + plate tree + water fountain + benches (set dressing)
	for i = 0, 5 do
		local cf = L(-30 + i * 1.3, FY + 0.45, 44.6)
		Geo.decorate(Geo.ball(decor, "Kettlebell", 0.8 + i * 0.06, cf, Pal.Plate, M.Metal))
		Geo.decorate(Geo.part(decor, "KettlebellHandle", Vector3.new(0.5, 0.35, 0.12), cf * CFrame.new(0, 0.55, 0), Pal.Plate, M.Metal))
	end
	local tree = L(24, FY, -8)
	Geo.part(model, "PlateTree", Vector3.new(0.35, 3.4, 0.35), tree * CFrame.new(0, 1.7, 0), Pal.Frame, M.Metal)
	Geo.part(decor, "PlateTreeBase", Vector3.new(2, 0.2, 2), tree * CFrame.new(0, 0.1, 0), Pal.FrameDark, M.Metal)
	for k, h in ipairs({ 0.9, 1.8, 2.7 }) do
		for _, s in ipairs({ -1, 1 }) do
			Geo.decorate(Geo.cyl(decor, "TreePlate", 0.16, 1.5 - k * 0.2, tree * CFrame.new(s * 0.35, h, 0), Pal.Plate, M.Rubber))
		end
	end
	local fountain = L(HW - 2, FY, -40)
	Geo.part(decor, "Fountain", Vector3.new(1.4, 3.2, 1.2), fountain * CFrame.new(0, 1.6, 0), Pal.Chrome, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.part(decor, "FountainBasin", Vector3.new(1.6, 0.3, 1.4), fountain * CFrame.new(-0.1, 3.3, 0), Pal.Steel, M.Metal))

	-- ================= gameplay parts =================
	local desk = Geo.part(model, "FrontDesk", Vector3.new(9, 3.4, 2.6), L(22, FY + 1.7, -38), Pal.Accent, M.SmoothPlastic, { Role = "Accent" })
	Geo.part(decor, "DeskTop", Vector3.new(9.4, 0.2, 3), desk.CFrame * CFrame.new(0, 1.8, 0), Pal.White, M.Marble, { CanCollide = false })
	local monitor = Geo.part(decor, "DeskMonitor", Vector3.new(1.4, 0.9, 0.1), desk.CFrame * CFrame.new(1.5, 2.45, 0.3) * CFrame.Angles(0, rad(180), 0), Pal.Black, M.SmoothPlastic, { CanCollide = false })
	Geo.decorate(Geo.part(decor, "DeskScreen", Vector3.new(1.25, 0.75, 0.02), monitor.CFrame * CFrame.new(0, 0, -0.06), Pal.Screen, M.Neon))
	Geo.decorate(Geo.part(model, "DeskSpawn", Vector3.new(1, 1, 1), L(22, 3, -35.5), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	Geo.decorate(Geo.part(model, "PlotSpawn", Vector3.new(1, 1, 1), L(0, 4, -40), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))

	-- owner's heavy bag (the owner's "Do a Rep" station)
	local bagCF = L(-18, FY + 4.6, -38)
	Geo.decorate(Geo.part(decor, "BagChain", Vector3.new(0.1, H - 8.6, 0.1), L(-18, (H + 8.6) / 2, -38), Pal.Steel, M.Metal))
	local bag = Geo.part(model, "WorkoutStation", Vector3.new(5.6, 2.2, 2.2), bagCF * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(150, 30, 34), M.Leather)
	bag.Shape = Enum.PartType.Cylinder
	Geo.decorate(Geo.cyl(decor, "BagBand", 0.4, 2.25, bagCF * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, rad(90)), Pal.Black, M.Leather))

	-- the gym interior volume (entering it with a follower seats them)
	Geo.decorate(Geo.part(model, "GymZone", Vector3.new(W - 2, H - 2, D - 2), L(0, H / 2, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1, CanCollide = false }))

	-- ================= stations =================
	local stations = Geo.folder(model, "Stations")
	for slot, pos in ipairs(Gym.LAYOUT) do
		local kind = Specs.SLOT_EXERCISES[slot]
		local cf = L(pos[1], FY, pos[2]) * CFrame.Angles(0, rad(pos[3]), 0)
		Stations.Build(kind, slot, stations, cf)
	end

	-- extra (non-interactive) equipment so the floor feels like a real, busy gym
	for _, d in ipairs(Gym.DECOR) do
		Stations.Build(d[1], 0, decor, L(d[2], FY, d[3]) * CFrame.Angles(0, rad(d[4]), 0), true)
	end

	return model
end

return Gym
