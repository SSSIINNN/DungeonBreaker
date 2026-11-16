local Players = game:GetService("Players")

local Travel = {}
local MOVE_COOLDOWN = 0.75

function Travel.getLivingRoot(player, state)
	if player.Parent ~= Players or not state or state.character ~= player.Character then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Travel.canMove(player, state, route)
	local root = Travel.getLivingRoot(player, state)
	if not root then
		return false, "DeadOrMissingCharacter"
	end
	if state.moving or os.clock() < state.readyAt then
		return false, "Cooldown"
	end
	if state.area ~= route.from then
		return false, "Area"
	end
	if route.owner and route.owner ~= player then
		return false, "Owner"
	end
	if route.requiredPhase and state.phase ~= route.requiredPhase then
		return false, "Sealed"
	end
	if not route.prompt.Enabled or not route.interaction:IsDescendantOf(workspace) then
		return false, "Unavailable"
	end
	local distance = (root.Position - route.interaction.WorldPosition).Magnitude
	if not (distance <= route.prompt.MaxActivationDistance) then
		return false, "Distance"
	end
	return true
end

function Travel.tryMove(player, state, route)
	local allowed, reason = Travel.canMove(player, state, route)
	if not allowed then
		return false, reason
	end
	return Travel.move(player, state, route.destination, route.to)
end

function Travel.move(player, state, destination, area)
	local root = Travel.getLivingRoot(player, state)
	if not root or state.moving then
		return false, "DeadOrMoving"
	end
	local character = player.Character

	-- Keep validation, movement, and state changes together without yielding.
	state.moving = true
	local moved, problem = pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(destination)
	end)
	state.moving = false
	if not moved then
		warn("DungeonBreaker travel failed", problem)
		return false, "MoveFailed"
	end
	state.area = area
	state.readyAt = os.clock() + MOVE_COOLDOWN
	-- This attribute is for inspection. The server table controls permission to travel.
	player:SetAttribute("CurrentArea", state.area)
	return true
end

function Travel.isAtExit(player, state, challenge)
	local root = Travel.getLivingRoot(player, state)
	local threshold = challenge and challenge.room.threshold
	if not root or state.area ~= "Dungeon" or state.challenge ~= challenge
		or challenge.owner ~= player or not threshold or not threshold:IsDescendantOf(workspace) then
		return false
	end
	local position = threshold.CFrame:PointToObjectSpace(root.Position)
	local halfSize = threshold.Size / 2
	return math.abs(position.X) <= halfSize.X and math.abs(position.Y) <= halfSize.Y
		and math.abs(position.Z) <= halfSize.Z
end

return Travel
