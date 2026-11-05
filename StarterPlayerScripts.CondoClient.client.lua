--!strict
-- CondoClient.client.lua
-- Client-side UI for the Condo system.
-- Put this in a LocalScript inside StarterPlayerScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local LockRemote = ReplicatedStorage:WaitForChild("CondoLockToggle")
local InviteRemote = ReplicatedStorage:WaitForChild("CondoInvite")
local PaintRemote = ReplicatedStorage:WaitForChild("CondoPaint")
local SelectCharacterRemote = ReplicatedStorage:WaitForChild("CondoSelectCharacter")
local RequestRemote = ReplicatedStorage:WaitForChild("CondoRequestState")
local StateRemote = ReplicatedStorage:WaitForChild("CondoState")

-- The selectable character presets, matching the server's CHARACTERS table.
local CHARACTER_NAMES = { "Collegiate", "Athlete", "Scholar", "Explorer" }

-- Current state the server tells us about.
local currentState = { unit = 1, owner = 0, locked = true, paint = 1 }

-- ============ UI BUILD ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CondoGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.fromOffset(300, 320)
frame.Position = UDim2.new(0.5, -150, 0.5, -160)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "My Condo"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -20, 0, 30)
status.Position = UDim2.new(0, 10, 0, 45)
status.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
status.Text = "Loading..."
status.TextColor3 = Color3.new(1, 1, 1)
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.Parent = frame

local function makeButton(name, text, yPos)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, -20, 0, 40)
	btn.Position = UDim2.new(0, 10, 0, yPos)
	btn.BackgroundColor3 = Color3.fromRGB(70, 110, 180)
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.Gotham
	btn.Parent = frame
	return btn
end

local lockButton = makeButton("LockButton", "Toggle Lock", 85)
local inviteButton = makeButton("InviteButton", "Invite Friend", 130)
local paintButton = makeButton("PaintButton", "Next Paint Color", 175)
local charButton = makeButton("CharacterButton", "Choose Character", 220)
local claimButton = makeButton("ClaimButton", "Claim This Unit", 265)

local prompt = Instance.new("TextLabel")
prompt.Size = UDim2.new(1, -20, 0, 20)
prompt.Position = UDim2.new(0, 10, 0, 315)
prompt.BackgroundTransparency = 1
prompt.Text = ""
prompt.TextColor3 = Color3.new(0.9, 0.9, 0.9)
prompt.TextScaled = true
prompt.Font = Enum.Font.Gotham
prompt.Parent = frame

-- Character picker panel (hidden until the Choose Character button is used).
local charPanel = Instance.new("Frame")
charPanel.Name = "CharacterPanel"
charPanel.Size = UDim2.fromOffset(280, 60 + #CHARACTER_NAMES * 36)
charPanel.Position = UDim2.new(0.5, -140, 0, 370)
charPanel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
charPanel.BorderSizePixel = 0
charPanel.Visible = false
charPanel.Parent = screenGui

local charTitle = Instance.new("TextLabel")
charTitle.Size = UDim2.new(1, 0, 0, 34)
charTitle.BackgroundTransparency = 1
charTitle.Text = "Select a character"
charTitle.TextColor3 = Color3.new(1, 1, 1)
charTitle.TextScaled = true
charTitle.Font = Enum.Font.GothamBold
charTitle.Parent = charPanel

local charButtons = {}
for i, name in ipairs(CHARACTER_NAMES) do
	local cbtn = Instance.new("TextButton")
	cbtn.Name = "Char" .. i
	cbtn.Size = UDim2.new(1, -20, 0, 30)
	cbtn.Position = UDim2.new(0, 10, 0, 38 + (i - 1) * 36)
	cbtn.BackgroundColor3 = Color3.fromRGB(70, 110, 180)
	cbtn.Text = name
	cbtn.TextColor3 = Color3.new(1, 1, 1)
	cbtn.TextScaled = true
	cbtn.Font = Enum.Font.Gotham
	cbtn.Parent = charPanel
	charButtons[i] = cbtn

	cbtn.Activated:Connect(function()
		SelectCharacterRemote:FireServer(i)
		charPanel.Visible = false
		prompt.Text = "Character set to " .. name
	end)
end

-- ============ HELPERS ============
local function updateUI()
	if currentState.owner == 0 then
		status.Text = "Unit " .. currentState.unit .. " — unclaimed"
		lockButton.Text = "Claim required"
		inviteButton.Text = "Claim required"
		paintButton.Text = "Claim required"
		charButton.Text = "Choose Character"
		claimButton.Visible = true
	else
		claimButton.Visible = false
		if currentState.owner == player.UserId then
			status.Text = "Unit " .. currentState.unit .. " — YOURS"
		else
			status.Text = "Unit " .. currentState.unit .. " — guest access"
		end
		lockButton.Text = currentState.locked and "Unlock Door" or "Lock Door"
		inviteButton.Text = "Invite Friend"
		paintButton.Text = "Next Paint Color"
		charButton.Text = "Choose Character"
	end
end

local function refresh()
	local result = RequestRemote:InvokeServer("refresh")
	if result then
		currentState = result
	end
	updateUI()
end

-- ============ SHOW/HIDE ============
local displayKeys = { [Enum.KeyCode.E] = true, [Enum.KeyCode.C] = true }
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if displayKeys[input.KeyCode] then
		frame.Visible = not frame.Visible
		if frame.Visible then
			refresh()
		end
	end
end)

-- ============ BUTTON ACTIONS ============
lockButton.Activated:Connect(function()
	if currentState.owner == 0 then
		refresh()
		return
	end
	local newLocked = not currentState.locked
	LockRemote:FireServer(currentState.unit, newLocked)
	currentState.locked = newLocked
	updateUI()
end)

inviteButton.Activated:Connect(function()
	if currentState.owner ~= player.UserId then
		prompt.Text = "Only the owner can invite."
		return
	end
	local targetPlayer = Players:GetPlayers()[2] or player
	if targetPlayer == player then
		prompt.Text = "No other player to invite."
		return
	end
	InviteRemote:FireServer(currentState.unit, targetPlayer.UserId)
	prompt.Text = "Invited " .. targetPlayer.Name
end)

local paintIndex = 1
paintButton.Activated:Connect(function()
	if currentState.owner == 0 then
		refresh()
		return
	end
	paintIndex = (paintIndex % 5) + 1
	PaintRemote:FireServer(currentState.unit, paintIndex)
	currentState.paint = paintIndex
	updateUI()
end)

claimButton.Activated:Connect(function()
	local result, err = RequestRemote:InvokeServer(currentState.unit)
	if result then
		currentState = result
		prompt.Text = "Condo claimed!"
	else
		prompt.Text = "Claim failed: " .. tostring(err or "Premium/coins required")
	end
	updateUI()
end)

charButton.Activated:Connect(function()
	charPanel.Visible = not charPanel.Visible
	if charPanel.Visible then
		charPanel.Position = UDim2.new(0.5, -140, 0, 370)
	end
end)

-- ============ LISTEN FOR SERVER STATE ============
StateRemote.OnClientEvent:Connect(function(data)
	if data and data.kind == "character" then
		-- Server confirmed a character selection for this player.
		prompt.Text = "Character set to " .. data.name
		return
	end
	if data and data.unit == currentState.unit then
		currentState = data
		updateUI()
	end
end)

print("[Condo] Condo client loaded. Press E to open/close the panel.")
