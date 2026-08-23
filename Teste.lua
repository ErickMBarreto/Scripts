-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (FIX SERVER TELEPORT OVERRIDE)
-- ====================================================================

-- [[ 1. SINGLETON & BOOTSTRAP ]]
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local UNIQUE_ID = "HubRapazes_Singleton_Tag"
if CoreGui:FindFirstChild(UNIQUE_ID) then return end

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

local scriptURL = "https://raw.githubusercontent.com/ErickMBarreto/Scripts/refs/heads/main/Teste.lua"
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

if not game:IsLoaded() then game.Loaded:Wait() end
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pgui = player:WaitForChild("PlayerGui", 20)

local function isInsideDungeon()
    local main = pgui and pgui:FindFirstChild("Main")
    if main and (main:FindFirstChild("DungeonFrame") or main:FindFirstChild("VirusFrame")) then return true end
    if workspace:FindFirstChild("Game") and (workspace.Game:FindFirstChild("Enemies") or workspace.Game:FindFirstChild("Teleports") or workspace.Game:FindFirstChild("Stages")) then return true end
    if workspace:FindFirstChild("Enemies") then return true end
    return false
end

local inDungeon = false
for _ = 1, 15 do
    if isInsideDungeon() then inDungeon = true break end
    task.wait(0.5)
end
if not inDungeon then
    pcall(function() singletonTag:Destroy() end)
    return
end

local SharedState = {
    IsRunning = true,
    IsRespawning = false,
    IsTransitioning = false,
    EnteringPortal = false,
    IsVirusActive = false,
    IsSelling = false,
    IsClaiming = false,
    IsDungeonEnded = false,
    LastRoomState = "Room1",
    CurrentTween = nil,
    CurrentTargetPos = nil,
    LastPortalAttempt = 0
}

-- [[ 2. CONFIGURAÇÕES ]]
local ConfigModule = {}
ConfigModule.Settings = {
    SelectedPhase = "One Piece",
    PositionMode = "Em Cima da Cabeça",
    CustomWeaponName = "VoidRods",
    AutoFarm = true,
    AutoAttack = true,
    AutoSkills = true,
    AutoStart = true,
    AutoPlayAgain = true,
    AutoEngage = true,
    HardcoreMode = false,
    StartWaitTime = 2.0,
    SkillCooldown = 0.8,
    SkillMaxDistance = 22,
    HeightAboveEnemy = 8.5,
    BackDistance = 6.0,
    TweenSpeed = 48,
    AttackSpeed = 0.15,
    AutoClaimQuests = false
}

local CONFIG_FILE = "HubRapazes_Config.json"

function ConfigModule.Save()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigModule.Settings))
        end
    end)
end

function ConfigModule.Load()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if data then
                for k, v in pairs(data) do
                    if ConfigModule.Settings[k] ~= nil then
                        ConfigModule.Settings[k] = v
                    end
                end
            end
        end
    end)
end
ConfigModule.Load()

-- [[ 3. MÓDULO DE PERSONAGEM & FÍSICA ]]
local CharacterModule = {}
local diedConnection = nil
local charConnection = nil
local flightStabilizer = nil

function CharacterModule.Get()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
        return char, char.HumanoidRootPart, char.Humanoid
    end
    return nil, nil, nil
end

function CharacterModule.StopMovement()
    if SharedState.CurrentTween then
        SharedState.CurrentTween:Cancel()
        SharedState.CurrentTween = nil
    end
    SharedState.CurrentTargetPos = nil
    local _, root = CharacterModule.Get()
    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

function CharacterModule.ApplyPhysicsStabilizers(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CanCollide = false
    end
end

flightStabilizer = RunService.Stepped:Connect(function()
    if SharedState.IsRunning and ConfigModule.Settings.AutoFarm and not SharedState.IsRespawning and not SharedState.EnteringPortal and not SharedState.IsTransitioning then
        local _, root, hum = CharacterModule.Get()
        if root and hum and hum.Health > 0 then
            if not SharedState.CurrentTween then
                root.AssemblyLinearVelocity = Vector3.new(0, 0.05, 0)
                root.AssemblyAngularVelocity = Vector3.zero
            else
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

function CharacterModule.GetSafeCFrame(targetPosition, lookAtPosition)
    local char = player.Character
    local rayOrigin = targetPosition + Vector3.new(0, 20, 0)
    local rayDirection = Vector3.new(0, -50, 0)
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if char then
        params.FilterDescendantsInstances = {char}
    end
    
    local hit = workspace:Raycast(rayOrigin, rayDirection, params)
    local safeY = targetPosition.Y

    if hit then
        local floorY = hit.Position.Y
        if safeY < (floorY + 3.5) then
            safeY = floorY + 3.5
        end
    end

    local safePos = Vector3.new(targetPosition.X, safeY, targetPosition.Z)
    return CFrame.new(safePos, lookAtPosition)
end

function CharacterModule.FlyToEnemy(targetPart)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.EnteringPortal or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not targetPart or not targetPart.Parent then return end

    local enemyPos = targetPart.Position
    if enemyPos.Magnitude > 20000 or enemyPos.Y > 500 or enemyPos.Y < -800 then
        CharacterModule.StopMovement()
        return
    end

    local mode = ConfigModule.Settings.PositionMode
    local targetCFrame

    if mode == "Em Cima da Cabeça" then
        local abovePos = enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1)
        targetCFrame = CFrame.lookAt(abovePos, enemyPos)
    elseif mode == "Nas Costas" then
        local lookVec = targetPart.CFrame.LookVector
        if lookVec.Magnitude > 0.1 then
            local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 2.5, 0)
            local backPos = enemyPos + backOffset
            targetCFrame = CFrame.lookAt(backPos, enemyPos)
        else
            targetCFrame = CFrame.lookAt(enemyPos + Vector3.new(0, 5, 5), enemyPos)
        end
    else
        local abovePos = enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0)
        targetCFrame = CharacterModule.GetSafeCFrame(abovePos, enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude

    if distance <= 1.2 then return end

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 1.8 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.08, 3.5)

    if SharedState.CurrentTween then 
        SharedState.CurrentTween:Cancel() 
    end

    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.FlyToPortal(targetCFrame)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not root.Parent then return end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.1, 5.0)

    if SharedState.CurrentTween then 
        SharedState.CurrentTween:Cancel() 
    end

    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.TriggerButton(btn)
    if not btn or not SharedState.IsRunning then return end
    pcall(function()
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
            if btn[evName] and firesignal then firesignal(btn[evName]) end
            if btn[evName] and getconnections then
                for _, c in ipairs(getconnections(btn[evName])) do c:Fire() end
            end
        end
    end)
end

function CharacterModule.PressKey(keyCode)
    if not SharedState.IsRunning then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- [[ 4. MÓDULO DE DETECÇÃO DE INIMIGOS ]]
local TargetingModule = {}

function TargetingModule.IsAlive(obj)
    if not obj or not obj.Parent then return false end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then return (hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead) end
    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP")
    if hpAttr then return tonumber(hpAttr) > 0 end
    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") then return tonumber(hpVal.Value) > 0 end
    return false
end

function TargetingModule.GetTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    return obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("HitBox")
        or obj:FindFirstChild("Head")
        or obj:FindFirstChild("Torso")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or obj:FindFirstChildWhichIsA("BasePart")
end

function TargetingModule.GetLivingEnemies(phase)
    local list = {}
    local char = player.Character
    local registered = {}

    local function addEntity(mob)
        if mob and mob:IsA("Model") and mob ~= char and not registered[mob] and not Players:GetPlayerFromCharacter(mob) then
            if TargetingModule.IsAlive(mob) and TargetingModule.GetTargetPart(mob) then
                registered[mob] = true
                table.insert(list, mob)
            end
        end
    end

    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = (gameFolder and gameFolder:FindFirstChild("Enemies")) or workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do addEntity(enemy) end
    end

    if SharedState.IsVirusActive or phase == "Incursão" then
        local virusFolder = (gameFolder and (gameFolder:FindFirstChild("Virus") or gameFolder:FindFirstChild("Boss") or gameFolder:FindFirstChild("SecretBoss"))) or workspace:FindFirstChild("Virus")
        if virusFolder then
            for _, mob in ipairs(virusFolder:GetChildren()) do addEntity(mob) end
            if TargetingModule.IsAlive(virusFolder) then addEntity(virusFolder) end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= char and not Players:GetPlayerFromCharacter(obj) then
                local name = obj.Name:lower()
                if name:find("mob") or name:find("enemy") or name:find("boss") or name:find("virus") or obj:FindFirstChildOfClass("Humanoid") then
                    addEntity(obj)
                end
            end
        end
    end

    if #list == 0 and gameFolder and gameFolder:FindFirstChild("Stages") then
        for _, stage in ipairs(gameFolder.Stages:GetChildren()) do
            local spawns = stage:FindFirstChild("Spawns") or stage
            for _, mob in ipairs(spawns:GetChildren()) do addEntity(mob) end
        end
    end

    return list
end

function TargetingModule.GetClosestEnemy(phase)
    local _, root = CharacterModule.Get()
    if not root then return nil, nil end

    local enemies = TargetingModule.GetLivingEnemies(phase)
    local closestEnemy, closestPart = nil, nil
    local minDistance = math.huge

    for _, enemy in ipairs(enemies) do
        local targetPart = TargetingModule.GetTargetPart(enemy)
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

-- [[ 5. MÓDULO DE COMBATE ]]
local CombatModule = {}
local attackRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Attack", 10)
local lastSkillUse = 0
local comboIndex = 1

function CombatModule.DetectWeapon()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if pguiRef then
        for _, desc in ipairs(pguiRef:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
                local txt = desc.Text:lower()
                if txt:find("unequip") or txt:find("desequipar") or txt:find("equipped") then
                    local parentSlot = desc:FindFirstAncestorWhichIsA("Frame") or desc:FindFirstAncestorWhichIsA("ImageLabel") or desc.Parent
                    if parentSlot and parentSlot.Name ~= "Items" and parentSlot.Name ~= "Scroll" then
                        return parentSlot.Name
                    end
                end
            end
        end
    end

    local char = player.Character
    if char and char:FindFirstChildOfClass("Tool") then return char:FindFirstChildOfClass("Tool").Name end
    local bp = player:FindFirstChild("Backpack")
    if bp and bp:FindFirstChildOfClass("Tool") then return bp:FindFirstChildOfClass("Tool").Name end
    return nil
end

function CombatModule.GetEffectiveWeapon()
    if ConfigModule.Settings.CustomWeaponName and ConfigModule.Settings.CustomWeaponName ~= "" then
        return ConfigModule.Settings.CustomWeaponName
    end
    return CombatModule.DetectWeapon() or "VoidRods"
end

function CombatModule.GetHotbar()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return nil end
    local mainGui = pguiRef:FindFirstChild("Main")
    if mainGui and mainGui:FindFirstChild("FrontFrame") and mainGui.FrontFrame:FindFirstChild("Hotbar") then
        return mainGui.FrontFrame.Hotbar:FindFirstChild("List") or mainGui.FrontFrame.Hotbar
    end
    return nil
end

function CombatModule.ExecuteM1()
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.EnteringPortal or not SharedState.IsRunning then return end
    comboIndex = (comboIndex % 4) + 1
    local weapon = CombatModule.GetEffectiveWeapon()
    if attackRemote then pcall(function() attackRemote:FireServer("M1", weapon, comboIndex, 0, 0, 2) end) end

    local char = player.Character
    if char and char:FindFirstChildOfClass("Tool") then pcall(function() char:FindFirstChildOfClass("Tool"):Activate() end) end
end

function CombatModule.ExecuteSkills()
    if (tick() - lastSkillUse) < ConfigModule.Settings.SkillCooldown then return end
    local _, root = CharacterModule.Get()
    if not root then return end

    local _, enemyPart = TargetingModule.GetClosestEnemy(ConfigModule.Settings.SelectedPhase)
    if enemyPart and (root.Position - enemyPart.Position).Magnitude <= ConfigModule.Settings.SkillMaxDistance then
        lastSkillUse = tick()
        local hotbarList = CombatModule.GetHotbar()
        if hotbarList then
            local s1 = hotbarList:FindFirstChild("Spell1", true) or hotbarList:FindFirstChild("Z", true)
            local s2 = hotbarList:FindFirstChild("Spell2", true) or hotbarList:FindFirstChild("X", true)
            local s3 = hotbarList:FindFirstChild("Ultimate", true) or hotbarList:FindFirstChild("Spell3", true) or hotbarList:FindFirstChild("C", true)

            if s1 then CharacterModule.TriggerButton(s1) else CharacterModule.PressKey(Enum.KeyCode.Z) end
            task.wait(0.06)
            if s2 then CharacterModule.TriggerButton(s2) else CharacterModule.PressKey(Enum.KeyCode.X) end
            task.wait(0.06)
            if s3 then CharacterModule.TriggerButton(s3) end
            CharacterModule.PressKey(Enum.KeyCode.C)
        else
            CharacterModule.PressKey(Enum.KeyCode.Z)
            task.wait(0.06)
            CharacterModule.PressKey(Enum.KeyCode.X)
            task.wait(0.06)
            CharacterModule.PressKey(Enum.KeyCode.C)
        end
    end
end

-- [[ 6. MÓDULO DE MISSÕES ]]
local QuestModule = {}
local questRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Quest", 10)

function QuestModule.ClaimAll()
    if not ConfigModule.Settings.AutoClaimQuests or SharedState.IsClaiming or not SharedState.IsRunning then return end
    local main = pgui:FindFirstChild("Main")
    local mainFrame = main and main:FindFirstChild("MainFrame")
    local questsFrame = mainFrame and mainFrame:FindFirstChild("Quests")
    local questsHolder = questsFrame and questsFrame:FindFirstChild("QuestsHolder")
    local claimBtn = questsFrame and questsFrame:FindFirstChild("Information") and questsFrame.Information:FindFirstChild("Claim")
    if not questsFrame or not questsHolder or not claimBtn then return end

    SharedState.IsClaiming = true
    local originalVisible = questsFrame.Visible
    questsFrame.Visible = false

    local tabs = {
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Hourly"),
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Daily"),
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Weekly")
    }

    local claimed = 0
    for _, tab in ipairs(tabs) do
        if tab then
            CharacterModule.TriggerButton(tab)
            task.wait(0.12)
            for _, slot in ipairs(questsHolder:GetChildren()) do
                if slot:IsA("GuiButton") then
                    local pLabel = slot:FindFirstChild("QuestProgress", true)
                    if pLabel and pLabel:IsA("TextLabel") then
                        local txt = pLabel.Text:lower()
                        if txt == "claim" or txt == "resgatar" or txt == "completed" then
                            CharacterModule.TriggerButton(slot)
                            task.wait(0.1)
                            CharacterModule.TriggerButton(claimBtn)
                            if questRemote then
                                pcall(function()
                                    questRemote:FireServer("Claim", slot.Name)
                                    questRemote:FireServer(slot.Name)
                                    local num = tonumber(slot.Name:match("%d+"))
                                    if num then questRemote:FireServer(num) end
                                end)
                            end
                            claimed = claimed + 1
                            task.wait(0.12)
                        end
                    end
                end
            end
        end
    end

    questsFrame.Visible = originalVisible
    if claimed > 0 then
        Fluent:Notify({ Title = "Quests Resgatadas", Content = string.format("%d missões coletadas!", claimed), Duration = 3.5 })
    end
    SharedState.IsClaiming = false
end

-- [[ 7. MÓDULO DE FLUXO & PORTAIS COM PAUSA DE SERVIDOR ]]
local FlowModule = {}

local BLEACH_PORTAL_1 = CFrame.new(4557.2, -305.5, 1925.0)
local BLEACH_PORTAL_2 = CFrame.new(5411.5, -561.0, 2550.0)

local OP_PORTAL_1_WAVE7  = CFrame.new(1196.6, -240.9, 1855.1)
local OP_PORTAL_2_WAVE12 = CFrame.new(2909.3, -105.7, 2151.7)

function FlowModule.GetWave()
    local stageLabel = pgui and pgui:FindFirstChild("Main")
        and pgui.Main:FindFirstChild("DungeonFrame")
        and pgui.Main.DungeonFrame:FindFirstChild("StatsHolder")
        and pgui.Main.DungeonFrame.StatsHolder:FindFirstChild("Stage")
        and pgui.Main.DungeonFrame.StatsHolder.Stage:FindFirstChild("Amount")

    if stageLabel and stageLabel:IsA("TextLabel") and stageLabel.Visible and stageLabel.Text ~= "" then
        local cur = stageLabel.Text:match("(%d+)%s*/%s*%d+") or stageLabel.Text:match("(%d+)")
        if cur then
            local n = tonumber(cur)
            if n and n >= 1 and n <= 15 then return n end
        end
    end
    return 1
end

local function triggerZoneTouch(targetPos)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not firetouchinterest then return end

    local gameFolder = workspace:FindFirstChild("Game")
    local tps = (gameFolder and gameFolder:FindFirstChild("Teleports")) or workspace:FindFirstChild("Teleports")
    if tps then
        for _, part in ipairs(tps:GetDescendants()) do
            if part:IsA("BasePart") and (part.Position - targetPos).Magnitude < 30 then
                pcall(function()
                    firetouchinterest(root, part, 0)
                    task.wait(0.04)
                    firetouchinterest(root, part, 1)
                end)
            end
        end
    end
end

function FlowModule.PassPortal(targetCFrame)
    local _, root, hum = CharacterModule.Get()
    if not root or not hum then return end

    if SharedState.EnteringPortal and (tick() - SharedState.LastPortalAttempt) > 4.0 then
        SharedState.EnteringPortal = false
    end

    if SharedState.EnteringPortal then return end

    local dist = (root.Position - targetCFrame.Position).Magnitude

    if dist > 5.0 then
        CharacterModule.FlyToPortal(targetCFrame)
    else
        SharedState.EnteringPortal = true
        SharedState.LastPortalAttempt = tick()
        CharacterModule.StopMovement()

        -- 1. Pousa o boneco na coordenada do chão
        root.CanCollide = true
        root.CFrame = targetCFrame * CFrame.new(0, -0.5, 0)
        triggerZoneTouch(targetCFrame.Position)

        -- 2. PAUSA O SCRIPT E ESPERA O SERVIDOR EXECUTAR O TELEPORTE
        local oldPos = root.Position
        local startWait = tick()
        local tpSuccess = false

        while (tick() - startWait) < 3.0 do
            task.wait(0.1)
            local _, curRoot = CharacterModule.Get()
            if curRoot and (curRoot.Position - oldPos).Magnitude > 60 then
                tpSuccess = true
                break
            end
            if curRoot then
                triggerZoneTouch(targetCFrame.Position)
            end
        end

        -- 3. Respiro pós-teleporte para carregar a sala sem sobreposição de CFrame
        if tpSuccess then
            task.wait(0.6)
        end

        local _, finalRoot = CharacterModule.Get()
        if finalRoot then
            finalRoot.CanCollide = false
            finalRoot.AssemblyLinearVelocity = Vector3.zero
        end

        SharedState.EnteringPortal = false
    end
end

-- Rota Bleach
function FlowModule.RunBleach()
    local _, root = CharacterModule.Get()
    if not root then return end

    if SharedState.IsVirusActive then
        local _, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
        if enemyPart then
            CharacterModule.FlyToEnemy(enemyPart)
        else
            CharacterModule.StopMovement()
        end
        return
    end

    local currentRoom = "Room1"
    if root.Position.Y < -450 then
        currentRoom = "Room2"
    elseif root.Position.Y > -400 and root.Position.Z > 2800 then
        currentRoom = "BossRoom"
    end

    if currentRoom ~= SharedState.LastRoomState then
        SharedState.LastRoomState = currentRoom
        CharacterModule.StopMovement()
        SharedState.EnteringPortal = false
        SharedState.IsTransitioning = true
        task.wait(0.4)
        SharedState.IsTransitioning = false
        return
    end

    if SharedState.EnteringPortal then return end
    local wave = FlowModule.GetWave()

    if wave >= 12 and currentRoom ~= "BossRoom" then
        FlowModule.PassPortal(BLEACH_PORTAL_2)
        return
    end
    if wave >= 8 and currentRoom == "Room1" then
        FlowModule.PassPortal(BLEACH_PORTAL_1)
        return
    end

    local _, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
    if enemyPart then
        CharacterModule.FlyToEnemy(enemyPart)
    else
        CharacterModule.StopMovement()
    end
end

-- Rota One Piece
function FlowModule.RunOnePiece()
    local _, root = CharacterModule.Get()
    if not root then return end

    if SharedState.IsVirusActive then
        local _, enemyPart = TargetingModule.GetClosestEnemy("One Piece")
        if enemyPart then
            CharacterModule.FlyToEnemy(enemyPart)
        else
            CharacterModule.StopMovement()
        end
        return
    end

    local currentRoom = "Room1"
    if root.Position.X >= 2200 and root.Position.X <= 2650 and root.Position.Z >= 1950 then
        currentRoom = "BossRoom"
    elseif root.Position.X >= 1400 then
        currentRoom = "Room2"
    end

    if currentRoom ~= SharedState.LastRoomState then
        SharedState.LastRoomState = currentRoom
        CharacterModule.StopMovement()
        SharedState.EnteringPortal = false
        SharedState.IsTransitioning = true
        task.wait(0.4)
        SharedState.IsTransitioning = false
        return
    end

    if SharedState.EnteringPortal then return end
    local wave = FlowModule.GetWave()

    -- Sequenciamento de Portais
    if wave >= 12 then
        if currentRoom == "Room1" then
            FlowModule.PassPortal(OP_PORTAL_1_WAVE7)
            return
        elseif currentRoom == "Room2" then
            FlowModule.PassPortal(OP_PORTAL_2_WAVE12)
            return
        end
    elseif wave >= 7 and currentRoom == "Room1" then
        FlowModule.PassPortal(OP_PORTAL_1_WAVE7)
        return
    end

    local _, enemyPart = TargetingModule.GetClosestEnemy("One Piece")
    if enemyPart then
        CharacterModule.FlyToEnemy(enemyPart)
    else
        CharacterModule.StopMovement()
    end
end

-- Rota Incursão
function FlowModule.RunIncursion()
    local _, enemyPart = TargetingModule.GetClosestEnemy("Incursão")
    if enemyPart then
        CharacterModule.FlyToEnemy(enemyPart)
    else
        CharacterModule.StopMovement()
    end
end

-- [[ 8. MÓDULO DE ESTADOS DA DUNGEON ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    local df = pgui and pgui:FindFirstChild("Main") and pgui.Main:FindFirstChild("DungeonFrame")
    if df and df.Visible then
        local startBtn = df:FindFirstChild("Start") or df:FindFirstChild("Play")
        if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
            CharacterModule.TriggerButton(startBtn)
            SharedState.IsVirusActive = false
        end
    end
end

function DungeonStateModule.CheckEngage()
    local main = pgui and pgui:FindFirstChild("Main")
    local virusFrame = main and main:FindFirstChild("VirusFrame")
    if virusFrame and virusFrame.Visible then
        local confirmBtn = virusFrame:FindFirstChild("Confirm", true) or virusFrame:FindFirstChild("Engage", true)
        if confirmBtn and confirmBtn:IsA("GuiObject") and confirmBtn.Visible then
            CharacterModule.TriggerButton(confirmBtn)
            SharedState.IsVirusActive = true
            SharedState.IsDungeonEnded = false
            return true
        end
    end
    return false
end

function DungeonStateModule.CheckEnd()
    local main = pgui and pgui:FindFirstChild("Main")
    local dungeonStats = main and main:FindFirstChild("DungeonFrame") and main.MainFrame and main.DungeonFrame:FindFirstChild("DungeonStats")
    dungeonStats = dungeonStats or (main and main:FindFirstChild("DungeonFrame") and main.DungeonFrame:FindFirstChild("DungeonStats"))
    local playAgainBtn = dungeonStats and dungeonStats:FindFirstChild("EndActions") and dungeonStats.EndActions:FindFirstChild("PlayAgain")

    if dungeonStats and dungeonStats.Visible and playAgainBtn and playAgainBtn.Visible then
        return true, playAgainBtn
    end
    return false, nil
end

local function onPlayerDiedHandler()
    CharacterModule.StopMovement()
    SharedState.EnteringPortal = false
    SharedState.IsTransitioning = false
    SharedState.LastRoomState = "Room1"

    if not ConfigModule.Settings.HardcoreMode then return end
    task.spawn(function()
        task.wait(23)
        if not SharedState.IsRunning or not ConfigModule.Settings.HardcoreMode or not ConfigModule.Settings.AutoPlayAgain then return end
        CharacterModule.StopMovement()
        local _, retryBtn = DungeonStateModule.CheckEnd()
        if retryBtn then
            queueNextExecution()
            task.wait(0.5)
            CharacterModule.TriggerButton(retryBtn)
            task.wait(3.0)
        end
    end)
end

local function bindCharacterEvents(char)
    if not char then return end
    CharacterModule.ApplyPhysicsStabilizers(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        if diedConnection then diedConnection:Disconnect() end
        diedConnection = hum.Died:Connect(onPlayerDiedHandler)
    end
end

if player.Character then bindCharacterEvents(player.Character) end
charConnection = player.CharacterAdded:Connect(function(newChar)
    SharedState.IsRespawning = true
    SharedState.IsTransitioning = false
    SharedState.EnteringPortal = false
    SharedState.LastRoomState = "Room1"
    CharacterModule.StopMovement()
    bindCharacterEvents(newChar)
    task.delay(0.8, function() SharedState.IsRespawning = false end)
end)

-- [[ 9. MOTOR PRINCIPAL DE LOOPS ]]
local initialRoutinesScheduled = false

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then CombatModule.ExecuteM1() end
        end
        task.wait(ConfigModule.Settings.AttackSpeed)
    end
end)

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoSkills and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then CombatModule.ExecuteSkills() end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoFarm and not SharedState.IsRespawning then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then
                if not initialRoutinesScheduled then
                    initialRoutinesScheduled = true
                    task.spawn(function()
                        task.wait(13)
                        if SharedState.IsRunning and ConfigModule.Settings.AutoClaimQuests and not SharedState.IsDungeonEnded then
                            QuestModule.ClaimAll()
                        end
                    end)
                end

                if ConfigModule.Settings.AutoStart then DungeonStateModule.CheckStart() end

                local ended, playAgainBtn = DungeonStateModule.CheckEnd()
                if ended and playAgainBtn then
                    SharedState.IsDungeonEnded = true
                    SharedState.IsVirusActive = false
                    CharacterModule.StopMovement()

                    if ConfigModule.Settings.AutoClaimQuests then
                        pcall(QuestModule.ClaimAll)
                        task.wait(0.2)
                    end

                    if ConfigModule.Settings.AutoEngage and DungeonStateModule.CheckEngage() then
                        SharedState.IsDungeonEnded = false
                        SharedState.IsVirusActive = true
                        task.wait(1.0)
                    elseif ConfigModule.Settings.AutoPlayAgain then
                        queueNextExecution()
                        task.wait(0.8)
                        CharacterModule.TriggerButton(playAgainBtn)
                        task.wait(3.0)
                    end
                else
                    SharedState.IsDungeonEnded = false
                    local engaged = false
                    if ConfigModule.Settings.AutoEngage and not SharedState.IsVirusActive then
                        engaged = DungeonStateModule.CheckEngage()
                    end

                    if engaged then
                        SharedState.IsDungeonEnded = false
                        SharedState.IsVirusActive = true
                        task.wait(1.0)
                    else
                        if ConfigModule.Settings.SelectedPhase == "One Piece" then
                            FlowModule.RunOnePiece()
                        elseif ConfigModule.Settings.SelectedPhase == "Bleach (Fase 4)" then
                            FlowModule.RunBleach()
                        elseif ConfigModule.Settings.SelectedPhase == "Incursão" then
                            FlowModule.RunIncursion()
                        end
                    end
                end
            else
                CharacterModule.StopMovement()
            end
        else
            CharacterModule.StopMovement()
        end
        task.wait(0.04)
    end
end)

-- [[ 10. INTERFACE VISUAL ]]
local UIModule = {}

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Hub dos Rapazes",
    SubTitle = "Anime Dungeons",
    TabWidth = 140,
    Size = UDim2.fromOffset(530, 430),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Farm" }),
    Settings = Window:AddTab({ Title = "Settings" })
}

local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "IBdihP_PersistentToggle"
toggleGui.ResetOnSpawn = false
toggleGui.DisplayOrder = 999999
pcall(function() toggleGui.Parent = CoreGui end)
if not toggleGui.Parent then toggleGui.Parent = pgui end

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

Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", floatBtn)
stroke.Color = Color3.fromRGB(0, 255, 170)
stroke.Thickness = 1.6

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
floatBtn.MouseButton1Click:Connect(function() toggleUI(true) end)

function UIModule.Shutdown()
    SharedState.IsRunning = false
    CharacterModule.StopMovement()
    if charConnection then charConnection:Disconnect() end
    if diedConnection then diedConnection:Disconnect() end
    if flightStabilizer then flightStabilizer:Disconnect() end
    if singletonTag and singletonTag.Parent then singletonTag:Destroy() end
    if toggleGui and toggleGui.Parent then toggleGui:Destroy() end
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

task.spawn(function()
    task.wait(0.8)
    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, btn in ipairs(gui:GetDescendants()) do
            if btn:IsA("ImageButton") or btn:IsA("TextButton") then
                if btn.Name:lower():find("close") then
                    btn.MouseButton1Click:Connect(UIModule.Shutdown)
                elseif btn.Name:lower():find("min") then
                    btn.MouseButton1Click:Connect(function() toggleUI(false) end)
                end
            end
        end
    end
end)

-- Componentes da UI
local PhaseSection = Tabs.Farm:AddSection("Configurações de Fase & Posição")
PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "One Piece", "Bleach (Fase 4)", "Incursão" },
    Default = ConfigModule.Settings.SelectedPhase,
    Callback = function(Value) ConfigModule.Settings.SelectedPhase = Value ConfigModule.Save() end
})

PhaseSection:AddDropdown("PositionModeSelector", {
    Title = "Modo de Posicionamento",
    Values = { "Em Cima da Cabeça", "Nas Costas", "Padrão (Anterior)" },
    Default = ConfigModule.Settings.PositionMode,
    Callback = function(Value) ConfigModule.Settings.PositionMode = Value ConfigModule.Save() end
})

local WeaponSection = Tabs.Farm:AddSection("Configuração de Arma")
local WeaponInput = WeaponSection:AddInput("WeaponInputBox", {
    Title = "Arma Equipada / Nome",
    Default = ConfigModule.Settings.CustomWeaponName,
    Placeholder = "Ex: VoidRods, Katana...",
    Finished = true,
    Callback = function(Value) ConfigModule.Settings.CustomWeaponName = Value ConfigModule.Save() end
})

WeaponSection:AddButton({
    Title = "🔍 Detectar Arma da Mão",
    Description = "Lê automaticamente o nome da arma equipada",
    Callback = function()
        local detected = CombatModule.DetectWeapon()
        if detected and detected ~= "" then
            ConfigModule.Settings.CustomWeaponName = detected
            WeaponInput:SetValue(detected)
            ConfigModule.Save()
            Fluent:Notify({ Title = "Arma Detectada", Content = "Identificada: " .. tostring(detected), Duration = 4 })
        else
            Fluent:Notify({ Title = "Não Encontrada", Content = "Digite o nome exato da arma.", Duration = 4 })
        end
    end
})

local CombatSection = Tabs.Farm:AddSection("Controles de Combate & Movimento")
CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoFarm = Value if not Value then CharacterModule.StopMovement() end end
})
CombatSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura Vertical (Y)",
    Default = ConfigModule.Settings.HeightAboveEnemy,
    Min = 2, Max = 18, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.HeightAboveEnemy = Value ConfigModule.Save() end
})
CombatSection:AddSlider("BackDistance", {
    Title = "Distância das Costas (Studs)",
    Default = ConfigModule.Settings.BackDistance,
    Min = 2, Max = 15, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.BackDistance = Value ConfigModule.Save() end
})
CombatSection:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo",
    Default = ConfigModule.Settings.TweenSpeed,
    Min = 20, Max = 90, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.TweenSpeed = Value ConfigModule.Save() end
})
CombatSection:AddToggle("HardcoreToggle", {
    Title = "Modo Hardcore",
    Description = "Espera 23s após a morte e clica em Play Again",
    Default = ConfigModule.Settings.HardcoreMode,
    Callback = function(Value) ConfigModule.Settings.HardcoreMode = Value ConfigModule.Save() end
})
CombatSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Boss Secreto)",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoEngage = Value end
})
CombatSection:AddToggle("AutoPlayAgainToggle", {
    Title = "Auto Play Again",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoPlayAgain = Value end
})
CombatSection:AddToggle("AutoStartToggle", {
    Title = "Auto Start Dungeon",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoStart = Value end
})
CombatSection:AddSlider("StartWaitTimeSlider", {
    Title = "Espera Inicial (segundos)",
    Default = ConfigModule.Settings.StartWaitTime,
    Min = 0.5, Max = 6.0, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.StartWaitTime = Value ConfigModule.Save() end
})
CombatSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1)",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoAttack = Value end
})
CombatSection:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills (Z, X e Ultimate)",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoSkills = Value end
})
CombatSection:AddSlider("SkillMaxDistSlider", {
    Title = "Distância das Skills (studs)",
    Default = ConfigModule.Settings.SkillMaxDistance,
    Min = 8, Max = 40, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.SkillMaxDistance = Value end
})
CombatSection:AddSlider("AttackSpeedSlider", {
    Title = "Velocidade do Ataque (s)",
    Default = ConfigModule.Settings.AttackSpeed,
    Min = 0.04, Max = 0.35, Rounding = 2,
    Callback = function(Value) ConfigModule.Settings.AttackSpeed = Value ConfigModule.Save() end
})
CombatSection:AddSlider("SkillCooldownSlider", {
    Title = "Intervalo das Skills (s)",
    Default = ConfigModule.Settings.SkillCooldown,
    Min = 0.2, Max = 4, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.SkillCooldown = Value ConfigModule.Save() end
})

-- ABA SETTINGS
local QuestsSection = Tabs.Settings:AddSection("Automação de Missões (Quests)")
QuestsSection:AddToggle("AutoClaimQuestsToggle", {
    Title = "Auto-Claim de Missões (13s pós-início)",
    Default = ConfigModule.Settings.AutoClaimQuests,
    Callback = function(Value) ConfigModule.Settings.AutoClaimQuests = Value ConfigModule.Save() end
})
QuestsSection:AddButton({
    Title = "⚡ Resgatar Missões Agora",
    Callback = function() pcall(QuestModule.ClaimAll) end
})

local SettingsSection = Tabs.Settings:AddSection("Gerenciamento do Script")
SettingsSection:AddButton({
    Title = "Encerrar Script por Completo",
    Callback = UIModule.Shutdown
})

Window:SelectTab(Tabs.Farm)
