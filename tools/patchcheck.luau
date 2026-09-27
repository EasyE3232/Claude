-- Offline test of tools/snippets/update_command.lua: runs it TWICE on an older place and saves the result.
--   git show <old-commit>:build/GymWars.rbxlx > build/old.rbxlx
--   lune run tools/patchcheck build/old.rbxlx build/patched.rbxlx   (then point staircheck/navcheck at it)
local process = require("@lune/process")
local fs = require("@lune/fs") local luau = require("@lune/luau") local roblox = require("@lune/roblox")
local g = roblox.deserializePlace(fs.readFile((process.args[1] or "build/old.rbxlx")))
local gr = roblox.Instance.new("Model") gr.Name = "GoodRonnie" gr.Parent = g:GetService("ServerStorage")
local env = {}
for k, v in roblox do env[k] = v end
local function lookAt(at, target)
	local fwd = (target - at).Unit local up = roblox.Vector3.new(0, 1, 0)
	local right = fwd:Cross(up).Unit local upv = right:Cross(fwd).Unit
	return roblox.CFrame.fromMatrix(at, right, upv, -fwd)
end
env.CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })
env.game = g env.workspace = g:GetService("Workspace")
for _, k in { "print", "warn", "ipairs", "pairs", "string", "math", "table", "tostring", "select", "type", "typeof", "setmetatable" } do env[k] = _G[k] or getfenv()[k] end
env.typeof = roblox.typeof or typeof
env.require = function(ms) return luau.load(ms.Source, { debugName = ms.Name, environment = env })() end
local src = fs.readFile("tools/snippets/update_command.lua")
luau.load(src, { debugName = "update", environment = env })()
local p1 = g:GetService("Workspace").GymWarsMap.Plots.Plot1.Floor.CFrame.Position
luau.load(src, { debugName = "update2", environment = env })()
local p2 = g:GetService("Workspace").GymWarsMap.Plots.Plot1.Floor.CFrame.Position
print("plot1 x after 1st paste:", p1.X, " after 2nd:", p2.X)
local map = g:GetService("Workspace").GymWarsMap
local walls, gates = 0, 0
for _, c in map.Environment:GetChildren() do if c.Name == "WorldWalls" then walls += 1 end end
for _, c in map.Belt:GetChildren() do if c.Name == "DropGate" or c.Name == "ExitGate" then gates += 1 end end
print("WorldWalls folders:", walls, "gates:", gates, "patch folder left:", g:GetService("ServerStorage"):FindFirstChild("_GymWarsPatch") ~= nil)
local yard = map.Plots.Plot1.Nav.Yard.CFrame.Position
print("Plot1 yard:", yard)
-- hidden floor moved with its plot?
local h = g:GetService("ServerStorage").HiddenGymFloors.Plot1.Floor2
local ramp for _, d in h:GetChildren() do if d.Name == "StairRamp" then ramp = d end end
print("Plot1 floor2 ramp local x:", (map.Plots.Plot1.Floor.CFrame:PointToObjectSpace(ramp.CFrame.Position)).X)
for _, d in g:GetDescendants() do if d:IsA("TextLabel") and d:FindFirstAncestor("Belt") then d:Destroy() end end
fs.writeFile((process.args[2] or "build/patched.rbxlx"), roblox.serializePlace(g))
