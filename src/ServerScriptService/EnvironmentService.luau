--[[
	EnvironmentService
	Turns the map's flat placeholder ground into real Roblox Terrain when the
	server starts:
	  - a grass field under the whole map (Terrain grass renders with real
	    texture, and with Terrain.Decoration on, animated grass blades)
	  - rolling grassy hills beyond the boundary walls for a natural horizon
	  - dynamic Clouds
	The part named Ground (attribute EditOnly) only exists so the map isn't
	floating in the void in Studio's edit view; it's removed once terrain is in.
]]

local EnvironmentService = {}

function EnvironmentService.Init()
	local terrain = workspace.Terrain
	local map = workspace:WaitForChild("GymWarsMap")
	local env = map:WaitForChild("Environment")
	local ground = env:FindFirstChild("Ground")

	local size = ground and ground.Size or Vector3.new(320, 4, 520)

	-- realistic material colors
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(94, 124, 56))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(78, 108, 48))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(102, 84, 62))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(112, 108, 102))
	end)

	-- the field: an 8-stud slab whose top sits exactly at y = 0 (voxel aligned)
	local fieldX = math.ceil((size.X + 40) / 8) * 8
	local fieldZ = math.ceil((size.Z + 40) / 8) * 8
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(fieldX, 8, fieldZ), Enum.Material.Grass)

	-- rolling hills outside the walls
	local rng = Random.new(42)
	local hx, hz = fieldX / 2, fieldZ / 2
	for _ = 1, 44 do
		local side = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-1, 1)
		local pos
		if side == 1 then
			pos = Vector3.new(-hx - rng:NextNumber(20, 80), 0, along * (hz + 60))
		elseif side == 2 then
			pos = Vector3.new(hx + rng:NextNumber(20, 80), 0, along * (hz + 60))
		elseif side == 3 then
			pos = Vector3.new(along * (hx + 60), 0, -hz - rng:NextNumber(20, 80))
		else
			pos = Vector3.new(along * (hx + 60), 0, hz + rng:NextNumber(20, 80))
		end
		local r = rng:NextNumber(34, 70)
		terrain:FillBall(pos - Vector3.new(0, r * rng:NextNumber(0.45, 0.7), 0), r, Enum.Material.Grass)
		if rng:NextNumber() < 0.3 then
			terrain:FillBall(pos + Vector3.new(rng:NextNumber(-10, 10), -r * 0.5, rng:NextNumber(-10, 10)), r * 0.45, Enum.Material.Rock)
		end
	end
	-- a wider base so the horizon never shows the edge of the world
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(fieldX + 400, 4, fieldZ + 400), Enum.Material.Grass)

	if ground then
		ground:Destroy()
	end

	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(245, 245, 250)
		clouds.Parent = terrain
	end
end

return EnvironmentService
