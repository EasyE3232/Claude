-- Tiny helper: send a toast to one player's HUD.
-- kind: "info" | "success" | "fail"
local RS = game:GetService("ReplicatedStorage")
local NotifyRemote = RS:WaitForChild("Remotes"):WaitForChild("Notify")

return function(player, text, kind)
	if player and player.Parent then
		NotifyRemote:FireClient(player, { Text = text, Kind = kind or "info" })
	end
end
