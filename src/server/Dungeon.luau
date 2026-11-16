local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local Travel = require(script.Parent.Travel)
local Combat = require(script.Parent.Combat)

local Dungeon = {players = {}}
local world
local slots = {}

local function setPhase(state, phase)
	state.phase = phase
	state.player:SetAttribute("DungeonStatus", phase)
end

local function releaseChoice(state)
	if state.choiceRoot and state.choiceRoot.Parent then
		state.choiceRoot.Anchored = false
	end
	state.choiceRoot = nil
end

local function clearChallenge(state)
	releaseChoice(state)
	local challenge = state.challenge
	state.challenge = nil
	state.player.RespawnLocation = world.lobbySpawn
	if challenge then
		for _, connection in ipairs(challenge.connections) do
			connection:Disconnect()
		end
		challenge.room.model:Destroy()
	end
	state.player:SetAttribute("MonstersRemaining", 0)
end

function Dungeon.tryClear(state, challenge)
	if state.challenge ~= challenge or state.phase ~= "Fighting" or challenge.spawning or challenge.remaining ~= 0
		or not Travel.getLivingRoot(state.player, state) then
		return false
	end
	World.openExit(challenge.room)
	challenge.previousExitZ = state.character.HumanoidRootPart.Position.Z
	setPhase(state, "Cleared")
	return true
end

local function createChallenge(state, roomNumber)
	state.attemptId += 1
	state.player:SetAttribute("AttemptId", state.attemptId)
	state.roomNumber = roomNumber
	state.player:SetAttribute("RoomNumber", roomNumber)
	local room = World.createRoom(world.rooms, state.player, state.slot)
	room.model:SetAttribute("AttemptId", state.attemptId)
	room.model:SetAttribute("RoomNumber", roomNumber)
	local challenge = {
		id = state.attemptId, owner = state.player, room = room,
		monsters = {}, remaining = 0, spawning = true, connections = {},
	}
	state.challenge = challenge
	return challenge
end

local function beginCombat(state, challenge)
	state.attackReadyAt = 0
	setPhase(state, "Fighting")
	Combat.spawn(challenge, function(defeatedChallenge)
		if state.challenge ~= defeatedChallenge or state.phase ~= "Fighting" then
			return
		end
		defeatedChallenge.remaining -= 1
		state.player:SetAttribute("MonstersRemaining", defeatedChallenge.remaining)
		Dungeon.tryClear(state, defeatedChallenge)
	end)
	challenge.spawning = false
	state.player:SetAttribute("MonstersRemaining", challenge.remaining)
	Dungeon.tryClear(state, challenge)
end

local function loadCharacter(state, spawn, destination, area)
	local player = state.player
	player.RespawnLocation = spawn
	local loaded, problem = pcall(function()
		player:LoadCharacterAsync()
	end)
	if Dungeon.players[player] ~= state or player.Parent ~= Players then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		warn("DungeonBreaker character load failed", problem)
		return false
	end
	-- LoadCharacterAsync can fail after creating a usable character.
	if not loaded then
		warn("DungeonBreaker character load recovered", problem)
	end
	state.character = character
	character:PivotTo(destination)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	humanoid.Health = humanoid.MaxHealth
	state.area = area
	state.readyAt = os.clock() + 0.75
	state.moving = false
	player:SetAttribute("CurrentArea", area)
	return true
end

local function respawnLobby(state)
	state.busy = true
	setPhase(state, "Respawning")
	local loaded = loadCharacter(state, world.lobbySpawn, world.lobbyStart, "Lobby")
	if Dungeon.players[state.player] ~= state then
		return false
	end
	state.busy = false
	if loaded then
		clearChallenge(state)
		setPhase(state, "Lobby")
	else
		setPhase(state, "Dead")
		if state.area == "Lobby" then
			task.delay(2, function()
				if Dungeon.players[state.player] == state and state.phase == "Dead" and not state.busy then
					respawnLobby(state)
				end
			end)
		end
	end
	return loaded
end

function Dungeon.enter(player)
	local state = Dungeon.players[player]
	if not state or state.busy or state.phase ~= "Lobby" or not Travel.canMove(player, state, world.entryRoute) then
		return false
	end
	state.busy = true
	setPhase(state, "Entering")
	local ok, problem = pcall(function()
		local challenge = createChallenge(state, 1)
		local route = table.clone(world.entryRoute)
		route.destination = challenge.room.arrival
		assert(Travel.tryMove(player, state, route), "Entry movement failed")
		player.RespawnLocation = challenge.room.spawn
		beginCombat(state, challenge)
	end)
	state.busy = false
	if not ok then
		warn("DungeonBreaker entry failed", problem)
		respawnLobby(state)
	end
	return ok
end

function Dungeon.checkExit(state)
	local challenge = state.challenge
	local root = Travel.getLivingRoot(state.player, state)
	if state.busy or state.phase ~= "Cleared" or not challenge or not root then
		return false
	end
	local previousZ = challenge.previousExitZ
	challenge.previousExitZ = root.Position.Z
	local threshold = challenge.room.threshold
	if not previousZ or previousZ <= threshold.Position.Z or root.Position.Z > threshold.Position.Z
		or not Travel.isAtExit(state.player, state, challenge) then
		return false
	end
	-- Only crossing the cleared doorway grants permission to choose a destination.
	state.choiceRoot = root
	root.Anchored = true
	setPhase(state, "Choosing")
	return true
end

function Dungeon.chooseDestination(player, choice, attemptId)
	local state = Dungeon.players[player]
	local challenge = state and state.challenge
	if not state or state.busy or state.phase ~= "Choosing" or state.attemptId ~= attemptId
		or not challenge or challenge.spawning or challenge.remaining ~= 0
		or not Travel.isAtExit(player, state, challenge) then
		return false
	end
	if choice ~= "Next" and choice ~= "Lobby" then
		return false
	end
	state.busy = true
	setPhase(state, "Switching")
	local ok, problem = pcall(function()
		if choice == "Lobby" then
			assert(Travel.move(player, state, world.lobbyStart, "Lobby"), "Lobby movement failed")
			clearChallenge(state)
			setPhase(state, "Lobby")
		else
			local nextNumber = state.roomNumber + 1
			clearChallenge(state)
			local nextChallenge = createChallenge(state, nextNumber)
			assert(Travel.move(player, state, nextChallenge.room.arrival, "Dungeon"), "Next room movement failed")
			player.RespawnLocation = nextChallenge.room.spawn
			beginCombat(state, nextChallenge)
		end
	end)
	state.busy = false
	if not ok then
		warn("DungeonBreaker destination change failed", problem)
		respawnLobby(state)
	end
	return ok
end

function Dungeon.choose(player, choice, attemptId)
	local state = Dungeon.players[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not state or state.busy or state.phase ~= "Dead" or state.area ~= "Dungeon"
		or attemptId ~= state.attemptId or (humanoid and humanoid.Health > 0) then
		return false
	end
	if choice ~= "Retry" and choice ~= "Lobby" then
		return false
	end
	-- Reserve the choice before LoadCharacterAsync yields.
	state.busy = true
	setPhase(state, "Respawning")
	if choice == "Lobby" then
		return respawnLobby(state)
	end
	local ok, problem = pcall(function()
		clearChallenge(state)
		local challenge = createChallenge(state, 1)
		assert(loadCharacter(state, challenge.room.spawn, challenge.room.arrival, "Dungeon"), "Retry respawn failed")
		if Dungeon.players[player] == state then
			beginCombat(state, challenge)
		end
	end)
	if Dungeon.players[player] ~= state then
		return false
	end
	state.busy = false
	if not ok then
		warn("DungeonBreaker retry failed", problem)
		local current = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if current and current.Health > 0 then
			respawnLobby(state)
		else
			releaseChoice(state)
			setPhase(state, "Dead")
		end
	end
	return ok
end

function Dungeon.addPlayer(player)
	if Dungeon.players[player] or player.Parent ~= Players then
		return
	end
	local slot = 1
	while slots[slot] do
		slot += 1
	end
	slots[slot] = true
	local state = {
		player = player, slot = slot, area = "Lobby", phase = "Lobby", attemptId = 0,
		readyAt = 0, attackReadyAt = 0, moving = false, busy = false,
	}
	Dungeon.players[player] = state
	player:SetAttribute("CurrentArea", "Lobby")
	player:SetAttribute("AttemptId", 0)
	player:SetAttribute("MonstersRemaining", 0)
	state.characterConnection = player.CharacterAdded:Connect(function(character)
		state.character = character
		if state.deathConnection then
			state.deathConnection:Disconnect()
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or Dungeon.players[player] ~= state or player.Character ~= character then
			return
		end
		state.deathConnection = humanoid.Died:Connect(function()
			if Dungeon.players[player] ~= state or state.character ~= character then
				return
			end
			releaseChoice(state)
			setPhase(state, "Dead")
			if state.area == "Lobby" then
				task.delay(Players.RespawnTime, function()
					if Dungeon.players[player] == state and state.character == character and not state.busy then
						respawnLobby(state)
					end
				end)
			end
		end)
	end)
	respawnLobby(state)
end

function Dungeon.removePlayer(player)
	local state = Dungeon.players[player]
	if not state then
		return
	end
	Dungeon.players[player] = nil
	slots[state.slot] = nil
	state.characterConnection:Disconnect()
	if state.deathConnection then
		state.deathConnection:Disconnect()
	end
	clearChallenge(state)
end

function Dungeon.start()
	if world then
		return
	end
	Players.CharacterAutoLoads = false
	world = World.build()
	local remotes = Instance.new("Folder")
	remotes.Name = "DungeonRemotes"
	remotes.Parent = ReplicatedStorage
	local attack = Instance.new("RemoteEvent")
	attack.Name = "Attack"
	attack.Parent = remotes
	attack.OnServerEvent:Connect(function(player, attemptId)
		local state = Dungeon.players[player]
		if state and state.attemptId == attemptId then
			Combat.attack(player, state)
		end
	end)
	local choice = Instance.new("RemoteEvent")
	choice.Name = "DeathChoice"
	choice.Parent = remotes
	choice.OnServerEvent:Connect(Dungeon.choose)
	local destinationChoice = Instance.new("RemoteEvent")
	destinationChoice.Name = "DestinationChoice"
	destinationChoice.Parent = remotes
	destinationChoice.OnServerEvent:Connect(Dungeon.chooseDestination)
	world.entryRoute.prompt.Triggered:Connect(Dungeon.enter)
	Players.PlayerAdded:Connect(Dungeon.addPlayer)
	Players.PlayerRemoving:Connect(Dungeon.removePlayer)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < 0.1 then
			return
		end
		local stepTime = math.min(elapsed, 0.25)
		elapsed = 0
		for _, state in pairs(Dungeon.players) do
			Combat.step(state, stepTime)
			Dungeon.checkExit(state)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(Dungeon.addPlayer, player)
	end
end

return Dungeon
