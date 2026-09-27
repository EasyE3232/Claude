-- Offline stair check: lune run tools/staircheck (body sweep + walking-surface continuity on a revealed switchback)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local g = roblox.deserializePlace(fs.readFile("build/GymWars.rbxlx"))
local ws = g:GetService("Workspace")
local plot = ws.GymWarsMap.Plots.Plot1
local hidden = g:GetService("ServerStorage").HiddenGymFloors.Plot1
for _, n in { "Floor2", "Roof2" } do hidden[n].Parent = plot end plot.Roof1.Parent = hidden
local floor = plot.Floor
local base = floor.CFrame * CFrame.new(0, -floor.Size.Y / 2, 0) -- plot origin at ground
-- collect collidable parts
local parts = {}
for _, d in plot:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide then table.insert(parts, d) end
end
print("collidable parts in plot:", #parts)
-- OBB vs point test helper: is world point p inside part?
local function inside(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
end
local function probe(label, pts)
	local hits = {}
	for _, lp in pts do
		local wp = base:PointToWorldSpace(lp)
		for _, part in parts do
			if part.Name ~= "StairRamp" and part.Name ~= "Landing" and inside(part, wp) then
				hits[part.Name .. " @" .. part.Parent.Name] = (hits[part.Name .. " @" .. part.Parent.Name] or 0) + 1
			end
		end
	end
	local n = 0
	for k, v in hits do print(label, "BLOCKED BY", k, v) n += 1 end
	if n == 0 then print(label, "clear") end
end
-- sweep columns (body 2 wide, heights 1..5 above walking surface)
local FY, FH = 0.4, 16
local function surfaceA(z) return FY + 0.5 + (z - 15) / 15 * 8 end
local function surfaceB(z) return FY + 8 + 0.5 + (30 - z) / 15 * 8 end
local pA, pB, pL, pTop, pBottom = {}, {}, {}, {}, {}
for z = 15.5, 29.5, 0.5 do for x = 16.5, 19.5, 1 do for h = 1, 5 do table.insert(pA, Vector3.new(x, surfaceA(z) + h, z)) end end end
for z = 15.5, 29.5, 0.5 do for x = 22.5, 25.5, 1 do for h = 1, 5 do table.insert(pB, Vector3.new(x, surfaceB(z) + h, z)) end end end
for z = 30.5, 34, 0.5 do for x = 16, 26, 1 do for h = 1, 5 do table.insert(pL, Vector3.new(x, FY + 8.5 + h, z)) end end end
for z = 10, 15, 0.5 do for x = 22.5, 25.5, 1 do for h = 1, 5 do table.insert(pTop, Vector3.new(x, FY + FH + h, z)) end end end
for z = 10, 15, 0.5 do for x = 16.5, 19.5, 1 do for h = 1, 5 do table.insert(pBottom, Vector3.new(x, FY + h, z)) end end end
probe("approach to flight A (floor 1)", pBottom)
probe("flight A", pA)
probe("landing", pL)
probe("flight B", pB)
probe("exit onto floor 2", pTop)
-- what's the walking surface under points? find ramp parts
for _, part in parts do if part.Name == "StairRamp" then
	local lp = base:PointToObjectSpace(part.CFrame.Position)
	print("ramp", part.Parent.Name, "center(local)", math.floor(lp.X*10)/10, math.floor(lp.Y*10)/10, math.floor(lp.Z*10)/10, "size", part.Size, "collide", part.CanCollide, "transp", part.Transparency)
end end
-- walking-surface continuity along the route: highest collidable top under each point
local function topAt(x, z, yMax)
	local best = -math.huge
	for _, part in parts do
		-- sample vertical line: test points from yMax down
		for y = yMax, yMax - 6, -0.05 do
			local wp = base:PointToWorldSpace(Vector3.new(x, y, z))
			if inside(part, wp) then
				if y > best then best = y end
				break
			end
		end
	end
	return best
end
local route = {}
for z = 8, 29.5, 0.5 do table.insert(route, { 18, z, "A" }) end
for x = 18, 24, 0.5 do table.insert(route, { x, 32.5, "L" }) end
for z = 30, 9, -0.5 do table.insert(route, { 24, z, "B" }) end
local prev
for _, r in route do
	local expect = r[3] == "A" and (r[2] < 15 and 0.4 or surfaceA(r[2])) or (r[3] == "L" and 8.9 or (r[2] < 15 and 16.4 or surfaceB(r[2])))
	local t = topAt(r[1], r[2], expect + 1.5)
	local flag = (prev and math.abs(t - prev) > 0.9) and "  <-- STEP " .. string.format("%.2f", t - prev) or ""
	if t < expect - 1.5 then flag ..= "  <-- NO FLOOR" end
	if flag ~= "" then print(string.format("%s x=%.1f z=%.1f top=%.2f expect=%.2f%s", r[3], r[1], r[2], t, expect, flag)) end
	prev = t
end
print("surface check done")
print("base", base.Position, "floor", floor.CFrame.Position)
for _, part in parts do if part.Name == "StairRamp" then
	local h = part.Size / 2
	local a = base:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(0, h.Y, -h.Z)))
	local b = base:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(0, h.Y, h.Z)))
	print(string.format("ramp top: front(z=%.2f,y=%.2f)  back(z=%.2f,y=%.2f)  x=%.2f", a.Z, a.Y, b.Z, b.Y, a.X))
end end
