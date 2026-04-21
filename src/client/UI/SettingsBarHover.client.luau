local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local MainScreen = PlayerGui:WaitForChild("Main")
local Constraint = MainScreen:WaitForChild("Constraint")

local Navbar = Constraint:WaitForChild("Navbar")
local Settingsbar = Navbar:WaitForChild("Settingsbar")

local Buttons = {
	Settingsbar:WaitForChild("Edit"),
	Settingsbar:WaitForChild("File"),
	Settingsbar:WaitForChild("Help"),
	Settingsbar:WaitForChild("Window"),
}

local ActiveButton: TextButton? = nil
local ActiveDropdown: GuiObject? = nil

local function GetRelativeInfo(Button: TextButton)
	local RelativeFrame = Button:FindFirstChild("Dropdown") :: GuiObject?
	return RelativeFrame
end

local function GetMousePosition(): Vector2
	local GuiInset = GuiService:GetGuiInset()
	local MouseLocation = UserInputService:GetMouseLocation()

	return MouseLocation - GuiInset
end

local function IsMouseInside(GuiObject: GuiObject): boolean
	local MousePosition = GetMousePosition()
	local AbsolutePosition = GuiObject.AbsolutePosition
	local AbsoluteSize = GuiObject.AbsoluteSize

	return MousePosition.X >= AbsolutePosition.X
		and MousePosition.X <= AbsolutePosition.X + AbsoluteSize.X
		and MousePosition.Y >= AbsolutePosition.Y
		and MousePosition.Y <= AbsolutePosition.Y + AbsoluteSize.Y
end

local function CloseAllDropdowns()
	for _, Button in ipairs(Buttons) do
		local RelativeFrame = GetRelativeInfo(Button)
		if RelativeFrame then
			RelativeFrame.Visible = false
		end
	end

	ActiveButton = nil
	ActiveDropdown = nil
end

local function OpenDropdown(Button: TextButton)
	local RelativeFrame = GetRelativeInfo(Button)
	if not RelativeFrame then
		return
	end

	for _, OtherButton in ipairs(Buttons) do
		local OtherFrame = GetRelativeInfo(OtherButton)
		if OtherFrame then
			OtherFrame.Visible = OtherButton == Button
		end
	end

	ActiveButton = Button
	ActiveDropdown = RelativeFrame
end

local function TryCloseOrSwitch()
	local CurrentButton = ActiveButton
	local CurrentDropdown = ActiveDropdown

	if not CurrentButton or not CurrentDropdown then
		return
	end

	if IsMouseInside(CurrentButton) or IsMouseInside(CurrentDropdown) then
		return
	end

	for _, Button in ipairs(Buttons) do
		if Button ~= CurrentButton and IsMouseInside(Button) then
			OpenDropdown(Button)
			return
		end
	end

	CloseAllDropdowns()
end

for _, Button in ipairs(Buttons) do
	local RelativeFrame = GetRelativeInfo(Button)

	Button.MouseEnter:Connect(function()
		OpenDropdown(Button)
	end)

	Button.MouseLeave:Connect(function()
		task.defer(TryCloseOrSwitch)
	end)

	if RelativeFrame then
		RelativeFrame.MouseLeave:Connect(function()
			task.defer(TryCloseOrSwitch)
		end)
	end
end
