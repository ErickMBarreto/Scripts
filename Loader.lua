-- ====================================================================
-- 1. TRAVA FÍSICA DE INSTÂNCIA ÚNICA
-- ====================================================================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local UNIQUE_ID = "HubRapazes_Singleton_Tag"
if CoreGui:FindFirstChild(UNIQUE_ID) then
    return
end

local singletonTag = Instance.new("Folder")
singletonTag.Name = UNIQUE_ID
pcall(function() singletonTag.Parent = CoreGui end)

for _, gui in ipairs({CoreGui, Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")}) do
    if gui then
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

-- ====================================================================
-- 2. REEXECUÇÃO AUTOMÁTICA INFINITA (Delta / Mobile)
-- ====================================================================
local scriptURL = "https://raw.githubusercontent.com/ErickMBarreto/Scripts/refs/heads/main/Loader.lua"

local function queueNextExecution()
    local queueFunc = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queueFunc then
        pcall(function()
            queueFunc(string.format([[
                repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
                task.wait(1.5)
                loadstring(game:HttpGet("%s"))()
            ]], scriptURL))
        end)
    end
end

queueNextExecution()

-- ====================================================================
-- 3. ESPERA DE CARREGAMENTO E TRAVA DO LOBBY
-- ====================================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pgui = player:WaitForChild("PlayerGui", 20)

local function isInsideDungeon()
    local main = pgui and pgui:FindFirstChild("Main")
    if main and (main:FindFirstChild("DungeonFrame") or main:FindFirstChild("VirusFrame")) then return true end
    if workspace:FindFirstChild("Game") and (workspace.Game:FindFirstChild("Enemies") or workspace.Game:FindFirstChild("Teleports")) then return true end
    if workspace:FindFirstChild("Enemies") then return true end
    return false
end

local inDungeon = false
for i = 1, 15 do
    if isInsideDungeon() then
        inDungeon = true
        break
    end
    task.wait(0.5)
end

if not inDungeon then
    pcall(function() singletonTag:Destroy() end)
    return
end

-- ====================================================================
-- 4. FLUXO PRINCIPAL DO HUB DOS RAPAZES
-- ====================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local attackRemote = nil
task.spawn(function()
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
    if remotesFolder then
        attackRemote = remotesFolder:WaitForChild("Attack", 10)
    end
end)

local Settings = {
    AutoFarm = true,
    AutoAttack = true,
    AutoSkills = true,
    AutoStart = true,
    AutoPlayAgain = true,
    AutoEngage = true,
    SkillCooldown = 0.8,
    SkillMaxDistance = 20,
    HeightAboveEnemy = 9.0,
    TweenSpeed = 90,
    AttackSpeed = 0.15
}

local currentTween = nil
local noclipConnection = nil
local isMoving = false
local usedTeleports = {}
local portalHistory = {}
local teleportCooldown = 0
local lastSkillUse = 0
local comboIndex = 1
local isDungeonEnded = false
local dungeonReady = false

local function getCharacter()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
        return char, char.HumanoidRootPart, char.Humanoid
    end
    return nil, nil, nil
end

local function stopMovement()
    isMoving = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    local _, root = getCharacter()
    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

player.CharacterAdded:Connect(function()
    stopMovement()
    teleportCooldown = 0
    dungeonReady = false

    if #portalHistory > 0 then
        local lastPortal = table.remove(portalHistory)
        if lastPortal then
            usedTeleports[lastPortal] = nil
        end
    end
end)

local function getWeaponName()
    local char = player.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Model") and (child.Name:lower():find("katana") or child.Name:lower():find("sword") or child.Name:lower():find("weapon")) then
                return child.Name
            end
        end
    end
    return "Katana"
end

-- Noclip e Flutuação Anti-Gravidade
local function toggleNoclip(enable)
    if enable then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                local char, root = getCharacter()
                if char and root and Settings.AutoFarm and not isDungeonEnded then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

local function smoothFlyTo(targetCFrame)
    if isDungeonEnded then return end
    local _, root = getCharacter()
    if not root or not root.Parent then return end
    
    isMoving = true
    local distance = (root.Position - targetCFrame.Position).Magnitude
    local duration = distance / math.max(Settings.TweenSpeed, 5)

    if currentTween then
        currentTween:Cancel()
    end

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
end

local function triggerGuiButton(btn)
    if not btn or not btn.Parent then return end
    if firesignal then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
    end
    if getconnections then
        for _, c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
        for _, c in ipairs(getconnections(btn.MouseButton1Down)) do pcall(function() c:Fire() end) end
        for _, c in ipairs(getconnections(btn.MouseButton1Up)) do pcall(function() c:Fire() end) end
    end
end

-- Detecção Direta do Botão Confirm (VirusFrame/Engage)
local function checkAndClickEngageButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return false end

    local main = pguiRef:FindFirstChild("Main")
    local virusFrame = main and main:FindFirstChild("VirusFrame")
    local warning = virusFrame and virusFrame:FindFirstChild("Warning")
    local buttons = warning and warning:FindFirstChild("Buttons")
    local confirmBtn = buttons and buttons:FindFirstChild("Confirm")

    if confirmBtn and confirmBtn:IsA("GuiObject") and confirmBtn.Visible and virusFrame.Visible then
        triggerGuiButton(confirmBtn)
        return true
    end

    return false
end

local function checkDungeonEnd()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return false end

    local main = pguiRef:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local dungeonStats = dungeonFrame and dungeonFrame:FindFirstChild("DungeonStats")
    local endActions = dungeonStats and dungeonStats:FindFirstChild("EndActions")
    local playAgainBtn = endActions and endActions:FindFirstChild("PlayAgain")

    if playAgainBtn and playAgainBtn:IsA("GuiObject") and playAgainBtn.Visible and dungeonStats.Visible then
        return true, playAgainBtn
    end

    return false, nil
end

local function handleDungeonStart()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return false end

    local main = pguiRef:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    
    if dungeonFrame and dungeonFrame.Visible then
        local startBtn = dungeonFrame:FindFirstChild("Start") or dungeonFrame:FindFirstChild("Play")
        if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
            triggerGuiButton(startBtn)
            task.wait(2.5)
            dungeonReady = true
            return true
        end
    end
    return false
end

-- Scanner de Inimigos Dinâmico
local function getDynamicClosestEnemy()
    local _, root = getCharacter()
    if not root then return nil, nil end

    local candidates = {}
    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = (gameFolder and gameFolder:FindFirstChild("Enemies")) or workspace:FindFirstChild("Enemies")
    
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            table.insert(candidates, enemy)
        end
    end

    if #candidates == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= player.Character and not Players:GetPlayerFromCharacter(obj) then
                if obj:FindFirstChildOfClass("Humanoid") then
                    table.insert(candidates, obj)
                end
            end
        end
    end

    local closestEnemy, closestRoot = nil, nil
    local minDistance = math.huge

    for _, enemy in ipairs(candidates) do
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health > 0 then
            local targetPart = enemy:FindFirstChild("HumanoidRootPart")
                or enemy:FindFirstChild("Bot")
                or enemy:FindFirstChild("Hitbox")
                or enemy:FindFirstChild("Torso")
                or enemy:FindFirstChild("Head")
                or (enemy:IsA("Model") and enemy.PrimaryPart)
                or (enemy:IsA("BasePart") and enemy)
                or enemy:FindFirstChildWhichIsA("BasePart")

            if targetPart and targetPart:IsA("BasePart") then
                local dist = (root.Position - targetPart.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestEnemy = enemy
                    closestRoot = targetPart
                end
            end
        end
    end

    return closestEnemy, closestRoot
end

-- Scanner Exclusivo para Fases com Portal (Detecta 'Teleports' ou 'Teleport')
local function getPhaseTeleport()
    if tick() < teleportCooldown then
        return nil, math.huge
    end

    local _, root = getCharacter()
    if not root then return nil, math.huge end

    local teleportParts = {}
    local gameFolder = workspace:FindFirstChild("Game")
    
    -- Busca direta nas pastas mapeadas
    local teleportsFolder = (gameFolder and (gameFolder:FindFirstChild("Teleports") or gameFolder:FindFirstChild("Teleport"))) 
        or workspace:FindFirstChild("Teleports") 
        or workspace:FindFirstChild("Teleport")

    if teleportsFolder then
        for _, teleportObj in ipairs(teleportsFolder:GetChildren()) do
            local hitbox = teleportObj:FindFirstChild("HitBox") 
                or (teleportObj:IsA("BasePart") and teleportObj) 
                or teleportObj:FindFirstChildWhichIsA("BasePart")

            if hitbox and not usedTeleports[hitbox] then
                table.insert(teleportParts, hitbox)
            end
        end
    end

    -- Se esta fase não tem pasta de portais, encerra sem mover
    if #teleportParts == 0 then
        return nil, math.huge
    end

    local closestHitbox = nil
    local minDistance = math.huge

    for _, hitbox in ipairs(teleportParts) do
        local dist = (root.Position - hitbox.Position).Magnitude
        if dist < minDistance then
            minDistance = dist
            closestHitbox = hitbox
        end
    end

    return closestHitbox, minDistance
end

local function getDynamicHotbar()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return nil end

    local mainGui = pguiRef:FindFirstChild("Main")
    if mainGui and mainGui:FindFirstChild("FrontFrame") and mainGui.FrontFrame:FindFirstChild("Hotbar") then
        return mainGui.FrontFrame.Hotbar:FindFirstChild("List") or mainGui.FrontFrame.Hotbar
    end
    return nil
end

local function executeNativeAttack()
    if isDungeonEnded or not dungeonReady then return end
    comboIndex = (comboIndex % 4) + 1
    local weapon = getWeaponName()

    if not attackRemote then
        attackRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Attack")
    end

    if attackRemote then
        pcall(function()
            attackRemote:FireServer("M1", weapon, comboIndex, 0, 0, 2)
        end)
    end

    local char = player.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
    end
end

-- Loop M1
task.spawn(function()
    while true do
        if Settings.AutoAttack and not isDungeonEnded and dungeonReady then
            local char, _, hum = getCharacter()
            if char and hum and hum.Health > 0 then
                executeNativeAttack()
            end
        end
        task.wait(Settings.AttackSpeed)
    end
end)

-- Loop Skills Inteligente (Só atinge com monstro perto)
task.spawn(function()
    while true do
        if Settings.AutoSkills and not isDungeonEnded and dungeonReady then
            local char, root, hum = getCharacter()
            if char and root and hum and hum.Health > 0 then
                if (tick() - lastSkillUse) >= Settings.SkillCooldown then
                    local _, enemyRoot = getDynamicClosestEnemy()
                    if enemyRoot and enemyRoot.Parent then
                        local distance = (root.Position - enemyRoot.Position).Magnitude
                        if distance <= Settings.SkillMaxDistance then
                            lastSkillUse = tick()
                            local hotbarList = getDynamicHotbar()
                            if hotbarList then
                                local spell1 = hotbarList:FindFirstChild("Spell1", true) or hotbarList:FindFirstChild("Z", true)
                                local spell2 = hotbarList:FindFirstChild("Spell2", true) or hotbarList:FindFirstChild("X", true)
                                local spell3 = hotbarList:FindFirstChild("Spell3", true) or hotbarList:FindFirstChild("C", true)

                                if spell1 then triggerGuiButton(spell1) end
                                task.wait(0.06)
                                if spell2 then triggerGuiButton(spell2) end
                                task.wait(0.06)
                                if spell3 then triggerGuiButton(spell3) end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Loop Principal Adaptável
task.spawn(function()
    while true do
        if Settings.AutoFarm then
            local char, root, hum = getCharacter()
            if char and root and hum and hum.Health > 0 then
                
                if Settings.AutoEngage then
                    checkAndClickEngageButton()
                end

                local ended, playAgainBtn = checkDungeonEnd()
                if ended then
                    isDungeonEnded = true
                    dungeonReady = false
                    table.clear(usedTeleports)
                    table.clear(portalHistory)
                    stopMovement()
                    
                    if Settings.AutoPlayAgain and playAgainBtn then
                        queueNextExecution()
                        task.wait(0.8)
                        triggerGuiButton(playAgainBtn)
                        task.wait(3.0)
                    end
                else
                    isDungeonEnded = false

                    -- 1. Warm-Up Gate: Garante o clique no Start antes de voar
                    if not dungeonReady then
                        if Settings.AutoStart and handleDungeonStart() then
                            stopMovement()
                        else
                            local pguiRef = player:FindFirstChild("PlayerGui")
                            local df = pguiRef and pguiRef:FindFirstChild("Main") and pguiRef.Main:FindFirstChild("DungeonFrame")
                            if not df or not df.Visible or not df:FindFirstChild("Start") or not df.Start.Visible then
                                dungeonReady = true
                            end
                        end
                        task.wait(0.2)
                    else
                        local enemy, enemyRoot = getDynamicClosestEnemy()

                        -- 2. Combate prioritário: Voa até o inimigo
                        if enemy and enemyRoot then
                            while Settings.AutoFarm and not isDungeonEnded and enemy.Parent and enemyRoot.Parent do
                                local enemyHum = enemy:FindFirstChildOfClass("Humanoid")
                                if enemyHum and enemyHum.Health <= 0 then break end

                                local _, currentRoot = getCharacter()
                                if not currentRoot then break end

                                local abovePos = enemyRoot.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
                                local targetCFrame = CFrame.new(abovePos, enemyRoot.Position)
                                smoothFlyTo(targetCFrame)
                                task.wait(0.05)
                            end
                        -- 3. Sem inimigos: Se a fase tiver portal, entra nele. Se não tiver, aguarda o spawn/boss.
                        else
                            local teleportHitbox, teleportDist = getPhaseTeleport()
                            if teleportHitbox then
                                smoothFlyTo(teleportHitbox.CFrame)
                                
                                if teleportDist <= 14 then
                                    root.CFrame = teleportHitbox.CFrame
                                    usedTeleports[teleportHitbox] = true
                                    table.insert(portalHistory, teleportHitbox)
                                    teleportCooldown = tick() + 2.0
                                    task.wait(0.8)
                                end
                            else
                                stopMovement()
                            end
                        end
                    end
                end
            else
                stopMovement()
            end
        else
            stopMovement()
        end
        task.wait(0.05)
    end
end)

toggleNoclip(Settings.AutoFarm)

local Window = Fluent:CreateWindow({
    Title = "Hub dos Rapazes",
    SubTitle = "Anime Dungeons",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Farm", Icon = "crosshair" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "IBdihP_PersistentToggle"
toggleGui.ResetOnSpawn = false
toggleGui.DisplayOrder = 999999
toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() toggleGui.Parent = CoreGui end)
if not toggleGui.Parent then toggleGui.Parent = player:WaitForChild("PlayerGui") end

local floatBtn = Instance.new("TextButton")
floatBtn.Name = "FloatButton"
floatBtn.Parent = toggleGui
floatBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
floatBtn.Position = UDim2.new(0.02, 0, 0.35, 0)
floatBtn.Size = UDim2.new(0, 48, 0, 48)
floatBtn.Text = "HUB"
floatBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
floatBtn.TextSize = 12
floatBtn.Font = Enum.Font.GothamBold
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Visible = false

local uiCorner = Instance.new("UICorner", floatBtn)
uiCorner.CornerRadius = UDim.new(0, 10)

local uiStroke = Instance.new("UIStroke", floatBtn)
uiStroke.Color = Color3.fromRGB(0, 255, 170)
uiStroke.Thickness = 1.6
uiStroke.Parent = floatBtn

local function toggleUI(show)
    floatBtn.Visible = not show
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("ScreenGui") and child ~= toggleGui and (child.Name:find("Fluent") or child.Name:find("ScreenGui")) then
                child.Enabled = show
            end
        end
    end
end

floatBtn.MouseButton1Click:Connect(function()
    toggleUI(true)
end)

task.spawn(function()
    task.wait(0.8)
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, btn in ipairs(gui:GetDescendants()) do
            if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and (btn.Name:lower():find("min") or btn.Name:lower():find("close")) then
                btn.MouseButton1Click:Connect(function()
                    toggleUI(false)
                end)
            end
        end
    end
end)

local FarmSection = Tabs.Farm:AddSection("Auto Farm & Combate")

FarmSection:AddToggle("AutoFarmEnemies", {
    Title = "Auto Farm Universal",
    Description = "Start -> Farm -> Portal/Spawn -> Auto Replay",
    Default = true,
    Callback = function(Value)
        Settings.AutoFarm = Value
        toggleNoclip(Value)
        if not Value then
            stopMovement()
        end
    end
})

FarmSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Virus Boss)",
    Description = "Clica automaticamente em Confirm no VirusFrame",
    Default = true,
    Callback = function(Value)
        Settings.AutoEngage = Value
    end
})

FarmSection:AddToggle("AutoPlayAgainToggle", {
    Title = "Auto Play Again",
    Description = "Clica em Jogar Novamente e persiste entre partidas",
    Default = true,
    Callback = function(Value)
        Settings.AutoPlayAgain = Value
    end
})

FarmSection:AddToggle("AutoStartToggle", {
    Title = "Auto Start Dungeon",
    Description = "Aguarda a fase carregar e inicia sozinho",
    Default = true,
    Callback = function(Value)
        Settings.AutoStart = Value
    end
})

FarmSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (Remote Nativo)",
    Description = "Dispara os ataques M1 continuamente",
    Default = true,
    Callback = function(Value)
        Settings.AutoAttack = Value
    end
})

FarmSection:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills (Spell 1, 2 e C)",
    Description = "Dispara skills apenas perto de inimigos",
    Default = true,
    Callback = function(Value)
        Settings.AutoSkills = Value
    end
})

FarmSection:AddSlider("SkillMaxDistSlider", {
    Title = "Distância das Skills (studs)",
    Default = 20,
    Min = 8,
    Max = 40,
    Rounding = 0,
    Callback = function(Value)
        Settings.SkillMaxDistance = Value
    end
})

FarmSection:AddSlider("AttackSpeedSlider", {
    Title = "Velocidade do Ataque (segundos)",
    Default = 0.15,
    Min = 0.04,
    Max = 0.35,
    Rounding = 2,
    Callback = function(Value)
        Settings.AttackSpeed = Value
    end
})

FarmSection:AddSlider("SkillCooldownSlider", {
    Title = "Intervalo das Skills (segundos)",
    Default = 0.8,
    Min = 0.2,
    Max = 4,
    Rounding = 1,
    Callback = function(Value)
        Settings.SkillCooldown = Value
    end
})

FarmSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura acima do Inimigo",
    Default = 9.0,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        Settings.HeightAboveEnemy = Value
    end
})

FarmSection:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo",
    Default = 90,
    Min = 20,
    Max = 160,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

Window:SelectTab(Tabs.Farm)
