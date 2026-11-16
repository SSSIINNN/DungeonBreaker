local Combat = {}
local Debris = game:GetService("Debris")
local CombatConfig = require(script.Parent.CombatConfig)

local MONSTER_HEALTH = 60
local MONSTER_SPEED = 7
local MONSTER_REACH = 4.5
local ATTACK_REACH = 8
local ATTACK_COOLDOWN = 0.45

local function bodyPart(model, name, size, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

function Combat.spawn(challenge, onDefeated)
	local folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = challenge.room.model
	for index, offset in ipairs({Vector3.new(-14, 3, -10), Vector3.new(0, 3, -18), Vector3.new(14, 3, -10)}) do
		local model = Instance.new("Model")
		model.Name = "Guardian_" .. index
		model:SetAttribute("OwnerUserId", challenge.owner.UserId)
		model:SetAttribute("AttemptId", challenge.id)
		local position = challenge.room.center + offset
		local root = bodyPart(model, "HumanoidRootPart", Vector3.new(2, 2, 2), position, Color3.new())
		root.Transparency = 1
		root.CanQuery = false
		model.PrimaryPart = root
		local body = bodyPart(model, "Body", Vector3.new(2.5, 3, 1.8), position,
			Color3.fromRGB(104, 97, 119))
		bodyPart(model, "Head", Vector3.new(1.8, 1.6, 1.8), position + Vector3.new(0, 2.2, 0),
			Color3.fromRGB(136, 128, 149))
		for _, side in ipairs({-1, 1}) do
			bodyPart(model, "Arm", Vector3.new(0.8, 2.5, 1), position + Vector3.new(side * 1.7, 0, 0), body.Color)
			bodyPart(model, "Leg", Vector3.new(0.9, 1.5, 1.2), position + Vector3.new(side * 0.7, -1.3, 0), body.Color)
			local eye = bodyPart(model, "Eye", Vector3.new(0.35, 0.3, 0.15),
				position + Vector3.new(side * 0.4, 2.35, -0.95), Color3.fromRGB(255, 95, 90))
			eye.Material = Enum.Material.Neon
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.DisplayName = "석상 수호자"
		humanoid.MaxHealth = MONSTER_HEALTH
		humanoid.Health = MONSTER_HEALTH
		humanoid.HealthDisplayDistance = 60
		humanoid.Parent = model
		local monster = {model = model, root = root, humanoid = humanoid, nextHitAt = 0, dead = false}
		challenge.monsters[model] = monster
		challenge.remaining += 1
		table.insert(challenge.connections, humanoid.Died:Connect(function()
			if monster.dead then
				return
			end
			monster.dead = true
			onDefeated(challenge)
			model:Destroy()
		end))
		model.Parent = folder
	end
end

function Combat.step(state, deltaTime)
	local challenge = state.challenge
	local character = state.character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if state.phase ~= "Fighting" or not challenge or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	for _, monster in pairs(challenge.monsters) do
		if monster.dead or monster.humanoid.Health <= 0 then
			continue
		end
		local offset = root.Position - monster.root.Position
		local horizontal = Vector3.new(offset.X, 0, offset.Z)
		local distance = horizontal.Magnitude
		if distance > MONSTER_REACH then
			local movement = horizontal.Unit * math.min(MONSTER_SPEED * deltaTime, distance - MONSTER_REACH)
			local position = monster.root.Position + movement
			local center = challenge.room.center
			position = Vector3.new(math.clamp(position.X, center.X - 27, center.X + 27),
				position.Y, math.clamp(position.Z, center.Z - 23, center.Z + 23))
			monster.model:PivotTo(CFrame.lookAt(position, position + horizontal.Unit))
		elseif math.abs(offset.Y) < 5 and now >= monster.nextHitAt then
			monster.nextHitAt = now + 1.2
			humanoid:TakeDamage(CombatConfig.MonsterAttackDamage)
		end
	end
end

function Combat.attack(player, state)
	if not state or state.busy or state.phase ~= "Fighting" or not state.challenge
		or state.character ~= player.Character then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or os.clock() < state.attackReadyAt then
		return false
	end
	state.attackReadyAt = os.clock() + ATTACK_COOLDOWN
	local swing = Instance.new("Part")
	swing.Name = "AttackSwing"
	swing.Size = Vector3.new(7, 0.25, 4)
	swing.CFrame = root.CFrame * CFrame.new(0, -0.5, -4)
	swing.Anchored = true
	swing.CanCollide = false
	swing.CanTouch = false
	swing.CanQuery = false
	swing.Material = Enum.Material.Neon
	swing.Color = Color3.fromRGB(255, 218, 132)
	swing.Transparency = 0.55
	swing.Parent = state.challenge.room.model
	Debris:AddItem(swing, 0.15)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local closest, closestDistance = nil, ATTACK_REACH
	for _, monster in pairs(state.challenge.monsters) do
		if monster.dead or monster.humanoid.Health <= 0 then
			continue
		end
		local offset = monster.root.Position - root.Position
		local distance = offset.Magnitude
		local inFront = distance < 0.1 or root.CFrame.LookVector:Dot(offset.Unit) >= 0.1
		if distance <= closestDistance and inFront then
			local hit = workspace:Raycast(root.Position, offset, rayParams)
			if not hit or hit.Instance:IsDescendantOf(monster.model) then
				closest, closestDistance = monster, distance
			end
		end
	end
	if closest then
		closest.humanoid:TakeDamage(CombatConfig.PlayerAttackDamage)
	end
	return true
end

return Combat
