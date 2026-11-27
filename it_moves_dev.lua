-- It Moves - Dev & Testing Script (Loadstring Ready)
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = {
	WalkSpeedBoost = 36,
	DefaultWalkSpeed = 16,
	TeleportCooldown = 1.2,
	Keywords = {
		Coal = {"coal", "فحم"},
		Island = {"island", "جزيرة", "جزر"},
		Lever = {"lever", "ليفر", "switch", "button"}
	},
	Colors = {
		Coal = Color3.fromRGB(110, 110, 110),
		Island = Color3.fromRGB(0, 220, 140),
		Lever = Color3.fromRGB(255, 200, 0)
	}
}

local State = {
	Speed = false,
	GodMode = false,
	ESP_Coal = false,
	ESP_Island = false,
	ESP_Lever = false,
	AutoTpCoal = false
}

local espFolder = playerGui:FindFirstChild("ItMoves_ESP")
if espFolder then
	espFolder:Destroy()
end
espFolder = Instance.new("Folder")
espFolder.Name = "ItMoves_ESP"
espFolder.Parent = playerGui

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function matchesCategory(instance, categoryName)
	local nameLower = string.lower(instance.Name)
	local list = Config.Keywords[categoryName]
	if not list then return false end

	for _, word in ipairs(list) do
		if string.find(nameLower, string.lower(word), 1, true) then
			return true
		end
	end

	local attrType = instance:GetAttribute("Type") or instance:GetAttribute("Category")
	if type(attrType) == "string" then
		for _, word in ipairs(list) do
			if string.lower(attrType) == string.lower(word) then
				return true
			end
		end
	end

	return false
end

local function getTargetPosition(obj)
	if obj:IsA("BasePart") then
		return obj.Position
	elseif obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart.Position
		end
		local part = obj:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end
	return nil
end

local function getAdornee(obj)
	if obj:IsA("BasePart") then
		return obj
	elseif obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function findItemsInCategory(categoryName)
	local results = {}
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if (desc:IsA("BasePart") or desc:IsA("Model")) and matchesCategory(desc, categoryName) then
			if getTargetPosition(desc) then
				table.insert(results, desc)
			end
		end
	end
	return results
end

-- نظام الـ ESP
local function clearESPByTag(tag)
	for _, child in ipairs(espFolder:GetChildren()) do
		if child:GetAttribute("EspTag") == tag then
			child:Destroy()
		end
	end
end

local function createEspForObject(obj, labelText, color, tag)
	local adornee = getAdornee(obj)
	if not adornee then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "Highlight_" .. obj.Name
	highlight.Adornee = obj
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = espFolder
	highlight:SetAttribute("EspTag", tag)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label_" .. obj.Name
	billboard.Adornee = adornee
	billboard.Size = UDim2.new(0, 120, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = espFolder
	billboard:SetAttribute("EspTag", tag)

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = labelText .. " [" .. obj.Name .. "]"
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 12
	textLabel.Parent = billboard
end

local function refreshESP(categoryName, enabled, labelPrefix)
	clearESPByTag(categoryName)
	if not enabled then return end

	local items = findItemsInCategory(categoryName)
	for _, item in ipairs(items) do
		createEspForObject(item, labelPrefix, Config.Colors[categoryName], categoryName)
	end
end

task.spawn(function()
	while true do
		task.wait(2.5)
		if State.ESP_Coal then refreshESP("Coal", true, "فحم") end
		if State.ESP_Island then refreshESP("Island", true, "جزيرة") end
		if State.ESP_Lever then refreshESP("Lever", true, "ليفر") end
	end
end)

-- حماية اللاعب من الوحش
local function applyGodModeProtection(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum.MaxHealth = math.huge
	hum.Health = hum.MaxHealth

	hum.HealthChanged:Connect(function(newHealth)
		if State.GodMode and newHealth < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
	end)
end

player.CharacterAdded:Connect(function(char)
	task.wait(0.25)
	if State.GodMode then
		applyGodModeProtection(char)
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and State.Speed then
		hum.WalkSpeed = Config.WalkSpeedBoost
	end
end)

-- تيليبورت الفحم (Toggle تلقائي + انتقال فوري عند التفعيل)
local coalIndex = 0
local function teleportNextCoal()
	local root = getRootPart()
	if not root then return end

	local coals = findItemsInCategory("Coal")
	if #coals == 0 then
		warn("لم يتم العثور على فحم بالأسماء المحددة في Config.Keywords.Coal")
		return
	end

	coalIndex = (coalIndex % #coals) + 1
	local pos = getTargetPosition(coals[coalIndex])
	if pos then
		root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	end
end

task.spawn(function()
	while true do
		task.wait(Config.TeleportCooldown)
		if State.AutoTpCoal then
			teleportNextCoal()
		end
	end
end)

-- حلقة السرعة والحماية
RunService.Heartbeat:Connect(function()
	local hum = getHumanoid()
	if not hum then return end

	if State.Speed then
		if hum.WalkSpeed ~= Config.WalkSpeedBoost then
			hum.WalkSpeed = Config.WalkSpeedBoost
		end
	else
		if hum.WalkSpeed == Config.WalkSpeedBoost then
			hum.WalkSpeed = Config.DefaultWalkSpeed
		end
	end

	if State.GodMode and hum.Health < hum.MaxHealth then
		hum.Health = hum.MaxHealth
	end
end)

-- بناء الواجهة
local oldGui = playerGui:FindFirstChild("ItMoves_DevPanel")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ItMoves_DevPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 340)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -45, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "IT MOVES | LOADSTRING PANEL"
titleLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -16, 0, 32)
tabsFrame.Position = UDim2.new(0, 8, 0, 44)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabsFrame

local pagesContainer = Instance.new("Frame")
pagesContainer.Size = UDim2.new(1, -16, 1, -86)
pagesContainer.Position = UDim2.new(0, 8, 0, 82)
pagesContainer.BackgroundTransparency = 1
pagesContainer.Parent = mainFrame

local pages = {}
local tabButtons = {}

local function createSectionPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "_Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.ScrollBarThickness = 4
	page.Visible = false
	page.Parent = pagesContainer

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = page

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 95, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(210, 215, 225)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Parent = tabsFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		for pName, pFrame in pairs(pages) do
			pFrame.Visible = (pName == name)
		end
		for tName, tBtn in pairs(tabButtons) do
			tBtn.BackgroundColor3 = (tName == name) and Color3.fromRGB(65, 120, 255) or Color3.fromRGB(40, 44, 56)
		end
	end)

	pages[name] = page
	tabButtons[name] = btn
	return page
end

local function addToggle(parent, text, getStateFn, setStateFn)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 38)
	btn.BackgroundColor3 = Color3.fromRGB(36, 40, 50)
	btn.Text = text .. ": OFF"
	btn.TextColor3 = Color3.fromRGB(235, 238, 245)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 13
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

	local function refreshVisual()
		local active = getStateFn()
		btn.Text = text .. (active and ": ON" or ": OFF")
		btn.BackgroundColor3 = active and Color3.fromRGB(35, 130, 85) or Color3.fromRGB(36, 40, 50)
	end

	btn.MouseButton1Click:Connect(function()
		setStateFn(not getStateFn())
		refreshVisual()
	end)

	refreshVisual()
end

local playerPage = createSectionPage("اللاعب")
local espPage = createSectionPage("ESP")
local tpPage = createSectionPage("تنقل")

pages["اللاعب"].Visible = true
tabButtons["اللاعب"].BackgroundColor3 = Color3.fromRGB(65, 120, 255)

addToggle(playerPage, "سرعة إضافية", function() return State.Speed end, function(v)
	State.Speed = v
end)

addToggle(playerPage, "حماية من الوحش", function() return State.GodMode end, function(v)
	State.GodMode = v
	if v and player.Character then
		applyGodModeProtection(player.Character)
	end
end)

addToggle(espPage, "ESP الفحم", function() return State.ESP_Coal end, function(v)
	State.ESP_Coal = v
	refreshESP("Coal", v, "فحم")
end)

addToggle(espPage, "ESP الجزر", function() return State.ESP_Island end, function(v)
	State.ESP_Island = v
	refreshESP("Island", v, "جزيرة")
end)

addToggle(espPage, "ESP الليفر", function() return State.ESP_Lever end, function(v)
	State.ESP_Lever = v
	refreshESP("Lever", v, "ليفر")
end)

addToggle(tpPage, "تيليبورت الفحم", function() return State.AutoTpCoal end, function(v)
	State.AutoTpCoal = v
	if v then
		teleportNextCoal()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = not screenGui.Enabled
end)
