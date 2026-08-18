-- ====================================================================
-- 1. TRAVA FÍSICA DE INSTÂNCIA ÚNICA (Impede duplicatas na tela)
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
                task.wait(1)
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
local pgui = player:WaitForChild("PlayerGui", 15)

local function isInsideDungeon()
    local main = pgui and pgui:FindFirstChild("Main")
    if main and (main:FindFirstChild("DungeonFrame") or main:FindFirstChild("VirusFrame")) then return true end
    if workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Enemies") then return true end
    return false
end

local inDungeon = false
for i = 1, 10 do
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
    HeightAboveEnemy = 9.0,
    TweenSpeed = 90,
    AttackSpeed = 0.25,
    LocalRoomRadius = 80,
    PortalTriggerDistance = 35
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
    teleportCooldown = tick() + 1.0

    if #portalHistory > 0 then
        local lastPortal = table.remove(portalHistory)
        if lastPortal then
            usedTeleports[lastPortal] = nil
        end
    end
end)

-- DETECTOR DE ARMA UNIVERSAL SIMPLIFICADO E BLINDADO
local function getWeaponName()
    local char = player.Character
    if char then
        -- 1. Tool equipada na mão
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and tool.Name ~= "" then
            return tool.Name
        end

        -- 2. Procura modelo de arma soldado ao braço/mão direita
        local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if rightArm then
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Model") and child.Name ~= "Animate" and not Players:GetPlayerFromCharacter(child) then
                    return child.Name
                end
            end
        end
    end

    -- 3. Backpack do player
    local bp = player:FindFirstChild("Backpack")
    if bp then
        local bpTool = bp:FindFirstChildOfClass("Tool")
        if bpTool and bpTool.Name ~= "" then
            return bpTool.Name
        end
    end

    return "Katana"
end

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

-- Detecção do Botão Engage (Main.VirusFrame.Warning.Buttons.Confirm)
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

local function checkAndClickStartButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return false end

    local main = pguiRef:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local startBtn = dungeonFrame and dungeonFrame:FindFirstChild("Start")

    if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible and dungeonFrame.Visible then
        triggerGuiButton(startBtn)
        table.clear(usedTeleports)
        table.clear(portalHistory)
        return true
    end

    return false
end

local function getClosestEnemyInRadius(maxDistance)
    local _, root = getCharacter()
    if not root then return nil, nil end

    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = (gameFolder and gameFolder:FindFirstChild("Enemies")) or workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil, nil end

    local closestEnemy, closestRoot = nil, nil
    local minDistance = maxDistance or math.huge

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        if enemy:IsA("Model") or enemy:IsA("Folder") or enemy:IsA("BasePart") then
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health > 0 then
                local targetPart = enemy:FindFirstChild("Bot") 
                    or enemy:FindFirstChild("HumanoidRootPart") 
                    or enemy:FindFirstChild("Hitbox") 
                    or enemy:FindFirstChild("Torso")
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
    end

    return closestEnemy, closestRoot
end

local function getActiveTeleport()
    if tick() < teleportCooldown then
        return nil, math.huge
    end

    local _, root = getCharacter()
    if not root then return nil, math.huge end

    local gameFolder = workspace:FindFirstChild("Game")
    local teleportsFolder = gameFolder and gameFolder:FindFirstChild("Teleports")

    if teleportsFolder then
        local closestHitbox = nil
        local minDistance = math.huge

        for _, teleportObj in ipairs(teleportsFolder:GetChildren()) do
            local hitbox = teleportObj:FindFirstChild("HitBox") or (teleportObj:IsA("BasePart") and teleportObj.Name == "HitBox" and teleportObj)
            
            if hitbox and hitbox:IsA("BasePart") and not usedTeleports[hitbox] then
                local dist = (root.Position - hitbox.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestHitbox = hitbox
                end
            end
        end

        return closestHitbox, minDistance
    end

    return nil, math.huge
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

-- Disparo Nativo de Ataque Restaurado e Estabilizado
local function executeNativeAttack()
    if isDungeonEnded then return end
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
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
end

local function farmTarget(enemy, enemyRoot)
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
end

task.spawn(function()
    while true do
        if Settings.AutoAttack and not isDungeonEnded then
            local char, _, hum = getCharacter()
            if char and hum and hum.Health > 0 then
                executeNativeAttack()
            end
        end
        task.wait(Settings.AttackSpeed)
    end
end)

task.spawn(function()
    while true do
        if Settings.AutoSkills and not isDungeonEnded then
            local char, _, hum = getCharacter()
            if char and hum and hum.Health > 0 then
                if (tick() - lastSkillUse) >= Settings.SkillCooldown then
                    lastSkillUse = tick()
                    local hotbarList = getDynamicHotbar()
                    if hotbarList then
                        local spell1 = hotbarList:FindFirstChild("Spell1", true)
                        local spell2 = hotbarList:FindFirstChild("Spell2", true)

                        if spell1 then triggerGuiButton(spell1) end
                        task.wait(0.08)
                        if spell2 then triggerGuiButton(spell2) end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

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
                    stopMovement()
                    
                    local engaged = false
                    if Settings.AutoEngage then
                        for i = 1, 20 do
                            if checkAndClickEngageButton() then
                                engaged = true
                                isDungeonEnded = false
                                task.wait(1.0)
                                break
                            end
                            task.wait(0.1)
                        end
                    end
                    
                    if not engaged then
                        isDungeonEnded = true
                        table.clear(usedTeleports)
                        table.clear(portalHistory)
                        
                        if Settings.AutoPlayAgain and playAgainBtn then
                            queueNextExecution()
                            task.wait(0.8)
                            triggerGuiButton(playAgainBtn)
                            task.wait(3.0)
                        end
                    end
                else
                    isDungeonEnded = false

                    if Settings.AutoStart and checkAndClickStartButton() then
                        stopMovement()
                        task.wait(3.0)
                    end

                    local localEnemy, localRoot = getClosestEnemyInRadius(Settings.LocalRoomRadius)

                    if localEnemy and localRoot then
                        farmTarget(localEnemy, localRoot)
                    else
                        local teleportHitbox, teleportDist = getActiveTeleport()
                        if teleportHitbox then
                            smoothFlyTo(teleportHitbox.CFrame)
                            if teleportDist <= 6 then
                                usedTeleports[teleportHitbox] = true
                                table.insert(portalHistory, teleportHitbox)
                                teleportCooldown = tick() + 3.0
                                stopMovement()
                                task.wait(1.2)
                            end
                        else
                            local distantEnemy, distantRoot = getClosestEnemyInRadius(math.huge)
                            if distantEnemy and distantRoot then
                                farmTarget(distantEnemy, distantRoot)
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
    Title = "Auto Farm Enemies",
    Description = "Start -> Farm -> Portal -> Auto Replay",
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
    Description = "Aperta 'Start' e aguarda 3s automaticamente",
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
    Title = "Auto Skills (Spell1 & Spell2)",
    Description = "Dispara automaticamente Spell1 e Spell2",
    Default = true,
    Callback = function(Value)
        Settings.AutoSkills = Value
    end
})

FarmSection:AddSlider("AttackSpeedSlider", {
    Title = "Velocidade do Ataque (segundos)",
    Default = 0.25,
    Min = 0.08,
    Max = 0.50,
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
