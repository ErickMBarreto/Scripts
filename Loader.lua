-- main.lua (v9.2 - Correção de Referência de Character/Root, ESP e Aproximação de NPC)
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pGui = player:WaitForChild("PlayerGui")

local function getRoot()
    local c = player.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChildWhichIsA("BasePart")
end

local parentUI = nil
pcall(function() if typeof(gethui) == "function" then parentUI = gethui() end end)
if not parentUI then pcall(function() parentUI = CoreGui end) end
if not parentUI then pcall(function() parentUI = pGui end) end

pcall(function()
    for _, name in ipairs({"RPGFruitFinderV4", "RPGFruitFinderV5", "UnifiedModularHubV6", "UnifiedModularHubV7", "IsolatedGrindV88", "GitSingleHubV9", "FullGitHubV91", "FullGitHubV92"}) do
        local old = parentUI:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

-- ============================================================================
-- 1. CORE, CONFIGURAÇÕES & PERSISTÊNCIA
-- ============================================================================
local Core = {}
local CONFIG_FILE = "ff_config_" .. tostring(game.PlaceId) .. ".json"
local HISTORY_FILE = "ff_visited_" .. tostring(game.PlaceId) .. ".json"
local ISLAND_FILE = "ff_islands_" .. tostring(game.PlaceId) .. ".json"
local EXPIRE_SECONDS = 2400
local HOP_WAIT_SECONDS = 10.0

Core.State = {
    busyWithFruit = false,
    busyWithGrind = false,
    isHopping = false,
    isTravelingIsland = false,
    hopEligibleTime = tick() + HOP_WAIT_SECONDS
}

Core.Settings = {
    esp = true,
    autoFruit = false,
    autoStore = true,
    tweenTravel = false,
    autoHop = false,
    autoPlayIntro = true,
    minRarityId = 2,
    autoGrind = false,
    autoAcceptQuest = true,
    autoRepeatQuest = true,
    grindDistance = 5,
    currentQuestIndex = 3,
    repeatsPerQuest = 10,
    currentQuestDoneCount = 0
}

pcall(function()
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(CONFIG_FILE) then
        local saved = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                if Core.Settings[k] ~= nil then Core.Settings[k] = v end
            end
        end
    end
end)
Core.Settings.currentQuestDoneCount = 0

function Core.SaveSettings()
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(CONFIG_FILE, HttpService:JSONEncode(Core.Settings))
        end
    end)
end

Core.IslandCache = {}
pcall(function()
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(ISLAND_FILE) then
        local dec = HttpService:JSONDecode(readfile(ISLAND_FILE))
        if type(dec) == "table" then
            for k, v in pairs(dec) do
                if type(v) == "table" and v.x and v.y and v.z then
                    Core.IslandCache[k] = Vector3.new(v.x, v.y, v.z)
                end
            end
        end
    end
end)

function Core.SaveIsland(name, pos)
    if not name or not pos then return end
    Core.IslandCache[name] = pos
    pcall(function()
        if typeof(writefile) == "function" then
            local out = {}
            for k, v in pairs(Core.IslandCache) do
                out[k] = { x = v.X, y = v.Y, z = v.Z }
            end
            writefile(ISLAND_FILE, HttpService:JSONEncode(out))
        end
    end)
end

function Core.ClickButton(btn)
    if not btn then return end
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, ev in ipairs({"MouseButton1Click", "Activated"}) do
                if btn[ev] then
                    for _, conn in ipairs(getconnections(btn[ev])) do
                        conn:Fire()
                    end
                end
            end
        end
    end)
end

function Core.MoveToPosition(targetPos, speedStudsPerSec)
    local root = getRoot()
    if not root or not targetPos then return end
    speedStudsPerSec = speedStudsPerSec or 300

    if Core.Settings.tweenTravel then
        local highStart = Vector3.new(root.Position.X, math.max(root.Position.Y, targetPos.Y) + 70, root.Position.Z)
        local highDest = Vector3.new(targetPos.X, highStart.Y, targetPos.Z)
        root.CFrame = CFrame.new(highStart)
        local dist = (highDest - highStart).Magnitude
        local duration = math.clamp(dist / speedStudsPerSec, 0.25, 10.0)

        local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(highDest)})
        tween:Play()
        tween.Completed:Wait()
    end

    root.CFrame = CFrame.new(targetPos)
    root.AssemblyLinearVelocity = Vector3.zero
end

function Core.SafeIslandTravel(targetPos, onProgress)
    local root = getRoot()
    if not root or not targetPos or Core.State.isTravelingIsland then return false end
    Core.State.isTravelingIsland = true

    local safeAltitude = 380
    local cruiseSpeed = 190

    local startAir = Vector3.new(root.Position.X, safeAltitude, root.Position.Z)
    local upTween = TweenService:Create(root, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(startAir)
    })
    upTween:Play()
    upTween.Completed:Wait()

    local destAir = Vector3.new(targetPos.X, safeAltitude, targetPos.Z)
    local horizontalDist = (destAir - startAir).Magnitude
    local travelTime = math.clamp(horizontalDist / cruiseSpeed, 0.8, 45.0)

    if onProgress then
        onProgress(string.format("Voando p/ ilha (%.0f studs • ~%.0fs)...", horizontalDist, travelTime))
    end

    local flightTween = TweenService:Create(root, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(destAir)
    })
    flightTween:Play()
    flightTween.Completed:Wait()

    local landTween = TweenService:Create(root, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    })
    landTween:Play()
    landTween.Completed:Wait()

    root.AssemblyLinearVelocity = Vector3.zero
    Core.State.isTravelingIsland = false
    return true
end

-- ============================================================================
-- 2. BANCO DE DADOS DAS 38 MISSÕES & RARIDADES DE FRUTAS
-- ============================================================================
local QUEST_ROADMAP = {
    { id = 1,  island = "Solmar Island",    title = "Defeat Pirates",             minLvl = 1,   giver = "Solmar Island Quest Giver",    mobs = {"Cutlass Pirate", "Flint Pirate"} },
    { id = 2,  island = "Solmar Island",    title = "Defeat Corrupt Marine",      minLvl = 5,   giver = "Solmar Island Quest Giver",    mobs = {"Marine Recruit", "Marine Corporal"} },
    { id = 3,  island = "Forbidden Island", title = "Defeat Werewolfs",           minLvl = 10,  giver = "Forbidden Island Quest Giver", mobs = {"Werewolf", "Fierce Werewolf"} },
    { id = 4,  island = "Forbidden Island", title = "Defeat Prime Werewolfs",     minLvl = 20,  giver = "Forbidden Island Quest Giver", mobs = {"Prime Werewolf", "Werewolf"} },
    { id = 5,  island = "Forbidden Island", title = "Free Old Friends",           minLvl = 30,  giver = "Forbidden Island Quest Giver", mobs = {"Corrupted Hunter", "Corrupted Veteran Hunter"} },
    { id = 6,  island = "Circus Town",      title = "Defeat Jester Pirates",      minLvl = 45,  giver = "Circus Town Quest Giver",      mobs = {"Jester Cutlass Pirate", "Jester Flint Pirate"} },
    { id = 7,  island = "Circus Town",      title = "Defeat Jester Pirate Leader",minLvl = 55,  giver = "Circus Town Quest Giver",      mobs = {"Jester Elite Cutlass Pirate", "Jester Musket Pirate"} },
    { id = 8,  island = "Circus Town",      title = "Defeat The Clowns",          minLvl = 65,  giver = "Circus Town Quest Giver",      mobs = {"Dual Katana Clown", "Flint Clown", "Bomb Clown"} },
    { id = 9,  island = "Golden Dunes",     title = "Defeat Desert Outlaws",      minLvl = 80,  giver = "Golden Dunes Quest Giver",     mobs = {"Desert Outlaw"} },
    { id = 10, island = "Golden Dunes",     title = "Defeat Desert Ruffians",     minLvl = 90,  giver = "Golden Dunes Quest Giver",     mobs = {"Desert Ruffian", "Flint Desert Ruffian"} },
    { id = 11, island = "Golden Dunes",     title = "Defeat Narmers Guard",       minLvl = 100, giver = "Golden Dunes Quest Giver",     mobs = {"Sword Narmers Guard", "Dual Sword Narmers Guard"} },
    { id = 12, island = "Frost Island",     title = "Defeat Ice Vikings",         minLvl = 115, giver = "Frost Island Quest Giver",     mobs = {"Viking Warrior", "Old Viking Warrior"} },
    { id = 13, island = "Frost Island",     title = "Defeat Cursed Armors",       minLvl = 125, giver = "Frost Island Quest Giver",     mobs = {"Haunted Knight", "Doomed Armor"} },
    { id = 14, island = "Frost Island",     title = "Defeat Frost-Cursed",        minLvl = 135, giver = "Frost Island Quest Giver",     mobs = {"Frozen Viking Warrior", "Frozen Haunted Knight"} },
    { id = 15, island = "Skull Island",     title = "Defeat Boars",               minLvl = 145, giver = "Skull Island Quest Giver",     mobs = {"Boar"} },
    { id = 16, island = "Shark Park",       title = "Defeat Sharkmen Patrollers", minLvl = 150, giver = "Shark Park Quest Giver",       mobs = {"Sharkman Patroller", "Triton Patroller"} },
    { id = 17, island = "Shark Park",       title = "Defeat Sharkmen Guards",     minLvl = 160, giver = "Shark Park Quest Giver",       mobs = {"Sharkman Guard", "Elite Sharkman"} },
    { id = 18, island = "Shark Park",       title = "Defeat Sharkmen Apprentice", minLvl = 170, giver = "Shark Park Quest Giver",       mobs = {"Sharkman Fighting Style Student", "Sharkman Fighting Style Master"} },
    { id = 19, island = "Rustfall",         title = "Rustfall Quest 1",           minLvl = 180, giver = "Rustfall Quest Giver",         mobs = {"Tax Collector", "Shock Trooper", "Tax Leader"} },
    { id = 20, island = "Rustfall",         title = "Rustfall Quest 2",           minLvl = 195, giver = "Rustfall Quest Giver",         mobs = {"Fiscal Officer", "Underpaid Guard", "Chief Fiscal Officer"} },
    { id = 21, island = "Rustfall",         title = "Rustfall Quest 3",           minLvl = 210, giver = "Rustfall Quest Giver",         mobs = {"Old Iron Sentinel", "Iron Sentinel", "Eletric Iron Sentinel"} },
    { id = 22, island = "Prison",           title = "Defeat Elite Prison Guards", minLvl = 230, giver = "Prison Quest Giver",           mobs = {"Elite Prison Guard", "Elite Prison Supervisor"} },
    { id = 23, island = "Prison",           title = "Defeat Ice Prison Guards",   minLvl = 240, giver = "Prison Quest Giver",           mobs = {"Elite Prison Ice Guard", "Elite Prison Ice Supervisor"} },
    { id = 24, island = "Prison",           title = "Defeat Lava Prison Guards",  minLvl = 250, giver = "Prison Quest Giver",           mobs = {"Elite Prison Lava Guard", "Elite Prison Lava Supervisor"} },
    { id = 25, island = "Valoria Island",   title = "Valoria Island Quest 1",     minLvl = 260, giver = "Valoria Island Quest Giver",   mobs = {"Rookie Sword Gladiator", "Rookie Gunner Gladiator"} },
    { id = 26, island = "Valoria Island",   title = "Valoria Island Quest 2",     minLvl = 270, giver = "Valoria Island Quest Giver",   mobs = {"Veteran Gladiator", "Veteran Beast Gladiator"} },
    { id = 27, island = "Valoria Island",   title = "Valoria Island Quest 3",     minLvl = 280, giver = "Valoria Island Quest Giver",   mobs = {"Elite Dual Sword Gladiator", "Elite Assassin Gladiator"} },
    { id = 28, island = "Windhaven",        title = "Windhaven Quest 1",          minLvl = 290, giver = "Windhaven Quest Giver",        mobs = {"Sky Politician", "Sky Suspicious Merchant"} },
    { id = 29, island = "Windhaven",        title = "Windhaven Quest 2",          minLvl = 300, giver = "Windhaven Quest Giver",        mobs = {"Sky Royal Guard", "Elite Sky Royal Guard", "Sky Royal Captain"} },
    { id = 30, island = "Windhaven",        title = "Windhaven Quest 3",          minLvl = 310, giver = "Windhaven Quest Giver",        mobs = {"Shadow Royal Guard"} },
    { id = 31, island = "Nerúvia",          title = "Nerúvia Quest 1",            minLvl = 325, giver = "Nerúvia Quest Giver",          mobs = {"VoidWalker Musket Pirate", "VoidWalker Cutlass Pirate"} },
    { id = 32, island = "Nerúvia",          title = "Nerúvia Quest 2",            minLvl = 340, giver = "Nerúvia Quest Giver",          mobs = {"VoidWalker Flint Pirate", "Veteran VoidWalker Musket Pirate", "Veteran VoidWalker Cutlass Pirate"} },
    { id = 33, island = "Nerúvia",          title = "Nerúvia Quest 3",            minLvl = 355, giver = "Nerúvia Quest Giver",          mobs = {"Elite VoidWalker Musket Pirate", "Elite VoidWalker Flint Pirate", "Elite VoidWalker Cutlass Pirate"} },
    { id = 34, island = "Marine Ford",      title = "Bastion Reach Quest 1",      minLvl = 370, giver = "Marine Ford Quest Giver",      mobs = {"Marine Rookie", "Marine Soldier"} },
    { id = 35, island = "Marine Ford",      title = "Bastion Reach Quest 2",      minLvl = 385, giver = "Marine Ford Quest Giver",      mobs = {"Marine Sergeant", "Marine Lieutenant"} },
    { id = 36, island = "Marine Ford",      title = "Bastion Reach Quest 3",      minLvl = 400, giver = "Marine Ford Quest Giver",      mobs = {"Marine Captain", "Marine Admiral Candidate"} },
    { id = 37, island = "Volcano Island",   title = "Defeat Volcano Guards",      minLvl = 415, giver = "Volcano Island Quest Giver",   mobs = {"Volcano Guard", "Volcano Supervisor"} },
    { id = 38, island = "Volcano Island",   title = "Defeat Elite Volcano Guards",minLvl = 430, giver = "Volcano Island Quest Giver", mobs = {"Elite Volcano Guard", "Elite Volcano Supervisor"} }
}

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

-- ============================================================================
-- 3. INTERFACE COMPLETA (ABAS AUTO-GRIND E FRUTAS & HOP)
-- ============================================================================
local UI = {
    SwitchUpdaters = {},
    FruitScroll = nil,
    HopNowBtn = nil,
    QuestSelectLabel = nil,
    QuotaLabel = nil,
    StatusLabel = nil
}

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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FullGitHubV92"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = parentUI

function UI.SetStatus(text)
    if UI.StatusLabel and UI.StatusLabel.Parent then
        UI.StatusLabel.Text = tostring(text)
    end
end

function UI.RefreshQuestUI()
    local idx = math.clamp(Core.Settings.currentQuestIndex, 1, #QUEST_ROADMAP)
    local q = QUEST_ROADMAP[idx]
    if UI.QuestSelectLabel and q then
        UI.QuestSelectLabel.Text = string.format("#%d/%d • %s (Lvl %d)\nIlha: %s", q.id, #QUEST_ROADMAP, q.title, q.minLvl, q.island)
    end
    if UI.QuotaLabel then
        UI.QuotaLabel.Text = string.format("Meta por Missão: %d / %d vezes", Core.Settings.currentQuestDoneCount, Core.Settings.repeatsPerQuest)
    end
end

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 345, 0, 560)
MainFrame.Position = UDim2.new(0.5, -172, 0.5, -280)
MainFrame.BackgroundColor3 = C_BG
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = C_BORDER

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = C_HEADER
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -76, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Vox Seas Hub v9.2 (Git Full)"
Title.TextColor3 = C_TEXT
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 28, 0, 26)
MinBtn.Position = UDim2.new(1, -64, 0.5, -13)
MinBtn.Text = "—"
MinBtn.TextColor3 = C_TEXT
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 26)
CloseBtn.Position = UDim2.new(1, -33, 0.5, -13)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = C_RED
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.Position = UDim2.new(0, 10, 0, 46)
TabBar.BackgroundTransparency = 1

local TabGrindBtn = Instance.new("TextButton", TabBar)
TabGrindBtn.Size = UDim2.new(0.49, 0, 1, 0)
TabGrindBtn.Text = "⚔️ Auto-Grind"
TabGrindBtn.Font = Enum.Font.GothamBold
TabGrindBtn.TextSize = 10.5
TabGrindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabGrindBtn.BackgroundColor3 = C_ACCENT
Instance.new("UICorner", TabGrindBtn).CornerRadius = UDim.new(0, 7)

local TabFruitBtn = Instance.new("TextButton", TabBar)
TabFruitBtn.Size = UDim2.new(0.49, 0, 1, 0)
TabFruitBtn.Position = UDim2.new(0.51, 0, 0, 0)
TabFruitBtn.Text = "🍎 Frutas & Hop"
TabFruitBtn.Font = Enum.Font.GothamBold
TabFruitBtn.TextSize = 10.5
TabFruitBtn.TextColor3 = C_MUTED
TabFruitBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", TabFruitBtn).CornerRadius = UDim.new(0, 7)

local GrindPanel = Instance.new("ScrollingFrame", MainFrame)
GrindPanel.Size = UDim2.new(1, -20, 1, -124)
GrindPanel.Position = UDim2.new(0, 10, 0, 82)
GrindPanel.BackgroundTransparency = 1
GrindPanel.ScrollBarThickness = 3
GrindPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
GrindPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y

local GrindLayout = Instance.new("UIListLayout", GrindPanel)
GrindLayout.Padding = UDim.new(0, 6)
GrindLayout.SortOrder = Enum.SortOrder.LayoutOrder

local FruitPanel = Instance.new("ScrollingFrame", MainFrame)
FruitPanel.Size = UDim2.new(1, -20, 1, -124)
FruitPanel.Position = UDim2.new(0, 10, 0, 82)
FruitPanel.BackgroundTransparency = 1
FruitPanel.ScrollBarThickness = 3
FruitPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
FruitPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
FruitPanel.Visible = false

local FruitLayout = Instance.new("UIListLayout", FruitPanel)
FruitLayout.Padding = UDim.new(0, 6)
FruitLayout.SortOrder = Enum.SortOrder.LayoutOrder

TabGrindBtn.MouseButton1Click:Connect(function()
    GrindPanel.Visible = true; FruitPanel.Visible = false
    TabGrindBtn.BackgroundColor3 = C_ACCENT; TabGrindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabFruitBtn.BackgroundColor3 = C_CARD; TabFruitBtn.TextColor3 = C_MUTED
end)

TabFruitBtn.MouseButton1Click:Connect(function()
    GrindPanel.Visible = false; FruitPanel.Visible = true
    TabFruitBtn.BackgroundColor3 = C_BLUE; TabFruitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabGrindBtn.BackgroundColor3 = C_CARD; TabGrindBtn.TextColor3 = C_MUTED
end)

local orderMap = { [GrindPanel] = 0, [FruitPanel] = 0 }
local function nextOrder(p)
    orderMap[p] = (orderMap[p] or 0) + 1
    return orderMap[p]
end

local function addSwitch(parent, key, labelText, subText, defaultState)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder = nextOrder(parent)
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = C_CARD
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", row).Color = C_BORDER

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -68, 0, 19)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = C_TEXT
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", row)
    sub.Size = UDim2.new(1, -68, 0, 15)
    sub.Position = UDim2.new(0, 10, 0, 22)
    sub.BackgroundTransparency = 1
    sub.Text = subText
    sub.TextColor3 = C_MUTED
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 9.5
    sub.TextXAlignment = Enum.TextXAlignment.Left

    local switchBg = Instance.new("TextButton", row)
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -54, 0.5, -11)
    switchBg.Text = ""
    switchBg.BackgroundColor3 = defaultState and C_ACCENT or Color3.fromRGB(50, 56, 72)
    Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", switchBg)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState
    local function setVisual(newVal)
        state = newVal
        TweenService:Create(switchBg, TweenInfo.new(0.18), {
            BackgroundColor3 = state and C_ACCENT or Color3.fromRGB(50, 56, 72)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end

    UI.SwitchUpdaters[key] = setVisual
    switchBg.MouseButton1Click:Connect(function()
        setVisual(not state)
        Core.Settings[key] = state
        if key == "autoHop" and state then
            Core.State.hopEligibleTime = math.max(Core.State.hopEligibleTime, tick() + HOP_WAIT_SECONDS)
        end
        Core.SaveSettings()
    end)
end

-- Switches Grind
addSwitch(GrindPanel, "autoGrind", "Auto-Grind Progressivo", "Vai ao NPC, aceita, caça e repete", Core.Settings.autoGrind)
addSwitch(GrindPanel, "autoAcceptQuest", "Auto-Aceitar Missão", "Vai até o NPC e aceita quando sem missão", Core.Settings.autoAcceptQuest)
addSwitch(GrindPanel, "autoRepeatQuest", "Auto-Repetir Missão", "Clica em repetir ao concluir 100%", Core.Settings.autoRepeatQuest)

-- Seletor de Missão
local QuestCard = Instance.new("Frame", GrindPanel)
QuestCard.LayoutOrder = nextOrder(GrindPanel)
QuestCard.Size = UDim2.new(1, 0, 0, 46)
QuestCard.BackgroundColor3 = C_CARD
Instance.new("UICorner", QuestCard).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", QuestCard).Color = C_BLUE

local PrevQBtn = Instance.new("TextButton", QuestCard)
PrevQBtn.Size = UDim2.new(0, 32, 0, 30)
PrevQBtn.Position = UDim2.new(0, 8, 0.5, -15)
PrevQBtn.Text = "◀"
PrevQBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevQBtn.Font = Enum.Font.GothamBold
PrevQBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", PrevQBtn).CornerRadius = UDim.new(0, 6)

UI.QuestSelectLabel = Instance.new("TextLabel", QuestCard)
UI.QuestSelectLabel.Size = UDim2.new(1, -88, 1, -6)
UI.QuestSelectLabel.Position = UDim2.new(0, 44, 0, 3)
UI.QuestSelectLabel.BackgroundTransparency = 1
UI.QuestSelectLabel.TextColor3 = C_TEXT
UI.QuestSelectLabel.Font = Enum.Font.GothamBold
UI.QuestSelectLabel.TextSize = 9.5
UI.QuestSelectLabel.TextWrapped = true

local NextQBtn = Instance.new("TextButton", QuestCard)
NextQBtn.Size = UDim2.new(0, 32, 0, 30)
NextQBtn.Position = UDim2.new(1, -40, 0.5, -15)
NextQBtn.Text = "▶"
NextQBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NextQBtn.Font = Enum.Font.GothamBold
NextQBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", NextQBtn).CornerRadius = UDim.new(0, 6)

PrevQBtn.MouseButton1Click:Connect(function()
    Core.Settings.currentQuestIndex = ((Core.Settings.currentQuestIndex - 2) % #QUEST_ROADMAP) + 1
    Core.Settings.currentQuestDoneCount = 0
    Core.SaveSettings(); UI.RefreshQuestUI()
end)

NextQBtn.MouseButton1Click:Connect(function()
    Core.Settings.currentQuestIndex = (Core.Settings.currentQuestIndex % #QUEST_ROADMAP) + 1
    Core.Settings.currentQuestDoneCount = 0
    Core.SaveSettings(); UI.RefreshQuestUI()
end)

-- Meta de Repetições
local QuotaCard = Instance.new("Frame", GrindPanel)
QuotaCard.LayoutOrder = nextOrder(GrindPanel)
QuotaCard.Size = UDim2.new(1, 0, 0, 38)
QuotaCard.BackgroundColor3 = C_CARD
Instance.new("UICorner", QuotaCard).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", QuotaCard).Color = C_BORDER

local MinusBtn = Instance.new("TextButton", QuotaCard)
MinusBtn.Size = UDim2.new(0, 32, 0, 26)
MinusBtn.Position = UDim2.new(0, 8, 0.5, -13)
MinusBtn.Text = "-1"
MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinusBtn.Font = Enum.Font.GothamBold
MinusBtn.TextSize = 10.5
MinusBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", MinusBtn).CornerRadius = UDim.new(0, 6)

UI.QuotaLabel = Instance.new("TextLabel", QuotaCard)
UI.QuotaLabel.Size = UDim2.new(1, -88, 1, 0)
UI.QuotaLabel.Position = UDim2.new(0, 44, 0, 0)
UI.QuotaLabel.BackgroundTransparency = 1
UI.QuotaLabel.TextColor3 = C_ACCENT
UI.QuotaLabel.Font = Enum.Font.GothamBold
UI.QuotaLabel.TextSize = 10.5

local PlusBtn = Instance.new("TextButton", QuotaCard)
PlusBtn.Size = UDim2.new(0, 32, 0, 26)
PlusBtn.Position = UDim2.new(1, -40, 0.5, -13)
PlusBtn.Text = "+1"
PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlusBtn.Font = Enum.Font.GothamBold
PlusBtn.TextSize = 10.5
PlusBtn.BackgroundColor3 = C_HEADER
Instance.new("UICorner", PlusBtn).CornerRadius = UDim.new(0, 6)

MinusBtn.MouseButton1Click:Connect(function()
    Core.Settings.repeatsPerQuest = math.max(1, Core.Settings.repeatsPerQuest - 1)
    Core.SaveSettings(); UI.RefreshQuestUI()
end)

PlusBtn.MouseButton1Click:Connect(function()
    Core.Settings.repeatsPerQuest = math.min(500, Core.Settings.repeatsPerQuest + 1)
    Core.SaveSettings(); UI.RefreshQuestUI()
end)

UI.RefreshQuestUI()

local SaveIslBtn = Instance.new("TextButton", GrindPanel)
SaveIslBtn.LayoutOrder = nextOrder(GrindPanel)
SaveIslBtn.Size = UDim2.new(1, 0, 0, 30)
SaveIslBtn.Text = "📍 Salvar Posicao da Ilha Atual"
SaveIslBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveIslBtn.Font = Enum.Font.GothamBold
SaveIslBtn.TextSize = 10
SaveIslBtn.BackgroundColor3 = C_FRUIT
Instance.new("UICorner", SaveIslBtn).CornerRadius = UDim.new(0, 7)
SaveIslBtn.MouseButton1Click:Connect(function()
    local q = QUEST_ROADMAP[Core.Settings.currentQuestIndex]
    local r = getRoot()
    if q and r then
        Core.SaveIsland(q.island, r.Position)
        UI.SetStatus("Salvo " .. q.island .. " no JSON.")
    end
end)

-- Switches Frutas
addSwitch(FruitPanel, "autoPlayIntro", "Auto-Iniciar (Pular Intro)", "Pula tela inicial ao entrar", Core.Settings.autoPlayIntro)
addSwitch(FruitPanel, "esp", "Radar Visual (ESP)", "Mostra frutas caídas no mapa", Core.Settings.esp)
addSwitch(FruitPanel, "autoFruit", "Coleta Automática", "Busca frutas do filtro alvo", Core.Settings.autoFruit)
addSwitch(FruitPanel, "autoStore", "Auto-Store (Guardar)", "Equipa e guarda fruta coletada", Core.Settings.autoStore)
addSwitch(FruitPanel, "tweenTravel", "Voo Suave", "Voa pelo alto ao deslocar", Core.Settings.tweenTravel)
addSwitch(FruitPanel, "autoHop", "Auto Server Hop (1-4P)", "Troca de sala se não achar alvo", Core.Settings.autoHop)

-- Filtro de Raridade
local RarityCard = Instance.new("Frame", FruitPanel)
RarityCard.LayoutOrder = nextOrder(FruitPanel)
RarityCard.Size = UDim2.new(1, 0, 0, 42)
RarityCard.BackgroundColor3 = C_CARD
Instance.new("UICorner", RarityCard).CornerRadius = UDim.new(0, 8)
local RarityStroke = Instance.new("UIStroke", RarityCard)
RarityStroke.Thickness = 1.5

local RarityBadge = Instance.new("TextLabel", RarityCard)
RarityBadge.Size = UDim2.new(0, 74, 0, 24)
RarityBadge.Position = UDim2.new(0, 10, 0.5, -12)
RarityBadge.Font = Enum.Font.GothamBold
RarityBadge.TextSize = 10
RarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", RarityBadge).CornerRadius = UDim.new(0, 6)

local RaritySub = Instance.new("TextLabel", RarityCard)
RaritySub.Size = UDim2.new(1, -100, 1, 0)
RaritySub.Position = UDim2.new(0, 92, 0, 0)
RaritySub.BackgroundTransparency = 1
RaritySub.TextColor3 = C_MUTED
RaritySub.Font = Enum.Font.Gotham
RaritySub.TextSize = 9.5
RaritySub.TextXAlignment = Enum.TextXAlignment.Left

local RarityBtn = Instance.new("TextButton", RarityCard)
RarityBtn.Size = UDim2.new(1, 0, 1, 0)
RarityBtn.BackgroundTransparency = 1
RarityBtn.Text = ""

local function syncRarity()
    local cur = RARITY_LEVELS[Core.Settings.minRarityId] or RARITY_LEVELS[2]
    RarityBadge.Text = cur.badge
    RarityBadge.BackgroundColor3 = cur.color
    RarityStroke.Color = cur.color
    RaritySub.Text = cur.desc
end
syncRarity()

RarityBtn.MouseButton1Click:Connect(function()
    Core.Settings.minRarityId = (Core.Settings.minRarityId % #RARITY_LEVELS) + 1
    Core.SaveSettings()
    syncRarity()
end)

-- Botão Novo Servidor + Limpar Histórico
local HopRow = Instance.new("Frame", FruitPanel)
HopRow.LayoutOrder = nextOrder(FruitPanel)
HopRow.Size = UDim2.new(1, 0, 0, 32)
HopRow.BackgroundTransparency = 1

UI.HopNowBtn = Instance.new("TextButton", HopRow)
UI.HopNowBtn.Size = UDim2.new(0.80, 0, 1, 0)
UI.HopNowBtn.Text = "🔄 Novo Servidor"
UI.HopNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.HopNowBtn.Font = Enum.Font.GothamBold
UI.HopNowBtn.TextSize = 11
UI.HopNowBtn.BackgroundColor3 = C_BLUE
Instance.new("UICorner", UI.HopNowBtn).CornerRadius = UDim.new(0, 7)

local ClearHistBtn = Instance.new("TextButton", HopRow)
ClearHistBtn.Size = UDim2.new(0.17, 0, 1, 0)
ClearHistBtn.Position = UDim2.new(0.83, 0, 0, 0)
ClearHistBtn.Text = "🗑️"
ClearHistBtn.TextColor3 = C_TEXT
ClearHistBtn.Font = Enum.Font.GothamBold
ClearHistBtn.BackgroundColor3 = C_CARD
Instance.new("UICorner", ClearHistBtn).CornerRadius = UDim.new(0, 7)

UI.FruitScroll = Instance.new("ScrollingFrame", FruitPanel)
UI.FruitScroll.LayoutOrder = nextOrder(FruitPanel)
UI.FruitScroll.Size = UDim2.new(1, 0, 0, 110)
UI.FruitScroll.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
UI.FruitScroll.ScrollBarThickness = 4
UI.FruitScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.FruitScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", UI.FruitScroll).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", UI.FruitScroll).Color = C_BORDER

local fListLayout = Instance.new("UIListLayout", UI.FruitScroll)
fListLayout.Padding = UDim.new(0, 6)

-- Barra de Status Fixa
local StatusBox = Instance.new("Frame", MainFrame)
StatusBox.Size = UDim2.new(1, -20, 0, 34)
StatusBox.Position = UDim2.new(0, 10, 1, -42)
StatusBox.BackgroundColor3 = C_HEADER
Instance.new("UICorner", StatusBox).CornerRadius = UDim.new(0, 7)
Instance.new("UIStroke", StatusBox).Color = C_BORDER

UI.StatusLabel = Instance.new("TextLabel", StatusBox)
UI.StatusLabel.Size = UDim2.new(1, -14, 1, -6)
UI.StatusLabel.Position = UDim2.new(0, 7, 0, 3)
UI.StatusLabel.BackgroundTransparency = 1
UI.StatusLabel.Text = "Hub v9.2 pronto."
UI.StatusLabel.TextColor3 = C_TEXT
UI.StatusLabel.Font = Enum.Font.Gotham
UI.StatusLabel.TextSize = 9.5
UI.StatusLabel.TextWrapped = true
UI.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

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
Instance.new("UIStroke", FloatingIcon).Color = C_FRUIT

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false; FloatingIcon.Visible = true
end)
FloatingIcon.MouseButton1Click:Connect(function()
    FloatingIcon.Visible = false; MainFrame.Visible = true
end)

-- ============================================================================
-- 4. MÓDULO AUTO-GRIND (APROXIMAÇÃO DO NPC + ACEITE + COMBATE + REPETIÇÃO)
-- ============================================================================
task.spawn(function()
    local ignoreMap = {}
    local counted = false
    local lastAccept = 0

    local function findNpcPos(qData)
        if not qData then return nil end
        local ok, pos = pcall(function()
            local gFolder = Workspace.IgnoreList.Int.NPCs.Quests.Grinding
            local islFolder = gFolder:FindFirstChild(qData.island)
            local model = islFolder and (islFolder:FindFirstChild(qData.giver) or islFolder:FindFirstChildWhichIsA("Model", true))
            if model then
                local p = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
                if p then return p.Position end
            end
            return nil
        end)
        if ok and pos then
            Core.SaveIsland(qData.island, pos)
            return pos
        end
        return Core.IslandCache[qData.island]
    end

    local function getQuestInfo()
        local info = { active = false, title = "", allDone = false, mobTarget = nil, prog = "" }
        pcall(function()
            local aq = pGui.ScreenGuis.MainUI.ProgressHUD.ActiveQuest
            if not aq.Visible then return end
            local total, done = 0, 0
            for _, d in ipairs(aq:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                    if d.Name == "Title" then
                        info.title = d.Text
                    elseif d.Text:match("%d+%s*/%s*%d+") then
                        local c, r = d.Text:match("(%d+)%s*/%s*(%d+)")
                        local cur, req = tonumber(c) or 0, tonumber(r) or 0
                        if req > 0 and req <= 50 then
                            total = total + 1
                            if cur >= req then
                                done = done + 1
                            elseif not info.mobTarget then
                                local m = d.Text:match("[Dd]efeat%s+([^:]+)") or d.Text:match("^([^:]+)")
                                if m then
                                    info.mobTarget = m:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^%d+%s*", "")
                                    info.prog = cur .. "/" .. req
                                end
                            end
                        end
                    end
                end
            end
            if info.title ~= "" or total > 0 then info.active = true end
            if total >= 1 and done >= total then info.allDone = true end
        end)
        return info
    end

    local function findRepeatBtn()
        local found = nil
        pcall(function()
            local prog = pGui.ScreenGuis.MainUI.ProgressHUD
            for _, d in ipairs(prog:GetDescendants()) do
                if d:IsA("GuiButton") and d.Visible then
                    local n = d.Name:lower()
                    if n:find("repeat") or n:find("repetir") then found = d; return end
                    local lbl = d:FindFirstChildWhichIsA("TextLabel", true)
                    if lbl and (lbl.Text:lower():find("repeat") or lbl.Text:lower():find("repetir")) then found = d; return end
                end
            end
        end)
        return found
    end

    local function mobReady(mob)
        if not mob or not mob.Parent then return false end
        if ignoreMap[mob] and tick() < ignoreMap[mob] then return false end
        if mob:GetAttribute("Dead") == true then return false end
        local hum = mob:FindFirstChildOfClass("Humanoid")
        local mr = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
        if not hum or not mr or hum.Health <= 0 or mr.Position.Y < -300 then return false end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.Physics then
            return false
        end
        local dcf = mob:GetAttribute("DeadCFrame")
        if mob:GetAttribute("Render") == false and typeof(dcf) == "CFrame" and (mr.Position - dcf.Position).Magnitude < 10 then
            return false
        end
        return true
    end

    local function mobMatches(mob, tName)
        if not tName or tName == "" then return false end
        local tLow = tName:lower()
        local orig = tostring(mob:GetAttribute("OriginalName") or ""):lower()
        local mLow = mob.Name:lower()
        if orig == tLow or (orig ~= "" and orig:find(tLow, 1, true)) or mLow:find(tLow, 1, true) then return true end
        if tLow:sub(-1) == "s" then
            local sg = tLow:sub(1, -2)
            if #sg >= 3 and ((orig ~= "" and orig:find(sg, 1, true)) or mLow:find(sg, 1, true)) then return true end
        end
        local last = tLow:match("(%a+)$")
        if last and #last >= 4 and ((orig ~= "" and orig:find(last, 1, true)) or mLow:find(last, 1, true)) then return true end
        return false
    end

    local function findTargetMob(tName, questMobs)
        local root = getRoot()
        local folder = Workspace:FindFirstChild("Playability") and Workspace.Playability:FindFirstChild("Enemys")
        if not folder or not root then return nil, nil end
        local list = {}
        if tName then table.insert(list, tName) end
        for _, m in ipairs(questMobs or {}) do table.insert(list, m) end

        for _, name in ipairs(list) do
            local best, bestR, bestSc = nil, nil, math.huge
            for _, mob in ipairs(folder:GetChildren()) do
                if mob:IsA("Model") and mobMatches(mob, name) and mobReady(mob) then
                    local mr = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                    if mr then
                        local sc = (mr.Position - root.Position).Magnitude + (mob:GetAttribute("Render") == false and 350 or 0)
                        if sc < bestSc then bestSc = sc; best = mob; bestR = mr end
                    end
                end
            end
            if best and bestR then return best, bestR, name end
        end
        return nil, nil, tName
    end

    local function equipWeapon()
        local c = player.Character
        if not c then return nil end
        local hum = c:FindFirstChildOfClass("Humanoid")
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and not t.Name:lower():find("fruit") then return t end
        end
        local bp = player:FindFirstChild("Backpack")
        if bp and hum then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and not t.Name:lower():find("fruit") then
                    hum:EquipTool(t); task.wait(0.15); return t
                end
            end
        end
        return nil
    end

    while ScreenGui and ScreenGui.Parent do
        pcall(function()
            local root = getRoot()
            local qData = QUEST_ROADMAP[math.clamp(Core.Settings.currentQuestIndex, 1, #QUEST_ROADMAP)]
            local qInfo = getQuestInfo()
            local repBtn = findRepeatBtn()

            if qInfo.active and root and qInfo.title == qData.title then
                Core.SaveIsland(qData.island, root.Position)
            end

            if Core.Settings.autoGrind and not Core.State.busyWithFruit and not Core.State.isTravelingIsland and root then
                Core.State.busyWithGrind = true
                if qInfo.active and qInfo.allDone then
                    if not counted then
                        counted = true
                        Core.Settings.currentQuestDoneCount = Core.Settings.currentQuestDoneCount + 1
                        Core.SaveSettings()
                        UI.RefreshQuestUI()
                    end
                    if Core.Settings.currentQuestDoneCount >= Core.Settings.repeatsPerQuest then
                        local prevIsl = qData.island
                        Core.Settings.currentQuestIndex = (Core.Settings.currentQuestIndex % #QUEST_ROADMAP) + 1
                        Core.Settings.currentQuestDoneCount = 0
                        Core.SaveSettings()
                        UI.RefreshQuestUI()
                        local nextQ = QUEST_ROADMAP[Core.Settings.currentQuestIndex]
                        if nextQ and nextQ.island ~= prevIsl then
                            local nPos = findNpcPos(nextQ)
                            if nPos then Core.SafeIslandTravel(nPos, UI.SetStatus) end
                        end
                        counted = false
                    elseif Core.Settings.autoRepeatQuest and repBtn then
                        UI.SetStatus(string.format("Repetindo missão (%d/%d)...", Core.Settings.currentQuestDoneCount, Core.Settings.repeatsPerQuest))
                        Core.ClickButton(repBtn)
                        task.wait(0.8)
                        counted = false
                    end
                elseif not qInfo.active then
                    counted = false
                    if Core.Settings.autoAcceptQuest and (tick() - lastAccept) >= 1.2 then
                        lastAccept = tick()
                        local npcPos = findNpcPos(qData)
                        if npcPos then
                            local d = (root.Position - npcPos).Magnitude
                            if d > 250 then
                                Core.SafeIslandTravel(npcPos, UI.SetStatus)
                            elseif d > 12 then
                                UI.SetStatus("Indo até o NPC de " .. qData.island .. "...")
                                Core.MoveToPosition(npcPos + Vector3.new(0, 2, 4), 250)
                                task.wait(0.25)
                            end
                        end
                        UI.SetStatus("Aceitando " .. qData.title .. "...")
                        pcall(function()
                            ReplicatedStorage.NetworkInstances.RemoteEvents.Quests:FireServer("AcceptGrinding", qData.title)
                        end)
                    end
                else
                    counted = false
                    local mob, mRoot, label = findTargetMob(qInfo.mobTarget, qData.mobs)
                    if mob and mRoot then
                        local weap = equipWeapon()
                        local tStart = tick()
                        while ScreenGui.Parent and Core.Settings.autoGrind and not Core.State.busyWithFruit and not Core.State.isTravelingIsland do
                            local rNow = getRoot()
                            if not rNow or not mobReady(mob) or not mRoot.Parent or (tick() - tStart) > 7 then
                                ignoreMap[mob] = tick() + 3.5
                                break
                            end
                            Core.MoveToPosition(mRoot.Position - (mRoot.CFrame.LookVector * Core.Settings.grindDistance) + Vector3.new(0, 1.5, 0), 280)
                            UI.SetStatus(string.format("[#%d %d/%d] %s (%s)", qData.id, Core.Settings.currentQuestDoneCount, Core.Settings.repeatsPerQuest, label, qInfo.prog))
                            if weap then weap:Activate() end
                            task.wait(0.18)
                        end
                    else
                        UI.SetStatus("Aguardando inimigo: " .. tostring(qInfo.mobTarget or qData.mobs[1]))
                    end
                end
                Core.State.busyWithGrind = false
            end
        end)
        task.wait(0.25)
    end
end)

-- ============================================================================
-- 5. MÓDULO FRUTAS, ESP & SERVER HOP (ISOLADO EM PCALL)
-- ============================================================================
task.spawn(function()
    local visited = {}
    local function loadHist()
        local h, now = {}, os.time()
        pcall(function()
            if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(HISTORY_FILE) then
                local dec = HttpService:JSONDecode(readfile(HISTORY_FILE))
                if type(dec) == "table" then
                    for id, ts in pairs(dec) do
                        if (now - tonumber(ts)) < EXPIRE_SECONDS then h[id] = ts end
                    end
                end
            end
        end)
        if game.JobId ~= "" then h[game.JobId] = now end
        return h
    end

    local function saveHist()
        pcall(function()
            if typeof(writefile) == "function" then writefile(HISTORY_FILE, HttpService:JSONEncode(visited)) end
        end)
    end

    local function countKeys(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

    visited = loadHist()
    saveHist()
    UI.HopNowBtn.Text = string.format("🔄 Novo Servidor (%d salvos)", countKeys(visited))

    local function hopNow()
        if Core.State.isHopping or Core.State.busyWithFruit then return end
        Core.State.isHopping = true
        UI.SetStatus("Buscando sala...")
        local ok, raw = pcall(function()
            return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100", game.PlaceId))
        end)
        if not ok or not raw then Core.State.isHopping = false; return end
        local dOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not dOk or not data or not data.data then Core.State.isHopping = false; return end

        local low, fb = {}, {}
        for _, s in ipairs(data.data) do
            if s.id and s.id ~= game.JobId and not visited[s.id] and s.playing and s.maxPlayers and s.playing < (s.maxPlayers - 1) and s.playing >= 1 then
                table.insert(s.playing <= 4 and low or fb, s)
            end
        end
        local pool = #low > 0 and low or fb
        if #pool == 0 then UI.SetStatus("Sem salas novas salvas. Use 🗑️."); Core.State.isHopping = false; return end

        local target = pool[math.random(1, #pool)]
        visited[target.id] = os.time()
        saveHist()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, player)
    end

    UI.HopNowBtn.MouseButton1Click:Connect(hopNow)
    ClearHistBtn.MouseButton1Click:Connect(function()
        visited = {[game.JobId] = os.time()}
        saveHist()
        UI.HopNowBtn.Text = string.format("🔄 Novo Servidor (%d salvos)", countKeys(visited))
        UI.SetStatus("Histórico de salas limpo!")
    end)

    local espMap = {}
    local function getFruitPos(obj)
        if not obj or not obj.Parent then return nil end
        local h = obj:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h.Position end
        if obj:IsA("Model") then return obj:GetPivot().Position end
        if obj:IsA("BasePart") then return obj.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position or nil
    end

    local function ensureESP(obj, meta)
        if espMap[obj] and espMap[obj].Parent then return end
        local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
        if not part then return end
        local bb = Instance.new("BillboardGui", part)
        bb.Adornee = part; bb.Size = UDim2.new(0, 160, 0, 38); bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = meta.color; lbl.TextStrokeTransparency = 0.2; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10.5
        espMap[obj] = bb
        task.spawn(function()
            while bb and bb.Parent and obj and obj.Parent do
                bb.Enabled = Core.Settings.esp
                local r = getRoot()
                if r then lbl.Text = string.format("[%s] %s (%.0f)", meta.tag, obj.Name, (part.Position - r.Position).Magnitude) end
                task.wait(0.35)
            end
        end)
    end

    local function collectFruit(item, meta)
        local r = getRoot()
        if Core.State.busyWithFruit or Core.State.isTravelingIsland or not r then return end
        local pos = getFruitPos(item)
        if not pos then return end
        Core.State.busyWithFruit = true
        UI.SetStatus("Coletando " .. item.Name .. "...")
        Core.MoveToPosition(pos + Vector3.new(0, 2.5, 0), 350)
        task.wait(0.25)
        pcall(function()
            local c = player.Character
            if item:IsA("Tool") and c and c:FindFirstChild("Humanoid") then c.Humanoid:EquipTool(item) end
        end)
        task.wait(0.25)
        if Core.Settings.autoStore then
            pcall(function()
                local storeBtn = pGui.ScreenGuis.MainUI.InteractionHUD.FruitOptions.Background.StoreButton
                Core.ClickButton(storeBtn)
            end)
        end
        Core.State.busyWithFruit = false
    end

    while ScreenGui and ScreenGui.Parent do
        pcall(function()
            if Core.Settings.autoPlayIntro then
                local lGui = pGui:FindFirstChild("LoadingScreenUI")
                if lGui and lGui.Enabled then
                    for _, d in ipairs(lGui:GetDescendants()) do
                        if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible then Core.ClickButton(d) end
                    end
                end
            end

            for _, c in ipairs(UI.FruitScroll:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
            end

            local dropped = Workspace:FindFirstChild("Playability") and Workspace.Playability:FindFirstChild("DroppedTools")
            local bestItem, bestMeta, count = nil, nil, 0
            if dropped then
                for _, item in ipairs(dropped:GetChildren()) do
                    local pos = getFruitPos(item)
                    if pos and item.Name:lower():find("fruit") then
                        count = count + 1
                        local meta = getFruitMeta(item.Name)
                        ensureESP(item, meta)
                        local okFilter = meta.tier >= Core.Settings.minRarityId
                        if okFilter and (not bestItem or meta.tier > bestMeta.tier) then
                            bestItem, bestMeta = item, meta
                        end

                        local row = Instance.new("Frame", UI.FruitScroll)
                        row.Size = UDim2.new(1, -8, 0, 36); row.BackgroundColor3 = C_CARD
                        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
                        local info = Instance.new("TextLabel", row)
                        info.Size = UDim2.new(1, -72, 1, 0); info.Position = UDim2.new(0, 8, 0, 0); info.BackgroundTransparency = 1
                        info.Text = string.format("[%s] %s", meta.tag, item.Name); info.TextColor3 = meta.color; info.Font = Enum.Font.GothamBold; info.TextSize = 9.5; info.TextXAlignment = Enum.TextXAlignment.Left

                        local takeBtn = Instance.new("TextButton", row)
                        takeBtn.Size = UDim2.new(0, 56, 0, 24); takeBtn.Position = UDim2.new(1, -62, 0.5, -12)
                        takeBtn.Text = "Pegar"; takeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); takeBtn.Font = Enum.Font.GothamBold; takeBtn.TextSize = 9.5; takeBtn.BackgroundColor3 = C_ACCENT
                        Instance.new("UICorner", takeBtn).CornerRadius = UDim.new(0, 5)
                        takeBtn.MouseButton1Click:Connect(function() task.spawn(function() collectFruit(item, meta) end) end)
                    end
                end
            end

            if count == 0 then
                local empty = Instance.new("TextLabel", UI.FruitScroll)
                empty.Size = UDim2.new(1, 0, 0, 32); empty.BackgroundTransparency = 1; empty.Text = "Nenhuma fruta caída no mapa."; empty.TextColor3 = C_MUTED; empty.Font = Enum.Font.Gotham; empty.TextSize = 9.5
            end

            if bestItem and not Core.State.busyWithFruit then
                if Core.Settings.autoHop then
                    Core.Settings.autoHop = false; Core.SaveSettings()
                    if UI.SwitchUpdaters["autoHop"] then UI.SwitchUpdaters["autoHop"](false) end
                end
                if Core.Settings.autoFruit then
                    collectFruit(bestItem, bestMeta)
                end
            elseif Core.Settings.autoHop and not bestItem and not Core.State.busyWithFruit and not Core.State.busyWithGrind and not Core.State.isHopping then
                local rem = Core.State.hopEligibleTime - tick()
                if rem > 0 then
                    UI.SetStatus(string.format("Sem fruta alvo. Hop em %.1fs...", rem))
                else
                    hopNow()
                end
            end
        end)
        task.wait(0.8)
    end
end)
