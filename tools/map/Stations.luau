--[[
	Stations — builds each piece of gym equipment from StationSpecs.

	Every station model contains:
	  Base      invisible part at the station origin (defines station space)
	  Rider     invisible part where the athlete's HumanoidRootPart is anchored
	  Approach  invisible floor point the athlete walks to before hopping on
	  Pad       floor plate (lit when the slot is unlocked)
	  Outline   floor outline strips (lit when the slot is unlocked)
	  Moving    Models the client animates (bar, stack, pedals...)
	  Cables    thin parts the client stretches between pulleys and handles
]]

local Geo = require("tools/map/Geo")
local Specs = require("src/ReplicatedStorage/Modules/Gym/StationSpecs")

local Stations = {}
local Pal = Geo.Palette
local M = Enum.Material
local rad = math.rad

-- ----------------------------------------------------------------------
-- Shared sub-builders
-- ----------------------------------------------------------------------
local function movingModel(station, name)
	return Geo.model(station:FindFirstChild("Moving"), name)
end

local function setPrimary(model, part)
	model.PrimaryPart = part
	return model
end

-- Olympic barbell centered at `cf` (axis = cf.X). Returns model.
local function barbell(parent, name, cf, plateColor)
	local b = Specs.BARBELL
	local m = Geo.model(parent, name)
	local shaftLen = b.SleeveStart * 2
	local shaft = Geo.cyl(m, "Shaft", shaftLen, b.ShaftDiameter, cf, Pal.Chrome, M.Metal, { Reflectance = 0.12, CanCollide = false })
	setPrimary(m, shaft)
	local sleeveLen = b.Length / 2 - b.SleeveStart
	for _, s in ipairs({ -1, 1 }) do
		Geo.cyl(m, "Collar", 0.1, 0.32, cf * CFrame.new(s * b.SleeveStart, 0, 0), Pal.Chrome, M.Metal, { CanCollide = false })
		Geo.cyl(m, "Sleeve", sleeveLen, b.SleeveDiameter, cf * CFrame.new(s * (b.SleeveStart + sleeveLen / 2), 0, 0), Pal.Chrome, M.Metal, { Reflectance = 0.15, CanCollide = false })
		local x = b.SleeveStart + 0.08
		for k = 1, b.Plates do
			local dia = k == 1 and b.PlateDiameter or b.PlateDiameter * 0.9
			x += b.PlateThickness / 2
			Geo.cyl(m, "Plate", b.PlateThickness, dia, cf * CFrame.new(s * x, 0, 0), plateColor or Pal.Plate, M.Rubber, { CanCollide = false })
			Geo.cyl(m, "PlateHub", b.PlateThickness + 0.02, 0.42, cf * CFrame.new(s * x, 0, 0), Pal.Chrome, M.Metal, { CanCollide = false })
			x += b.PlateThickness / 2 + 0.01
		end
		Geo.cyl(m, "Clip", 0.1, 0.3, cf * CFrame.new(s * (x + 0.06), 0, 0), Pal.Accent, M.Rubber, { CanCollide = false, Role = "Accent" })
	end
	return m
end

local function dumbbell(parent, name, cf)
	local d = Specs.DumbbellCurl
	local m = Geo.model(parent, name)
	local handle = Geo.cyl(m, "Handle", d.HandleLength, 0.17, cf, Pal.Steel, M.Metal, { CanCollide = false })
	setPrimary(m, handle)
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (d.HandleLength / 2 + d.HeadLength / 2)
		Geo.cyl(m, "Head", d.HeadLength, d.HeadDiameter, cf * CFrame.new(x, 0, 0), Pal.Plate, M.Rubber, { CanCollide = false })
		Geo.cyl(m, "Cap", 0.03, d.HeadDiameter * 0.55, cf * CFrame.new(x + s * (d.HeadLength / 2 + 0.01), 0, 0), Pal.Chrome, M.Metal, { CanCollide = false })
	end
	return m
end

-- Weight stack column. stackPos = bottom center (station-local). The top
-- `movingCount` plates live in Moving/Stack so the client can lift them.
local function weightStack(station, L, stackPos, plates, plateH, movingCount, height)
	height = height or 7.6
	local static = station
	local base = L(CFrame.new(stackPos))
	Geo.part(static, "StackBase", Vector3.new(2.3, 0.3, 1.3), base * CFrame.new(0, -0.2, 0), Pal.FrameDark, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(static, "StackPost", Vector3.new(0.32, height, 0.32), base * CFrame.new(s * 1.0, height / 2 - 0.35, 0), Pal.Frame, M.Metal)
		Geo.decorate(Geo.cyl(static, "GuideRod", height - 0.6, 0.08, base * CFrame.new(s * 0.42, height / 2 - 0.3, 0) * CFrame.Angles(0, 0, rad(90)), Pal.Chrome, M.Metal))
	end
	Geo.part(static, "StackTopBeam", Vector3.new(2.3, 0.3, 0.4), base * CFrame.new(0, height - 0.4, 0), Pal.Frame, M.Metal)
	local shroud = Geo.part(static, "StackShroud", Vector3.new(2.3, height - 0.8, 0.08), base * CFrame.new(0, height / 2 - 0.2, -0.62), Pal.FrameDark, M.Metal)
	Geo.decorate(Geo.part(static, "ShroudStripe", Vector3.new(0.18, height - 1.4, 0.02), shroud.CFrame * CFrame.new(0.7, 0, 0.05), Pal.Accent, M.Neon, { Role = "Accent" }))

	local moving = movingModel(station, "Stack")
	local first
	for i = 1, plates do
		local cf = base * CFrame.new(0, (i - 0.5) * plateH, 0)
		local isMoving = i > plates - movingCount
		local p = Geo.part(isMoving and moving or static, "StackPlate", Vector3.new(1.3, plateH - 0.025, 0.75), cf, Pal.Stack, M.Metal, { CanCollide = false })
		if isMoving and not first then
			first = p
		end
	end
	local topY = plates * plateH
	local cap = Geo.part(moving, "StackCap", Vector3.new(1.34, 0.12, 0.8), base * CFrame.new(0, topY + 0.06, 0), Pal.Chrome, M.Metal, { CanCollide = false })
	Geo.decorate(Geo.ball(moving, "Pin", 0.16, base * CFrame.new(0.1, (plates - movingCount + 0.5) * plateH, 0.42), Pal.Accent, M.Rubber, { Role = "Accent" }))
	setPrimary(moving, cap)
	return moving
end

local function cable(station, name, a, b)
	local folder = station:FindFirstChild("Cables")
	return Geo.decorate(Geo.tube(folder, name, a, b, 0.05, Pal.Black, M.Rubber))
end

local function pulley(parent, name, cf)
	return Geo.decorate(Geo.cyl(parent, name, 0.14, 0.5, cf, Pal.Chrome, M.Metal))
end

local function grip(parent, name, cf, length, diameter)
	return Geo.decorate(Geo.cyl(parent, name, length or 0.4, diameter or 0.2, cf, Pal.Accent, M.Rubber, { Role = "Accent" }))
end

-- ----------------------------------------------------------------------
-- Individual machines. L(localCF) -> world CFrame, P(v3) -> world point
-- ----------------------------------------------------------------------
local B = {}

function B.Treadmill(st, L, sp)
	local deckLen, w = sp.DeckLength, sp.DeckWidth
	Geo.part(st, "Deck", Vector3.new(w, 0.42, deckLen), L(CFrame.new(0, 0.29, -0.2)), Pal.FrameDark, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(st, "SideRail", Vector3.new(0.34, 0.1, deckLen - 0.5), L(CFrame.new(s * (w / 2 - 0.17), sp.BeltTop - 0.01, -0.05)), Color3.fromRGB(88, 90, 96), M.SmoothPlastic)
	end
	Geo.part(st, "Belt", Vector3.new(sp.BeltWidth, 0.06, sp.BeltLength), L(CFrame.new(0, sp.BeltTop - 0.03, 0)), Pal.Belt, M.Rubber, { CanCollide = false })
	Geo.part(st, "MotorHood", Vector3.new(w, 0.55, 0.95), L(CFrame.new(0, 0.62, -3.35)), Pal.Frame, M.SmoothPlastic)
	Geo.decorate(Geo.part(st, "HoodStripe", Vector3.new(w - 0.3, 0.06, 0.04), L(CFrame.new(0, 0.7, -2.86)), Pal.Accent, M.Neon, { Role = "Accent" }))
	Geo.cyl(st, "RearCap", w - 0.2, 0.45, L(CFrame.new(0, 0.34, 3.0)), Pal.Frame, M.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		Geo.beam(st, "Upright", L(CFrame.new(s * 1.25, 0.8, -3.35)).Position, L(CFrame.new(s * 1.25, 4.3, -3.6)).Position, 0.28, Pal.FrameDark, M.Metal)
		-- side handrail
		local a = L(CFrame.new(s * 1.38, 3.72, -3.45)).Position
		local b = L(CFrame.new(s * 1.38, 3.72, -1.85)).Position
		Geo.tube(st, "Handrail", a, b, 0.17, Pal.Frame, M.Metal)
		Geo.tube(st, "HandrailDrop", b, L(CFrame.new(s * 1.38, 0.62, -1.4)).Position, 0.15, Pal.Frame, M.Metal)
		grip(st, "RailGrip", Geo.axisCF(a, b) * CFrame.new(0.3, 0, 0), 0.9, 0.22)
	end
	local console = Geo.part(st, "Console", Vector3.new(2.9, 0.95, 0.9), L(CFrame.new(0, 4.55, -3.6) * CFrame.Angles(rad(35), 0, 0)), Pal.Frame, M.SmoothPlastic)
	local screen = Geo.decorate(Geo.part(st, "Screen", Vector3.new(1.7, 0.62, 0.04), console.CFrame * CFrame.new(0, 0.05, 0.46), Pal.Screen, M.Neon))
	Geo.surfaceText(screen, Enum.NormalId.Back, "4.4 MPH   0.0%   12:48", { Color = Color3.fromRGB(150, 220, 255), Font = Enum.Font.Code })
	Geo.tube(st, "FrontGrip", L(CFrame.new(-1.1, 3.95, -3.2)).Position, L(CFrame.new(1.1, 3.95, -3.2)).Position, 0.15, Pal.Accent, M.Rubber, { Role = "Accent" })

	local L2 = sp.BeltLength
	for k = 1, sp.Slats do
		local z = -L2 / 2 + (k - 0.5) * L2 / sp.Slats
		local m = movingModel(st, "Slat" .. k)
		setPrimary(m, Geo.decorate(Geo.part(m, "Slat", Vector3.new(sp.BeltWidth - 0.12, 0.02, 0.09), L(CFrame.new(0, sp.BeltTop + 0.006, z)), Pal.Slat, M.Rubber)))
	end
	return CFrame.new(0, sp.BeltTop + 3, sp.PelvisZ), Vector3.new(0, 0, 4.6)
end

function B.Bike(st, L, sp)
	local P = function(x, y, z)
		return L(CFrame.new(x, y, z)).Position
	end
	for _, z in ipairs({ -1.7, 1.5 }) do
		Geo.part(st, "Stabilizer", Vector3.new(2.3, 0.2, 0.32), L(CFrame.new(0, 0.14, z)), Pal.FrameDark, M.Metal)
		for _, s in ipairs({ -1, 1 }) do
			Geo.part(st, "Foot", Vector3.new(0.3, 0.1, 0.34), L(CFrame.new(s * 1.05, 0.05, z)), Pal.Plate, M.Rubber)
		end
	end
	Geo.beam(st, "MainBeam", P(0, 0.26, 1.5), P(0, 0.26, -1.7), 0.3, Pal.FrameDark, M.Metal)
	Geo.beam(st, "DownTube", P(0, 0.3, -1.55), P(0, 3.3, -1.25), 0.28, Pal.Frame, M.Metal)
	Geo.beam(st, "SeatTube", P(0, 0.3, 1.3), P(0, sp.SaddleTop - 0.22, sp.SaddleZ), 0.26, Pal.Frame, M.Metal)
	Geo.beam(st, "CrankTube", P(0, 0.3, 0.55), P(0, sp.CrankCenter.Y, sp.CrankCenter.Z), 0.26, Pal.Frame, M.Metal)
	-- chain guard
	Geo.part(st, "ChainGuard", Vector3.new(0.12, 0.9, 1.6), L(CFrame.new(0.38, 1.15, -0.45)), Pal.Frame, M.SmoothPlastic, { CanCollide = false })
	-- flywheel (spins)
	local fw = movingModel(st, "Flywheel")
	local fc = sp.FlywheelCenter
	local disc = Geo.cyl(fw, "Disc", 0.24, sp.FlywheelDiameter, L(CFrame.new(fc)), Pal.Chrome, M.Metal, { Reflectance = 0.2, CanCollide = false })
	setPrimary(fw, disc)
	for _, a in ipairs({ 0, 90 }) do
		Geo.decorate(Geo.part(fw, "Spoke", Vector3.new(0.27, 0.1, sp.FlywheelDiameter * 0.85), L(CFrame.new(fc) * CFrame.Angles(rad(a), 0, 0)), Pal.FrameDark, M.Metal))
	end
	Geo.decorate(Geo.cyl(fw, "Rim", 0.26, sp.FlywheelDiameter * 0.35, L(CFrame.new(fc)), Pal.Accent, M.Rubber, { Role = "Accent" }))
	-- handlebars
	local hb = sp.HandlebarPos
	Geo.tube(st, "Stem", P(0, 3.3, -1.25), P(hb.X, hb.Y, hb.Z), 0.16, Pal.Frame, M.Metal)
	Geo.tube(st, "Handlebar", P(-0.9, hb.Y, hb.Z), P(0.9, hb.Y, hb.Z), 0.14, Pal.Frame, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		Geo.tube(st, "Horn", P(s * sp.HandlebarGripX, hb.Y, hb.Z), P(s * sp.HandlebarGripX, hb.Y + 0.22, hb.Z - 0.45), 0.13, Pal.Frame, M.Metal)
		grip(st, "BarGrip", L(CFrame.new(s * sp.HandlebarGripX, hb.Y, hb.Z)), 0.4, 0.19)
	end
	local mon = Geo.part(st, "Monitor", Vector3.new(0.7, 0.45, 0.1), L(CFrame.new(0, hb.Y + 0.35, hb.Z - 0.08) * CFrame.Angles(rad(-30), 0, 0)), Pal.Frame, M.SmoothPlastic, { CanCollide = false })
	Geo.decorate(Geo.part(st, "MonitorScreen", Vector3.new(0.55, 0.3, 0.02), mon.CFrame * CFrame.new(0, 0, 0.05), Pal.Screen, M.Neon))
	-- saddle
	Geo.part(st, "Saddle", Vector3.new(0.62, 0.22, 1.05), L(CFrame.new(0, sp.SaddleTop - 0.11, sp.SaddleZ)), Pal.Pad, M.Leather)
	Geo.decorate(Geo.part(st, "SaddleNose", Vector3.new(0.36, 0.2, 0.5), L(CFrame.new(0, sp.SaddleTop - 0.12, sp.SaddleZ - 0.7)), Pal.Pad, M.Leather))
	-- crank + pedals (spin)
	local c, r = sp.CrankCenter, sp.CrankRadius
	local crank = movingModel(st, "Crank")
	local hub = Geo.cyl(crank, "Hub", 1.0, 0.34, L(CFrame.new(c)), Pal.Chrome, M.Metal, { CanCollide = false })
	setPrimary(crank, hub)
	Geo.decorate(Geo.part(crank, "ArmR", Vector3.new(0.08, r + 0.1, 0.14), L(CFrame.new(c + Vector3.new(0.52, r / 2, 0))), Pal.Chrome, M.Metal))
	Geo.decorate(Geo.part(crank, "ArmL", Vector3.new(0.08, r + 0.1, 0.14), L(CFrame.new(c + Vector3.new(-0.52, -r / 2, 0))), Pal.Chrome, M.Metal))
	for _, side in ipairs({ { "PedalR", 1, r }, { "PedalL", -1, -r } }) do
		local pm = movingModel(st, side[1])
		local pos = c + Vector3.new(side[2] * sp.PedalX, side[3], 0)
		setPrimary(pm, Geo.decorate(Geo.part(pm, "Pedal", Vector3.new(0.42, 0.08, 0.5), L(CFrame.new(pos)), Pal.FrameDark, M.Metal)))
		Geo.decorate(Geo.part(pm, "Strap", Vector3.new(0.44, 0.12, 0.06), L(CFrame.new(pos + Vector3.new(0, 0.1, -0.12))), Pal.Accent, M.Rubber, { Role = "Accent" }))
	end
	return CFrame.new(0, sp.SaddleTop + 0.9, sp.SaddleZ), Vector3.new(2.0, 0, 1.2)
end

function B.BenchPress(st, L, sp)
	local len = sp.PadZ1 - sp.PadZ0
	local mid = (sp.PadZ0 + sp.PadZ1) / 2
	Geo.part(st, "Pad", Vector3.new(sp.PadWidth, 0.3, len), L(CFrame.new(0, sp.PadTop - 0.15, mid)), Pal.Pad, M.Leather)
	Geo.decorate(Geo.part(st, "PadPiping", Vector3.new(sp.PadWidth + 0.02, 0.05, len + 0.02), L(CFrame.new(0, sp.PadTop - 0.28, mid)), Pal.Accent, M.Rubber, { Role = "Accent" }))
	Geo.part(st, "PadFrame", Vector3.new(0.45, 0.3, len - 0.3), L(CFrame.new(0, sp.PadTop - 0.46, mid)), Pal.Frame, M.Metal)
	for _, z in ipairs({ sp.PadZ0 + 0.35, sp.PadZ1 - 0.5 }) do
		Geo.part(st, "Leg", Vector3.new(0.3, sp.PadTop - 0.6, 0.3), L(CFrame.new(0, (sp.PadTop - 0.6) / 2, z)), Pal.Frame, M.Metal)
		Geo.part(st, "FootBar", Vector3.new(1.4, 0.18, 0.32), L(CFrame.new(0, 0.09, z)), Pal.FrameDark, M.Metal)
	end
	local uz = sp.HookZ + 0.18
	Geo.part(st, "UprightBase", Vector3.new(sp.UprightX * 2 + 0.5, 0.2, 0.5), L(CFrame.new(0, 0.1, uz)), Pal.FrameDark, M.Metal)
	Geo.part(st, "UprightBrace", Vector3.new(0.35, 0.2, 1.6), L(CFrame.new(0, 0.1, uz - 0.6)), Pal.FrameDark, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(st, "Upright", Vector3.new(0.32, 4.3, 0.32), L(CFrame.new(s * sp.UprightX, 2.15, uz)), Pal.Frame, M.Metal)
		Geo.decorate(Geo.part(st, "UprightStripe", Vector3.new(0.06, 3.6, 0.02), L(CFrame.new(s * sp.UprightX, 2.3, uz - 0.17)), Pal.Accent, M.Rubber, { Role = "Accent" }))
		local hookY = sp.HookY - Specs.BARBELL.ShaftDiameter / 2 - 0.06
		Geo.part(st, "JHook", Vector3.new(0.3, 0.12, 0.5), L(CFrame.new(s * sp.UprightX, hookY, sp.HookZ + 0.03)), Pal.Accent, M.Rubber, { Role = "Accent" })
		Geo.part(st, "JHookLip", Vector3.new(0.3, 0.3, 0.08), L(CFrame.new(s * sp.UprightX, hookY + 0.1, sp.HookZ - 0.2)), Pal.Accent, M.Rubber, { Role = "Accent" })
		-- plate storage peg with spare plates
		local peg = L(CFrame.new(s * (sp.UprightX + 0.55), 1.0, uz))
		Geo.cyl(st, "Peg", 0.9, 0.2, peg, Pal.Chrome, M.Metal)
		for k = 1, 2 do
			Geo.decorate(Geo.cyl(st, "SparePlate", 0.16, 1.5 - k * 0.2, peg * CFrame.new(s * (-0.25 + k * 0.18), 0.12 * k, 0), Pal.Plate, M.Rubber))
		end
	end
	barbell(st:FindFirstChild("Moving"), "Bar", L(CFrame.new(0, sp.HookY, sp.HookZ)))
	local rider = CFrame.new(0, sp.PadTop + 0.5, sp.PelvisZ) * CFrame.Angles(rad(90), 0, 0)
	return rider, Vector3.new(2.3, 0, -0.9)
end

function B.DumbbellCurl(st, L, sp)
	Geo.part(st, "Mat", Vector3.new(3.4, 0.04, 3.4), L(CFrame.new(0, 0.02, 0)), Color3.fromRGB(34, 35, 38), M.Rubber, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		local m = dumbbell(st:FindFirstChild("Moving"), s < 0 and "DumbbellL" or "DumbbellR", L(CFrame.new(s * 1.5, 2.35, 0) * CFrame.Angles(0, rad(90), 0)))
		m.Name = s < 0 and "DumbbellL" or "DumbbellR"
	end
	return CFrame.new(0, 3, 0), Vector3.new(0, 0, 2.4)
end

function B.LatPulldown(st, L, sp)
	local P = function(x, y, z)
		return L(CFrame.new(x, y, z)).Position
	end
	weightStack(st, L, sp.StackPos, sp.StackPlates, sp.PlateHeight, 6, 7.9)
	-- top beam over the athlete
	Geo.beam(st, "TopBeam", P(0, 7.85, sp.StackPos.Z), P(0, 7.85, sp.PulleyTop.Z + 0.3), 0.36, Pal.Frame, M.Metal)
	pulley(st, "TopPulley", L(CFrame.new(sp.PulleyTop)))
	pulley(st, "StackPulley", L(CFrame.new(0, sp.PulleyTop.Y, sp.StackPos.Z)))
	-- seat
	Geo.beam(st, "SeatRail", P(0, 0.16, sp.SeatZ + 0.5), P(0, 0.16, sp.StackPos.Z), 0.3, Pal.FrameDark, M.Metal)
	Geo.part(st, "SeatPost", Vector3.new(0.3, sp.SeatTop - 0.3, 0.3), L(CFrame.new(0, (sp.SeatTop - 0.3) / 2, sp.SeatZ)), Pal.Frame, M.Metal)
	Geo.part(st, "Seat", Vector3.new(1.4, 0.26, 1.3), L(CFrame.new(0, sp.SeatTop - 0.13, sp.SeatZ)), Pal.Pad, M.Leather)
	-- knee pads
	Geo.beam(st, "KneePost", P(0, sp.SeatTop - 0.3, sp.KneePadZ + 0.3), P(0, sp.KneePadY, sp.KneePadZ), 0.2, Pal.Frame, M.Metal)
	Geo.tube(st, "KneeBar", P(-0.9, sp.KneePadY, sp.KneePadZ), P(0.9, sp.KneePadY, sp.KneePadZ), 0.14, Pal.Chrome, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		Geo.cyl(st, "KneePad", 0.7, 0.45, L(CFrame.new(s * 0.5, sp.KneePadY, sp.KneePadZ)), Pal.Pad, M.Leather)
	end
	-- bar
	local bar = Geo.model(st:FindFirstChild("Moving"), "Bar")
	local bcf = L(CFrame.new(0, sp.BarRestY, sp.BarZ))
	setPrimary(bar, Geo.cyl(bar, "Shaft", sp.BarLength - 0.6, 0.14, bcf, Pal.Chrome, M.Metal, { CanCollide = false }))
	for _, s in ipairs({ -1, 1 }) do
		local a = bcf * Vector3.new(s * (sp.BarLength / 2 - 0.3), 0, 0)
		local b = bcf * Vector3.new(s * (sp.BarLength / 2), -0.28, 0)
		Geo.decorate(Geo.tube(bar, "Bend", a, b, 0.14, Pal.Chrome, M.Metal))
		grip(bar, "Grip", bcf * CFrame.new(s * sp.GripX, 0, 0), 0.55, 0.2)
	end
	Geo.decorate(Geo.part(bar, "Clip", Vector3.new(0.12, 0.2, 0.12), bcf * CFrame.new(0, 0.12, 0), Pal.Black, M.Metal))
	cable(st, "Cable1", L(CFrame.new(sp.PulleyTop)).Position, bcf * Vector3.new(0, 0.12, 0))
	local stackTop = sp.StackPos + Vector3.new(0, sp.StackPlates * sp.PlateHeight, 0)
	cable(st, "Cable2", L(CFrame.new(stackTop)).Position, P(0, sp.PulleyTop.Y, sp.StackPos.Z))
	return CFrame.new(0, sp.SeatTop + 1, sp.SeatZ), Vector3.new(0, 0, 2.6)
end

function B.Squat(st, L, sp)
	Geo.part(st, "Platform", Vector3.new(7.6, 0.04, 7), L(CFrame.new(0, 0.02, 0.6)), Color3.fromRGB(30, 31, 34), M.Rubber, { CanCollide = false })
	local H = sp.Height
	for _, z in ipairs({ sp.FrontPostZ, sp.BackPostZ }) do
		for _, s in ipairs({ -1, 1 }) do
			Geo.part(st, "Post", Vector3.new(0.36, H, 0.36), L(CFrame.new(s * sp.PostX, H / 2, z)), Pal.Frame, M.Metal)
			if z == sp.FrontPostZ then
				Geo.decorate(Geo.part(st, "PostStripe", Vector3.new(0.08, H - 1, 0.02), L(CFrame.new(s * sp.PostX, H / 2, z - 0.19)), Pal.Accent, M.Rubber, { Role = "Accent" }))
			end
		end
		Geo.part(st, "TopCross", Vector3.new(sp.PostX * 2 + 0.36, 0.3, 0.3), L(CFrame.new(0, H - 0.15, z)), Pal.Frame, M.Metal)
	end
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(st, "TopSide", Vector3.new(0.3, 0.3, sp.BackPostZ - sp.FrontPostZ), L(CFrame.new(s * sp.PostX, H - 0.15, (sp.FrontPostZ + sp.BackPostZ) / 2)), Pal.Frame, M.Metal)
		Geo.part(st, "FloorSide", Vector3.new(0.3, 0.2, sp.BackPostZ - sp.FrontPostZ + 0.4), L(CFrame.new(s * sp.PostX, 0.1, (sp.FrontPostZ + sp.BackPostZ) / 2)), Pal.FrameDark, M.Metal)
		local hookY = sp.HookY - Specs.BARBELL.ShaftDiameter / 2 - 0.06
		Geo.part(st, "JHook", Vector3.new(0.32, 0.12, sp.FrontPostZ - sp.HookZ + 0.2), L(CFrame.new(s * sp.PostX, hookY, (sp.FrontPostZ + sp.HookZ) / 2 - 0.05)), Pal.Accent, M.Rubber, { Role = "Accent" })
		Geo.part(st, "JHookLip", Vector3.new(0.32, 0.3, 0.08), L(CFrame.new(s * sp.PostX, hookY + 0.1, sp.HookZ - 0.2)), Pal.Accent, M.Rubber, { Role = "Accent" })
		Geo.part(st, "Safety", Vector3.new(0.3, 0.3, 2.3), L(CFrame.new(s * sp.PostX, sp.SafetyY, sp.FrontPostZ - 1.1)), Pal.Steel, M.Metal)
		local peg = L(CFrame.new(s * (sp.PostX + 0.6), 1.2, sp.BackPostZ))
		Geo.cyl(st, "Peg", 1.0, 0.2, peg, Pal.Chrome, M.Metal)
		for k = 1, 3 do
			Geo.decorate(Geo.cyl(st, "SparePlate", 0.16, 1.55 - k * 0.15, peg * CFrame.new(s * (-0.3 + k * 0.18), 0.05 * k, 0), Pal.Plate, M.Rubber))
		end
	end
	Geo.tube(st, "PullBar", L(CFrame.new(-sp.PostX, H - 0.5, sp.FrontPostZ - 0.1)).Position, L(CFrame.new(sp.PostX, H - 0.5, sp.FrontPostZ - 0.1)).Position, 0.16, Pal.Chrome, M.Metal)
	barbell(st:FindFirstChild("Moving"), "Bar", L(CFrame.new(0, sp.HookY, sp.HookZ)))
	return CFrame.new(0, 3, -0.95), Vector3.new(0, 0, -3.2)
end

function B.CableRow(st, L, sp)
	local P = function(x, y, z)
		return L(CFrame.new(x, y, z)).Position
	end
	weightStack(st, L, sp.StackPos, sp.StackPlates, sp.PlateHeight, 6, 7.2)
	Geo.beam(st, "Rail", P(0, 0.2, 2.5), P(0, 0.2, sp.ColumnZ + 0.6), 0.34, Pal.FrameDark, M.Metal)
	Geo.part(st, "SeatPost", Vector3.new(0.3, sp.SeatTop - 0.4, 0.3), L(CFrame.new(0, (sp.SeatTop - 0.4) / 2 + 0.2, sp.SeatZ)), Pal.Frame, M.Metal)
	Geo.part(st, "Seat", Vector3.new(1.3, 0.25, 1.6), L(CFrame.new(0, sp.SeatTop - 0.125, sp.SeatZ)), Pal.Pad, M.Leather)
	local plate = Geo.part(st, "FootPlate", Vector3.new(1.9, 0.12, 1.1), L(CFrame.new(0, sp.PlateY - 0.04, sp.PlateZ + 0.15) * CFrame.Angles(rad(62), 0, 0)), Pal.Steel, M.DiamondPlate)
	Geo.beam(st, "PlateBrace", P(0, 0.3, sp.PlateZ - 0.3), plate.CFrame.Position, 0.22, Pal.Frame, M.Metal)
	Geo.part(st, "PulleyHousing", Vector3.new(0.6, 0.6, 0.6), L(CFrame.new(sp.PulleyExit + Vector3.new(0, 0, -0.35))), Pal.Frame, M.Metal)
	pulley(st, "LowPulley", L(CFrame.new(sp.PulleyExit)))
	Geo.part(st, "HandleHook", Vector3.new(0.2, 0.2, 0.5), L(CFrame.new(sp.HandleRest + Vector3.new(0, -0.22, -0.2))), Pal.Steel, M.Metal)
	-- V handle
	local hm = Geo.model(st:FindFirstChild("Moving"), "Handle")
	local hcf = L(CFrame.new(sp.HandleRest))
	setPrimary(hm, Geo.decorate(Geo.part(hm, "Center", Vector3.new(0.2, 0.14, 0.3), hcf * CFrame.new(0, 0, -0.2), Pal.Chrome, M.Metal)))
	for _, s in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.tube(hm, "Arm", hcf * Vector3.new(0, 0, -0.3), hcf * Vector3.new(s * 0.2, 0.05, 0.05), 0.09, Pal.Chrome, M.Metal))
		Geo.decorate(Geo.tube(hm, "Grip", hcf * Vector3.new(s * 0.2, 0.28, 0.12), hcf * Vector3.new(s * 0.2, -0.18, -0.05), 0.17, Pal.Accent, M.Rubber, { Role = "Accent" }))
	end
	cable(st, "Cable1", L(CFrame.new(sp.PulleyExit)).Position, hcf * Vector3.new(0, 0, -0.3))
	return CFrame.new(0, sp.SeatTop + 1, sp.SeatZ), Vector3.new(0, 0, 3.4)
end

function B.LegExtension(st, L, sp)
	local P = function(x, y, z)
		return L(CFrame.new(x, y, z)).Position
	end
	weightStack(st, L, sp.StackPos, sp.StackPlates, sp.PlateHeight, 5, 5.6)
	Geo.beam(st, "Rail", P(0, 0.16, sp.StackPos.Z), P(0, 0.16, sp.PivotZ - 0.4), 0.32, Pal.FrameDark, M.Metal)
	Geo.part(st, "SeatPost", Vector3.new(0.34, sp.SeatTop - 0.4, 0.34), L(CFrame.new(0, (sp.SeatTop - 0.4) / 2 + 0.1, sp.SeatZ)), Pal.Frame, M.Metal)
	local seatFront = sp.PivotZ + 0.25
	local seatBack = 1.25
	Geo.part(st, "Seat", Vector3.new(1.6, 0.28, seatBack - seatFront), L(CFrame.new(0, sp.SeatTop - 0.14, (seatFront + seatBack) / 2)), Pal.Pad, M.Leather)
	-- adjustable back pad
	local bp = Geo.model(st:FindFirstChild("Moving"), "BackPad")
	setPrimary(bp, Geo.part(bp, "Pad", Vector3.new(1.5, 2.5, 0.36), L(CFrame.new(0, sp.SeatTop + 1.45, 1.05)), Pal.Pad, M.Leather, { CanCollide = false }))
	Geo.decorate(Geo.part(bp, "Post", Vector3.new(0.22, 1.9, 0.22), L(CFrame.new(0, sp.SeatTop + 0.6, 1.35)), Pal.Frame, M.Metal))
	-- cam housing on the right side at knee height
	Geo.cyl(st, "Cam", 0.3, 0.7, L(CFrame.new(1.05, sp.PivotY, sp.PivotZ)), Pal.Accent, M.Rubber, { Role = "Accent" })
	Geo.beam(st, "CamPost", P(1.05, 0.2, sp.PivotZ + 0.2), P(1.05, sp.PivotY, sp.PivotZ), 0.26, Pal.Frame, M.Metal)
	-- lever with ankle roller
	local lever = Geo.model(st:FindFirstChild("Moving"), "Lever")
	local rollerY, rollerZ = sp.PivotY - 1.1, sp.PivotZ - 0.72
	setPrimary(lever, Geo.decorate(Geo.beam(lever, "Arm", P(1.05, sp.PivotY, sp.PivotZ), P(1.05, rollerY, rollerZ), 0.18, Pal.Frame, M.Metal)))
	Geo.decorate(Geo.tube(lever, "Cross", P(-0.85, rollerY, rollerZ), P(1.05, rollerY, rollerZ), 0.12, Pal.Chrome, M.Metal))
	for _, s in ipairs({ -1, 1 }) do
		Geo.decorate(Geo.cyl(lever, "Roller", 0.7, 0.46, L(CFrame.new(s * 0.45, rollerY, rollerZ)), Pal.Pad, M.Leather))
	end
	-- side handles
	for _, s in ipairs({ -1, 1 }) do
		local h = CFrame.new(s * sp.HandleX, sp.SeatTop + 0.35, sp.SeatZ - 0.1)
		Geo.beam(st, "HandlePost", P(s * sp.HandleX, sp.SeatTop - 0.25, sp.SeatZ + 0.1), (L(h)).Position, 0.14, Pal.Frame, M.Metal)
		grip(st, "Handle", L(h * CFrame.Angles(0, rad(90), 0)), 0.6, 0.2)
	end
	return CFrame.new(0, sp.SeatTop + 1, 0.3), Vector3.new(-2.2, 0, 0.4)
end

function B.Deadlift(st, L, sp)
	local ps = sp.PlatformSize
	Geo.part(st, "PlatformWood", Vector3.new(3.2, ps.Y, ps.Z), L(CFrame.new(0, ps.Y / 2, 0.3)), Pal.Wood, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(st, "PlatformRubber", Vector3.new((ps.X - 3.2) / 2, ps.Y, ps.Z), L(CFrame.new(s * (1.6 + (ps.X - 3.2) / 4), ps.Y / 2, 0.3)), Color3.fromRGB(28, 28, 31), M.Rubber)
	end
	Geo.decorate(Geo.part(st, "PlatformEdge", Vector3.new(ps.X + 0.1, ps.Y + 0.01, 0.12), L(CFrame.new(0, ps.Y / 2, 0.3 - ps.Z / 2)), Pal.Accent, M.Rubber, { Role = "Accent" }))
	-- chalk bowl
	local stand = L(CFrame.new(4.7, 1.6, 2.5))
	Geo.part(st, "ChalkPost", Vector3.new(0.2, 3.2, 0.2), stand, Pal.Frame, M.Metal)
	Geo.decorate(Geo.cyl(st, "ChalkBowl", 0.35, 1.0, stand * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, rad(90)), Pal.Frame, M.Metal))
	Geo.decorate(Geo.cyl(st, "Chalk", 0.05, 0.85, stand * CFrame.new(0, 1.88, 0) * CFrame.Angles(0, 0, rad(90)), Pal.White, M.Sand))
	barbell(st:FindFirstChild("Moving"), "Bar", L(CFrame.new(0, ps.Y + Specs.BARBELL.PlateDiameter / 2, sp.BarZ)))
	return CFrame.new(0, ps.Y + 3, 0.55), Vector3.new(0, 0, 4.4)
end

function B.ShoulderPress(st, L, sp)
	Geo.part(st, "Seat", Vector3.new(1.3, 0.25, 1.3), L(CFrame.new(0, sp.SeatTop - 0.125, sp.SeatZ)), Pal.Pad, M.Leather)
	Geo.part(st, "SeatPost", Vector3.new(0.3, sp.SeatTop - 0.25, 0.3), L(CFrame.new(0, (sp.SeatTop - 0.25) / 2, sp.SeatZ)), Pal.Frame, M.Metal)
	local back = L(CFrame.new(0, sp.SeatTop + 1.65, sp.BackZ) * CFrame.Angles(rad(10), 0, 0))
	Geo.part(st, "BackPad", Vector3.new(1.25, 3.0, 0.32), back, Pal.Pad, M.Leather)
	Geo.decorate(Geo.part(st, "BackPiping", Vector3.new(1.27, 3.02, 0.05), back * CFrame.new(0, 0, 0.14), Pal.Accent, M.Rubber, { Role = "Accent" }))
	Geo.beam(st, "BackPost", L(CFrame.new(0, 0.2, sp.BackZ + 0.5)).Position, (back * CFrame.new(0, 0, 0.25)).Position, 0.26, Pal.Frame, M.Metal)
	Geo.part(st, "FloorFrame", Vector3.new(1.6, 0.18, 2.2), L(CFrame.new(0, 0.09, sp.SeatZ + 0.35)), Pal.FrameDark, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		dumbbell(st:FindFirstChild("Moving"), s < 0 and "DumbbellL" or "DumbbellR", L(CFrame.new(s * 1.7, 3.6, -0.2)))
	end
	return CFrame.new(0, sp.SeatTop + 1, sp.SeatZ), Vector3.new(0, 0, -2.9)
end

function B.PullUp(st, L, sp)
	local P = function(x, y, z)
		return L(CFrame.new(x, y, z)).Position
	end
	Geo.part(st, "BasePlate", Vector3.new(4.2, 0.25, 3.4), L(CFrame.new(0, 0.125, 0.8)), Pal.FrameDark, M.DiamondPlate)
	local postZ = 1.15
	for _, s in ipairs({ -1, 1 }) do
		Geo.part(st, "Post", Vector3.new(0.38, 9.5, 0.38), L(CFrame.new(s * 1.95, 4.75, postZ)), Pal.Frame, M.Metal)
		Geo.decorate(Geo.part(st, "PostStripe", Vector3.new(0.08, 8, 0.02), L(CFrame.new(s * 1.95, 4.8, postZ - 0.2)), Pal.Accent, M.Rubber, { Role = "Accent" }))
		Geo.beam(st, "HandleArm", P(s * 1.95, 9.3, postZ), P(s * 1.95, sp.HandleY + 0.1, sp.HandleZ), 0.3, Pal.Frame, M.Metal)
		grip(st, "PullGrip", L(CFrame.new(s * sp.HandleX, sp.HandleY, sp.HandleZ)), 0.7, 0.22)
		-- dip handles
		local a = P(s * 1.2, sp.DipY, postZ - 0.2)
		local b = P(s * 1.2, sp.DipY, sp.StepZ - 0.95)
		Geo.tube(st, "DipBar", a, b, 0.16, Pal.Frame, M.Metal)
		grip(st, "DipGrip", Geo.axisCF(a, b) * CFrame.new(0.35, 0, 0), 0.7, 0.22)
		Geo.beam(st, "DipBrace", P(s * 1.95, sp.DipY, postZ), a, 0.2, Pal.Frame, M.Metal)
		-- steps
		Geo.part(st, "Step", Vector3.new(0.95, 0.2, 1.0), L(CFrame.new(s * 0.85, sp.StepY - 0.1, sp.StepZ)), Pal.Steel, M.DiamondPlate)
		Geo.beam(st, "StepPost", P(s * 0.85, 0.25, sp.StepZ + 0.3), P(s * 0.85, sp.StepY - 0.2, sp.StepZ + 0.3), 0.2, Pal.Frame, M.Metal)
	end
	Geo.tube(st, "PullBar", P(-1.95, sp.HandleY + 0.1, sp.HandleZ), P(1.95, sp.HandleY + 0.1, sp.HandleZ), 0.18, Pal.Chrome, M.Metal)
	Geo.part(st, "TopCross", Vector3.new(4.3, 0.34, 0.34), L(CFrame.new(0, 9.35, postZ)), Pal.Frame, M.Metal)
	-- assist knee pad on a carriage
	local pad = Geo.model(st:FindFirstChild("Moving"), "KneePad")
	local restCenterY = sp.PadRestTop - 0.15
	setPrimary(pad, Geo.part(pad, "Pad", Vector3.new(1.5, 0.3, 1.1), L(CFrame.new(0, restCenterY, sp.KneePadZ)), Pal.Pad, M.Leather, { CanCollide = false }))
	Geo.decorate(Geo.beam(pad, "Carriage", P(0, restCenterY - 0.2, sp.KneePadZ + 0.3), P(0, restCenterY - 0.2, postZ), 0.22, Pal.Frame, M.Metal))
	weightStack(st, L, sp.StackPos, sp.StackPlates, sp.PlateHeight, 5, 6.2)
	return CFrame.new(0, sp.StepY + 3, sp.StepZ), Vector3.new(0, 0, -2.6)
end

-- ----------------------------------------------------------------------
-- decor = true builds a non-interactive copy (set dressing, no slot)
function Stations.Build(kind, slot, parent, baseCF, decor)
	local sp = Specs[kind]
	assert(sp and B[kind], "Unknown station kind " .. tostring(kind))
	local st = Instance.new("Model")
	st.Name = decor and ("Decor" .. kind) or ("Station" .. slot)
	if not decor then
		st:SetAttribute("Exercise", kind)
		st:SetAttribute("Slot", slot)
	end
	st.Parent = parent
	Geo.folder(st, "Moving")
	Geo.folder(st, "Cables")

	local L = function(cf)
		return baseCF * cf
	end
	local base = Geo.part(st, "Base", Vector3.new(1, 0.2, 1), baseCF * CFrame.new(0, 0.1, 0), Pal.Black, M.SmoothPlastic, { Transparency = 1 })
	Geo.decorate(base)
	base.CFrame = baseCF
	st.PrimaryPart = base

	local riderLocal, approachLocal = B[kind](st, L, sp)
	if decor then
		return st
	end

	local rider = Geo.decorate(Geo.part(st, "Rider", Vector3.new(2, 2, 1), baseCF * riderLocal, Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	rider.CastShadow = false
	local approach = Geo.decorate(Geo.part(st, "Approach", Vector3.new(1, 0.2, 1), baseCF * CFrame.new(approachLocal), Pal.Black, M.SmoothPlastic, { Transparency = 1 }))
	approach.CastShadow = false

	-- floor pad (slot indicator) at the approach point + outline around the footprint
	local pad = Geo.decorate(Geo.part(st, "Pad", Vector3.new(2.4, 0.06, 2.4), baseCF * CFrame.new(approachLocal + Vector3.new(0, 0.04, 0)), Color3.fromRGB(28, 30, 38), M.SmoothPlastic, { Transparency = 0.2 }))
	pad.CastShadow = false
	Geo.surfaceText(pad, Enum.NormalId.Top, tostring(slot), { Name = "SlotNumber", Color = Color3.fromRGB(230, 235, 245), PPS = 60 })

	local fp = sp.Footprint
	local outline = Geo.model(st, "Outline")
	local w, d = fp.X / 2 + 0.3, fp.Z / 2 + 0.3
	for _, e in ipairs({
		{ Vector3.new(fp.X + 0.6, 0.04, 0.14), Vector3.new(0, 0.02, -d) },
		{ Vector3.new(fp.X + 0.6, 0.04, 0.14), Vector3.new(0, 0.02, d) },
		{ Vector3.new(0.14, 0.04, fp.Z + 0.6), Vector3.new(-w, 0.02, 0) },
		{ Vector3.new(0.14, 0.04, fp.Z + 0.6), Vector3.new(w, 0.02, 0) },
	}) do
		local p = Geo.decorate(Geo.part(outline, "Edge", e[1], baseCF * CFrame.new(e[2]), Color3.fromRGB(28, 30, 38), M.SmoothPlastic))
		p.CastShadow = false
	end
	return st
end

return Stations
