local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Main = PlayerGui:WaitForChild("Main")
local Constraint = Main:WaitForChild("Constraint")
local Navbar = Constraint:WaitForChild("Navbar")

local SelectionBar = Navbar:WaitForChild("Selectionbar")

local function UpdateSelectionBar()
	local CurrentMode = Player:GetAttribute("CurrentMode") :: string?

	for _, Child in ipairs(SelectionBar:GetChildren()) do
		if Child:IsA("GuiObject") then
			Child.Visible = false
		end
	end

	local TargetVisual = SelectionBar:FindFirstChild(CurrentMode)
	if TargetVisual then
		TargetVisual.Visible = true
	end
end

Player:GetAttributeChangedSignal("CurrentMode"):Connect(UpdateSelectionBar)
UpdateSelectionBar()
