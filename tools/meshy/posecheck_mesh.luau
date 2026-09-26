-- Poses a baked mesh character's rig offline: lune run tools/meshy/posecheck_mesh <Name>
-- -> build/mesh_poses.json (render with tools/meshy/render_mesh.py <Name>)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local L = require("../lib/loader")
local name = process.args[1] or "RonnieCurlman"
local data = L.require("src/ReplicatedStorage/MeshAssets/" .. name .. "/Mesh")
L.setGame({ GetService = function() return {} end })
local MC = L.require("src/ReplicatedStorage/Modules/MeshCharacter")
local RigSolver = L.require("src/ReplicatedStorage/Modules/Gym/RigSolver")
local Poses = L.require("src/ReplicatedStorage/Modules/Gym/Poses")
local rig = MC.BuildRig(data)
local r = RigSolver.new(rig)
r:setRootCFrame(rig.HumanoidRootPart.CFrame)
local out = {}
for _, pose in ipairs({ "Rest", "DoubleBiceps", "MostMuscular", "SideChest", "Point" }) do
	r:reset()
	if pose ~= "Rest" then
		Poses.Apply(r, pose)
	end
	local W = r:solve()
	local frame = { t = pose, parts = {} }
	for part in pairs(data.Chunks) do
		frame.parts[part] = { W[part]:GetComponents() }
	end
	table.insert(out, frame)
end
fs.writeFile("build/mesh_poses.json", serde.encode("json", out))
