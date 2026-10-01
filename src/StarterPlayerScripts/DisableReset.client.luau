local StarterGui = game:GetService("StarterGui")

--------------------------------------------------------------------
-- Turns off "Reset Character" in the Roblox menu (the button shows
-- greyed out and does nothing). SetCore can fail while Roblox's core
-- scripts are still loading, so keep trying for a bit.
--------------------------------------------------------------------
for _ = 1, 30 do
	local ok = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	if ok then
		break
	end
	task.wait(1)
end
