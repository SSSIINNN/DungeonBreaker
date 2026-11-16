local World = {}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local STONE = Color3.fromRGB(92, 94, 100)
local TRIM = Color3.fromRGB(130, 129, 124)
local GOLD = Color3.fromRGB(255, 183, 72)
local BLUE = Color3.fromRGB(70, 160, 255)
local LOBBY_CENTER = Vector3.new(0, 0, 72)
local ROOM_SIZE = Vector3.new(64, 2, 56)

local function part(parent, name, size, frame, color, material)
	local block = Instance.new("Part")
	block.Name = name
	block.Size = size
	block.CFrame = frame
	block.Color = color
	block.Material = material or Enum.Material.Slate
	block.Anchored = true
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block.Parent = parent
	return block
end

local function stoneFloor(parent, center, size)
	part(parent, "Foundation", size, CFrame.new(center), STONE)
	for x = -size.X / 2 + 4, size.X / 2 - 4, 8 do
		for z = -size.Z / 2 + 4, size.Z / 2 - 4, 8 do
			part(parent, "StoneTile", Vector3.new(7.9, 0.12, 7.9),
				CFrame.new(center + Vector3.new(x, 1, z)), TRIM, Enum.Material.Cobblestone)
		end
	end
end

local function sign(adornee, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(220, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 33)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(255, 237, 196)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 24
	label.Text = text
	label.Parent = gui
end

local function doorway(parent, name, frame, color, title, action)
	local door = Instance.new("Model")
	door.Name = name
	door.Parent = parent
	local posts = {}
	for _, x in ipairs({-7, 7}) do
		table.insert(posts, part(door, "StonePost", Vector3.new(2, 14, 3), frame * CFrame.new(x, 7, 0), TRIM))
		part(door, "PostBase", Vector3.new(3, 1, 4), frame * CFrame.new(x, 0.5, 0), STONE)
	end
	local lintel = part(door, "Lintel", Vector3.new(16, 2, 3), frame * CFrame.new(0, 14, 0), TRIM)
	local leftPost = frame:PointToObjectSpace(posts[1].Position)
	local rightPost = frame:PointToObjectSpace(posts[2].Position)
	local left = leftPost.X + posts[1].Size.X / 2
	local right = rightPost.X - posts[2].Size.X / 2
	local bottom = math.min(leftPost.Y - posts[1].Size.Y / 2, rightPost.Y - posts[2].Size.Y / 2)
	local top = frame:PointToObjectSpace(lintel.Position).Y - lintel.Size.Y / 2
	-- 문틀과 바닥 안쪽에 겹쳐 사선에서도 가장자리에 틈이 생기지 않게 한다.
	local overlap = 0.15
	local portal = part(door, "Portal", Vector3.new(right - left + overlap * 2, top - bottom + overlap * 2, 0.6),
		frame * CFrame.new((left + right) / 2, (bottom + top) / 2, 0), color, Enum.Material.Neon)
	portal.Transparency = 0.3
	sign(portal, title)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1
	light.Range = 18
	light.Parent = portal
	local interaction = Instance.new("Attachment")
	interaction.Name = "Interaction"
	interaction.Parent = portal
	interaction.WorldCFrame = frame * CFrame.new(0, 3, 1.5)
	local prompt
	if action then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TravelPrompt"
		prompt.ActionText = action
		prompt.ObjectText = title
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = interaction
	end
	return prompt, interaction
end

local function torch(parent, position)
	local holder = Instance.new("Model")
	holder.Name = "Torch"
	holder.Parent = parent
	part(holder, "Handle", Vector3.new(0.5, 3, 0.5), CFrame.new(position),
		Color3.fromRGB(67, 42, 28), Enum.Material.Wood)
	part(holder, "Brazier", Vector3.new(1.4, 0.5, 1.4), CFrame.new(position + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(42, 43, 47), Enum.Material.Metal)
	local ember = part(holder, "Ember", Vector3.new(0.7, 0.8, 0.7),
		CFrame.new(position + Vector3.new(0, 1.8, 0)), GOLD, Enum.Material.Neon)
	ember.CanCollide = false
	local flame = Instance.new("Fire")
	flame.Color = GOLD
	flame.SecondaryColor = Color3.fromRGB(255, 87, 28)
	flame.Size = 3
	flame.Heat = 3
	flame.Parent = ember
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 195, 116)
	light.Brightness = 2
	light.Range = 34
	light.Shadows = true
	light.Parent = ember
end

function World.build()
	local root = Instance.new("Model")
	root.Name = "DungeonBreakerWorld"
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = root
	stoneFloor(lobby, LOBBY_CENTER, Vector3.new(48, 2, 48))
	for _, x in ipairs({-23, 23}) do
		part(lobby, "SideWall", Vector3.new(2, 10, 48),
			CFrame.new(LOBBY_CENTER + Vector3.new(x, 6, 0)), STONE, Enum.Material.Brick)
	end
	part(lobby, "BackWall", Vector3.new(48, 10, 2),
		CFrame.new(LOBBY_CENTER + Vector3.new(0, 6, 23)), STONE, Enum.Material.Brick)
	for _, x in ipairs({-16, 16}) do
		part(lobby, "EntranceWall", Vector3.new(16, 16, 2),
			CFrame.new(x, 9, 52), STONE, Enum.Material.Brick)
	end
	part(lobby, "EntrancePath", Vector3.new(8, 0.15, 32), CFrame.new(0, 1.1, 69),
		Color3.fromRGB(157, 140, 107), Enum.Material.Slate)
	local enterPrompt, enterInteraction = doorway(lobby, "DungeonEntrance", CFrame.new(0, 1, 52),
		GOLD, "던전 입구", "던전 입장")
	torch(lobby, Vector3.new(-11, 5, 54))
	torch(lobby, Vector3.new(11, 5, 54))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 0.5, 6)
	spawn.CFrame = CFrame.new(0, 1.25, 82)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lobby
	local rooms = Instance.new("Folder")
	rooms.Name = "Rooms"
	rooms.Parent = root
	root.Parent = workspace
	return {
		rooms = rooms,
		lobbySpawn = spawn,
		lobbyStart = CFrame.new(0, 5, 82),
		entryRoute = {
			from = "Lobby", to = "Dungeon",
			prompt = enterPrompt, interaction = enterInteraction,
		},
	}
end

function World.createRoom(parent, owner, slot)
	local center = Vector3.new(180 + (slot - 1) * 140, 0, 0)
	local room = Instance.new("Model")
	room.Name = "Room_" .. owner.UserId
	room:SetAttribute("OwnerUserId", owner.UserId)
	stoneFloor(room, center, ROOM_SIZE)
	for _, x in ipairs({-31, 31}) do
		part(room, "SideWall", Vector3.new(2, 18, ROOM_SIZE.Z),
			CFrame.new(center + Vector3.new(x, 10, 0)), STONE, Enum.Material.Brick)
		for _, z in ipairs({-18, 0, 18}) do
			part(room, "Buttress", Vector3.new(3, 18, 3),
				CFrame.new(center + Vector3.new(x, 10, z)), TRIM)
		end
	end
	part(room, "BackWall", Vector3.new(ROOM_SIZE.X, 18, 2),
		CFrame.new(center + Vector3.new(0, 10, 27)), STONE, Enum.Material.Brick)
	for _, x in ipairs({-19, 19}) do
		part(room, "FrontWall", Vector3.new(26, 18, 2),
			CFrame.new(center + Vector3.new(x, 10, -27)), STONE, Enum.Material.Brick)
	end
	part(room, "FrontWallTop", Vector3.new(12, 4, 2),
		CFrame.new(center + Vector3.new(0, 17, -27)), STONE, Enum.Material.Brick)
	local centerWall = part(room, "FrontWallCenter", Vector3.new(12, 14, 2),
		CFrame.new(center + Vector3.new(0, 8, -27)), STONE, Enum.Material.Brick)
	for _, x in ipairs({-27, 27}) do
		for _, z in ipairs({-17, 17}) do
			torch(room, center + Vector3.new(x, 6, z))
		end
	end
	for _, x in ipairs({-12, 12}) do
		torch(room, center + Vector3.new(x, 6, -24))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RetrySpawn"
	spawn.Size = Vector3.new(6, 0.5, 6)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 1.25, 12))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = room
	local info = {
		model = room,
		center = center,
		spawn = spawn,
		arrival = CFrame.new(center + Vector3.new(0, 5, 12)),
		centerWall = centerWall,
	}
	room.Parent = parent
	return info
end

function World.openExit(room)
	if room.threshold then
		return
	end
	-- Remove collision immediately so the opening animation cannot trap a character.
	room.centerWall.CanCollide = false
	room.centerWall.CanTouch = false
	room.centerWall.CanQuery = false
	TweenService:Create(room.centerWall, TweenInfo.new(0.6), {
		CFrame = room.centerWall.CFrame + Vector3.new(0, 16, 0), Transparency = 1,
	}):Play()
	Debris:AddItem(room.centerWall, 0.7)
	local frame = CFrame.new(room.center + Vector3.new(0, 1, -27))
	doorway(room.model, "ClearExit", frame, BLUE, "출구 · 걸어서 진입")
	local portal = room.model.ClearExit.Portal
	portal.CanCollide = false
	portal.CanTouch = false
	portal.CanQuery = false
	local backingDepth = 0.4
	local backing = part(room.model.ClearExit, "PortalBacking", Vector3.new(portal.Size.X, portal.Size.Y, backingDepth),
		portal.CFrame * CFrame.new(0, 0, -(portal.Size.Z + backingDepth) / 2), BLUE, Enum.Material.Neon)
	backing.Transparency = 0
	backing.CanCollide = false
	backing.CanTouch = false
	backing.CanQuery = false
	part(room.model, "ExitLanding", Vector3.new(16, 2, 14),
		CFrame.new(room.center + Vector3.new(0, 0, -32)), STONE, Enum.Material.Cobblestone)
	local threshold = part(room.model.ClearExit, "Threshold", Vector3.new(10, 10, 6),
		CFrame.new(room.center + Vector3.new(0, 6, -27)), BLUE)
	threshold.Transparency = 1
	threshold.CanCollide = false
	threshold.CanTouch = false
	threshold.CanQuery = false
	room.threshold = threshold
end

return World
