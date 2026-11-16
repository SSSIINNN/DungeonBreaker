-- Studio 서버에서 임시 ModuleScript로 불러온 뒤 require(testModule)(서버 모듈 폴더)로 실행한다.
return function(modules)
	local World = require(modules.World)
	local Combat = require(modules.Combat)
	local Dungeon = require(modules.Dungeon)
	local config = require(modules.CombatConfig)
	local playerDamage, monsterDamage = config.PlayerAttackDamage, config.MonsterAttackDamage
	local worldRoot
	local connections = {}
	local ok, problem = xpcall(function()
		local world = World.build()
		worldRoot = world.rooms.Parent
		worldRoot.Name = "PortalCombatCheck"
		local entrance = worldRoot.Lobby.DungeonEntrance
		assert(world.entryRoute.prompt.KeyboardKeyCode == Enum.KeyCode.E, "입구 E 상호작용")
		assert((world.entryRoute.interaction.WorldPosition - Vector3.new(0, 4, 53.5)).Magnitude < 0.001,
			"입구 상호작용 위치 유지")

		local function checkOpening(door)
			local posts = {}
			for _, child in ipairs(door:GetChildren()) do
				if child.Name == "StonePost" then table.insert(posts, child) end
			end
			table.sort(posts, function(a, b) return a.Position.X < b.Position.X end)
			local portal = door.Portal
			local low, high = portal.Position - portal.Size / 2, portal.Position + portal.Size / 2
			assert(low.X < posts[1].Position.X + posts[1].Size.X / 2, "왼쪽 문틀 겹침")
			assert(high.X > posts[2].Position.X - posts[2].Size.X / 2, "오른쪽 문틀 겹침")
			assert(low.Y < posts[1].Position.Y - posts[1].Size.Y / 2, "바닥 겹침")
			assert(high.Y > door.Lintel.Position.Y - door.Lintel.Size.Y / 2, "상단 문틀 겹침")
		end
		checkOpening(entrance)

		local choiceCount = 0
		local owner = {
			UserId = -1,
			Parent = game:GetService("Players"),
			SetAttribute = function(_, name, value)
				if name == "DungeonStatus" and value == "Choosing" then choiceCount += 1 end
			end,
		}
		local room = World.createRoom(world.rooms, owner, 100)
		assert(not room.model:FindFirstChild("ClearExit"), "클리어 전 출구 없음")
		World.openExit(room)
		checkOpening(room.model.ClearExit)
		local exit = room.model.ClearExit
		local portal, backing = exit.Portal, exit.PortalBacking
		assert(not portal.CanCollide and not backing.CanCollide, "출구와 가림판 통과 가능")
		assert(backing.Transparency == 0 and backing.Color == portal.Color, "불투명 파란 가림판")
		assert(backing.Size.X == portal.Size.X and backing.Size.Y == portal.Size.Y, "전체 개구부 가림")
		local offset = portal.CFrame:PointToObjectSpace(backing.Position)
		assert(math.abs(offset.X) < 0.001 and math.abs(offset.Y) < 0.001, "가림판 중앙 정렬")
		assert(math.abs(offset.Z + (portal.Size.Z + backing.Size.Z) / 2) < 0.001, "포털 바로 뒤 가림판")
		local childCount = #room.model:GetDescendants()
		World.openExit(room)
		assert(room.model.ClearExit == exit and #room.model:GetDescendants() == childCount, "출구 중복 생성 방지")

		local challenge = {owner = owner, id = 1, room = room, monsters = {}, remaining = 0, connections = connections}
		Combat.spawn(challenge, function() end)
		local target = challenge.monsters[room.model.Monsters.Guardian_1]
		local character = Instance.new("Model")
		character.Name = "TestCharacter"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.CFrame = CFrame.lookAt(target.root.Position + Vector3.new(0, 0, 4), target.root.Position)
		root.Parent = character
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.Parent = character
		character.Parent = worldRoot
		owner.Character = character
		local state = {
			player = owner, area = "Dungeon", phase = "Fighting", character = character,
			challenge = challenge, attackReadyAt = 0,
		}
		local function checkDamage(expectedPlayer, expectedMonster)
			target.humanoid.Health = target.humanoid.MaxHealth
			humanoid.Health = humanoid.MaxHealth
			target.nextHitAt = 0
			state.attackReadyAt = 0
			assert(Combat.attack(owner, state), "플레이어 공격 허용")
			assert(target.humanoid.Health == target.humanoid.MaxHealth - expectedPlayer, "플레이어 피해량 적용")
			Combat.step(state, 0)
			assert(humanoid.Health == humanoid.MaxHealth - expectedMonster, "몬스터 피해량 적용")
		end
		checkDamage(playerDamage, monsterDamage)
		config.PlayerAttackDamage = 10
		checkDamage(10, monsterDamage)
		config.PlayerAttackDamage = playerDamage
		config.MonsterAttackDamage = 3
		checkDamage(playerDamage, 3)
		config.MonsterAttackDamage = monsterDamage

		assert(not Dungeon.tryClear(state, challenge), "몬스터가 남으면 클리어 거부")
		challenge.remaining = 0
		assert(Dungeon.tryClear(state, challenge), "전멸 후 클리어 허용")
		root.CFrame = room.threshold.CFrame * CFrame.new(0, 0, 1)
		assert(not Dungeon.checkExit(state), "출구 앞에서는 선택하지 않음")
		root.CFrame = room.threshold.CFrame * CFrame.new(0, 0, -0.1)
		assert(Dungeon.checkExit(state) and state.phase == "Choosing", "출구 통과 시 선택 상태 진입")
		for _ = 1, 3 do assert(not Dungeon.checkExit(state), "반복 출구 검사 무시") end
		assert(choiceCount == 1, "선택 상태는 한 번만 발생")
	end, debug.traceback)
	config.PlayerAttackDamage, config.MonsterAttackDamage = playerDamage, monsterDamage
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if worldRoot then worldRoot:Destroy() end
	assert(ok, problem)
	return "PASS: portal coverage, opaque passable backing, single exit/choice, independent attack damage"
end
