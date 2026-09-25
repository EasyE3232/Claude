--[[
	EnvironmentService
	Sky dressing at server start: adds dynamic Clouds to Terrain. The ground
	itself is the map's flat grass part (GymWarsMap.Environment.Ground).
]]

local EnvironmentService = {}

function EnvironmentService.Init()
	local terrain = workspace.Terrain
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(245, 245, 250)
		clouds.Parent = terrain
	end
end

return EnvironmentService
