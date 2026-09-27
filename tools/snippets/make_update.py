"""Build tools/snippets/update_command.lua: one command-bar line that upgrades
an existing Gym Wars place in Studio (scripts + map fixes), no file swapping.

  python3 tools/snippets/make_update.py
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FILES = [
    "src/ReplicatedStorage/Modules/Characters.luau",
    "src/ReplicatedStorage/Modules/Constants.luau",
    "src/ReplicatedStorage/Modules/MeshCharacter.luau",
    "src/ReplicatedStorage/Modules/Gym/Poses.luau",
    "src/ServerScriptService/BeltService.luau",
    "src/ServerScriptService/CharacterLooks.luau",
    "src/ServerScriptService/CharacterModels.luau",
    "src/ServerScriptService/GymNav.luau",
    "src/ServerScriptService/InfluencerService.luau",
    "src/ServerScriptService/Main.server.luau",
    "src/ServerScriptService/NpcService.luau",
    "src/StarterPlayerScripts/CharacterEffects.client.luau",
    "src/StarterPlayerScripts/GymAnimator.client.luau",
    "src/StarterPlayerScripts/MeshCharacters.client.luau",
]

def lstr(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == "\\": out.append("\\\\")
        elif ch == '"': out.append('\\"')
        elif ch == "\n": out.append("\\n")
        elif ch == "\t": out.append("\\t")
        elif ch == "\r": continue
        elif o < 32: out.append("\\%d" % o)
        else: out.append(ch)
    out.append('"')
    return "".join(out)

entries = []
for f in FILES:
    rel = f[len("src/"):]
    parts = rel.split("/")
    name = parts[-1][:-len(".luau")]
    cls = "ModuleScript"
    if name.endswith(".server"): cls, name = "Script", name[:-7]
    elif name.endswith(".client"): cls, name = "LocalScript", name[:-7]
    path = "/".join(parts[:-1] + [name])
    entries.append("{%s,%s,%s}" % (lstr(path), lstr(cls), lstr(open(os.path.join(ROOT, f), encoding="utf-8").read())))

# the map fixes + script install, all on one line (no comments: `--` would eat the rest)
code = r'''
local SS=game:GetService("ServerStorage") local RS=game:GetService("ReplicatedStorage") local SSS=game:GetService("ServerScriptService") local SPS=game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
local map=workspace:FindFirstChild("GymWarsMap") if not map then warn("GymWarsMap not found") return end
local n=0
local kill={Promenade=true,Curb=true,Walkway=true,WalkCurb=true}
for _,d in ipairs(map:GetDescendants()) do if d:IsA("BasePart") and kill[d.Name] then d:Destroy() n+=1 end end
local belt=map:FindFirstChild("Belt")
if belt then for _,d in ipairs(belt:GetDescendants()) do if d:IsA("BasePart") and (d.Name=="BeltTrack" or d.Name=="BeltSkirt" or d.Name=="BeltGlow" or d.Name=="RailLeft" or d.Name=="RailRight") then d:Destroy() n+=1 end end local ch=belt:FindFirstChild("Chevrons") if ch then ch:Destroy() end end
for _,root in ipairs({map,SS:FindFirstChild("HiddenGymFloors")}) do if root then for _,d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then if d.Name=="RoofSlab" then d.Material=Enum.Material.Slate elseif d.Name=="TunnelLeft" or d.Name=="TunnelRight" or d.Name=="TunnelTop" then d.Material=Enum.Material.Metal end end end end end
local sp=workspace:FindFirstChild("SpawnLocation") if sp then sp.Color=Color3.fromRGB(88,148,66) sp.Material=Enum.Material.Grass end
local FY,FH=0.4,16
local function ft(f) return FY+(f-1)*FH end
local function mk(parent,name,size,cf,visible) local p=Instance.new("Part") p.Name=name p.Anchored=true p.Size=size p.CFrame=cf p.Transparency=1 p.CastShadow=false p.Material=Enum.Material.SmoothPlastic if not visible then p.CanCollide=false p.CanTouch=false p.CanQuery=false end p.Parent=parent return p end
local plots=map:FindFirstChild("Plots")
local ramps=0
for _,plot in ipairs(plots and plots:GetChildren() or {}) do
local floor=plot:FindFirstChild("Floor")
if floor then
local base=floor.CFrame*CFrame.new(0,-floor.Size.Y/2,0)
local function L(x,y,z) return base*CFrame.new(x,y,z) end
local hidden=SS:FindFirstChild("HiddenGymFloors") and SS.HiddenGymFloors:FindFirstChild(plot.Name)
for f=2,3 do
local folder=plot:FindFirstChild("Floor"..f) or (hidden and hidden:FindFirstChild("Floor"..f))
if folder then
for _,d in ipairs(folder:GetChildren()) do if d.Name=="StairRamp" then d:Destroy() end end
local y0=ft(f-1) local ym=y0+FH/2 local y1=y0+FH
for _,fl in ipairs({{18,15,30,y0,ym+0.5},{24,30,15,ym+0.5,y1}}) do
local a=L(fl[1],fl[4],fl[2]).Position local b=L(fl[1],fl[5],fl[3]).Position
local r=mk(folder,"StairRamp",Vector3.new(6,1.2,(b-a).Magnitude+0.2),CFrame.lookAt((a+b)/2,b)*CFrame.new(0,-0.6,0),true)
ramps+=1
end
end
end
local old=plot:FindFirstChild("Nav") if old then old:Destroy() end
local nav=Instance.new("Folder") nav.Name="Nav" nav.Parent=plot
local one=Vector3.new(1,1,1)
local function np(name,x,y,z) mk(nav,name,one,L(x,y,z)) end
np("DoorOut",0,FY,-40) np("Lobby",0,FY,-30)
for f=1,3 do np("Cross"..f,0,ft(f),12.5) if f<3 then np("StairFoot"..f,18,ft(f),12.5) np("LandA"..f,18,ft(f)+8.5,32.5) np("LandB"..f,24,ft(f)+8.5,32.5) np("StairTop"..(f+1),24,ft(f+1),12.5) end end
np("F3Turn",24,ft(3),14) np("F3Lane",9.5,ft(3),14)
local fp=floor.CFrame.Position
mk(nav,"Yard",one,CFrame.new((fp.X>0 and 1 or -1)*17,0,fp.Z))
nav:SetAttribute("FloorY",FY) nav:SetAttribute("FloorH",FH) nav:SetAttribute("AisleX",0)
end
end
local o1=SSS:FindFirstChild("RonnieSwap") if o1 then o1:Destroy() end
local o2=SPS and SPS:FindFirstChild("RonnieSwapClient") if o2 then o2:Destroy() end
local roots={ReplicatedStorage=RS,ServerScriptService=SSS,StarterPlayerScripts=SPS}
local installed=0
for _,e in ipairs(FILES) do
local segs=string.split(e[1],"/")
local parent=roots[segs[1]]
for i=2,#segs-1 do local c=parent:FindFirstChild(segs[i]) if not c then c=Instance.new("Folder") c.Name=segs[i] c.Parent=parent end parent=c end
local name=segs[#segs]
local s=parent:FindFirstChild(name)
if s and s.ClassName~=e[2] then s:Destroy() s=nil end
if not s then s=Instance.new(e[2]) s.Name=name s.Parent=parent end
s.Source=e[3]
installed+=1
end
print(("GYM WARS UPDATED: %d scripts, %d concrete/conveyor parts removed, %d stair ramps rebuilt. Press Ctrl/Cmd+S, then Play."):format(installed,n,ramps))
'''
lines = [l.strip() for l in code.strip().splitlines() if l.strip()]
body = " ".join(lines)
cmd = "local FILES={" + ",".join(entries) + "} do " + body + " end"
out = os.path.join(ROOT, "tools", "snippets", "update_command.lua")
open(out, "w", encoding="utf-8").write(cmd + "\n")
print(out, len(cmd), "chars")
