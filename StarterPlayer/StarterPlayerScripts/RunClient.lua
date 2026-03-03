-- RunClient.lua
-- Minimal run timer + notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local runEvent = remotes:WaitForChild("RunEvent")

local runStart = os.clock()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.fromOffset(220, 50)
timerLabel.Position = UDim2.fromOffset(20, 20)
timerLabel.BackgroundTransparency = 0.3
timerLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Text = "Time: 0.00"
timerLabel.Parent = screenGui

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.fromOffset(420, 44)
infoLabel.Position = UDim2.fromScale(0.5, 0.08)
infoLabel.AnchorPoint = Vector2.new(0.5, 0)
infoLabel.BackgroundTransparency = 0.25
infoLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.GothamBold
infoLabel.Text = "Reach the finish pad!"
infoLabel.Visible = false
infoLabel.Parent = screenGui

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.fromOffset(180, 40)
coinsLabel.Position = UDim2.fromOffset(20, 78)
coinsLabel.BackgroundTransparency = 0.3
coinsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
coinsLabel.TextColor3 = Color3.fromRGB(255, 231, 77)
coinsLabel.TextScaled = true
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = screenGui

local function showMessage(text, seconds)
	infoLabel.Text = text
	infoLabel.Visible = true
	task.delay(seconds or 2, function()
		if infoLabel.Text == text then
			infoLabel.Visible = false
		end
	end)
end

local function formatTime(value)
	return string.format("%.2f", value)
end

local function bindCoinsLabel()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end

	local coins = leaderstats:WaitForChild("Coins", 10)
	if not coins then
		return
	end

	local function refresh()
		coinsLabel.Text = ("Coins: %d"):format(coins.Value)
	end

	refresh()
	coins:GetPropertyChangedSignal("Value"):Connect(refresh)
end

RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - runStart
	timerLabel.Text = ("Time: %s"):format(formatTime(elapsed))
end)

runEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.type) ~= "string" then
		return
	end

	if payload.type == "Checkpoint" then
		showMessage(("Checkpoint reached: %s"):format(payload.name or ""), 1.5)
	elseif payload.type == "Finish" then
		local timeValue = tonumber(payload.time) or 0
		showMessage(("Finish! Time: %s"):format(formatTime(timeValue)), 2.5)
		runStart = os.clock()
	elseif payload.type == "Sync" then
		runStart = os.clock()
	end
end)

player.CharacterAdded:Connect(function()
	runStart = os.clock()
end)

bindCoinsLabel()
