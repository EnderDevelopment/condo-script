--!strict
-- CondoManager.server.lua
-- Server-side manager for the Condo (private residence) system.
-- Put this in a Script inside ServerScriptService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============ CONFIG ============
local PRICE = 50              -- robux to claim a new condo unit
local MAX_UNITS = 10          -- how many CondoUnit<Number> folders exist
local PAINT_COLORS = {
	Color3.fromRGB(255, 255, 255), -- white
	Color3.fromRGB(255, 206, 158), -- beige
	Color3.fromRGB(153, 217, 234), -- light blue
	Color3.fromRGB(152, 251, 152), -- mint
	Color3.fromRGB(255, 192, 203), -- pink
	Color3.fromRGB(255, 255, 0),   -- yellow
}

-- Named, family-friendly character presets.
-- Each preset has a display name and a list of accessory/model Instance data
-- to put on the player's character when selected. All are safe, fully-clothed
-- outfits (no adult or sexualized content).
local CHARACTERS = {
	{
		name = "Collegiate",
		accessories = {
			{ kind = "Shirt", color = Color3.fromRGB(60, 90, 160) },
			{ kind = "Pants", color = Color3.fromRGB(40, 40, 45) },
		},
	},
	{
		name = "Athlete",
		accessories = {
			{ kind = "Shirt", color = Color3.fromRGB(220, 80, 60) },
			{ kind = "Pants", color = Color3.fromRGB(30, 30, 35) },
			{ kind = "Hat",   color = Color3.fromRGB(220, 80, 60) },
		},
	},
	{
		name = "Scholar",
		accessories = {
			{ kind = "Shirt", color = Color3.fromRGB(120, 90, 160) },
			{ kind = "Pants", color = Color3.fromRGB(60, 50, 80) },
			{ kind = "Glasses", color = Color3.fromRGB(40, 40, 45) },
		},
	},
	{
		name = "Explorer",
		accessories = {
			{ kind = "Shirt", color = Color3.fromRGB(80, 130, 80) },
			{ kind = "Pants", color = Color3.fromRGB(70, 70, 60) },
			{ kind = "Hat",   color = Color3.fromRGB(110, 90, 60) },
		},
	},
}
-- ================================

-- Cache the remotes (must exist in ReplicatedStorage).
local Remotes = ReplicatedStorage:WaitForChild("CondoLockToggle")
local InviteRemote = ReplicatedStorage:WaitForChild("CondoInvite")
local PaintRemote = ReplicatedStorage:WaitForChild("CondoPaint")
local SelectCharacterRemote = ReplicatedStorage:WaitForChild("CondoSelectCharacter")
local RequestRemote = ReplicatedStorage:WaitForChild("CondoRequestState")
local StateRemote = ReplicatedStorage:WaitForChild("CondoState")

-- unitNumber -> ownerUserId (0 = unclaimed)
local ownedBy: { [number]: number } = {}
-- unitNumber -> set of invited user ids
local invites: { [number]: { [number]: boolean } } = {}
-- unitNumber -> locked state
local lockedState: { [number]: boolean } = {}
-- unitNumber -> color index currently painted
local paintedColor: { [number]: number } = {}

for i = 1, MAX_UNITS do
	ownedBy[i] = 0
	invites[i] = {}
	lockedState[i] = true
	paintedColor[i] = 1
end

local function getUnitFolder(unit: number)
	return workspace:FindFirstChild("CondoUnit" .. unit)
end

local function hasAccess(player: Player, unit: number): boolean
	if unit < 1 or unit > MAX_UNITS then
		return false
	end
	if ownedBy[unit] == 0 then
		return false
	end
	if ownedBy[unit] == player.UserId then
		return true
	end
	return invites[unit][player.UserId] == true
end

local function broadcastState(unit: number)
	-- Tell everyone the current lock/owned state of a unit.
	local data = {
		unit = unit,
		owner = ownedBy[unit],
		locked = lockedState[unit],
		paint = paintedColor[unit],
	}
	StateRemote:FireAllClients(data)
end

-- ============ LOCK / UNLOCK ============
Remotes.OnServerEvent:Connect(function(player, unit: number, newLocked: boolean)
	if not hasAccess(player, unit) then
		warn("[Condo] " .. player.Name .. " tried to lock unit " .. unit .. " without access.")
		return
	end
	local door = getUnitFolder(unit) and getUnitFolder(unit):FindFirstChild("Door")
	if not door then
		warn("[Condo] Unit " .. unit .. " has no Door part.")
		return
	end
	lockedState[unit] = newLocked

	-- Visually lock/unlock the door.
	if newLocked then
		door.Color = Color3.fromRGB(120, 120, 120)
		door.Transparency = 0.4
		door.CanCollide = true
	else
		door.Color = Color3.fromRGB(82, 138, 82)
		door.Transparency = 0.2
		door.CanCollide = false
	end
	broadcastState(unit)
end)

-- ============ INVITE FRIEND ============
InviteRemote.OnServerEvent:Connect(function(player, unit: number, targetUserId: number)
	if not hasAccess(player, unit) then
		warn("[Condo] " .. player.Name .. " tried to invite to unit " .. unit .. " without access.")
		return
	end
	if ownedBy[unit] ~= player.UserId then
		warn("[Condo] Only the owner of unit " .. unit .. " may invite friends.")
		return
	end
	invites[unit][targetUserId] = true
	broadcastState(unit)
end)

-- ============ PAINT / REDECORATE ============
PaintRemote.OnServerEvent:Connect(function(player, unit: number, colorIndex: number)
	if not hasAccess(player, unit) then
		warn("[Condo] " .. player.Name .. " tried to paint unit " .. unit .. " without access.")
		return
	end
	local color = PAINT_COLORS[colorIndex]
	if not color then
		warn("[Condo] Invalid color index " .. tostring(colorIndex) .. ".")
		return
	end
	local folder = getUnitFolder(unit)
	if not folder then
		return
	end
	local roomsFolder = folder:FindFirstChild("Rooms")
	if roomsFolder then
		for _, room in ipairs(roomsFolder:GetChildren()) do
			local wall = room:FindFirstChild("Wall")
			if wall and wall:IsA("Part") then
				wall.Color = color
			end
		end
	end
	paintedColor[unit] = colorIndex
	broadcastState(unit)
end)

-- ============ SELECT CHARACTER ============
-- Each preset is a safe, fully-clothed outfit. We implement it by tinting
-- the character's limbs via BodyColors and optionally adding a simple hat
-- or glasses accessory. No adult or sexualized content.

-- Remove our previously-applied accessories so presets can switch cleanly.
local function clearPlayerOutfit(player: Player)
	local character = player.Character
	if not character then
		return
	end
	-- Remove accessories we added (hats / glasses).
	local arbitrary = character:FindFirstChild("ArbitraryAccessories")
	if arbitrary then
		for _, accessory in ipairs(arbitrary:GetChildren()) do
			if accessory.Name == "CondoHat" or accessory.Name == "CondoGlasses" then
				accessory:Destroy()
			end
		end
	end
end

-- Apply one preset: tint the shirt/pants/limbs to the preset's hue so each
-- selectable character reads as a distinct, safe outfit.
local function applyCharacter(player: Player, index: number): (boolean, string?)
	local preset = CHARACTERS[index]
	if not preset then
		return false, "Unknown character."
	end
	local character = player.Character
	if not character then
		return false, "Your character is not ready yet."
	end
	clearPlayerOutfit(player)

	-- Tint shirt and pants to the preset's primary color.
	local shirtAccent = preset.accessories[1] and preset.accessories[1].color or Color3.new(1, 1, 1)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = Color3.fromRGB(255, 206, 158)
		bodyColors.TorsoColor3 = shirtAccent
		bodyColors.LeftArmColor3 = shirtAccent
		bodyColors.RightArmColor3 = shirtAccent
		bodyColors.LeftLegColor3 = Color3.fromRGB(40, 40, 45)
		bodyColors.RightLegColor3 = Color3.fromRGB(40, 40, 45)
	end

	-- Optionally place a simple hat/glasses accessory (safe cosmetics).
	for _, item in ipairs(preset.accessories) do
		if item.kind == "Hat" then
			local hat = Instance.new("Accessory")
			hat.Name = "CondoHat"
			-- A plain, safe beanie-like accessory; replace the handle mesh
			-- with your own mesh ID for a nicer look.
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1.4, 0.6, 1.4)
			handle.Color = item.color
			handle.BrickColor = BrickColor.new(item.color)
			handle.CanCollide = false
			handle.Transparency = 0.1
			handle.Parent = hat
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, 0.6, 1)
			mesh.Parent = handle
			hat.Parent = character
		elseif item.kind == "Glasses" then
			local glasses = Instance.new("Accessory")
			glasses.Name = "CondoGlasses"
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1, 0.2, 0.2)
			handle.Color = item.color
			handle.BrickColor = BrickColor.new(item.color)
			handle.CanCollide = false
			handle.Transparency = 0.2
			handle.Parent = glasses
			glasses.Parent = character
		end
	end
	return true, preset.name
end

SelectCharacterRemote.OnServerEvent:Connect(function(player, index: number)
	local ok, result = applyCharacter(player, index)
	if not ok then
		warn("[Condo] " .. player.Name .. " character select failed: " .. tostring(result))
		return
	end
	StateRemote:FireClient(player, { kind = "character", index = index, name = result })
end)

-- ============ CLAIM UNIT ============
local function claimUnit(player: Player, unit: number)
	if unit < 1 or unit > MAX_UNITS then
		return false, "That unit does not exist."
	end
	if ownedBy[unit] ~= 0 then
		return false, "That unit is already owned."
	end
	if not player:IsPremium() then
		return false, "You must be a Premium member to claim a condo."
	end
	if player.StarterCoins and player.StarterCoins.Value < PRICE then
		return false, "Not enough coins to claim this unit."
	end
	ownedBy[unit] = player.UserId
	if player.StarterCoins then
		player.StarterCoins.Value -= PRICE
	end
	broadcastState(unit)
	return true, "Condo claimed!"
end

-- ============ STATE REQUEST (client->server) ============
-- Client calls with:
--   -1            -> query the first unclaimed unit (no claim)
--   unit number   -> attempt to claim that unit
--   "refresh"     -> get current state for the player's unit
RequestRemote.OnServerInvoke = function(player, action)
	-- Refresh: report the unit the player owns or has guest access to.
	if action == "refresh" then
		for i = 1, MAX_UNITS do
			if ownedBy[i] == player.UserId or invites[i][player.UserId] == true then
				return { unit = i, owner = ownedBy[i], locked = lockedState[i], paint = paintedColor[i] }
			end
		end
		-- Not claimed yet: give the first free unit as a suggestion.
		for i = 1, MAX_UNITS do
			if ownedBy[i] == 0 then
				return { unit = i, owner = 0, locked = lockedState[i], paint = paintedColor[i] }
			end
		end
		return nil
	end

	-- Find first unclaimed unit (query only).
	if action == -1 or action == nil then
		for i = 1, MAX_UNITS do
			if ownedBy[i] == 0 then
				return { unit = i, owner = 0, locked = lockedState[i], paint = paintedColor[i] }
			end
		end
		return nil
	end

	-- Claim a specific unit.
	local unit = action
	if type(unit) ~= "number" then
		return nil, "Invalid request."
	end
	local ok, err = claimUnit(player, unit)
	if ok then
		return { unit = unit, owner = player.UserId, locked = lockedState[unit], paint = paintedColor[unit] }
	end
	return nil, err
end

print("[Condo] CondoManager server loaded.")
