local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local MainScreen = PlayerGui:WaitForChild("Main")
local Constraint = MainScreen:WaitForChild("Constraint")

local Toolbar = Constraint:WaitForChild("Toolbar")

local Buttons = {
	Toolbar:WaitForChild("Blur"),
	Toolbar:WaitForChild("Canvas"),
	Toolbar:WaitForChild("Eraser"),
	Toolbar:WaitForChild("Fill"),
	Toolbar:WaitForChild("Pencil"),
	Toolbar:WaitForChild("Pen"),
	Toolbar:WaitForChild("Shape"),
	Toolbar:WaitForChild("Select"),
}

local function GetRelativeInfo(Button: TextButton)
	local RelativeFrame = Button[Button.Name]
	return RelativeFrame
end

for _, Button in ipairs(Buttons) do
	Button.MouseEnter:Connect(function()
		local RelativeFrame = GetRelativeInfo(Button)
		RelativeFrame.Visible = true
	end)

	Button.MouseLeave:Connect(function()
		local RelativeFrame = GetRelativeInfo(Button)
		RelativeFrame.Visible = false
	end)
end
