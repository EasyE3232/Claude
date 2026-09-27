-- Offline NPC route check: lune run tools/navcheck (plans every machine route in a gym and sweeps a body along each leg)
local fs = require("@lune/fs")
local L = require("./lib/loader")
local R = L.roblox
local Vector3, CFrame = R.Vector3, R.CFrame
local g = R.deserializePlace(fs.readFile("build/GymWars.rbxlx"))
L.setGame(g)
local ws = g:GetService("Workspace")
local plots = ws.GymWarsMap.Plots
local hidden = g:GetService("ServerStorage").HiddenGymFloors
local testPlot = plots.Plot2
for _, n in { "Floor2", "Floor3", "Roof3" } do hidden[testPlot.Name][n].Parent = testPlot end
testPlot.Roof1.Parent = hidden[testPlot.Name]
local GymNav = L.require("src/ServerScriptService/GymNav")
-- collidable parts (all plots + env, excluding stair ramps/landings which ARE the walking surface)
local parts = {}
for _, d in ws.GymWarsMap:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide and d.Name ~= "Ground" and d.Name ~= "RedCarpet" and d.Name ~= "StairRamp" and d.Name ~= "Landing" and not d.Name:match("^Floor$") and not d.Name:match("^Slab") then
		table.insert(parts, d)
	end
end
local function inside(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return math.abs(lp.X) <= h.X + 0.8 and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z + 0.8 -- 0.8 = body radius
end
local function sweep(a, b)
	local hits = {}
	local lo = Vector3.new(math.min(a.X, b.X) - 12, math.min(a.Y, b.Y) - 12, math.min(a.Z, b.Z) - 12)
	local hi = Vector3.new(math.max(a.X, b.X) + 12, math.max(a.Y, b.Y) + 12, math.max(a.Z, b.Z) + 12)
	local near = {}
	for _, part in parts do
		local c = part.CFrame.Position
		local r = part.Size.Magnitude / 2
		if c.X + r > lo.X and c.X - r < hi.X and c.Y + r > lo.Y and c.Y - r < hi.Y and c.Z + r > lo.Z and c.Z - r < hi.Z then
			table.insert(near, part)
		end
	end
	local n = math.max(2, math.ceil((b - a).Magnitude / 0.5))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		for _, h in { 1.5, 3, 4.5, 6 } do
			local q = p + Vector3.new(0, h, 0)
			for _, part in near do
				if inside(part, q) then hits[part.Name .. "/" .. part.Parent.Name] = true end
			end
		end
	end
	local out = {}
	for k in hits do table.insert(out, k) end
	return out
end
local start = Vector3.new(0, 3, 0) -- on the carpet
for _, st in testPlot:GetDescendants() do
	if st:IsA("Model") and st:GetAttribute("Floor") and st:FindFirstChild("Approach") then
		local ap = st.Approach.CFrame.Position
		local route = GymNav.Route(start, testPlot, st:GetAttribute("Floor"), ap)
		table.insert(route, ap)
		print(("slot %d (%s, floor %d): %d points"):format(st:GetAttribute("Slot"), st.Name, st:GetAttribute("Floor"), #route))
		local prev = start
		for i, p in route do
			-- stair legs: skip body sweep where the path is on a ramp (legs that change height)
			if math.abs(p.Y - prev.Y) < 1 then
				local hits = sweep(Vector3.new(prev.X, p.Y, prev.Z), p)
				if #hits > 0 then print("   leg " .. i .. " BLOCKED:", table.concat(hits, ", ")) end
			end
			prev = p
		end
	end
end
print("--- theft: Plot2 floor 2 -> Plot3 floor 3 ---")
local other = plots.Plot3
for _, n in { "Floor2", "Floor3", "Roof3" } do hidden[other.Name][n].Parent = other end
other.Roof1.Parent = hidden[other.Name]
local fromSt, toSt
for _, st in testPlot:GetDescendants() do if st:IsA("Model") and st:GetAttribute("Slot") == 17 and st:FindFirstChild("Approach") then fromSt = st end end
for _, st in other:GetDescendants() do if st:IsA("Model") and st:GetAttribute("Slot") == 31 and st:FindFirstChild("Approach") then toSt = st end end
local from = fromSt.Approach.CFrame.Position + Vector3.new(0, 4, 0)
local ap = toSt.Approach.CFrame.Position
local route = GymNav.Route(from, other, 3, ap)
table.insert(route, ap)
print("points:", #route)
local prev = from - Vector3.new(0, 4, 0)
for i, p in route do
	if math.abs(p.Y - prev.Y) < 1 then
		local hits = sweep(Vector3.new(prev.X, p.Y, prev.Z), p)
		if #hits > 0 then print("   leg " .. i .. " BLOCKED:", table.concat(hits, ", ")) end
	end
	prev = p
end
print("theft route checked")
print("--- theft: Plot2 floor 3 -> Plot3 floor 1 ---")
local f3, t1
for _, st in testPlot:GetDescendants() do if st:IsA("Model") and st:GetAttribute("Slot") == 29 and st:FindFirstChild("Approach") then f3 = st end end
for _, st in other:GetDescendants() do if st:IsA("Model") and st:GetAttribute("Slot") == 5 and st:FindFirstChild("Approach") then t1 = st end end
local from2 = f3.Approach.CFrame.Position + Vector3.new(0, 4, 0)
local ap2 = t1.Approach.CFrame.Position
local r2 = GymNav.Route(from2, other, 1, ap2)
table.insert(r2, ap2)
print("points:", #r2)
local pv = from2 - Vector3.new(0, 4, 0)
for i, p in r2 do
	if math.abs(p.Y - pv.Y) < 1 then
		local hits = sweep(Vector3.new(pv.X, p.Y, pv.Z), p)
		if #hits > 0 then print("   leg " .. i .. " BLOCKED:", table.concat(hits, ", ")) end
	end
	pv = p
end
print("floor-3 exit route checked")
