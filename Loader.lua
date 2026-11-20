-- main.lua (Arquivo Único Modularizado p/ GitHub Raw + Proteção pcall)
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

local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = newChar:WaitForChild("HumanoidRootPart")
end)

local parentUI = nil
pcall(function() if typeof(gethui) == "function" then parentUI = gethui() end end)
if not parentUI then pcall(function() parentUI = CoreGui end) end
if not parentUI then parentUI = pGui end

pcall(function()
    for _, name in ipairs({"RPGFruitFinderV4", "RPGFruitFinderV5", "UnifiedModularHubV6", "UnifiedModularHubV7", "IsolatedGrindV88", "GitSingleHubV9"}) do
        local old = parentUI:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

-- ============================================================================
-- 1. CORE & PERSISTÊNCIA
-- ============================================================================
local Core = {}
local CONFIG_FILE = "ff_config_" .. tostring(game.PlaceId) .. ".json"
local HISTORY_FILE = "ff_visited_" .. tostring(game.PlaceId) .. ".json"
local ISLAND_FILE = "ff_islands_" .. tostring(game.PlaceId) .. ".json"

Core.State = {
    busyWithFruit = false,
    busyWithGrind = false,
    isHopping = false,
    isTravelingIsland = false,
    hopEligibleTime = tick() + 10
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

function Core.MoveTo(pos, speed)
    if not root or not pos then return end
    speed = speed or 300
    if Core.Settings.tweenTravel then
        local highStart = Vector3.new(root.Position.X, math.max(root.Position.Y, pos.Y) + 70, root.Position.Z)
        local highDest = Vector3.new(pos.X, highStart.Y, pos.Z)
        root.CFrame = CFrame.new(highStart)
        local dur = math.clamp((highDest - highStart).Magnitude / speed, 0.25, 10)
        local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(highDest)})
        tw:Play(); tw.Completed:Wait()
    end
    root.CFrame = CFrame.new(pos)
    root.AssemblyLinearVelocity = Vector3.zero
end

function Core.SafeIslandTravel(targetPos, onMsg)
    if not root or not targetPos or Core.State.isTravelingIsland then return false end
    Core.State.isTravelingIsland = true

    local alt = 380
    local airStart = Vector3.new(root.Position.X, alt, root.Position.Z)
    local t1 = TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {CFrame = CFrame.new(airStart)})
    t1:Play(); t1.Completed:Wait()

    local airDest = Vector3.new(targetPos.X, alt, targetPos.Z)
    local dist = (airDest - airStart).Magnitude
    local dur = math.clamp(dist / 190, 0.8, 40)
    if onMsg then onMsg(string.format("Voando %.0f studs (~%.0fs)...", dist, dur)) end

    local t2 = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(airDest)})
    t2:Play(); t2.Completed:Wait()

    local t3 = TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))})
    t3:Play(); t3.Completed:Wait()

    root.AssemblyLinearVelocity = Vector3.zero
    Core.State.isTravelingIsland = false
    return true
end

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

-- ============================================================================
-- 2. INTERFACE (SEMPRE CARREGADA PRIMEIRO)
-- ============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GitSingleHubV9"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = parentUI

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 330, 0, 390)
Main.Position = UDim2.new(0.5, -165, 0.22, 0)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", Main).Color = Color3.fromRGB(45, 50, 66)

local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1, -40, 0, 32)
Header.Position = UDim2.new(0, 12, 0, 2)
Header.BackgroundTransparency = 1
Header.Text = "Vox Seas Hub v9.0 (Git Single)"
Header.TextColor3 = Color3.fromRGB(240, 244, 248)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 12
Header.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Main)
CloseBtn.Size = UDim2.new(0, 26, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0, 5)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TabBar = Instance.new("Frame", Main)
TabBar.Size = UDim2.new(1, -20, 0, 28)
TabBar.Position = UDim2.new(0, 10, 0, 38)
TabBar.BackgroundTransparency = 1

local TabGrind = Instance.new("TextButton", TabBar)
TabGrind.Size = UDim2.new(0.49, 0, 1, 0)
TabGrind.Text = "Auto-Grind"
TabGrind.Font = Enum.Font.GothamBold
TabGrind.TextSize = 10.5
TabGrind.TextColor3 = Color3.fromRGB(255, 255, 255)
TabGrind.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
Instance.new("UICorner", TabGrind).CornerRadius = UDim.new(0, 6)

local TabFruit = Instance.new("TextButton", TabBar)
TabFruit.Size = UDim2.new(0.49, 0, 1, 0)
TabFruit.Position = UDim2.new(0.51, 0, 0, 0)
TabFruit.Text = "Frutas & Hop"
TabFruit.Font = Enum.Font.GothamBold
TabFruit.TextSize = 10.5
TabFruit.TextColor3 = Color3.fromRGB(160, 168, 184)
TabFruit.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
Instance.new("UICorner", TabFruit).CornerRadius = UDim.new(0, 6)

local GrindPage = Instance.new("Frame", Main)
GrindPage.Size = UDim2.new(1, -20, 1, -116)
GrindPage.Position = UDim2.new(0, 10, 0, 72)
GrindPage.BackgroundTransparency = 1

local FruitPage = Instance.new("Frame", Main)
FruitPage.Size = UDim2.new(1, -20, 1, -116)
FruitPage.Position = UDim2.new(0, 10, 0, 72)
FruitPage.BackgroundTransparency = 1
FruitPage.Visible = false

TabGrind.MouseButton1Click:Connect(function()
    GrindPage.Visible = true; FruitPage.Visible = false
    TabGrind.BackgroundColor3 = Color3.fromRGB(16, 185, 129); TabGrind.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabFruit.BackgroundColor3 = Color3.fromRGB(28, 32, 42); TabFruit.TextColor3 = Color3.fromRGB(160, 168, 184)
end)

TabFruit.MouseButton1Click:Connect(function()
    GrindPage.Visible = false; FruitPage.Visible = true
    TabFruit.BackgroundColor3 = Color3.fromRGB(59, 130, 246); TabFruit.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabGrind.BackgroundColor3 = Color3.fromRGB(28, 32, 42); TabGrind.TextColor3 = Color3.fromRGB(160, 168, 184)
end)

local StatusLbl = Instance.new("TextLabel", Main)
StatusLbl.Size = UDim2.new(1, -20, 0, 32)
StatusLbl.Position = UDim2.new(0, 10, 1, -38)
StatusLbl.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
StatusLbl.TextColor3 = Color3.fromRGB(235, 240, 245)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 9.5
StatusLbl.TextWrapped = true
StatusLbl.Text = "Pronto. Selecione a aba desejada."
Instance.new("UICorner", StatusLbl).CornerRadius = UDim.new(0, 6)

local function setStatus(t)
    if StatusLbl and StatusLbl.Parent then StatusLbl.Text = tostring(t) end
end

local function makeToggle(parent, yPos, text, key)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10.5
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function sync()
        local on = Core.Settings[key]
        btn.Text = text .. ": " .. (on and "ON" or "OFF")
        btn.BackgroundColor3 = on and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(50, 56, 72)
    end
    sync()

    btn.MouseButton1Click:Connect(function()
        Core.Settings[key] = not Core.Settings[key]
        Core.SaveSettings()
        sync()
    end)
    return sync
end

-- Controles da Aba Grind
makeToggle(GrindPage, 0, "Auto-Grind", "autoGrind")
makeToggle(GrindPage, 34, "Auto-Aceitar Missao", "autoAcceptQuest")
makeToggle(GrindPage, 68, "Auto-Repetir Missao", "autoRepeatQuest")

local QBar = Instance.new("Frame", GrindPage)
QBar.Size = UDim2.new(1, 0, 0, 38)
QBar.Position = UDim2.new(0, 0, 0, 104)
QBar.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
Instance.new("UICorner", QBar).CornerRadius = UDim.new(0, 6)

local PrevQ = Instance.new("TextButton", QBar)
PrevQ.Size = UDim2.new(0, 30, 0, 28)
PrevQ.Position = UDim2.new(0, 5, 0.5, -14)
PrevQ.Text = "<"
PrevQ.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevQ.Font = Enum.Font.GothamBold
PrevQ.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
Instance.new("UICorner", PrevQ).CornerRadius = UDim.new(0, 5)

local QLabel = Instance.new("TextLabel", QBar)
QLabel.Size = UDim2.new(1, -78, 1, 0)
QLabel.Position = UDim2.new(0, 39, 0, 0)
QLabel.BackgroundTransparency = 1
QLabel.TextColor3 = Color3.fromRGB(240, 244, 248)
QLabel.Font = Enum.Font.GothamBold
QLabel.TextSize = 9.5
QLabel.TextWrapped = true

local NextQ = Instance.new("TextButton", QBar)
NextQ.Size = UDim2.new(0, 30, 0, 28)
NextQ.Position = UDim2.new(1, -35, 0.5, -14)
NextQ.Text = ">"
NextQ.TextColor3 = Color3.fromRGB(255, 255, 255)
NextQ.Font = Enum.Font.GothamBold
NextQ.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
Instance.new("UICorner", NextQ).CornerRadius = UDim.new(0, 5)

local QuotaLabel = Instance.new("TextLabel", GrindPage)
QuotaLabel.Size = UDim2.new(1, 0, 0, 20)
QuotaLabel.Position = UDim2.new(0, 0, 0, 146)
QuotaLabel.BackgroundTransparency = 1
QuotaLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
QuotaLabel.Font = Enum.Font.GothamBold
QuotaLabel.TextSize = 10

local function refreshQuestUI()
    local idx = math.clamp(Core.Settings.currentQuestIndex, 1, #QUEST_ROADMAP)
    local q = QUEST_ROADMAP[idx]
    if q then
        QLabel.Text = string.format("#%d %s\nIlha: %s", q.id, q.title, q.island)
    end
    QuotaLabel.Text = string.format("Meta: %d / %d vezes", Core.Settings.currentQuestDoneCount, Core.Settings.repeatsPerQuest)
end
refreshQuestUI()

PrevQ.MouseButton1Click:Connect(function()
    Core.Settings.currentQuestIndex = ((Core.Settings.currentQuestIndex - 2) % #QUEST_ROADMAP) + 1
    Core.Settings.currentQuestDoneCount = 0
    Core.SaveSettings()
    refreshQuestUI()
end)

NextQ.MouseButton1Click:Connect(function()
    Core.Settings.currentQuestIndex = (Core.Settings.currentQuestIndex % #QUEST_ROADMAP) + 1
    Core.Settings.currentQuestDoneCount = 0
    Core.SaveSettings()
    refreshQuestUI()
end)

local SaveIslBtn = Instance.new("TextButton", GrindPage)
SaveIslBtn.Size = UDim2.new(1, 0, 0, 28)
SaveIslBtn.Position = UDim2.new(0, 0, 0, 170)
SaveIslBtn.Text = "Salvar Posicao da Ilha Atual"
SaveIslBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveIslBtn.Font = Enum.Font.GothamBold
SaveIslBtn.TextSize = 10
SaveIslBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
Instance.new("UICorner", SaveIslBtn).CornerRadius = UDim.new(0, 6)
SaveIslBtn.MouseButton1Click:Connect(function()
    local q = QUEST_ROADMAP[Core.Settings.currentQuestIndex]
    if q and root then
        Core.SaveIsland(q.island, root.Position)
        setStatus("Salvo " .. q.island .. " no JSON.")
    end
end)

-- Controles da Aba Frutas
makeToggle(FruitPage, 0, "ESP Frutas", "esp")
makeToggle(FruitPage, 34, "Auto-Coletar Frutas", "autoFruit")
makeToggle(FruitPage, 68, "Auto-Store (Guardar)", "autoStore")
makeToggle(FruitPage, 102, "Voo Suave", "tweenTravel")
makeToggle(FruitPage, 136, "Auto Server Hop", "autoHop")

-- ============================================================================
-- 3. LOOP DE AUTO-GRIND (ISOLADO EM PCALL)
-- ============================================================================
task.spawn(function()
    local ignoreMap = {}
    local counted = false
    local lastAccept = 0

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
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        for _, t in ipairs(char:GetChildren()) do
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
                        refreshQuestUI()
                    end
                    if Core.Settings.currentQuestDoneCount >= Core.Settings.repeatsPerQuest then
                        local prevIsl = qData.island
                        Core.Settings.currentQuestIndex = (Core.Settings.currentQuestIndex % #QUEST_ROADMAP) + 1
                        Core.Settings.currentQuestDoneCount = 0
                        Core.SaveSettings()
                        refreshQuestUI()
                        local nextQ = QUEST_ROADMAP[Core.Settings.currentQuestIndex]
                        if nextQ and nextQ.island ~= prevIsl and Core.IslandCache[nextQ.island] then
                            Core.SafeIslandTravel(Core.IslandCache[nextQ.island], setStatus)
                        end
                        counted = false
                    elseif Core.Settings.autoRepeatQuest and repBtn then
                        setStatus("Repetindo quest...")
                        Core.ClickButton(repBtn)
                        task.wait(0.8)
                        counted = false
                    end
                elseif not qInfo.active then
                    counted = false
                    if Core.Settings.autoAcceptQuest and (tick() - lastAccept) >= 1.2 then
                        lastAccept = tick()
                        setStatus("Aceitando " .. qData.title .. "...")
                        ReplicatedStorage.NetworkInstances.RemoteEvents.Quests:FireServer("AcceptGrinding", qData.title)
                    end
                else
                    counted = false
                    local mob, mRoot, label = findTargetMob(qInfo.mobTarget, qData.mobs)
                    if mob and mRoot then
                        local weap = equipWeapon()
                        local tStart = tick()
                        while ScreenGui.Parent and Core.Settings.autoGrind and not Core.State.busyWithFruit and not Core.State.isTravelingIsland do
                            if not mobReady(mob) or not mRoot.Parent or (tick() - tStart) > 7 then
                                ignoreMap[mob] = tick() + 3.5
                                break
                            end
                            Core.MoveTo(mRoot.Position - (mRoot.CFrame.LookVector * Core.Settings.grindDistance) + Vector3.new(0, 1.5, 0))
                            setStatus(string.format("[%d/%d] %s (%s)", Core.Settings.currentQuestDoneCount, Core.Settings.repeatsPerQuest, label, qInfo.prog))
                            if weap then weap:Activate() end
                            task.wait(0.18)
                        end
                    else
                        setStatus("Aguardando inimigo: " .. tostring(qInfo.mobTarget or qData.mobs[1]))
                    end
                end
                Core.State.busyWithGrind = false
            end
        end)
        task.wait(0.25)
    end
end)

-- ============================================================================
-- 4. LOOP DE FRUTAS & SERVER HOP (ISOLADO EM PCALL)
-- ============================================================================
task.spawn(function()
    local visited = {}
    pcall(function()
        if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(HISTORY_FILE) then
            visited = HttpService:JSONDecode(readfile(HISTORY_FILE)) or {}
        end
    end)
    if game.JobId ~= "" then visited[game.JobId] = os.time() end

    while ScreenGui and ScreenGui.Parent do
        pcall(function()
            if Core.Settings.autoFruit and not Core.State.busyWithFruit and not Core.State.isTravelingIsland and root then
                local dropped = Workspace:FindFirstChild("Playability") and Workspace.Playability:FindFirstChild("DroppedTools")
                if dropped then
                    for _, item in ipairs(dropped:GetChildren()) do
                        if item.Name:lower():find("fruit") then
                            local h = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart", true)
                            if h then
                                Core.State.busyWithFruit = true
                                setStatus("Coletando fruta: " .. item.Name)
                                Core.MoveTo(h.Position + Vector3.new(0, 2.5, 0), 350)
                                task.wait(0.3)
                                Core.State.busyWithFruit = false
                                break
                            end
                        end
                    end
                end
            end
        end)
        task.wait(1.0)
    end
end)
