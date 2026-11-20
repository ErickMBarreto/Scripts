-- ============================================================================
-- [MODULO: CORE_INIT]
-- ============================================================================
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pGui = player:WaitForChild("PlayerGui")

local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")

local function clearHoverConstraints(hrp)
    if not hrp then return end
    for _, name in ipairs({"RPGHoverBP", "RPGHoverGyro"}) do
        local c = hrp:FindFirstChild(name)
        if c then pcall(function() c:Destroy() end) end
    end
end

local function zeroPhysics(hrp, hum)
    if hrp and hrp:IsA("BasePart") then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum and hum:IsA("Humanoid") then
        pcall(function()
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            if hum.PlatformStand then hum.PlatformStand = false end
        end)
    end
end

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = newChar:WaitForChild("HumanoidRootPart")
    pcall(function() clearHoverConstraints(root) end)
end)

local parentUI = nil
pcall(function() if typeof(gethui) == "function" then parentUI = gethui() end end)
if not parentUI then pcall(function() parentUI = CoreGui end) end
if not parentUI then pcall(function() parentUI = pGui end) end

pcall(function()
    for _, name in ipairs({"RPGFruitFinderV4", "RPGFruitFinderV5", "RPGFruitFinderV6", "RPGHubV6", "RPGHubV7", "RPGHubV8", "RPGHubV9"}) do
        local old = parentUI:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

local function queueSelfForNextServer()
    local qot = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if typeof(qot) == "function" then
        pcall(function()
            qot('repeat task.wait() until game:IsLoaded(); if typeof(isfile) == "function" and isfile("RPGHub_V9.lua") then loadstring(readfile("RPGHub_V9.lua"))() end')
        end)
    end
end

queueSelfForNextServer()

-- ============================================================================
-- [MODULO: DATA_CATALOGS]
-- ============================================================================
local RARITY_LEVELS = {
    { id = 1, name = "All",       badge = "ALL",       desc = "Todas as frutas (Common+)",  color = Color3.fromRGB(148, 163, 184) },
    { id = 2, name = "Rare",      badge = "RARE+",     desc = "Ignora Kilo e Thorn",        color = Color3.fromRGB(59, 130, 246) },
    { id = 3, name = "Epic",      badge = "EPIC+",     desc = "Apenas 2.5% ou menor",       color = Color3.fromRGB(168, 85, 247) },
    { id = 4, name = "Legendary", badge = "LEGEND+",   desc = "Apenas 1.0% ou menor",       color = Color3.fromRGB(245, 158, 11) },
    { id = 5, name = "Mythical",  badge = "MYTHICAL",  desc = "Apenas 0.3% (Top Tier)",     color = Color3.fromRGB(244, 63, 94) }
}

local FRUIT_CATALOG = {
    ["kilo"]     = { tier = 1, tag = "COMMON",    color = Color3.fromRGB(156, 163, 175) },
    ["thorn"]    = { tier = 1, tag = "COMMON",    color = Color3.fromRGB(156, 163, 175) },
    ["haze"]     = { tier = 2, tag = "RARE",      color = Color3.fromRGB(59, 130, 246) },
    ["bomb"]     = { tier = 2, tag = "RARE",      color = Color3.fromRGB(59, 130, 246) },
    ["barrier"]  = { tier = 2, tag = "RARE",      color = Color3.fromRGB(59, 130, 246) },
    ["magma"]    = { tier = 3, tag = "EPIC",      color = Color3.fromRGB(168, 85, 247) },
    ["divide"]   = { tier = 3, tag = "EPIC",      color = Color3.fromRGB(168, 85, 247) },
    ["flame"]    = { tier = 3, tag = "EPIC",      color = Color3.fromRGB(168, 85, 247) },
    ["sand"]     = { tier = 3, tag = "EPIC",      color = Color3.fromRGB(168, 85, 247) },
    ["dark"]     = { tier = 4, tag = "LEGENDARY", color = Color3.fromRGB(245, 158, 11) },
    ["light"]    = { tier = 4, tag = "LEGENDARY", color = Color3.fromRGB(245, 158, 11) },
    ["mirror"]   = { tier = 4, tag = "LEGENDARY", color = Color3.fromRGB(245, 158, 11) },
    ["ice"]      = { tier = 4, tag = "LEGENDARY", color = Color3.fromRGB(245, 158, 11) },
    ["buddha"]   = { tier = 5, tag = "MYTHICAL",  color = Color3.fromRGB(244, 63, 94) },
    ["gravity"]  = { tier = 5, tag = "MYTHICAL",  color = Color3.fromRGB(244, 63, 94) },
    ["venom"]    = { tier = 5, tag = "MYTHICAL",  color = Color3.fromRGB(244, 63, 94) },
    ["rubber"]   = { tier = 4, tag = "SPECIAL",   color = Color3.fromRGB(245, 158, 11) },
    ["forest"]   = { tier = 5, tag = "MYTHICAL",  color = Color3.fromRGB(244, 63, 94) },
    ["operator"] = { tier = 5, tag = "MYTHICAL",  color = Color3.fromRGB(244, 63, 94) }
}

local function getFruitMeta(fruitName)
    local low = tostring(fruitName):lower()
    for key, meta in pairs(FRUIT_CATALOG) do
        if low:find(key) then return meta end
    end
    return { tier = 4, tag = "UNKNOWN", color = Color3.fromRGB(16, 185, 129) }
end

local ISLAND_SPAWNS = {
    ["Solmar Island"]    = Vector3.new(-143, 30, 325),
    ["Forbidden Island"] = Vector3.new(5685, 62, -4573),
    ["Circus Town"]      = Vector3.new(-7178, 38, -8762),
    ["Golden Dunes"]     = Vector3.new(-7136, 56, 10618),
    ["Frost Island"]     = Vector3.new(-17936, 158, 305),
    ["Skull Island"]     = Vector3.new(-6638, 42, 4343),
    ["Shark Park"]       = Vector3.new(781, 48, 5908),
    ["Rustfall"]         = Vector3.new(6646, 1348, 10718),
    ["Prison"]           = Vector3.new(10595, 40, 1038),
    ["Valoria Island"]   = Vector3.new(993, 38, -7704),
    ["Windhaven"]        = Vector3.new(6420, 3448, 10320),
    ["Neruvia"]          = Vector3.new(7688, 102, -13533),
    ["Marine Ford"]      = Vector3.new(-17643, 75, -10102),
    ["Volcano Island"]   = Vector3.new(-16600, 238, 9789)
}

local ISLAND_ORDER = {
    { name = "Solmar Island",    lv = "Lv 1+" },
    { name = "Forbidden Island", lv = "Lv 10+" },
    { name = "Circus Town",      lv = "Lv 45+" },
    { name = "Golden Dunes",     lv = "Lv 80+" },
    { name = "Frost Island",     lv = "Lv 115+" },
    { name = "Skull Island",     lv = "Lv 145+" },
    { name = "Shark Park",       lv = "Lv 150+" },
    { name = "Rustfall",         lv = "Lv 180+" },
    { name = "Prison",           lv = "Lv 230+" },
    { name = "Valoria Island",   lv = "Lv 260+" },
    { name = "Windhaven",        lv = "Lv 290+" },
    { name = "Neruvia",          lv = "Lv 325+" },
    { name = "Marine Ford",      lv = "Lv 370+" },
    { name = "Volcano Island",   lv = "Lv 415+" }
}

local GRIND_QUESTS = {
    { minLv = 1,   island = "Solmar Island",    quest = "Defeat Pirates" },
    { minLv = 5,   island = "Solmar Island",    quest = "Defeat Corrupt Marine" },
    { minLv = 10,  island = "Forbidden Island", quest = "Defeat Werewolfs" },
    { minLv = 20,  island = "Forbidden Island", quest = "Defeat Prime Werewolfs" },
    { minLv = 30,  island = "Forbidden Island", quest = "Free Old Friends" },
    { minLv = 45,  island = "Circus Town",      quest = "Defeat Bugg Pirates" },
    { minLv = 55,  island = "Circus Town",      quest = "Defeat Bugg Pirate Leader" },
    { minLv = 65,  island = "Circus Town",      quest = "Defeat The Clowns" },
    { minLv = 80,  island = "Golden Dunes",     quest = "Defeat Desert Outlaws" },
    { minLv = 90,  island = "Golden Dunes",     quest = "Defeat Desert Ruffians" },
    { minLv = 100, island = "Golden Dunes",     quest = "Defeat Narmers Guard" },
    { minLv = 115, island = "Frost Island",     quest = "Defeat Ice Vikings" },
    { minLv = 125, island = "Frost Island",     quest = "Defeat Cursed Armors" },
    { minLv = 135, island = "Frost Island",     quest = "Defeat Frost-Cursed" },
    { minLv = 145, island = "Skull Island",     quest = "Defeat Boars" },
    { minLv = 150, island = "Shark Park",       quest = "Defeat Sharkmen Patrollers" },
    { minLv = 160, island = "Shark Park",       quest = "Defeat Sharkmen Guards" },
    { minLv = 170, island = "Shark Park",       quest = "Defeat Sharkmen Apprentice" },
    { minLv = 180, island = "Rustfall",         quest = "Rustfall Quest 1" },
    { minLv = 195, island = "Rustfall",         quest = "Rustfall Quest 2" },
    { minLv = 210, island = "Rustfall",         quest = "Rustfall Quest 3" },
    { minLv = 230, island = "Prison",           quest = "Defeat Elite Prison Guards" },
    { minLv = 240, island = "Prison",           quest = "Defeat Ice Prison Guards" },
    { minLv = 250, island = "Prison",           quest = "Defeat Lava Prison Guards" },
    { minLv = 260, island = "Valoria Island",   quest = "Valoria Island Quest 1" },
    { minLv = 270, island = "Valoria Island",   quest = "Valoria Island Quest 2" },
    { minLv = 280, island = "Valoria Island",   quest = "Valoria Island Quest 3" },
    { minLv = 290, island = "Windhaven",        quest = "Windhaven Quest 1" },
    { minLv = 300, island = "Windhaven",        quest = "Windhaven Quest 2" },
    { minLv = 310, island = "Windhaven",        quest = "Windhaven Quest 3" },
    { minLv = 325, island = "Neruvia",          quest = "Neruvia Quest 1" },
    { minLv = 340, island = "Neruvia",          quest = "Neruvia Quest 2" },
    { minLv = 355, island = "Neruvia",          quest = "Neruvia Quest 3" },
    { minLv = 370, island = "Marine Ford",      quest = "Marine Ford Quest 1" },
    { minLv = 385, island = "Marine Ford",      quest = "Marine Ford Quest 2" },
    { minLv = 400, island = "Marine Ford",      quest = "Marine Ford Quest 3" },
    { minLv = 415, island = "Volcano Island",   quest = "Defeat Volcano Guards" },
    { minLv = 430, island = "Volcano Island",   quest = "Defeat Elite Volcano Guards" }
}

local function getPlayerLevel()
    local lv = player:GetAttribute("Level")
    if type(lv) == "number" then return lv end
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, obj in ipairs(ls:GetChildren()) do
            if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                local n = obj.Name:lower()
                if n:find("lv") or n:find("level") then
                    return obj.Value
                end
            end
        end
    end
    return nil
end

local function getQuestsRemote()
    local net = ReplicatedStorage:FindFirstChild("NetworkInstances")
    local re = net and net:FindFirstChild("RemoteEvents")
    return re and re:FindFirstChild("Quests")
end

local function findQuestGiverForIsland(islandName)
    local ignore = Workspace:FindFirstChild("IgnoreList")
    local intFolder = ignore and ignore:FindFirstChild("Int")
    local npcs = intFolder and intFolder:FindFirstChild("NPCs")
    local questsFolder = npcs and npcs:FindFirstChild("Quests")
    local grindingFolder = questsFolder and questsFolder:FindFirstChild("Grinding")
    if not grindingFolder then return nil end

    local islandFolder = grindingFolder:FindFirstChild(islandName)
    if not islandFolder then
        local lowTarget = islandName:lower()
        for _, child in ipairs(grindingFolder:GetChildren()) do
            if child.Name:lower():find(lowTarget, 1, true) or lowTarget:find(child.Name:lower(), 1, true) then
                islandFolder = child
                break
            end
        end
    end
    if not islandFolder then return nil end

    for _, npc in ipairs(islandFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
            if hrp then return npc, hrp end
        end
    end
    return nil
end

-- ============================================================================
-- [MODULO: STORAGE_UI]
-- ============================================================================
local CONFIG_FILE = "rpghub_config_" .. tostring(game.PlaceId) .. ".json"
local HISTORY_FILE = "rpghub_visited_" .. tostring(game.PlaceId) .. ".json"
local EXPIRE_SECONDS = 2400
local HOP_WAIT_SECONDS = 10.0

local settings = {
    esp = true,
    autoFruit = false,
    autoStore = true,
    tweenTravel = false,
    autoHop = false,
    autoPlayIntro = true,
    minRarityId = 2,
    autoGrind = false,
    autoAcceptQuest = true,
    autoAdvanceQuest = true,
    grindHeight = 7.0,
    questRepeatGoal = 5,
    savedQuestIndex = 1
}

pcall(function()
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(CONFIG_FILE) then
        local saved = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                if settings[k] ~= nil then settings[k] = v end
            end
        end
    end
end)

local function saveSettings()
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(CONFIG_FILE, HttpService:JSONEncode(settings))
        end
    end)
end

local function loadVisitedServers()
    local history = {}
    local now = os.time()
    pcall(function()
        if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(HISTORY_FILE) then
            local decoded = HttpService:JSONDecode(readfile(HISTORY_FILE))
            if type(decoded) == "table" then
                for jobId, ts in pairs(decoded) do
                    if (now - tonumber(ts)) < EXPIRE_SECONDS then
                        history[jobId] = ts
                    end
                end
            end
        end
    end)
    if game.JobId and game.JobId ~= "" then history[game.JobId] = now end
    return history
end

local function saveVisitedServers(history)
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(HISTORY_FILE, HttpService:JSONEncode(history))
        end
    end)
end

local function countTable(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

local visitedServers = loadVisitedServers()
saveVisitedServers(visitedServers)
local shortJobId = (game.JobId and #game.JobId >= 6) and string.sub(game.JobId, 1, 6) or "LOCAL"

local function clickGuiButton(btn)
    if not btn then return end
    pcall(function()
        if typeof(firesignal) == "function" and btn:IsA("GuiButton") then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
            firesignal(btn.Activated)
        end
    end)
    pcall(function()
        if typeof(getconnections) == "function" and btn:IsA("GuiButton") then
            for _, ev in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
                if btn[ev] then
                    for _, conn in ipairs(getconnections(btn[ev])) do
                        conn:Fire()
                    end
                end
            end
        end
    end)
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            local inset = GuiService:GetGuiInset()
            local cX = pos.X + (size.X / 2)
            local cY = pos.Y + (size.Y / 2) + inset.Y
            VirtualInputManager:SendMouseButtonEvent(cX, cY, 0, true, game, 1)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(cX, cY, 0, false, game, 1)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if settings.autoPlayIntro then
            local loadingGui = pGui:FindFirstChild("LoadingScreenUI")
            if loadingGui and loadingGui.Enabled then
                pcall(function()
                    local net = ReplicatedStorage:FindFirstChild("NetworkInstances")
                    local re = net and net:FindFirstChild("RemoteEvents")
                    if re then
                        if re:FindFirstChild("CutsceneSkip") then re.CutsceneSkip:FireServer() end
                        if re:FindFirstChild("StartGame") then re.StartGame:FireServer() end
                    end
                end)
                for _, desc in ipairs(loadingGui:GetDescendants()) do
                    if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                        clickGuiButton(desc)
                    end
                end
            end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RPGHubV9"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = parentUI

local C_BG = Color3.fromRGB(18, 20, 26)
local C_HEADER = Color3.fromRGB(24, 27, 36)
local C_CARD = Color3.fromRGB(26, 30, 40)
local C_BORDER = Color3.fromRGB(45, 50, 66)
local C_TEXT = Color3.fromRGB(240, 244, 248)
local C_MUTED = Color3.fromRGB(148, 156, 172)
local C_ACCENT = Color3.fromRGB(16, 185, 129)
local C_FRUIT = Color3.fromRGB(245, 158, 11)
local C_BLUE = Color3.fromRGB(59, 130, 246)
local C_RED = Color3.fromRGB(239, 68, 68)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 350, 0, 600)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -300)
MainFrame.BackgroundColor3 = C_BG
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = C_BORDER
MainStroke.Thickness = 1.5

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = C_HEADER
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.Text = string.format("RPG Hub v9.18  -  ID: %s", shortJobId)
Title.TextColor3 = C_TEXT
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 28, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.Text = "-"
MinBtn.TextColor3 = C_TEXT
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = C_RED
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(1, -20, 0, 32)
TabBar.Position = UDim2.new(0, 10, 0, 46)
TabBar.BackgroundTransparency = 1

local FruitTabBtn = Instance.new("TextButton", TabBar)
FruitTabBtn.Size = UDim2.new(0.32, 0, 1, 0)
FruitTabBtn.Text = "Frutas"
FruitTabBtn.Font = Enum.Font.GothamBold
FruitTabBtn.TextSize = 11
Instance.new("UICorner", FruitTabBtn).CornerRadius = UDim.new(0, 7)

local GrindTabBtn = Instance.new("TextButton", TabBar)
GrindTabBtn.Size = UDim2.new(0.32, 0, 1, 0)
GrindTabBtn.Position = UDim2.new(0.34, 0, 0, 0)
GrindTabBtn.Text = "Auto Grind"
GrindTabBtn.Font = Enum.Font.GothamBold
GrindTabBtn.TextSize = 11
Instance.new("UICorner", GrindTabBtn).CornerRadius = UDim.new(0, 7)

local IslandTabBtn = Instance.new("TextButton", TabBar)
IslandTabBtn.Size = UDim2.new(0.32, 0, 1, 0)
IslandTabBtn.Position = UDim2.new(0.68, 0, 0, 0)
IslandTabBtn.Text = "Ilhas (14)"
IslandTabBtn.Font = Enum.Font.GothamBold
IslandTabBtn.TextSize = 11
Instance.new("UICorner", IslandTabBtn).CornerRadius = UDim.new(0, 7)

local function makeScrollPage(vis)
    local p = Instance.new("ScrollingFrame", MainFrame)
    p.Size = UDim2.new(1, -20, 1, -126)
    p.Position = UDim2.new(0, 10, 0, 84)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = vis
    local lay = Instance.new("UIListLayout", p)
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    return p
end

local FruitPage = makeScrollPage(true)
local GrindPage = makeScrollPage(false)
local IslandPage = makeScrollPage(false)

local function selectTab(tabName)
    FruitPage.Visible = (tabName == "fruit")
    GrindPage.Visible = (tabName == "grind")
    IslandPage.Visible = (tabName == "island")
    FruitTabBtn.BackgroundColor3 = (tabName == "fruit") and C_ACCENT or C_CARD
    GrindTabBtn.BackgroundColor3 = (tabName == "grind") and C_BLUE or C_CARD
    IslandTabBtn.BackgroundColor3 = (tabName == "island") and C_FRUIT or C_CARD
end
selectTab("fruit")

FruitTabBtn.MouseButton1Click:Connect(function() selectTab("fruit") end)
GrindTabBtn.MouseButton1Click:Connect(function() selectTab("grind") end)
IslandTabBtn.MouseButton1Click:Connect(function() selectTab("island") end)

local StatusBox = Instance.new("Frame", MainFrame)
StatusBox.Size = UDim2.new(1, -20, 0, 34)
StatusBox.Position = UDim2.new(0, 10, 1, -40)
StatusBox.BackgroundColor3 = C_HEADER
Instance.new("UICorner", StatusBox).CornerRadius = UDim.new(0, 7)

local StatusLabel = Instance.new("TextLabel", StatusBox)
StatusLabel.Size = UDim2.new(1, -12, 1, 0)
StatusLabel.Position = UDim2.new(0, 6, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Pronto para operar na V9.18."
StatusLabel.TextColor3 = C_TEXT
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextWrapped = true

local FloatingIcon = Instance.new("TextButton", ScreenGui)
FloatingIcon.Size = UDim2.new(0, 48, 0, 48)
FloatingIcon.Position = UDim2.new(0.05, 0, 0.25, 0)
FloatingIcon.BackgroundColor3 = C_HEADER
FloatingIcon.Text = "🍎"
FloatingIcon.TextSize = 22
FloatingIcon.Visible = false
FloatingIcon.Active = true
FloatingIcon.Draggable = true
Instance.new("UICorner", FloatingIcon).CornerRadius = UDim.new(1, 0)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingIcon.Visible = true
end)
FloatingIcon.MouseButton1Click:Connect(function()
    FloatingIcon.Visible = false
    MainFrame.Visible = true
end)
CloseBtn.MouseButton1Click:Connect(function()
    clearHoverConstraints(root)
    ScreenGui:Destroy()
end)

local switchUpdaters = {}
local orderCounter = 0
local function nextOrder()
    orderCounter = orderCounter + 1
    return orderCounter
end

local function createToggleRow(parent, key, labelText, defaultState, callback)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder = nextOrder()
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = C_CARD
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -64, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = C_TEXT
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10.5
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -52, 0.5, -11)
    btn.Text = defaultState and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9.5
    btn.BackgroundColor3 = defaultState and C_ACCENT or Color3.fromRGB(60, 66, 80)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local st = defaultState
    local function setVisual(v)
        st = v
        btn.Text = st and "ON" or "OFF"
        btn.BackgroundColor3 = st and C_ACCENT or Color3.fromRGB(60, 66, 80)
    end
    if key then switchUpdaters[key] = setVisual end

    btn.MouseButton1Click:Connect(function()
        setVisual(not st)
        callback(st)
    end)
end

-- ============================================================================
-- [MODULO: MOVEMENT]
-- ============================================================================
local isTraveling = false
local isHopping = false
local isGrindingMob = false
local isQuestBusy = false
local questRunToken = 0
local islandSettleUntil = 0

local function isTokenValid(token)
    return token == questRunToken and ScreenGui and ScreenGui.Parent and root and root.Parent
end

local function settleAfterTouchdown(targetPos, lookAtPos, pauseSec, token)
    if not root or not targetPos then return end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local touchdownPos = targetPos + Vector3.new(0, 6, 0)
    local cf = lookAtPos and CFrame.lookAt(touchdownPos, Vector3.new(lookAtPos.X, touchdownPos.Y, lookAtPos.Z)) or CFrame.new(touchdownPos)

    pcall(function()
        root.CFrame = cf
        zeroPhysics(root, hum)
    end)

    local endAt = tick() + (pauseSec or 1.5)
    while tick() < endAt do
        if token and not isTokenValid(token) then break end
        if root and root.Parent then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        task.wait(0.15)
    end
end

local function moveRootToPosition(targetPos, labelDesc, token, isIslandJump)
    if not root or not targetPos then return end
    clearHoverConstraints(root)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local startPos = root.Position
    local dist = (targetPos - startPos).Magnitude
    if dist <= 6 then return end

    StatusLabel.Text = string.format("Aproximando de %s (%.0f studs)...", labelDesc or "destino", dist)

    if dist > 120 then
        local cruiseY = math.max(startPos.Y, targetPos.Y) + 90
        local climbPos = Vector3.new(startPos.X, cruiseY, startPos.Z)
        local cruiseTarget = Vector3.new(targetPos.X, cruiseY, targetPos.Z)

        local climbTw = TweenService:Create(root, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(climbPos)
        })
        climbTw:Play()
        climbTw.Completed:Wait()
        if token and not isTokenValid(token) then return end
        zeroPhysics(root, hum)

        local horizDist = (Vector3.new(cruiseTarget.X, 0, cruiseTarget.Z) - Vector3.new(climbPos.X, 0, climbPos.Z)).Magnitude
        local speed = settings.tweenTravel and 140 or 220
        local travelTime = math.clamp(horizDist / speed, 2.0, 25.0)

        local moveTw = TweenService:Create(root, TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
            CFrame = CFrame.new(cruiseTarget)
        })
        moveTw:Play()
        moveTw.Completed:Wait()
        if token and not isTokenValid(token) then return end
        zeroPhysics(root, hum)

        StatusLabel.Text = string.format("Aguardando antes de pousar em %s...", labelDesc or "destino")
        pcall(function() player:RequestStreamAroundAsync(targetPos) end)
        local preLandEnd = tick() + (isIslandJump and 1.6 or 0.7)
        while tick() < preLandEnd do
            if token and not isTokenValid(token) then return end
            zeroPhysics(root, hum)
            task.wait(0.15)
        end

        local dropPos = targetPos + Vector3.new(0, 8, 0)
        local dropTw = TweenService:Create(root, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
            CFrame = CFrame.new(dropPos)
        })
        dropTw:Play()
        dropTw.Completed:Wait()
        if token and not isTokenValid(token) then return end
    else
        pcall(function() player:RequestStreamAroundAsync(targetPos) end)
        local shortTime = math.clamp(dist / 90, 0.5, 1.8)
        local shortTw = TweenService:Create(root, TweenInfo.new(shortTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
        })
        shortTw:Play()
        shortTw.Completed:Wait()
        if token and not isTokenValid(token) then return end
    end

    settleAfterTouchdown(targetPos, nil, isIslandJump and 1.5 or 0.6, token)
end

local function travelToIslandByName(islandName)
    local spawnPos = ISLAND_SPAWNS[islandName]
    if not spawnPos or isTraveling or isQuestBusy then return false end
    questRunToken = questRunToken + 1
    local myToken = questRunToken

    isTraveling = true
    isQuestBusy = true
    isGrindingMob = false
    clearHoverConstraints(root)
    moveRootToPosition(spawnPos, islandName, myToken, true)
    if isTokenValid(myToken) then
        islandSettleUntil = tick() + 1.5
        StatusLabel.Text = "Assentado em " .. islandName
    end
    if myToken == questRunToken then
        isQuestBusy = false
        isTraveling = false
    end
    return true
end

-- ============================================================================
-- [MODULO: FRUIT_RADAR]
-- ============================================================================
local activeEspTags = {}
local hopEligibleTime = tick() + HOP_WAIT_SECONDS

createToggleRow(FruitPage, "autoPlayIntro", "Auto-Iniciar (Pular Intro)", settings.autoPlayIntro, function(v) settings.autoPlayIntro = v; saveSettings() end)
createToggleRow(FruitPage, "esp", "Radar Visual (ESP)", settings.esp, function(v)
    settings.esp = v
    saveSettings()
    for _, tag in pairs(activeEspTags) do
        if tag and tag.Parent then tag.Enabled = settings.esp end
    end
end)
createToggleRow(FruitPage, "autoFruit", "Coleta Automatica", settings.autoFruit, function(v) settings.autoFruit = v; saveSettings() end)
createToggleRow(FruitPage, "autoStore", "Auto-Store (Guardar)", settings.autoStore, function(v) settings.autoStore = v; saveSettings() end)
createToggleRow(FruitPage, "tweenTravel", "Voo Suave (Anti-Kick)", settings.tweenTravel, function(v) settings.tweenTravel = v; saveSettings() end)
createToggleRow(FruitPage, "autoHop", "Auto Server Hop (1-4P)", settings.autoHop, function(v)
    settings.autoHop = v
    if v then hopEligibleTime = math.max(hopEligibleTime, tick() + HOP_WAIT_SECONDS) end
    saveSettings()
end)

local RarityBtn = Instance.new("TextButton", FruitPage)
RarityBtn.LayoutOrder = nextOrder()
RarityBtn.Size = UDim2.new(1, 0, 0, 36)
RarityBtn.Font = Enum.Font.GothamBold
RarityBtn.TextSize = 10.5
RarityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", RarityBtn).CornerRadius = UDim.new(0, 7)

local function refreshRarityBtn()
    local cur = RARITY_LEVELS[settings.minRarityId] or RARITY_LEVELS[2]
    RarityBtn.Text = string.format("Raridade Alvo: %s (%s)", cur.badge, cur.desc)
    RarityBtn.BackgroundColor3 = cur.color
end
refreshRarityBtn()

RarityBtn.MouseButton1Click:Connect(function()
    settings.minRarityId = (settings.minRarityId % #RARITY_LEVELS) + 1
    saveSettings()
    refreshRarityBtn()
end)

local HopRow = Instance.new("Frame", FruitPage)
HopRow.LayoutOrder = nextOrder()
HopRow.Size = UDim2.new(1, 0, 0, 32)
HopRow.BackgroundTransparency = 1

local HopNowBtn = Instance.new("TextButton", HopRow)
HopNowBtn.Size = UDim2.new(0.76, 0, 1, 0)
HopNowBtn.Text = string.format("Novo Servidor (%d salvos)", countTable(visitedServers))
HopNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HopNowBtn.Font = Enum.Font.GothamBold
HopNowBtn.TextSize = 10
HopNowBtn.BackgroundColor3 = C_BLUE
Instance.new("UICorner", HopNowBtn).CornerRadius = UDim.new(0, 7)

local ClearHistBtn = Instance.new("TextButton", HopRow)
ClearHistBtn.Size = UDim2.new(0.21, 0, 1, 0)
ClearHistBtn.Position = UDim2.new(0.79, 0, 0, 0)
ClearHistBtn.Text = "Limpar"
ClearHistBtn.TextColor3 = C_TEXT
ClearHistBtn.Font = Enum.Font.GothamBold
ClearHistBtn.TextSize = 9.5
ClearHistBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", ClearHistBtn).CornerRadius = UDim.new(0, 7)

ClearHistBtn.MouseButton1Click:Connect(function()
    visitedServers = {[game.JobId] = os.time()}
    saveVisitedServers(visitedServers)
    HopNowBtn.Text = string.format("Novo Servidor (%d salvos)", countTable(visitedServers))
end)

local FruitScroll = Instance.new("ScrollingFrame", FruitPage)
FruitScroll.LayoutOrder = nextOrder()
FruitScroll.Size = UDim2.new(1, 0, 0, 100)
FruitScroll.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
FruitScroll.ScrollBarThickness = 3
FruitScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", FruitScroll).CornerRadius = UDim.new(0, 8)
local fLay = Instance.new("UIListLayout", FruitScroll)
fLay.Padding = UDim.new(0, 5)
fLay.SortOrder = Enum.SortOrder.LayoutOrder

local function executeServerHop()
    if isHopping or isTraveling or isQuestBusy then return end
    isHopping = true
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100", game.PlaceId)
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if ok and raw then
        local decOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if decOk and data and data.data then
            local pool = {}
            for _, srv in ipairs(data.data) do
                if srv.id and srv.id ~= game.JobId and not visitedServers[srv.id] and srv.playing and srv.playing <= 4 then
                    table.insert(pool, srv)
                end
            end
            if #pool > 0 then
                local chosen = pool[math.random(1, #pool)]
                visitedServers[chosen.id] = os.time()
                saveVisitedServers(visitedServers)
                TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen.id, player)
                return
            end
        end
    end
    isHopping = false
end

HopNowBtn.MouseButton1Click:Connect(executeServerHop)

-- ============================================================================
-- [MODULO: AUTO_GRIND]
-- ============================================================================
local currentQuestReps = 0
local lastQuestCompletedFlag = false
local selectedQuestIndex = math.clamp(tonumber(settings.savedQuestIndex) or 1, 1, #GRIND_QUESTS)
local lastQuestActionTime = 0

local function parseActiveQuest()
    local hasActiveQuest = false
    local pendingTargets = {}
    local allCompleted = false
    local repeatButtons = {}
    local questSummary = {}
    local activeTitle = ""

    pcall(function()
        local aq = pGui:FindFirstChild("ScreenGuis")
            and pGui.ScreenGuis:FindFirstChild("MainUI")
            and pGui.ScreenGuis.MainUI:FindFirstChild("ProgressHUD")
            and pGui.ScreenGuis.MainUI.ProgressHUD:FindFirstChild("ActiveQuest")
        if aq and aq.Visible then
            hasActiveQuest = true
            local repBox = aq:FindFirstChild("Container") and aq.Container:FindFirstChild("RepeatQuest")
            if repBox and repBox.Visible then
                for _, child in ipairs(repBox:GetDescendants()) do
                    if child:IsA("GuiButton") and child.Visible then
                        table.insert(repeatButtons, child)
                    end
                end
            end
            for _, desc in ipairs(aq:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                    local txt = desc.Text
                    if desc.Name == "Title" and txt ~= "REPEAT QUEST" then activeTitle = txt end
                    local mobName, curStr, maxStr = txt:match("^Defeat%s+(.+):%s*(%d+)%s*/%s*(%d+)$")
                        or txt:match("^([^:]+):%s*(%d+)%s*/%s*(%d+)$")
                    if mobName and curStr and maxStr then
                        local cVal = tonumber(curStr) or 0
                        local mVal = tonumber(maxStr) or 1
                        table.insert(questSummary, string.format("%s (%d/%d)", mobName, cVal, mVal))
                        if cVal < mVal then table.insert(pendingTargets, mobName:lower()) end
                    end
                end
            end
            if (#repeatButtons > 0 and #pendingTargets == 0) or (#questSummary > 0 and #pendingTargets == 0) then
                allCompleted = true
            end
        end
    end)
    return hasActiveQuest, pendingTargets, allCompleted, repeatButtons, questSummary, activeTitle
end

local function isMobAlive(mob)
    if not mob or not mob.Parent then return false end
    if mob:GetAttribute("Dead") == true then return false end
    local hrp = mob:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return false end
    local head = mob:FindFirstChild("Head")
    if head and head:IsA("BasePart") and head.Transparency >= 0.9 then return false end
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if hum then
        local hHP = hum:GetAttribute("HandlerHealth")
        if type(hHP) == "number" and hHP <= 0 then return false end
    end
    return true
end

local function mobMatchesTargetList(mob, pendingTargets)
    if #pendingTargets == 0 then return true end
    local cands = {
        tostring(mob:GetAttribute("OriginalName") or ""):lower(),
        tostring(mob:GetAttribute("AlternativeName") or ""):lower(),
        mob.Name:lower()
    }
    for _, tKey in ipairs(pendingTargets) do
        for _, c in ipairs(cands) do
            if c ~= "" and (c:find(tKey, 1, true) or tKey:find(c, 1, true)) then return true end
        end
    end
    return false
end

local function findBestGrindMob(pendingTargets, islandAnchorPos, allowAnyInIsland)
    local enemys = Workspace:FindFirstChild("Playability") and Workspace.Playability:FindFirstChild("Enemys")
    if not enemys or not root then return nil end
    local bestMob, bestScore = nil, math.huge
    for _, mob in ipairs(enemys:GetChildren()) do
        if isMobAlive(mob) and (allowAnyInIsland or mobMatchesTargetList(mob, pendingTargets)) then
            local hrp = mob:FindFirstChild("HumanoidRootPart")
            local distIsl = islandAnchorPos and (hrp.Position - islandAnchorPos).Magnitude or 0
            if not islandAnchorPos or distIsl <= 3000 then
                local dist = (hrp.Position - root.Position).Magnitude
                local bonus = (mob:GetAttribute("Render") == true) and -400 or 0
                local score = dist + bonus
                if score < bestScore then
                    bestScore = score
                    bestMob = mob
                end
            end
        end
    end
    return bestMob
end

local function equipCombatTool()
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and not t.Name:lower():find("fruit") then return t end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not t.Name:lower():find("fruit") then
                hum:EquipTool(t)
                task.wait(0.15)
                return t
            end
        end
    end
    return nil
end

local function triggerCombatAttack(equippedTool, targetMob)
    pcall(function()
        if equippedTool and equippedTool.Parent == char then equippedTool:Activate() end
    end)
    pcall(function()
        local combatRE = ReplicatedStorage:FindFirstChild("NetworkInstances")
            and ReplicatedStorage.NetworkInstances:FindFirstChild("RemoteEvents")
            and ReplicatedStorage.NetworkInstances.RemoteEvents:FindFirstChild("CombatTools")
        if combatRE and combatRE:IsA("RemoteEvent") then
            combatRE:FireServer(targetMob)
        end
    end)
end

local function applyHoverLock(hrp, hoverOffsetY)
    if not root or not hrp then return nil end
    local lockedPos = hrp.Position + Vector3.new(0, hoverOffsetY, 0)
    local lookCf = CFrame.lookAt(lockedPos, hrp.Position)
    root.CFrame = lookCf
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    local bp = root:FindFirstChild("RPGHoverBP")
    if not bp then
        bp = Instance.new("BodyPosition")
        bp.Name = "RPGHoverBP"
        bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bp.P = 15000
        bp.D = 1200
        bp.Parent = root
    end
    bp.Position = lockedPos

    local bg = root:FindFirstChild("RPGHoverGyro")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "RPGHoverGyro"
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.P = 15000
        bg.D = 500
        bg.Parent = root
    end
    bg.CFrame = lookCf
    return lockedPos
end

local function engageGrindTarget(targetMob)
    if not targetMob or not root then return end
    local hrp = targetMob:FindFirstChild("HumanoidRootPart")
    local hum = targetMob:FindFirstChildOfClass("Humanoid")
    if not hrp or not hrp.Parent then return end

    local mLabel = tostring(targetMob:GetAttribute("OriginalName") or targetMob.Name)
    if (hrp.Position - root.Position).Magnitude > 45 then
        isTraveling = true
        moveRootToPosition(hrp.Position + Vector3.new(0, settings.grindHeight, 0), mLabel, nil, false)
        isTraveling = false
    end

    if isTraveling or isQuestBusy or not hrp.Parent or not isMobAlive(targetMob) then return end

    isGrindingMob = true
    local lockedPos = applyHoverLock(hrp, settings.grindHeight)
    local tool = equipCombatTool()

    while settings.autoGrind and not isTraveling and not isQuestBusy and isMobAlive(targetMob) and hrp.Parent do
        local _, pTargetsNow, cNow = parseActiveQuest()
        if cNow and #pTargetsNow == 0 then break end

        local des = hrp.Position + Vector3.new(0, settings.grindHeight, 0)
        if not lockedPos or (des - lockedPos).Magnitude > 4.5 then
            lockedPos = applyHoverLock(hrp, settings.grindHeight)
        end

        local hHP = hum and hum:GetAttribute("HandlerHealth")
        StatusLabel.Text = type(hHP) == "number"
            and string.format("Travado em %s [HP: %.0f]...", mLabel, math.max(0, hHP))
            or string.format("Travado em %s...", mLabel)

        if not tool or tool.Parent ~= char then tool = equipCombatTool() end
        triggerCombatAttack(tool, targetMob)
        task.wait(0.25)
    end

    clearHoverConstraints(root)
    isGrindingMob = false
end

createToggleRow(GrindPage, "autoGrind", "Auto-Farm de Inimigos", settings.autoGrind, function(v)
    settings.autoGrind = v
    if not v then
        questRunToken = questRunToken + 1
        isQuestBusy = false
        isTraveling = false
        isGrindingMob = false
        if root then clearHoverConstraints(root) end
    end
    saveSettings()
end)
createToggleRow(GrindPage, "autoAcceptQuest", "Auto-Aceitar & Repetir", settings.autoAcceptQuest, function(v) settings.autoAcceptQuest = v; saveSettings() end)
createToggleRow(GrindPage, "autoAdvanceQuest", "Auto-Trocar Missao (Ciclo)", settings.autoAdvanceQuest, function(v) settings.autoAdvanceQuest = v; saveSettings() end)

local SelCard = Instance.new("Frame", GrindPage)
SelCard.LayoutOrder = nextOrder()
SelCard.Size = UDim2.new(1, 0, 0, 76)
SelCard.BackgroundColor3 = C_CARD
Instance.new("UICorner", SelCard).CornerRadius = UDim.new(0, 8)

local SelTitle = Instance.new("TextLabel", SelCard)
SelTitle.Size = UDim2.new(1, -88, 0, 18)
SelTitle.Position = UDim2.new(0, 10, 0, 4)
SelTitle.BackgroundTransparency = 1
SelTitle.TextColor3 = C_TEXT
SelTitle.Font = Enum.Font.GothamBold
SelTitle.TextSize = 10.5
SelTitle.TextXAlignment = Enum.TextXAlignment.Left

local SelSub = Instance.new("TextLabel", SelCard)
SelSub.Size = UDim2.new(1, -88, 0, 15)
SelSub.Position = UDim2.new(0, 10, 0, 22)
SelSub.BackgroundTransparency = 1
SelSub.TextColor3 = C_MUTED
SelSub.Font = Enum.Font.Gotham
SelSub.TextSize = 9.5
SelSub.TextXAlignment = Enum.TextXAlignment.Left

local PrevBtn = Instance.new("TextButton", SelCard)
PrevBtn.Size = UDim2.new(0, 32, 0, 26)
PrevBtn.Position = UDim2.new(1, -74, 0, 8)
PrevBtn.Text = "<"
PrevBtn.TextColor3 = C_TEXT
PrevBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", PrevBtn).CornerRadius = UDim.new(0, 6)

local NextBtn = Instance.new("TextButton", SelCard)
NextBtn.Size = UDim2.new(0, 32, 0, 26)
NextBtn.Position = UDim2.new(1, -38, 0, 8)
NextBtn.Text = ">"
NextBtn.TextColor3 = C_TEXT
NextBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", NextBtn).CornerRadius = UDim.new(0, 6)

local StartBtn = Instance.new("TextButton", SelCard)
StartBtn.Size = UDim2.new(1, -16, 0, 26)
StartBtn.Position = UDim2.new(0, 8, 1, -32)
StartBtn.Text = "Iniciar Nesta Missao"
StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartBtn.Font = Enum.Font.GothamBold
StartBtn.TextSize = 10.5
StartBtn.BackgroundColor3 = C_ACCENT
Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 6)

local function refreshSelUI()
    local q = GRIND_QUESTS[selectedQuestIndex] or GRIND_QUESTS[1]
    SelTitle.Text = string.format("[%d/%d] %s", selectedQuestIndex, #GRIND_QUESTS, q.quest)
    SelSub.Text = string.format("%s (Lv %d+)", q.island, q.minLv)
end
refreshSelUI()

local function travelAndAcceptQuest(qEntry, abandonFirst)
    if not qEntry or not root or isQuestBusy then return end
    questRunToken = questRunToken + 1
    local myToken = questRunToken

    isQuestBusy = true
    isTraveling = true
    isGrindingMob = false
    clearHoverConstraints(root)

    local qRemote = getQuestsRemote()
    if abandonFirst and qRemote then
        pcall(function() qRemote:FireServer("Abandon") end)
        task.wait(0.35)
        if not isTokenValid(myToken) then return end
    end

    local _, npcHrp = findQuestGiverForIsland(qEntry.island)
    if not npcHrp and ISLAND_SPAWNS[qEntry.island] then
        moveRootToPosition(ISLAND_SPAWNS[qEntry.island], qEntry.island, myToken, true)
        if not isTokenValid(myToken) then return end
        _, npcHrp = findQuestGiverForIsland(qEntry.island)
    end

    local standPos = root.Position
    local lookTarget = npcHrp and npcHrp.Position or nil
    if npcHrp then
        standPos = npcHrp.Position + (npcHrp.CFrame.LookVector * 3.5) + Vector3.new(0, 1.5, 0)
        if (standPos - root.Position).Magnitude > 4 then
            moveRootToPosition(standPos, qEntry.island .. " NPC", myToken, false)
            if not isTokenValid(myToken) then return end
        end
    end

    StatusLabel.Text = string.format("Aguardando NPC (%s) - 2s...", qEntry.quest)
    settleAfterTouchdown(standPos, lookTarget, 1.1, myToken)
    if not isTokenValid(myToken) then return end

    if qRemote then
        StatusLabel.Text = "Aceitando nova missao: " .. qEntry.quest
        pcall(function() qRemote:FireServer("AcceptGrinding", qEntry.quest) end)
    end

    settleAfterTouchdown(standPos, lookTarget, 1.0, myToken)
    if not isTokenValid(myToken) then return end

    islandSettleUntil = tick() + 0.8
    if myToken == questRunToken then
        isTraveling = false
        isQuestBusy = false
    end
end

PrevBtn.MouseButton1Click:Connect(function()
    selectedQuestIndex = (selectedQuestIndex - 2) % #GRIND_QUESTS + 1
    settings.savedQuestIndex = selectedQuestIndex
    saveSettings()
    currentQuestReps = 0
    refreshSelUI()
end)

NextBtn.MouseButton1Click:Connect(function()
    selectedQuestIndex = (selectedQuestIndex % #GRIND_QUESTS) + 1
    settings.savedQuestIndex = selectedQuestIndex
    saveSettings()
    currentQuestReps = 0
    refreshSelUI()
end)

StartBtn.MouseButton1Click:Connect(function()
    if isQuestBusy then return end
    currentQuestReps = 0
    settings.savedQuestIndex = selectedQuestIndex
    settings.autoGrind = true
    if switchUpdaters["autoGrind"] then switchUpdaters["autoGrind"](true) end
    saveSettings()
    task.spawn(function() travelAndAcceptQuest(GRIND_QUESTS[selectedQuestIndex], true) end)
end)

local OptRow = Instance.new("Frame", GrindPage)
OptRow.LayoutOrder = nextOrder()
OptRow.Size = UDim2.new(1, 0, 0, 34)
OptRow.BackgroundTransparency = 1

local RepBtn = Instance.new("TextButton", OptRow)
RepBtn.Size = UDim2.new(0.49, 0, 1, 0)
RepBtn.BackgroundColor3 = C_CARD
RepBtn.TextColor3 = C_ACCENT
RepBtn.Font = Enum.Font.GothamBold
RepBtn.TextSize = 10
Instance.new("UICorner", RepBtn).CornerRadius = UDim.new(0, 7)

local HeiBtn = Instance.new("TextButton", OptRow)
HeiBtn.Size = UDim2.new(0.49, 0, 1, 0)
HeiBtn.Position = UDim2.new(0.51, 0, 0, 0)
HeiBtn.BackgroundColor3 = C_CARD
HeiBtn.TextColor3 = C_BLUE
HeiBtn.Font = Enum.Font.GothamBold
HeiBtn.TextSize = 10
Instance.new("UICorner", HeiBtn).CornerRadius = UDim.new(0, 7)

local repPresets = { 3, 5, 10 }
local repIdx = 2
for i, r in ipairs(repPresets) do if r == settings.questRepeatGoal then repIdx = i end end
local function refreshRepBtn()
    settings.questRepeatGoal = repPresets[repIdx]
    RepBtn.Text = string.format("Meta: %dx / Missao", settings.questRepeatGoal)
end
refreshRepBtn()
RepBtn.MouseButton1Click:Connect(function()
    repIdx = (repIdx % #repPresets) + 1
    refreshRepBtn()
    saveSettings()
end)

local heightPresets = { 5.0, 7.0, 9.0 }
local heightIdx = 2
for i, h in ipairs(heightPresets) do if math.abs(h - settings.grindHeight) < 0.2 then heightIdx = i end end
local function refreshHeiBtn()
    settings.grindHeight = heightPresets[heightIdx]
    HeiBtn.Text = string.format("Altura: %.0f studs", settings.grindHeight)
end
refreshHeiBtn()
HeiBtn.MouseButton1Click:Connect(function()
    heightIdx = (heightIdx % #heightPresets) + 1
    refreshHeiBtn()
    saveSettings()
end)

local ProgCard = Instance.new("Frame", GrindPage)
ProgCard.LayoutOrder = nextOrder()
ProgCard.Size = UDim2.new(1, 0, 0, 82)
ProgCard.BackgroundColor3 = C_CARD
Instance.new("UICorner", ProgCard).CornerRadius = UDim.new(0, 8)

local ProgLabel = Instance.new("TextLabel", ProgCard)
ProgLabel.Size = UDim2.new(1, -14, 1, -8)
ProgLabel.Position = UDim2.new(0, 7, 0, 4)
ProgLabel.BackgroundTransparency = 1
ProgLabel.Text = "Aguardando inicio..."
ProgLabel.TextColor3 = C_TEXT
ProgLabel.Font = Enum.Font.Gotham
ProgLabel.TextSize = 9.5
ProgLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgLabel.TextYAlignment = Enum.TextYAlignment.Top
ProgLabel.TextWrapped = true

for _, isl in ipairs(ISLAND_ORDER) do
    local r = Instance.new("Frame", IslandPage)
    r.LayoutOrder = nextOrder()
    r.Size = UDim2.new(1, 0, 0, 34)
    r.BackgroundColor3 = C_CARD
    Instance.new("UICorner", r).CornerRadius = UDim.new(0, 7)

    local l = Instance.new("TextLabel", r)
    l.Size = UDim2.new(1, -80, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = string.format("%s (%s)", isl.name, isl.lv)
    l.TextColor3 = C_TEXT
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left

    local b = Instance.new("TextButton", r)
    b.Size = UDim2.new(0, 64, 0, 22)
    b.Position = UDim2.new(1, -70, 0.5, -11)
    b.Text = "Ir Agora"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 9.5
    b.BackgroundColor3 = C_BLUE
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function()
        if not isTraveling and not isQuestBusy then
            task.spawn(function() travelToIslandByName(isl.name) end)
        end
    end)
end

task.spawn(function()
    if not char then char = player.CharacterAdded:Wait() end
    root = char:WaitForChild("HumanoidRootPart")
    Workspace:WaitForChild("Playability", 15)

    while ScreenGui and ScreenGui.Parent do
        local hasAQ, pTargets, allComp, repBtns, qSum, aTitle = parseActiveQuest()
        local lv = getPlayerLevel()
        local qEntry = GRIND_QUESTS[selectedQuestIndex] or GRIND_QUESTS[1]
        ProgLabel.Text = string.format("[%s] %s\nCiclo: %d/%d | Lv: %s",
            aTitle ~= "" and aTitle or qEntry.quest,
            #qSum > 0 and table.concat(qSum, " | ") or "Sem objetivo ativo",
            currentQuestReps, settings.questRepeatGoal, lv and tostring(lv) or "?")

        if settings.autoGrind and not isTraveling and not isGrindingMob and not isQuestBusy and root and tick() >= islandSettleUntil then
            local qRemote = getQuestsRemote()
            if allComp and not lastQuestCompletedFlag then
                lastQuestCompletedFlag = true
                currentQuestReps = currentQuestReps + 1
            elseif not allComp then
                lastQuestCompletedFlag = false
            end

            local triggeredQuestAction = false
            if settings.autoAcceptQuest and qRemote then
                if not hasAQ and (tick() - lastQuestActionTime) > 2.2 then
                    lastQuestActionTime = tick()
                    triggeredQuestAction = true
                    travelAndAcceptQuest(qEntry, false)
                elseif allComp and (tick() - lastQuestActionTime) > 1.3 then
                    lastQuestActionTime = tick()
                    triggeredQuestAction = true
                    if settings.autoAdvanceQuest and currentQuestReps >= settings.questRepeatGoal then
                        currentQuestReps = 0
                        lastQuestCompletedFlag = false
                        if selectedQuestIndex < #GRIND_QUESTS then
                            selectedQuestIndex = selectedQuestIndex + 1
                            settings.savedQuestIndex = selectedQuestIndex
                            saveSettings()
                            refreshSelUI()
                        end
                        travelAndAcceptQuest(GRIND_QUESTS[selectedQuestIndex], true)
                    else
                        pcall(function() qRemote:FireServer("Repeat") end)
                        for _, btn in ipairs(repeatButtons) do clickGuiButton(btn) end
                        task.wait(0.35)
                        lastQuestCompletedFlag = false
                    end
                end
            end

            if not triggeredQuestAction and not isTraveling and not isQuestBusy then
                local islSpawn = ISLAND_SPAWNS[qEntry.island]
                local targetMob = findBestGrindMob(pTargets, islSpawn, false) or findBestGrindMob(pTargets, islSpawn, true)

                if not targetMob and islSpawn and (islSpawn - root.Position).Magnitude > 120 then
                    isTraveling = true
                    moveRootToPosition(islSpawn, qEntry.island, nil, false)
                    isTraveling = false
                    targetMob = findBestGrindMob(pTargets, islSpawn, false) or findBestGrindMob(pTargets, islSpawn, true)
                end

                if targetMob then
                    engageGrindTarget(targetMob)
                else
                    clearHoverConstraints(root)
                    StatusLabel.Text = "Aguardando respawn em " .. qEntry.island .. "..."
                end
            end
        end
        task.wait(0.35)
    end
end)

