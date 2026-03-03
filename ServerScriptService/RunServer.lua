-- RunServer.lua
-- Minimal speedrun + checkpoint + coins + saving.
-- Version 1 goal: ship a complete playable loop.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerStore = DataStoreService:GetDataStore("SpeedrunObby_V1")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local runEvent = remotes:WaitForChild("RunEvent")

-- Workspace references
local map = workspace:WaitForChild("Map")
local startPad = map:WaitForChild("StartPad")
local finishPad = map:WaitForChild("FinishPad")
local checkpointsFolder = map:WaitForChild("Checkpoints")
local coinsFolder = map:WaitForChild("Coins")

-- In-memory state (resets when server closes)
-- [userId] = {
--   runStart = number,
--   checkpointCFrame = CFrame,
--   touchedCheckpoints = {[checkpointName] = true},
--   touchedCoins = {[coinName] = true}
-- }
local runState = {}

local function safeGetAsync(key)
	local ok, result = pcall(function()
		return playerStore:GetAsync(key)
	end)

	if ok then
		return result
	end

	warn("GetAsync failed for", key, result)
	return nil
end

local function safeSetAsync(key, value)
	local ok, err = pcall(function()
		playerStore:SetAsync(key, value)
	end)

	if not ok then
		warn("SetAsync failed for", key, err)
	end

	return ok
end

local function ensureLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = leaderstats

	local best = Instance.new("NumberValue")
	best.Name = "BestTime"
	best.Value = 0
	best.Parent = leaderstats

	return coins, best
end

local function getCharacterRoot(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportToCFrame(player, targetCFrame)
	local character = player.Character
	local root = getCharacterRoot(character)
	if not root then
		return
	end

	root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
end

local function getPlayerState(player)
	local state = runState[player.UserId]
	if state then
		return state
	end

	state = {
		runStart = os.clock(),
		checkpointCFrame = startPad.CFrame,
		touchedCheckpoints = {},
		touchedCoins = {},
	}

	runState[player.UserId] = state
	return state
end

local function getSaveKey(player)
	return ("player_%d"):format(player.UserId)
end

local function savePlayerData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local best = leaderstats:FindFirstChild("BestTime")
	if not coins or not best then
		return false
	end

	local payload = {
		coins = coins.Value,
		bestTime = best.Value,
	}

	return safeSetAsync(getSaveKey(player), payload)
end

local function loadPlayerData(player, coinsValue, bestValue)
	local data = safeGetAsync(getSaveKey(player))
	if type(data) ~= "table" then
		return
	end

	if type(data.coins) == "number" then
		coinsValue.Value = math.max(0, math.floor(data.coins))
	end

	if type(data.bestTime) == "number" then
		bestValue.Value = math.max(0, data.bestTime)
	end
end

local function characterFromHit(hitPart)
	if not hitPart then
		return nil
	end

	local candidate = hitPart.Parent
	if candidate and candidate:FindFirstChildOfClass("Humanoid") then
		return candidate
	end

	return nil
end

local function playerFromHit(hitPart)
	local character = characterFromHit(hitPart)
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function handleCheckpointTouch(checkpointPart, hitPart)
	local player = playerFromHit(hitPart)
	if not player then
		return
	end

	local state = getPlayerState(player)
	if state.touchedCheckpoints[checkpointPart.Name] then
		return
	end

	state.touchedCheckpoints[checkpointPart.Name] = true
	state.checkpointCFrame = checkpointPart.CFrame

	runEvent:FireClient(player, {
		type = "Checkpoint",
		name = checkpointPart.Name,
	})
end

local function handleCoinTouch(coinPart, hitPart)
	local player = playerFromHit(hitPart)
	if not player then
		return
	end

	local state = getPlayerState(player)
	if state.touchedCoins[coinPart.Name] then
		return
	end

	state.touchedCoins[coinPart.Name] = true

	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue then
		coinsValue.Value += 1
	end

	coinPart.Transparency = 1
	coinPart.CanTouch = false

	task.delay(8, function()
		if not coinPart.Parent then
			return
		end
		coinPart.Transparency = 0
		coinPart.CanTouch = true
	end)
end

local function handleFinishTouch(hitPart)
	local player = playerFromHit(hitPart)
	if not player then
		return
	end

	local state = getPlayerState(player)
	local elapsed = os.clock() - state.runStart
	elapsed = math.max(0, elapsed)

	local leaderstats = player:FindFirstChild("leaderstats")
	local bestValue = leaderstats and leaderstats:FindFirstChild("BestTime")

	local isPersonalBest = false
	if bestValue and (bestValue.Value == 0 or elapsed < bestValue.Value) then
		bestValue.Value = elapsed
		isPersonalBest = true
	end

	runEvent:FireClient(player, {
		type = "Finish",
		time = elapsed,
		personalBest = isPersonalBest,
	})

	state.runStart = os.clock()
	state.checkpointCFrame = startPad.CFrame
	state.touchedCheckpoints = {}
	state.touchedCoins = {}

	teleportToCFrame(player, startPad.CFrame)
end

local function onCharacterAdded(player, character)
	local state = getPlayerState(player)

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		task.wait(0.15)
		teleportToCFrame(player, state.checkpointCFrame)
	end)

	task.wait(0.1)
	teleportToCFrame(player, state.checkpointCFrame)
end

local function onPlayerAdded(player)
	local coinsValue, bestValue = ensureLeaderstats(player)
	loadPlayerData(player, coinsValue, bestValue)

	getPlayerState(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	runEvent:FireClient(player, {
		type = "Sync",
		bestTime = bestValue.Value,
	})
end

local function onPlayerRemoving(player)
	savePlayerData(player)
	runState[player.UserId] = nil
end

for _, checkpoint in ipairs(checkpointsFolder:GetChildren()) do
	if checkpoint:IsA("BasePart") then
		checkpoint.Touched:Connect(function(hitPart)
			handleCheckpointTouch(checkpoint, hitPart)
		end)
	end
end

for _, coin in ipairs(coinsFolder:GetChildren()) do
	if coin:IsA("BasePart") then
		coin.Touched:Connect(function(hitPart)
			handleCoinTouch(coin, hitPart)
		end)
	end
end

finishPad.Touched:Connect(handleFinishTouch)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
