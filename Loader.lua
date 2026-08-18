-- ====================================================================
-- 1. TRAVA FÍSICA DE INSTÂNCIA ÚNICA (Singleton Anti-Duplicação)
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
-- 4. SISTEMA DE SALVAMENTO DE CONFIGURAÇÃO / PRESET
-- ====================================================================
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "HubRapazes_Config.json"

local Settings = {
    SelectedPhase = "Bleach (Fase 4)",
    AutoFarm = true,
    AutoAttack = true,
    AutoSkills = true,
    AutoStart = true,
    AutoPlayAgain = true,
    AutoEngage = true,
    StartWaitTime = 3.0,
    SkillCooldown = 0.8,
    SkillMaxDistance = 20,
    HeightAboveEnemy = 9.0,
    TweenSpeed = 90,
    AttackSpeed = 0.15,
    LocalFightRadius = 160 -- Raio máximo para aceitar monstros da sala atual
}

local function saveConfig()
    pcall(function()
        if writefile then
            local data = HttpService:JSONEncode({
                SelectedPhase = Settings.SelectedPhase,
                HeightAboveEnemy = Settings.HeightAboveEnemy,
                TweenSpeed = Settings.TweenSpeed,
                AttackSpeed = Settings.AttackSpeed,
                SkillCooldown = Settings.SkillCooldown
            })
            writefile(CONFIG_FILE, data)
        end
    end)
end

local function loadConfig()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local data = HttpService:JSONDecode(raw)
            if data then
                if data.SelectedPhase then Settings.SelectedPhase = data.SelectedPhase end
                if data.HeightAboveEnemy then Settings.HeightAboveEnemy = data.HeightAboveEnemy end
                if data.TweenSpeed then Settings.TweenSpeed = data.TweenSpeed end
                if data.AttackSpeed then Settings.AttackSpeed = data.AttackSpeed end
                if data.SkillCooldown then Settings.SkillCooldown = data.SkillCooldown end
            end
        end
    end)
end

loadConfig()

-- ====================================================================
-- 5. SERVIÇOS E ESTADOS GLOBAIS
-- ====================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local isScriptRunning = true
local currentTween = nil
local noclipConnection = nil
local charConnection = nil

-- Estados de Progressão Rígida (Fase 4)
local passedPortal1 = false
local passedPortal2 = false
local needsBossReturn = false

local teleportCooldown = 0
local lastSkillUse = 0
local comboIndex = 1
local isDungeonEnded = false
local dungeonReady = false
local attackRemote = nil
local cachedWeaponName = "VoidRods"

local function getCharacter()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
        return char, char.HumanoidRootPart, char.Humanoid
    end
    return nil, nil, nil
end

local function stopMovement()
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

charConnection = player.CharacterAdded:Connect(function()
    stopMovement()
    teleportCooldown = 0
    attackRemote = nil

    if passedPortal2 then
        passedPortal2 = false
        needsBossReturn = true
    end
end)

local function toggleNoclip(enable)
    if enable and isScriptRunning then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                local char, root = getCharacter()
                if char and root and Settings.AutoFarm and not isDungeonEnded and isScriptRunning then
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
    if isDungeonEnded or not isScriptRunning then return end
    local _, root = getCharacter()
    if not root or not root.Parent then return end
    
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
    if not btn or not btn.Parent or not isScriptRunning then return end
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

local function pressKey(keyCode)
    if not isScriptRunning then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- ====================================================================
-- 6. COMBATE NATIVO & INVENTÁRIO
-- ====================================================================
local function findAttackRemote()
    if attackRemote and attackRemote.Parent then return attackRemote end
    for _, container in ipairs({ReplicatedStorage, ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage:FindFirstChild("Events")}) do
        if container then
            local rem = container:FindFirstChild("Attack") or container:FindFirstChild("M1") or container:FindFirstChild("Combat")
            if rem and rem:IsA("RemoteEvent") then
                attackRemote = rem
                return attackRemote
            end
        end
    end
    return nil
end

local function getDynamicEquippedWeapon()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if pguiRef then
        local scroll = pguiRef:FindFirstChild("Scroll", true)
        if scroll and scroll.Parent and scroll.Parent.Name == "Items" then
            for _, slot in ipairs(scroll:GetChildren()) do
                if slot:IsA("GuiObject") then
                    for _, desc in ipairs(slot:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower():find("unequip") then
                            cachedWeaponName = slot.Name
                            return cachedWeaponName
                        end
                    end
                end
            end
        end
    end

    local char = player.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            cachedWeaponName = tool.Name
            return cachedWeaponName
        end
    end

    return cachedWeaponName
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

-- ====================================================================
-- 7. SCANNERS DE COMBATE LOCAL E PORTAIS
-- ====================================================================
local function getCurrentWaveNumber()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if pguiRef then
        for _, desc in ipairs(pguiRef:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                local current, total = desc.Text:match("(%d+)%s*/%s*(%d+)")
                if current then
                    return tonumber(current)
                end
            end
        end
    end
    return 1
end

local function getEntityTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    return obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("Bot")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("HitBox")
        or obj:FindFirstChild("Torso")
        or obj:FindFirstChild("UpperTorso")
        or obj:FindFirstChild("Head")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or (obj:IsA("BasePart") and obj)
        or obj:FindFirstChildWhichIsA("BasePart")
end

local function isEntityAlive(obj)
    if not obj or not obj.Parent then return false end
    
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then 
        if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
            return false
        end
        return true
    end

    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP")
    if hpAttr then return tonumber(hpAttr) > 0 end

    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") then return tonumber(hpVal.Value) > 0 end

    return getEntityTargetPart(obj) ~= nil
end

-- Retorna APENAS os inimigos vivos da área local do jogador
local function getLocalLivingEnemies()
    local list = {}
    local char, root = getCharacter()
    if not root then return list end

    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = (gameFolder and gameFolder:FindFirstChild("Enemies")) or workspace:FindFirstChild("Enemies")

    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if isEntityAlive(enemy) then
                local part = getEntityTargetPart(enemy)
                if part and (root.Position - part.Position).Magnitude <= Settings.LocalFightRadius then
                    table.insert(list, enemy)
                end
            end
        end
    end

    if #list == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= char and not Players:GetPlayerFromCharacter(obj) then
                if obj.Name:lower():find("enemy") or obj.Name:lower():find("mob") or obj.Name:lower():find("boss") or obj:FindFirstChildOfClass("Humanoid") then
                    if isEntityAlive(obj) then
                        local part = getEntityTargetPart(obj)
                        if part and (root.Position - part.Position).Magnitude <= Settings.LocalFightRadius then
                            table.insert(list, obj)
                        end
                    end
                end
            end
        end
    end

    return list
end

local function getClosestLocalEnemy()
    local _, root = getCharacter()
    if not root then return nil, nil end

    local enemies = getLocalLivingEnemies()
    local closestEnemy, closestPart = nil, nil
    local minDistance = math.huge

    for _, enemy in ipairs(enemies) do
        local targetPart = getEntityTargetPart(enemy)
        if targetPart and targetPart:IsA("BasePart") then
            local dist = (root.Position - targetPart.Position).Magnitude
            if dist < minDistance then
                minDistance = dist
                closestEnemy = enemy
                closestPart = targetPart
            end
        end
    end

    return closestEnemy, closestPart
end

-- Busca a HitBox física de um portal pelo nome (Teleport1 ou Teleport2)
local function getPortalHitBox(portalName)
    local gameFolder = workspace:FindFirstChild("Game")
    local teleportsFolder = (gameFolder and gameFolder:FindFirstChild("Teleports")) or workspace:FindFirstChild("Teleports")
    
    if teleportsFolder then
        local p = teleportsFolder:FindFirstChild(portalName)
        if p then
            return p:FindFirstChild("HitBox") or p:FindFirstChild("Hitbox") or (p:IsA("BasePart") and p) or p:FindFirstChildWhichIsA("BasePart")
        end
    end

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc.Name == portalName then
            return desc:FindFirstChild("HitBox") or desc:FindFirstChild("Hitbox") or (desc:IsA("BasePart") and desc) or desc:FindFirstChildWhichIsA("BasePart")
        end
    end

    return nil
end

-- ====================================================================
-- 8. CONTROLES DE INTERFACE (ENGAGE, START, REPLAY)
-- ====================================================================
local function checkAndClickEngageButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef or not isScriptRunning then return false end

    local main = pguiRef:FindFirstChild("Main")
    local virusFrame = main and main:FindFirstChild("VirusFrame")
    if virusFrame and virusFrame.Visible then
        local confirmBtn = virusFrame:FindFirstChild("Confirm", true) or virusFrame:FindFirstChild("Engage", true)
        if confirmBtn and confirmBtn:IsA("GuiObject") and confirmBtn.Visible then
            triggerGuiButton(confirmBtn)
            return true
        end
    end

    for _, desc in ipairs(pguiRef:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            local txt = desc:IsA("TextButton") and desc.Text:lower() or desc.Name:lower()
            if txt:find("engage") or (txt:find("confirm") and desc:FindFirstAncestorWhichIsA("Frame") and desc:FindFirstAncestorWhichIsA("Frame").Name:lower():find("virus")) then
                triggerGuiButton(desc)
                return true
            end
        end
    end

    return false
end

local function checkDungeonEnd()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef or not isScriptRunning then return false end

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
    if not pguiRef or not isScriptRunning then return false end

    local main = pguiRef:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    
    if dungeonFrame and dungeonFrame.Visible then
        local startBtn = dungeonFrame:FindFirstChild("Start") or dungeonFrame:FindFirstChild("Play")
        if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
            triggerGuiButton(startBtn)
            task.wait(Settings.StartWaitTime)
            dungeonReady = true
            return true
        end
    end
    return false
end

-- ====================================================================
-- 9. TRAVA E EXECUÇÃO DE COMBATE
-- ====================================================================
local function isPortalTransitionActive()
    local wave = getCurrentWaveNumber()
    local localEnemies = getLocalLivingEnemies()

    if needsBossReturn then return true end
    if not passedPortal1 and (wave >= 8 or #localEnemies == 0) then return true end
    if passedPortal1 and not passedPortal2 and (wave >= 12 or #localEnemies == 0) then return true end
    return false
end

local function executeNativeAttack()
    if isDungeonEnded or not isScriptRunning or isPortalTransitionActive() then return end
    comboIndex = (comboIndex % 4) + 1
    local weapon = getDynamicEquippedWeapon()

    local rem = findAttackRemote()
    if rem then
        pcall(function()
            rem:FireServer("M1", weapon, comboIndex, 0, 0, 2)
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

task.spawn(function()
    while isScriptRunning do
        if Settings.AutoAttack and not isDungeonEnded and not isPortalTransitionActive() then
            local char, _, hum = getCharacter()
            if char and hum and hum.Health > 0 then
                executeNativeAttack()
            end
        end
        task.wait(Settings.AttackSpeed)
    end
end)

task.spawn(function()
    while isScriptRunning do
        if Settings.AutoSkills and not isDungeonEnded and not isPortalTransitionActive() then
            local char, root, hum = getCharacter()
            if char and root and hum and hum.Health > 0 then
                if (tick() - lastSkillUse) >= Settings.SkillCooldown then
                    local _, enemyPart = getClosestLocalEnemy()
                    if enemyPart and enemyPart.Parent then
                        local distance = (root.Position - enemyPart.Position).Magnitude
                        if distance <= Settings.SkillMaxDistance then
                            lastSkillUse = tick()
                            local hotbarList = getDynamicHotbar()
                            if hotbarList then
                                local spell1 = hotbarList:FindFirstChild("Spell1", true) or hotbarList:FindFirstChild("Z", true)
                                local spell2 = hotbarList:FindFirstChild("Spell2", true) or hotbarList:FindFirstChild("X", true)
                                local ultimateBtn = hotbarList:FindFirstChild("Ultimate", true) or hotbarList:FindFirstChild("Spell3", true) or hotbarList:FindFirstChild("C", true)

                                if spell1 then triggerGuiButton(spell1) else pressKey(Enum.KeyCode.Z) end
                                task.wait(0.06)
                                if spell2 then triggerGuiButton(spell2) else pressKey(Enum.KeyCode.X) end
                                task.wait(0.06)
                                if ultimateBtn then triggerGuiButton(ultimateBtn) end
                                pressKey(Enum.KeyCode.C)
                            else
                                pressKey(Enum.KeyCode.Z)
                                task.wait(0.06)
                                pressKey(Enum.KeyCode.X)
                                task.wait(0.06)
                                pressKey(Enum.KeyCode.C)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- ====================================================================
-- 10. MÁQUINA DE ESTADOS DA FASE BLEACH
-- ====================================================================
local function forceTeleportThrough(hitbox)
    local char, root = getCharacter()
    if not root or not hitbox then return false end

    local initialPos = root.Position
    local dist = (root.Position - hitbox.Position).Magnitude

    if dist > 8 then
        smoothFlyTo(hitbox.CFrame)
    else
        stopMovement()
        root.CFrame = hitbox.CFrame
        
        if firetouchinterest then
            pcall(function()
                firetouchinterest(root, hitbox, 0)
                task.wait(0.05)
                firetouchinterest(root, hitbox, 1)
            end)
        end
        
        task.wait(0.4)
        local postDist = (root.Position - initialPos).Magnitude
        if postDist > 30 then
            return true -- Confirmou mudança de área
        end
    end
    return false
end

local function runBleachPhaseFlow()
    local localEnemies = getLocalLivingEnemies()
    local wave = getCurrentWaveNumber()

    -- 1. MORTE NO BOSS: Força retorno pelo Teleport2
    if needsBossReturn then
        local p2 = getPortalHitBox("Teleport2")
        if p2 then
            if forceTeleportThrough(p2) then
                passedPortal2 = true
                needsBossReturn = false
                teleportCooldown = tick() + 2.0
            end
            return
        else
            needsBossReturn = false
        end
    end

    -- 2. BLOQUEIO OBRIGATÓRIO SALA 1 -> ENTRA NO TELEPORT 1
    if not passedPortal1 and (wave >= 8 or #localEnemies == 0) then
        local p1 = getPortalHitBox("Teleport1")
        if p1 then
            if forceTeleportThrough(p1) then
                passedPortal1 = true
                teleportCooldown = tick() + 2.0
            end
            return
        else
            passedPortal1 = true
        end
    end

    -- 3. BLOQUEIO OBRIGATÓRIO SALA 2 -> ENTRA NO TELEPORT 2
    if passedPortal1 and not passedPortal2 and (wave >= 12 or #localEnemies == 0) then
        local p2 = getPortalHitBox("Teleport2")
        if p2 then
            if forceTeleportThrough(p2) then
                passedPortal2 = true
                teleportCooldown = tick() + 2.0
            end
            return
        else
            passedPortal2 = true
        end
    end

    -- 4. COMBATE NORMAL NA ÁREA ATUAL
    if #localEnemies > 0 then
        local enemy, enemyPart = getClosestLocalEnemy()
        if enemy and enemyPart then
            while isScriptRunning and Settings.AutoFarm and not isDungeonEnded and enemy.Parent and enemyPart.Parent and isEntityAlive(enemy) and not isPortalTransitionActive() do
                local _, currentRoot = getCharacter()
                if not currentRoot then break end

                local abovePos = enemyPart.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
                local targetCFrame = CFrame.new(abovePos, enemyPart.Position)
                smoothFlyTo(targetCFrame)
                task.wait(0.05)
            end
        end
    else
        stopMovement()
    end
end

-- Loop Principal de Decisão
task.spawn(function()
    while isScriptRunning do
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
                    passedPortal1 = false
                    passedPortal2 = false
                    needsBossReturn = false
                    stopMovement()
                    
                    if Settings.AutoPlayAgain and playAgainBtn then
                        queueNextExecution()
                        task.wait(0.8)
                        triggerGuiButton(playAgainBtn)
                        task.wait(3.0)
                    end
                else
                    isDungeonEnded = false

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
                        if Settings.SelectedPhase == "Bleach (Fase 4)" then
                            runBleachPhaseFlow()
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

-- ====================================================================
-- 11. INTERFACE FLUENT LIMPA E BOTÃO FLUTUANTE
-- ====================================================================
local Window = Fluent:CreateWindow({
    Title = "Hub dos Rapazes",
    SubTitle = "Anime Dungeons",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 380),
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

local function destroyScript()
    isScriptRunning = false
    Settings.AutoFarm = false
    Settings.AutoAttack = false
    Settings.AutoSkills = false
    
    stopMovement()
    toggleNoclip(false)
    
    if charConnection then
        charConnection:Disconnect()
        charConnection = nil
    end

    if singletonTag and singletonTag.Parent then
        singletonTag:Destroy()
    end
    local st = CoreGui:FindFirstChild(UNIQUE_ID)
    if st then st:Destroy() end

    if toggleGui and toggleGui.Parent then
        toggleGui:Destroy()
    end
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name:find("Fluent") or child.Name == "IBdihP_PersistentToggle" then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

task.spawn(function()
    task.wait(0.8)
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, btn in ipairs(gui:GetDescendants()) do
            if (btn:IsA("ImageButton") or btn:IsA("TextButton")) then
                if btn.Name:lower():find("close") then
                    btn.MouseButton1Click:Connect(function()
                        destroyScript()
                    end)
                elseif btn.Name:lower():find("min") then
                    btn.MouseButton1Click:Connect(function()
                        toggleUI(false)
                    end)
                end
            end
        end
    end
end)

local PhaseSection = Tabs.Farm:AddSection("Fase Ativa")

PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "Bleach (Fase 4)" },
    Default = Settings.SelectedPhase,
    Callback = function(Value)
        Settings.SelectedPhase = Value
        saveConfig()
        passedPortal1 = false
        passedPortal2 = false
        needsBossReturn = false
    end
})

local CombatSection = Tabs.Farm:AddSection("Controles de Farm")

CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Description = "Executa a rota mapeada da fase selecionada",
    Default = true,
    Callback = function(Value)
        Settings.AutoFarm = Value
        toggleNoclip(Value)
        if not Value then
            stopMovement()
        end
    end
})

CombatSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Boss Secreto)",
    Description = "Clica automaticamente em Engage/Confirm em qualquer fase",
    Default = true,
    Callback = function(Value)
        Settings.AutoEngage = Value
    end
})

CombatSection:AddToggle("AutoPlayAgainToggle", {
    Title = "Auto Play Again",
    Description = "Reinicia a partida automaticamente ao vencer/perder",
    Default = true,
    Callback = function(Value)
        Settings.AutoPlayAgain = Value
    end
})

CombatSection:AddToggle("AutoStartToggle", {
    Title = "Auto Start Dungeon",
    Description = "Inicia a fase sozinho (espera 3s)",
    Default = true,
    Callback = function(Value)
        Settings.AutoStart = Value
    end
})

CombatSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1)",
    Description = "Dispara os ataques básicos continuamente",
    Default = true,
    Callback = function(Value)
        Settings.AutoAttack = Value
    end
})

CombatSection:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills (Z, X e Ultimate)",
    Description = "Dispara skills apenas perto de inimigos",
    Default = true,
    Callback = function(Value)
        Settings.AutoSkills = Value
    end
})

CombatSection:AddSlider("SkillMaxDistSlider", {
    Title = "Distância das Skills (studs)",
    Default = Settings.SkillMaxDistance,
    Min = 8,
    Max = 40,
    Rounding = 0,
    Callback = function(Value)
        Settings.SkillMaxDistance = Value
    end
})

CombatSection:AddSlider("AttackSpeedSlider", {
    Title = "Velocidade do Ataque (segundos)",
    Default = Settings.AttackSpeed,
    Min = 0.04,
    Max = 0.35,
    Rounding = 2,
    Callback = function(Value)
        Settings.AttackSpeed = Value
        saveConfig()
    end
})

CombatSection:AddSlider("SkillCooldownSlider", {
    Title = "Intervalo das Skills (segundos)",
    Default = Settings.SkillCooldown,
    Min = 0.2,
    Max = 4,
    Rounding = 1,
    Callback = function(Value)
        Settings.SkillCooldown = Value
        saveConfig()
    end
})

CombatSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura acima do Inimigo",
    Default = Settings.HeightAboveEnemy,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        Settings.HeightAboveEnemy = Value
        saveConfig()
    end
})

CombatSection:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo",
    Default = Settings.TweenSpeed,
    Min = 20,
    Max = 160,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
        saveConfig()
    end
})

local SettingsSection = Tabs.Settings:AddSection("Gerenciamento do Script")

SettingsSection:AddButton({
    Title = "Encerrar Script por Completo",
    Description = "Para todos os loops e libera o carregamento de uma nova versão",
    Callback = function()
        destroyScript()
    end
})

Window:SelectTab(Tabs.Farm)
