local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Network = ReplicatedStorage:WaitForChild("Network")
local Remotes = Network:WaitForChild("Remote")
local UpdateModeRemote = Remotes:WaitForChild("UpdateMode") :: RemoteEvent

local MainScreen = PlayerGui:WaitForChild("Main")
local Constraint = MainScreen:WaitForChild("Constraint")
local Toolbar = Constraint:WaitForChild("Toolbar")

local Extratools = Constraint:WaitForChild("Extratools")

local REQUEST_TIMEOUT_SECONDS = 3

local ActiveMode = (Player:GetAttribute("CurrentMode") :: string?) or ""
local PendingMode: string? = nil
local RequestStartedAt = 0

local function IsModeButton(Instance: Instance): boolean
	return Instance:IsA("TextButton") or Instance:IsA("ImageButton")
end

local function GetModeName(Button: GuiButton): string?
	local AttributeMode = Button:GetAttribute("Mode")
	if typeof(AttributeMode) == "string" and AttributeMode ~= "" then
		return AttributeMode
	end

	if Button.Name == "" then
		return nil
	end

	return Button.Name
end

local function GetButtons(): { GuiButton }
	local Buttons = {}

	for _, Descendant in ipairs(Toolbar:GetDescendants()) do
		if IsModeButton(Descendant) then
			table.insert(Buttons, Descendant :: GuiButton)
		end
	end

	table.sort(Buttons, function(Left, Right)
		return Left.Name < Right.Name
	end)

	return Buttons
end

local function IsAdditionalModeButton(Instance: Instance): boolean
	return (Instance:IsA("TextButton") or Instance:IsA("ImageButton")) and Instance.Parent ~= Toolbar
end

local function UpdateExtratoolsForMode(Button: GuiButton?, ModeName: string?)
	local HasAdditionalModes = Button ~= nil and Button:GetAttribute("HasAdditionalModes") == true
	Extratools.Visible = HasAdditionalModes

	for _, Descendant in ipairs(Extratools:GetDescendants()) do
		if IsAdditionalModeButton(Descendant) then
			local FromMode = Descendant:GetAttribute("FromMode")
			local ShouldShow = HasAdditionalModes and typeof(FromMode) == "string" and FromMode == ModeName
			Descendant.Visible = ShouldShow
		end
	end
end

local function UpdateVisualState()
	local Buttons = GetButtons()
	local ChangeInProgress = Player:GetAttribute("ModeChangeInProgress") == true

	for _, Button in ipairs(Buttons) do
		local ButtonMode = GetModeName(Button)
		local IsActive = ButtonMode ~= nil and ButtonMode == ActiveMode
		local IsPending = ButtonMode ~= nil and ButtonMode == PendingMode

		Button.AutoButtonColor = not ChangeInProgress
		Button.Active = not ChangeInProgress or IsPending
		Button.Selectable = not ChangeInProgress or IsPending
		Button:SetAttribute("IsActiveMode", IsActive)
		Button:SetAttribute("IsPendingMode", IsPending)
	end

	Toolbar:SetAttribute("CurrentMode", ActiveMode)
	Toolbar:SetAttribute("PendingMode", PendingMode)
	Toolbar:SetAttribute("ModeChangeInProgress", ChangeInProgress)
end

local function ClearStalePendingRequest()
	if PendingMode == nil then
		return
	end

	if Player:GetAttribute("ModeChangeInProgress") == true then
		return
	end

	if time() - RequestStartedAt < REQUEST_TIMEOUT_SECONDS then
		return
	end

	PendingMode = nil
	UpdateVisualState()
end

local function CanRequestModeChange(RequestedMode: string): (boolean, string?)
	ClearStalePendingRequest()

	if RequestedMode == "" then
		return false, "Mode name was empty"
	end

	if PendingMode ~= nil or Player:GetAttribute("ModeChangeInProgress") == true then
		return false, "Another mode change is already in progress"
	end

	if RequestedMode == ActiveMode then
		return false, "Requested mode is already active"
	end

	return true, nil
end

local function RequestModeChange(RequestedMode: string)
	local CanRequest = CanRequestModeChange(RequestedMode)
	if not CanRequest then
		warn(("Ignored mode change request for %q"):format(RequestedMode))
		return
	end

	PendingMode = RequestedMode
	RequestStartedAt = time()
	UpdateVisualState()
	warn(("Requesting mode change to %q"):format(RequestedMode))
	UpdateModeRemote:FireServer(RequestedMode)
end

local function BindButton(Button: GuiButton)
	Button.Activated:Connect(function()
		local RequestedMode = GetModeName(Button)
		if RequestedMode == nil then
			warn(("Mode button %s is missing a valid mode name"):format(Button:GetFullName()))
			return
		end

		UpdateExtratoolsForMode(Button, RequestedMode)
		RequestModeChange(RequestedMode)
	end)
end

for _, Button in ipairs(GetButtons()) do
	BindButton(Button)
end

Toolbar.DescendantAdded:Connect(function(Descendant)
	if IsModeButton(Descendant) then
		BindButton(Descendant :: GuiButton)
		UpdateVisualState()
	end
end)

Player:GetAttributeChangedSignal("CurrentMode"):Connect(function()
	ActiveMode = (Player:GetAttribute("CurrentMode") :: string?) or ""
	warn(("Current mode is now %q"):format(ActiveMode))

	if PendingMode ~= nil and PendingMode == ActiveMode then
		PendingMode = nil
	end

	UpdateVisualState()
end)

Player:GetAttributeChangedSignal("ModeChangeInProgress"):Connect(function()
	if Player:GetAttribute("ModeChangeInProgress") ~= true then
		ClearStalePendingRequest()
	end

	UpdateVisualState()
end)

UpdateVisualState()

local InitialModeButton: GuiButton? = nil
for _, Button in ipairs(GetButtons()) do
	if GetModeName(Button) == ActiveMode then
		InitialModeButton = Button
		break
	end
end

UpdateExtratoolsForMode(InitialModeButton, ActiveMode)
