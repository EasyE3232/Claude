--[[
	MeshCharacters
	Dresses every rig tagged with a MeshCharacter attribute in its imported
	model (see ReplicatedStorage.Modules.MeshCharacter).
]]

local RS = game:GetService("ReplicatedStorage")
local MeshCharacter = require(RS:WaitForChild("Modules"):WaitForChild("MeshCharacter"))

local function consider(inst)
	if inst:IsA("Model") and inst:GetAttribute("MeshCharacter") then
		task.spawn(MeshCharacter.Attach, inst)
	end
end

workspace.DescendantAdded:Connect(consider)
for _, d in ipairs(workspace:GetDescendants()) do
	consider(d)
end
