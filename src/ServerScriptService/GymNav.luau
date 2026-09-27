--[[
	GymNav
	Deterministic routes into, through and out of the gyms, built from the
	invisible Nav points every plot carries (tools/map/Gym.luau):

	  Yard -> DoorOut -> Lobby -> CrossN (center aisle at the stair path)
	  -> StairFootN -> LandAN -> LandBN -> StairTop(N+1) ... -> machine

	NPCs walk these point to point (NpcService.WalkTo with a route), so they
	never depend on the navmesh to find the stairs.
]]

local GymNav = {}

local function navOf(plotModel)
	return plotModel and plotModel:FindFirstChild("Nav")
end

local function pt(nav, name)
	local p = nav and nav:FindFirstChild(name)
	return p and p.CFrame.Position or nil
end

local function add(route, p)
	if p then
		table.insert(route, p)
	end
end

-- Which plot (model) is `pos` inside, and on which floor?
function GymNav.Locate(pos)
	local map = workspace:FindFirstChild("GymWarsMap")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil, 1
	end
	for _, model in ipairs(plots:GetChildren()) do
		local zone = model:FindFirstChild("GymZone")
		local nav = navOf(model)
		if zone and nav then
			local lp = zone.CFrame:PointToObjectSpace(pos)
			local h = zone.Size / 2
			if math.abs(lp.X) <= h.X + 1 and math.abs(lp.Z) <= h.Z + 1 and lp.Y <= h.Y and lp.Y >= -h.Y - 2 then
				local base = pt(nav, "Lobby") or zone.CFrame.Position
				local fy = nav:GetAttribute("FloorH") or 16
				local rel = pos.Y - base.Y
				local floor = math.clamp(math.floor(rel / fy) + 1, 1, 3)
				return model, floor
			end
		end
	end
	return nil, 1
end

local function descend(route, nav, from, to)
	for k = from, to + 1, -1 do
		add(route, pt(nav, "StairTop" .. k))
		add(route, pt(nav, "LandB" .. (k - 1)))
		add(route, pt(nav, "LandA" .. (k - 1)))
		add(route, pt(nav, "StairFoot" .. (k - 1)))
	end
end

local function ascend(route, nav, from, to)
	for k = from, to - 1 do
		add(route, pt(nav, "StairFoot" .. k))
		add(route, pt(nav, "LandA" .. k))
		add(route, pt(nav, "LandB" .. k))
		add(route, pt(nav, "StairTop" .. (k + 1)))
	end
end

-- From a machine, first step out into the floor's walkway (center aisle on
-- floors 1-2, the lane on floor 3) so the walk to the stairs/door is clear.
local function exitToWalkway(route, nav, floor, pos, toStairs)
	if floor <= 2 then
		local cross = nav:FindFirstChild("Cross" .. floor)
		if cross then
			local lp = cross.CFrame:PointToObjectSpace(pos)
			add(route, cross.CFrame * Vector3.new(0, 0, lp.Z))
			if toStairs then
				add(route, cross.CFrame.Position)
			end
		end
	else
		local lane = nav:FindFirstChild("F3Lane")
		if lane then
			local lp = lane.CFrame:PointToObjectSpace(pos)
			local z = lp.Z + (lp.Z > -20 and 0.6 or 0)
			add(route, lane.CFrame * Vector3.new(lp.X, 0, z))
			add(route, lane.CFrame * Vector3.new(0, 0, z))
			add(route, pt(nav, "F3Lane"))
			add(route, pt(nav, "F3Turn"))
		end
	end
end

-- Route (list of Vector3, not including the final approach point) from
-- `fromPos` to a machine on `destFloor` of `destPlot`, whose approach point
-- is `approachPos`.
function GymNav.Route(fromPos, destPlot, destFloor, approachPos)
	local route = {}
	local destNav = navOf(destPlot)
	if not destNav then
		return route
	end
	local curPlot, curFloor = GymNav.Locate(fromPos)
	local cameViaStairsOrDoor = false

	-- leaving another gym: down to the ground floor and out the front door
	if curPlot and curPlot ~= destPlot then
		local nav = navOf(curPlot)
		exitToWalkway(route, nav, curFloor, fromPos, curFloor > 1)
		if curFloor > 1 then
			descend(route, nav, curFloor, 1)
			add(route, pt(nav, "Cross1"))
		end
		add(route, pt(nav, "Lobby"))
		add(route, pt(nav, "DoorOut"))
		add(route, pt(nav, "Yard"))
		curPlot, curFloor = nil, 1
	end

	-- outside: across the lawn and in through the door
	if not curPlot then
		add(route, pt(destNav, "Yard"))
		add(route, pt(destNav, "DoorOut"))
		add(route, pt(destNav, "Lobby"))
		curFloor = 1
		cameViaStairsOrDoor = true
	end

	if curFloor ~= destFloor and not cameViaStairsOrDoor then
		-- already inside this gym on another floor: out to the walkway first
		exitToWalkway(route, destNav, curFloor, fromPos, true)
	end
	if curFloor < destFloor then
		add(route, pt(destNav, "Cross" .. curFloor))
		ascend(route, destNav, curFloor, destFloor)
		cameViaStairsOrDoor = true
	elseif curFloor > destFloor then
		descend(route, destNav, curFloor, destFloor)
		cameViaStairsOrDoor = true
	end

	-- last stretch on the machine's floor: along the center aisle to the
	-- machine's row, then across to it (floors 1-2 have a center aisle;
	-- floor 3 is open rows, so the final steer handles it)
	if cameViaStairsOrDoor and destFloor <= 2 and approachPos then
		local lobby = pt(destNav, "Lobby")
		local cross = pt(destNav, "Cross" .. destFloor)
		if destFloor > 1 or curFloor ~= 1 then
			add(route, cross)
		end
		if lobby and cross then
			-- a point on the center aisle level with the machine
			local aisleCF = destNav:FindFirstChild("Cross" .. destFloor).CFrame
			local lp = aisleCF:PointToObjectSpace(approachPos)
			add(route, aisleCF * Vector3.new(0, 0, lp.Z))
		end
	elseif destFloor == 3 and cameViaStairsOrDoor and approachPos then
		-- off the stairs, behind the benches, down the lane, across to the row
		local lane = destNav:FindFirstChild("F3Lane")
		add(route, pt(destNav, "F3Turn"))
		add(route, pt(destNav, "F3Lane"))
		if lane then
			local lp = lane.CFrame:PointToObjectSpace(approachPos)
			-- walk the row a little on the open side of the machine
			local z = lp.Z + (lp.Z > -20 and 0.6 or 0)
			add(route, lane.CFrame * Vector3.new(0, 0, z))
			add(route, lane.CFrame * Vector3.new(lp.X, 0, z))
		end
	end
	return route
end

return GymNav
