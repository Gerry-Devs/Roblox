local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--------------------------------------------------------------------
-- Players carrying an egg / monster (attribute "Holding", set by the
-- server) keep their arms in the carry pose: the walk animation's arm
-- swing is cancelled on this screen, so it looks like the arms hold it.
--------------------------------------------------------------------
local ARM_JOINTS = {
	{ "RightUpperArm", "RightShoulder" }, { "LeftUpperArm", "LeftShoulder" },
	{ "RightLowerArm", "RightElbow" }, { "LeftLowerArm", "LeftElbow" },
	{ "Torso", "Right Shoulder" }, { "Torso", "Left Shoulder" },
}
local function keepArmsStill()
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Holding") then
			local character = p.Character
			if character then
				for _, j in ipairs(ARM_JOINTS) do
					local holder = character:FindFirstChild(j[1])
					local motor = holder and holder:FindFirstChild(j[2])
					if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then
						motor.Transform = CFrame.identity
					end
				end
			end
		end
	end
end
-- after the walk animation has moved the arms, and again before drawing
RunService.Stepped:Connect(keepArmsStill)
RunService:BindToRenderStep("HoldArmsStill", Enum.RenderPriority.Character.Value + 1, keepArmsStill)
