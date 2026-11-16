local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("DungeonRemotes")
local attackRemote = remotes:WaitForChild("Attack")
local choiceRemote = remotes:WaitForChild("DeathChoice")
local destinationRemote = remotes:WaitForChild("DestinationChoice")

local gui = Instance.new("ScreenGui")
gui.Name = "DungeonHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, name, text, position, size)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Position = position
	item.Size = size
	item.BackgroundTransparency = 1
	item.TextColor3 = Color3.fromRGB(246, 238, 220)
	item.TextSize = 22
	item.Font = Enum.Font.GothamBold
	item.TextWrapped = true
	item.Text = text
	item.Parent = parent
	return item
end

local status = label(gui, "Status", "", UDim2.new(0.5, -180, 0, 12), UDim2.fromOffset(360, 76))
status.BackgroundColor3 = Color3.fromRGB(25, 26, 34)
status.BackgroundTransparency = 0.15
local health = label(gui, "Health", "", UDim2.new(0, 18, 1, -64), UDim2.fromOffset(210, 44))
health.BackgroundColor3 = Color3.fromRGB(25, 26, 34)
health.BackgroundTransparency = 0.15

local function button(parent, name, text, position, size, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = color
	item.TextColor3 = Color3.fromRGB(255, 250, 239)
	item.TextSize = 20
	item.Font = Enum.Font.GothamBold
	item.Text = text
	item.Parent = parent
	return item
end

local attackButton = button(gui, "Attack", "공격 · 클릭 / F", UDim2.new(1, -200, 1, -82),
	UDim2.fromOffset(182, 60), Color3.fromRGB(112, 71, 37))
local choicePanel = Instance.new("Frame")
choicePanel.Name = "ChoicePanel"
choicePanel.Size = UDim2.fromScale(1, 1)
choicePanel.BackgroundColor3 = Color3.fromRGB(13, 14, 20)
choicePanel.BackgroundTransparency = 0.18
choicePanel.Active = true
choicePanel.Visible = false
choicePanel.Parent = gui
local card = Instance.new("Frame")
card.Name = "Choices"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.9, 0, 0, 280)
card.BackgroundColor3 = Color3.fromRGB(32, 32, 43)
card.Parent = choicePanel
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(420, 280)
limit.Parent = card
local title = label(card, "Title", "도전 실패", UDim2.new(0, 12, 0, 20), UDim2.new(1, -24, 0, 44))
local deathMessage = label(card, "Message", "다음 행동을 선택하세요.",
	UDim2.new(0, 12, 0, 66), UDim2.new(1, -24, 0, 40))
deathMessage.TextSize = 17
local primary = button(card, "Primary", "다시 도전", UDim2.new(0, 24, 0, 128),
	UDim2.new(1, -48, 0, 52), Color3.fromRGB(139, 82, 40))
local back = button(card, "Lobby", "로비로 돌아가기", UDim2.new(0, 24, 0, 196),
	UDim2.new(1, -48, 0, 52), Color3.fromRGB(54, 94, 105))

local pendingChoice
local nextAttackAt = 0
local healthConnection

local function updateHUD()
	local phase = player:GetAttribute("DungeonStatus")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0
	local deadInDungeon = phase == "Dead" and not alive and player:GetAttribute("CurrentArea") == "Dungeon"
	local atExit = phase == "Choosing" and alive
	local processing = pendingChoice ~= nil or phase == "Respawning" or phase == "Switching"
	local wasVisible = choicePanel.Visible
	choicePanel.Visible = deadInDungeon or atExit or (pendingChoice ~= nil and processing)
	local destinationMode = atExit or pendingChoice == "Destination"
	title.Text = if destinationMode then "이동할 곳을 선택하세요" else "도전 실패"
	primary.Text = if destinationMode then "다음 던전 가기" else "다시 도전"
	primary.Active = (deadInDungeon or atExit) and not processing
	back.Active = primary.Active
	primary.AutoButtonColor = primary.Active
	back.AutoButtonColor = back.Active
	deathMessage.Text = if processing then "준비하는 중…" else "다음 행동을 선택하세요."
	attackButton.Visible = phase == "Fighting"
	if phase == "Fighting" then
		status.Text = string.format("제 %d방 · 전투 중\n남은 몬스터 %d",
			player:GetAttribute("RoomNumber") or 1, player:GetAttribute("MonstersRemaining") or 0)
	elseif phase == "Cleared" then
		status.Text = "던전 클리어!\n정면에 열린 문으로 걸어가세요"
	elseif phase == "Choosing" then
		status.Text = "던전 클리어!\n목적지를 선택하세요"
	elseif phase == "Lobby" then
		status.Text = "로비\n노란 입구에서 E · 던전 입장"
	elseif phase == "Dead" then
		status.Text = "도전 실패"
	else
		status.Text = "준비 중…"
	end
	if choicePanel.Visible and not wasVisible and not processing and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = primary
	elseif not choicePanel.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(card) then
		GuiService.SelectedObject = nil
	end
end

local function attack()
	if player:GetAttribute("DungeonStatus") ~= "Fighting" or os.clock() < nextAttackAt then
		return
	end
	nextAttackAt = os.clock() + 0.45
	attackRemote:FireServer(player:GetAttribute("AttemptId"))
	attackButton.BackgroundColor3 = Color3.fromRGB(202, 137, 61)
	TweenService:Create(attackButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(112, 71, 37)}):Play()
end

local function choose(choice)
	local phase = player:GetAttribute("DungeonStatus")
	if pendingChoice or (phase ~= "Dead" and phase ~= "Choosing") then
		return
	end
	pendingChoice = if phase == "Choosing" then "Destination" else "Death"
	updateHUD()
	local remote = if phase == "Choosing" then destinationRemote else choiceRemote
	remote:FireServer(choice, player:GetAttribute("AttemptId"))
end

primary.Activated:Connect(function()
	choose(if player:GetAttribute("DungeonStatus") == "Choosing" then "Next" else "Retry")
end)
back.Activated:Connect(function() choose("Lobby") end)
attackButton.Activated:Connect(attack)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		attack()
	end
end)
player:GetAttributeChangedSignal("DungeonStatus"):Connect(function()
	local phase = player:GetAttribute("DungeonStatus")
	if phase ~= "Respawning" and phase ~= "Switching" then
		pendingChoice = nil
	end
	updateHUD()
end)
player:GetAttributeChangedSignal("MonstersRemaining"):Connect(updateHUD)
player:GetAttributeChangedSignal("CurrentArea"):Connect(updateHUD)
player:GetAttributeChangedSignal("RoomNumber"):Connect(updateHUD)

local function characterAdded(character)
	if healthConnection then
		healthConnection:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid")
	local function updateHealth()
		health.Text = string.format("체력 %d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		updateHUD()
	end
	healthConnection = humanoid.HealthChanged:Connect(updateHealth)
	updateHealth()
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then
	task.spawn(characterAdded, player.Character)
end
updateHUD()
