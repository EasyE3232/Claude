--[[
	MeshCharacter
	Characters made from a Meshy (or any static textured) model, baked by
	tools/meshy/import.py into ReplicatedStorage.MeshAssets.<Name>:

	  Mesh.luau   rig (parts + joints at the model's real shoulders/elbows/...),
	              the mesh cut into the 15 R15 body parts, texture layout
	  Tex*.luau   base color texture, base64 RGB (4 chars = 1 pixel)

	Server: BuildRig(data) -> an invisible R15 rig that walks, paths and does
	every workout like any other influencer.
	Client: Attach(model) builds the textured body-part meshes with
	EditableMesh / EditableImage and welds each one to its rig part.

	Published games: EditableMesh/EditableImage need the owner to be ID
	verified with "Enable Mesh / Image APIs" on (Creator Dashboard). Studio
	play-tests always work. If creation fails, the rig parts are shown instead.
]]

local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")

local MeshCharacter = {}

local function assets()
	return RS:FindFirstChild("MeshAssets")
end

function MeshCharacter.Get(name)
	local folder = assets() and assets():FindFirstChild(name)
	local mod = folder and folder:FindFirstChild("Mesh")
	if not mod then
		return nil
	end
	local ok, data = pcall(require, mod)
	return ok and data or nil
end

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- ----------------------------------------------------------------------
-- Rig (server)
-- ----------------------------------------------------------------------
function MeshCharacter.BuildRig(data)
	local model = Instance.new("Model")
	model.Name = data.Name
	local parts = {}
	for name, def in pairs(data.Parts) do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = v3(def.Size)
		p.CFrame = CFrame.new(v3(def.Center))
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(90, 60, 45)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		parts[name] = p
	end
	for _, j in ipairs(data.Joints) do
		local name, p1, p0, pivot = j[1], parts[j[2]], parts[j[3]], v3(j[4])
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = CFrame.new(pivot - p0.CFrame.Position)
		m.C1 = CFrame.new(pivot - p1.CFrame.Position)
		m.Parent = p1
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = data.HipHeight
	hum.Parent = model
	Instance.new("Animator").Parent = hum
	model.PrimaryPart = parts.HumanoidRootPart
	model:SetAttribute("MeshCharacter", data.Name)
	return model
end

-- ----------------------------------------------------------------------
-- Visuals (client)
-- ----------------------------------------------------------------------
local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64[string.byte(alphabet, i)] = i - 1
	end
end

local textures = {} -- [name] = EditableImage | false (failed) | "loading"
local meshes = {} -- [name] = { [partName] = EditableMesh } | false

local function buildTexture(data)
	local folder = assets():FindFirstChild(data.Name)
	local tex = data.Texture
	local w, h = tex.Width, tex.Height
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	if not img then
		return nil
	end
	local buf = buffer.create(w * h * 4)
	local pixel = 0
	for _, modName in ipairs(tex.Modules) do
		local s = require(folder:WaitForChild(modName))
		local n = #s // 4
		for i = 0, n - 1 do
			local a, b, c, d = string.byte(s, i * 4 + 1, i * 4 + 4)
			local v = B64[a] * 262144 + B64[b] * 4096 + B64[c] * 64 + B64[d]
			local r, g, bl = v // 65536, (v // 256) % 256, v % 256
			buffer.writeu32(buf, (pixel + i) * 4, r + g * 256 + bl * 65536 + 4278190080)
			if i % 65536 == 65535 then
				task.wait() -- spread decoding over a few frames
			end
		end
		pixel += n
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	return img
end

local function buildMesh(chunk)
	local em = AssetService:CreateEditableMesh()
	if not em then
		return nil
	end
	local P, T, N, F = chunk.P, chunk.T, chunk.N, chunk.F
	local vids, tids, nids = {}, {}, {}
	for i = 1, #P, 3 do
		vids[#vids + 1] = em:AddVertex(Vector3.new(P[i], P[i + 1], P[i + 2]))
	end
	for i = 1, #T, 2 do
		tids[#tids + 1] = em:AddUV(Vector2.new(T[i], T[i + 1]))
	end
	for i = 1, #N, 3 do
		nids[#nids + 1] = em:AddNormal(Vector3.new(N[i], N[i + 1], N[i + 2]))
	end
	for i = 1, #F, 9 do
		local fid = em:AddTriangle(vids[F[i]], vids[F[i + 1]], vids[F[i + 2]])
		em:SetFaceUVs(fid, { tids[F[i + 3]], tids[F[i + 4]], tids[F[i + 5]] })
		em:SetFaceNormals(fid, { nids[F[i + 6]], nids[F[i + 7]], nids[F[i + 8]] })
	end
	return em
end

local function ensureAssets(data)
	local name = data.Name
	while textures[name] == "loading" do
		task.wait()
	end
	if textures[name] == nil then
		textures[name] = "loading"
		local ok, img = pcall(buildTexture, data)
		local okM, set = pcall(function()
			local out = {}
			for partName, chunk in pairs(data.Chunks) do
				local em = buildMesh(chunk)
				if not em then
					return nil
				end
				out[partName] = em
			end
			return out
		end)
		if not ok or not img then
			warn("[MeshCharacter] texture failed for " .. name .. ": " .. tostring(img))
		end
		if not okM or not set then
			warn("[MeshCharacter] mesh failed for " .. name .. ": " .. tostring(set))
		end
		textures[name] = (ok and img) or false
		meshes[name] = (okM and set) or false
	end
	return textures[name], meshes[name]
end

local function showRig(model)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Transparency = 0 -- local only: fallback so the character never goes invisible
		end
	end
end

function MeshCharacter.Attach(model)
	local name = model:GetAttribute("MeshCharacter")
	if not name or model:GetAttribute("MeshAttached") then
		return
	end
	model:SetAttribute("MeshAttached", true) -- local attribute: once per client
	local data = MeshCharacter.Get(name)
	if not data then
		showRig(model)
		return
	end
	local img, set = ensureAssets(data)
	if not set then
		showRig(model)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MeshVisual"
	for partName in pairs(data.Chunks) do
		local limb = model:WaitForChild(partName, 10)
		local em = set[partName]
		if not (limb and limb:IsA("BasePart") and em) then
			continue
		end
		local ok, mp = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromObject(em), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if not ok or not mp then
			warn("[MeshCharacter] CreateMeshPartAsync failed: " .. tostring(mp))
			showRig(model)
			folder:Destroy()
			return
		end
		if not model.Parent then
			folder:Destroy()
			return
		end
		mp.Name = partName
		mp.Anchored = false
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.Material = Enum.Material.SmoothPlastic
		-- body parts are open shells cut from one skin: render the inside too
		-- so bending joints never show a see-through hole
		mp.DoubleSided = true
		mp.Color = Color3.new(1, 1, 1)
		if img then
			mp.TextureContent = Content.fromObject(img)
		end
		-- each chunk was baked centered on its part, so it simply takes the
		-- part's frame and (scaled) size
		mp.Size = limb.Size
		mp.CFrame = limb.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = mp
		weld.Parent = mp
		mp.Parent = folder
	end
	folder.Parent = model
end

return MeshCharacter
