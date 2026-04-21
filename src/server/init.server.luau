local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = ReplicatedStorage:FindFirstChild("Network")
local Remotes = Network:FindFirstChild("Remote")

local UpdateModeRemote = Remotes:FindFirstChild("UpdateMode")

local VALID_MODE_PATTERN = "^[%w_%-]+$"
local DEFAULT_MODE = "Select"

local function sanitizeModeName(ModeName: unknown): string?
	if typeof(ModeName) ~= "string" then
		return nil
	end

	local NormalizedMode = string.match(ModeName, "^%s*(.-)%s*$")
	if NormalizedMode == nil or NormalizedMode == "" then
		return nil
	end

	if not string.match(NormalizedMode, VALID_MODE_PATTERN) then
		return nil
	end

	return NormalizedMode
end

local function initializePlayerState(Player: Player)
	if Player:GetAttribute("CurrentMode") == nil then
		Player:SetAttribute("CurrentMode", DEFAULT_MODE)
	end

	if Player:GetAttribute("ModeChangeInProgress") == nil then
		Player:SetAttribute("ModeChangeInProgress", false)
	end
end

Players.PlayerAdded:Connect(initializePlayerState)

for _, Player in ipairs(Players:GetPlayers()) do
	initializePlayerState(Player)
end

UpdateModeRemote.OnServerEvent:Connect(function(Player, RequestedMode)
	local SanitizedMode = sanitizeModeName(RequestedMode)
	if SanitizedMode == nil then
		warn(("Rejected invalid mode request from %s"):format(Player.Name))
		return
	end

	if Player:GetAttribute("ModeChangeInProgress") == true then
		warn(("Rejected overlapping mode request %q from %s"):format(SanitizedMode, Player.Name))
		return
	end

	if Player:GetAttribute("CurrentMode") == SanitizedMode then
		warn(("%s requested mode %q, but it is already active"):format(Player.Name, SanitizedMode))
		return
	end

	Player:SetAttribute("ModeChangeInProgress", true)
	warn(("Applying mode %q for %s"):format(SanitizedMode, Player.Name))
	Player:SetAttribute("CurrentMode", SanitizedMode)
	Player:SetAttribute("ModeChangeInProgress", false)
end)
