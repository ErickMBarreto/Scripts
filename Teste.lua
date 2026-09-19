-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (RESTAURADO: COMBATE, MOVIMENTO & BOSS RUSH)
-- ====================================================================

-- [[ 1. TRAVA GLOBAL LIMPA ]]
if getgenv and getgenv().HubDosRapazes_Loaded then
    return
end
if getgenv then
    getgenv().HubDosRapazes_Loaded = true
end

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local scriptURL = "https://raw.githubusercontent.com/ErickMBarreto/Scripts/refs/heads/main/Teste.lua"
local SCRIPT_NAME = "HubRapazes_Local.lua"

pcall(function()
    if writefile then
        local rawCode = game:HttpGet(scriptURL)
        if rawCode and #rawCode > 500 then
            writefile(SCRIPT_NAME, rawCode)
        end
    end
end)

local hasQueued = false
local function queueNextExecution()
    if hasQueued then return end
    hasQueued = true

    local queueFunc = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queueFunc then
        pcall(function()
            queueFunc(string.format([[
                if getgenv then getgenv().HubDosRapazes_Loaded = nil end
                repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
                task.wait(2.5)
                
                if readfile and isfile and isfile("%s") then
                    loadstring(readfile("%s"))()
                else
                    loadstring(game:HttpGet("%s"))()
                end
            ]], SCRIPT_NAME, SCRIPT_NAME, scriptURL))
        end)
    end
end

if not game:IsLoaded() then 
    pcall(function() game.Loaded:Wait() end) 
end

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pgui = player:WaitForChild("PlayerGui", 30)

for _, gui in ipairs({CoreGui, pgui}) do
    if gui then
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") or child.Name == "HubRapazes_BlackScreen" then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local SharedState = {
    IsRunning = true,
    IsRespawning = false,
    IsTransitioning = false,
    EnteringPortal = false,
    IsVirusActive = false,
    IsSelling = false,
    IsClaiming = false,
    IsDungeonEnded = false,
    HasExecutedSell = false,
    HasExecutedQuests = false,
    HasSentWebhook = false,
    LastRoomState = "Room1",
    CurrentTween = nil,
    CurrentTargetPos = nil,
    LastPortalAttempt = 0,
    LastStartAttempt = 0,
    HasClickedStart = false,
    StartLockUntil = 0,
    RespawnLockUntil = 0,
    HasTarget = false,
    IsSelectingBonus = false,
    HasPassedPortal1 = false,
    HasEnteredBossRoom = false
}

-- [[ 2. CONFIGURAÇÕES ]]
local ConfigModule = {}
ConfigModule.Settings = {
    SelectedPhase = "Boss Rush",
    PositionMode = "Nas Costas",
    CustomWeaponName = "Yoru",
    AutoFarm = true,
    AutoAttack = true,
    AutoSkills = true,
    AutoStart = true,
    AutoPlayAgain = true,
    AutoEngage = false,
    HardcoreMode = false,
    SkillCooldown = 0.8,
    SkillMaxDistance = 22,
    HeightAboveEnemy = 8.5,
    BackDistance = 4.5,
    TweenSpeed = 50,
    AttackSpeed = 0.15,
    AutoClaimQuests = false,
    AutoSell = false,
    SellDelaySeconds = 10,
    AutoFavoriteSecrets = true,
    AutoFavoriteMythics = false,
    SellCommon = true,
    SellRare = true,
    SellEpic = true,
    SellLegendary = true,
    SellMythic = false,
    InfinityCardSlot = 1,
    InfinityAutoSkipWave = true,
    InfinityOrbitRadius = 10.0,
    InfinityOrbitHeight = 12.5,
    InfinityOrbitSpeed = 3.0,
    WebhookEnabled = false,
    WebhookURL = "https://discord.com/api/webhooks/1542138848195248258/Xqpgk33GsjM5UrMxT0IqIvkKvKulvSJQVc6CSuPmrf6lmrjNXwjxCwGCOK0aJun-Y83o",
    NotifySecrets = true,
    NotifyMythics = true,
    NotifyEveryRun = false,
    FPSBoost = true,
    DisableParticles = true,
    DisableShadows = true,
    BlackScreenAFK = false
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

-- [[ 3. OTIMIZADOR DE FPS ]]
local OptimizerModule = {}

function OptimizerModule.CleanInstance(v)
    if not ConfigModule.Settings.FPSBoost then return end
    pcall(function()
        if ConfigModule.Settings.DisableParticles then
            if v:IsA("ParticleEmitter") or v:IsA("Sparkles") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = false
            end
        end
        if v:IsA("Light") then v.Enabled = false end
        if v:IsA("MeshPart") or v:IsA("Part") then
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
        end
        if v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1 end
    end)
end

function OptimizerModule.ApplyAll()
    if not ConfigModule.Settings.FPSBoost then return end
    pcall(function()
        if ConfigModule.Settings.DisableShadows then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 1
        end
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
                effect.Enabled = false
            end
        end
        for _, desc in ipairs(workspace:GetDescendants()) do
            OptimizerModule.CleanInstance(desc)
        end
    end)
end

workspace.DescendantAdded:Connect(function(child)
    if ConfigModule.Settings.FPSBoost then
        task.delay(0.1, function() OptimizerModule.CleanInstance(child) end)
    end
end)

function OptimizerModule.SetBlackScreen(enabled)
    pcall(function()
        local sg = CoreGui:FindFirstChild("HubRapazes_BlackScreen") or pgui:FindFirstChild("HubRapazes_BlackScreen")
        if enabled then
            if not sg then
                sg = Instance.new("ScreenGui")
                sg.Name = "HubRapazes_BlackScreen"
                sg.DisplayOrder = 999998
                sg.ResetOnSpawn = false
                pcall(function() sg.Parent = CoreGui end)
                if not sg.Parent then sg.Parent = pgui end

                local bg = Instance.new("Frame", sg)
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
                bg.BorderSizePixel = 0

                local txt = Instance.new("TextLabel", bg)
                txt.Size = UDim2.new(1, 0, 0, 40)
                txt.Position = UDim2.new(0, 0, 0.45, 0)
                txt.Text = "MODO AFK ATIVO (POUPANDO BATERIA E RAM)"
                txt.TextColor3 = Color3.fromRGB(0, 255, 170)
                txt.Font = Enum.Font.GothamBold
                txt.TextSize = 14
                txt.BackgroundTransparency = 1
            end
            sg.Enabled = true
            RunService:Set3dRenderingEnabled(false)
        else
            if sg then sg.Enabled = false end
            RunService:Set3dRenderingEnabled(true)
        end
    end)
end

task.spawn(function()
    task.wait(2.5)
    OptimizerModule.ApplyAll()
end)

-- [[ 4. WEBHOOK DISCORD ]]
local WebhookModule = {}
function WebhookModule.Send(payloadTable)
    if not ConfigModule.Settings.WebhookEnabled or ConfigModule.Settings.WebhookURL == "" then return end
    task.spawn(function()
        local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not httpRequest then return end
        pcall(function()
            httpRequest({
                Url = ConfigModule.Settings.WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payloadTable)
            })
        end)
    end)
end

function WebhookModule.ProcessDungeonDrops()
    if SharedState.HasSentWebhook or not ConfigModule.Settings.WebhookEnabled then return end
    local df = pgui and pgui:FindFirstChild("Main") and (pgui.Main:FindFirstChild("DungeonFrame") or pgui.Main:FindFirstChild("BossRushFrame") or pgui.Main:FindFirstChild("RaidFrame"))
    local stats = df and df:FindFirstChild("DungeonStats")
    local rewardedHolder = stats and stats:FindFirstChild("RewardedHolder")
    if not rewardedHolder then return end

    local droppedItems = {}
    local hasSecret, hasMythic = false, false
    for _, child in ipairs(rewardedHolder:GetChildren()) do
        if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("GuiObject") then
            local itemName = child.Name
            local itemVal = child:FindFirstChild("Item")
            if itemVal and itemVal:IsA("ObjectValue") and itemVal.Value then
                itemName = itemVal.Value.Name
                local r = tostring(itemVal.Value:GetAttribute("Rarity") or ""):lower()
                if r:find("secret") then hasSecret = true end
                if r:find("mythic") then hasMythic = true end
            end
            local chanceLabel = child:FindFirstChild("DropChance")
            local chanceTxt = (chanceLabel and chanceLabel:IsA("TextLabel")) and chanceLabel.Text or ""
            table.insert(droppedItems, string.format("• **%s** %s", itemName, chanceTxt ~= "" and ("(" .. chanceTxt .. ")") or ""))
        end
    end

    local shouldNotify = ConfigModule.Settings.NotifyEveryRun or (ConfigModule.Settings.NotifySecrets and hasSecret) or (ConfigModule.Settings.NotifyMythics and hasMythic)
    if shouldNotify then
        SharedState.HasSentWebhook = true
        local dropsText = #droppedItems > 0 and table.concat(droppedItems, "\n") or "Nenhum item especial"
        local embedColor = hasSecret and 16711680 or (hasMythic and 16744192 or 65450)
        WebhookModule.Send({
            ["username"] = "Hub dos Rapazes Bot",
            ["avatar_url"] = "https://i.imgur.com/8Qf9Z2N.png",
            ["embeds"] = {{
                ["title"] = "⚔️ Fase Concluída - " .. tostring(ConfigModule.Settings.SelectedPhase),
                ["color"] = embedColor,
                ["fields"] = {
                    { ["name"] = "👤 Jogador", ["value"] = player.Name, ["inline"] = true },
                    { ["name"] = "🗺️ Fase", ["value"] = ConfigModule.Settings.SelectedPhase, ["inline"] = true },
                    { ["name"] = "🎁 Drops da Partida", ["value"] = dropsText, ["inline"] = false }
                },
                ["footer"] = { ["text"] = "Hub dos Rapazes • " .. os.date("%X") }
            }}
        })
    end
end

-- [[ 5. PERSONAGEM E MOVIMENTO ]]
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
    if root then
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
end

function CharacterModule.IsActionBlocked()
    if tick() < SharedState.StartLockUntil then return true end
    if tick() < SharedState.RespawnLockUntil then return true end
    return SharedState.IsRespawning or SharedState.EnteringPortal or SharedState.IsTransitioning or SharedState.IsDungeonEnded or not SharedState.IsRunning
end

flightStabilizer = RunService.Stepped:Connect(function()
    if SharedState.IsRunning and ConfigModule.Settings.AutoFarm and not CharacterModule.IsActionBlocked() then
        local _, root, hum = CharacterModule.Get()
        if root and hum and hum.Health > 0 then
            root.AssemblyAngularVelocity = Vector3.zero
            if not SharedState.CurrentTween then
                root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
            end
        end
    end
end)

function CharacterModule.FlyToEnemy(targetPart, overrideMode)
    if CharacterModule.IsActionBlocked() or SharedState.IsSelectingBonus then 
        CharacterModule.StopMovement()
        return 
    end
    local _, root = CharacterModule.Get()
    if not root or not targetPart or not targetPart.Parent then 
        CharacterModule.StopMovement()
        return 
    end

    local enemyPos = targetPart.Position
    local mode = overrideMode or ConfigModule.Settings.PositionMode
    local targetCFrame

    if mode == "Nas Costas" then
        local lookVec = targetPart.CFrame.LookVector
        local horizontalLook = Vector3.new(lookVec.X, 0, lookVec.Z)
        if horizontalLook.Magnitude > 0.05 then
            lookVec = horizontalLook.Unit
        end
        local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 1.2, 0)
        targetCFrame = CFrame.new(enemyPos + backOffset, enemyPos)
    elseif mode == "Em Cima da Cabeça" then
        targetCFrame = CFrame.new(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1), enemyPos)
    else
        targetCFrame = CFrame.new(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0), enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude
    if distance <= 1.2 then return end

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 1.5 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 15), 0.1, 2.0)

    if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.TriggerButton(btn)
    if not btn or not SharedState.IsRunning then return end
    pcall(function()
        if firesignal then
            if btn.Activated then firesignal(btn.Activated) end
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
            if btn.MouseButton1Down then firesignal(btn.MouseButton1Down) end
        end
        if getconnections then
            for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
                if btn[evName] then
                    for _, c in ipairs(getconnections(btn[evName])) do c:Fire() end
                end
            end
        end
    end)
end

-- [[ 6. DETECÇÃO DE INIMIGOS (RESTAURADA E CONFIÁVEL) ]]
local TargetingModule = {}

function TargetingModule.IsAlive(obj)
    if not obj or not obj.Parent then return false end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then return true end

    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("CurrentHealth")
    if hpAttr and tonumber(hpAttr) and tonumber(hpAttr) > 0 then return true end

    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") and tonumber(hpVal.Value) and tonumber(hpVal.Value) > 0 then return true end

    return false
end

function TargetingModule.GetTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    return obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("HitBox")
        or obj:FindFirstChild("Head")
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

    -- 1. Pastas do jogo
    local gameFolder = workspace:FindFirstChild("Game")
    local searchContainers = {
        workspace:FindFirstChild("BossRush"),
        workspace:FindFirstChild("Enemies"),
        workspace:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("BossRush"),
        gameFolder and gameFolder:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("Enemies"),
        gameFolder and gameFolder:FindFirstChild("Stages"),
        gameFolder and gameFolder:FindFirstChild("Raids"),
        gameFolder and gameFolder:FindFirstChild("Infinity"),
        workspace:FindFirstChild("SAO")
    }

    for _, container in ipairs(searchContainers) do
        if container then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("Model") then addEntity(desc) end
            end
            if container:IsA("Model") then addEntity(container) end
        end
    end

    -- 2. Varredura ampla de emergência em Models com Humanoid vivos no Workspace
    if #list == 0 then
        for _, desc in ipairs(workspace:GetChildren()) do
            if desc:IsA("Model") and desc ~= char and not Players:GetPlayerFromCharacter(desc) then
                addEntity(desc)
            end
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

-- [[ 7. COMBATE (M1 E SKILLS DESVINCULADOS DE TRAVAS FALSAS) ]]
local CombatModule = {}
local attackRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Attack", 10)
local skillRemote = ReplicatedStorage:WaitForChild("Remotes", 10):FindFirstChild("Skill") or ReplicatedStorage:WaitForChild("Remotes", 10):FindFirstChild("Spell")
local lastSkillUse = 0
local comboIndex = 1

function CombatModule.GetEffectiveWeapon()
    if ConfigModule.Settings.CustomWeaponName and ConfigModule.Settings.CustomWeaponName ~= "" then
        return ConfigModule.Settings.CustomWeaponName
    end
    return "Yoru"
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
    comboIndex = (comboIndex % 4) + 1
    local weapon = CombatModule.GetEffectiveWeapon()
    if attackRemote then 
        pcall(function() attackRemote:FireServer("M1", weapon, comboIndex, 0, 0, 2) end) 
    end
    local char = player.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end
end

function CombatModule.ExecuteSkills()
    if (tick() - lastSkillUse) < ConfigModule.Settings.SkillCooldown then return end
    lastSkillUse = tick()
    local hotbarList = CombatModule.GetHotbar()
    if hotbarList then
        local s1 = hotbarList:FindFirstChild("Spell1", true) or hotbarList:FindFirstChild("Z", true)
        local s2 = hotbarList:FindFirstChild("Spell2", true) or hotbarList:FindFirstChild("X", true)
        local s3 = hotbarList:FindFirstChild("Ultimate", true) or hotbarList:FindFirstChild("Spell3", true) or hotbarList:FindFirstChild("C", true)

        if s1 then CharacterModule.TriggerButton(s1) end
        task.wait(0.04)
        if s2 then CharacterModule.TriggerButton(s2) end
        task.wait(0.04)
        if s3 then CharacterModule.TriggerButton(s3) end
    end
    if skillRemote then
        pcall(function()
            skillRemote:FireServer(1)
            skillRemote:FireServer(2)
            skillRemote:FireServer(3)
        end)
    end
end

-- [[ 8. FLUXO EXCLUSIVO DO BOSS RUSH ]]
local FlowModule = {}
local dungeonRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Dungeon", 10)

function FlowModule.RunBossRush()
    local closestBoss, bossPart = TargetingModule.GetClosestEnemy("Boss Rush")
    if closestBoss and bossPart and bossPart.Parent then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(bossPart, "Nas Costas")
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

-- [[ 9. AUTO-START & AUTO-PLAYAGAIN ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    if not pgui or (tick() - SharedState.LastStartAttempt) < 0.4 then return end
    SharedState.LastStartAttempt = tick()

    for _, desc in ipairs(pgui:GetDescendants()) do
        if desc:IsA("GuiButton") and desc.Name == "Start" and desc.Visible then
            CharacterModule.TriggerButton(desc)
            SharedState.HasClickedStart = true
            pcall(function()
                if dungeonRemote then
                    dungeonRemote:FireServer("Start")
                    dungeonRemote:FireServer("Play")
                end
            end)
            return
        end
    end
end

function DungeonStateModule.CheckEnd()
    if not pgui then return false, nil end
    for _, btn in ipairs(pgui:GetDescendants()) do
        if btn:IsA("GuiButton") and btn.Name == "PlayAgain" and btn.Visible then
            return true, btn
        end
    end
    return false, nil
end

local function onPlayerDiedHandler()
    CharacterModule.StopMovement()
    SharedState.HasTarget = false

    if ConfigModule.Settings.AutoPlayAgain then
        task.spawn(function()
            task.wait(1.5)
            for _ = 1, 80 do
                if not SharedState.IsRunning then break end
                local ended, retryBtn = DungeonStateModule.CheckEnd()
                if ended and retryBtn then
                    SharedState.IsDungeonEnded = true
                    queueNextExecution()
                    task.wait(0.2)
                    CharacterModule.TriggerButton(retryBtn)
                    pcall(function()
                        if dungeonRemote then dungeonRemote:FireServer("PlayAgain") end
                    end)
                    break
                end
                task.wait(0.3)
            end
        end)
    end
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
    SharedState.HasTarget = false
    SharedState.IsDungeonEnded = false
    hasQueued = false
    CharacterModule.StopMovement()
    bindCharacterEvents(newChar)
    task.delay(1.0, function() SharedState.IsRespawning = false end)
end)

-- [[ 10. LOOPS PRINCIPAIS INDEPENDENTES ]]

-- Loop 1: Ataque M1 (bater constante se estiver em combate)
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not CharacterModule.IsActionBlocked() then
            local _, root, hum = CharacterModule.Get()
            if hum and hum.Health > 0 and SharedState.HasTarget then
                CombatModule.ExecuteM1()
            end
        end
        task.wait(ConfigModule.Settings.AttackSpeed)
    end
end)

-- Loop 2: Skills
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoSkills and not SharedState.IsDungeonEnded and not CharacterModule.IsActionBlocked() then
            local _, root, hum = CharacterModule.Get()
            if hum and hum.Health > 0 and SharedState.HasTarget then
                CombatModule.ExecuteSkills()
            end
        end
        task.wait(0.1)
    end
end)

-- Loop 3: Movimento do Boss Rush e PlayAgain de Vitória
task.spawn(function()
    local isHandlingVictory = false
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoStart then
            DungeonStateModule.CheckStart()
        end

        if ConfigModule.Settings.AutoFarm and not SharedState.IsRespawning then
            local _, root, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then
                -- Checagem de Vitória (PlayAgain na tela)
                local ended, playAgainBtn = DungeonStateModule.CheckEnd()
                if ended and playAgainBtn then
                    SharedState.IsDungeonEnded = true
                    SharedState.HasTarget = false
                    CharacterModule.StopMovement()

                    pcall(WebhookModule.ProcessDungeonDrops)

                    if ConfigModule.Settings.AutoPlayAgain and not isHandlingVictory then
                        isHandlingVictory = true
                        task.spawn(function()
                            task.wait(3.0) -- Aguarda os 3s de fim de fase
                            if SharedState.IsRunning then
                                queueNextExecution()
                                task.wait(0.2)
                                CharacterModule.TriggerButton(playAgainBtn)
                                pcall(function()
                                    if dungeonRemote then dungeonRemote:FireServer("PlayAgain") end
                                end)
                            end
                            task.wait(3.0)
                            SharedState.IsDungeonEnded = false
                            isHandlingVictory = false
                        end)
                    end
                else
                    -- Roda a perseguição do Boss Rush
                    FlowModule.RunBossRush()
                end
            end
        end
        task.wait(0.05)
    end
end)

-- [[ 11. INTERFACE VISUAL ]]
local Window = Fluent:CreateWindow({
    Title = "Hub dos Rapazes",
    SubTitle = "Anime Dungeons (Boss Rush)",
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

Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Default = true,
    Callback = function(Value) 
        ConfigModule.Settings.AutoFarm = Value 
        if not Value then CharacterModule.StopMovement() end 
    end
})

Tabs.Farm:AddToggle("AutoStartToggle", {
    Title = "Auto Start",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoStart = Value end
})

Tabs.Farm:AddToggle("AutoPlayAgainToggle", {
    Title = "Auto Play Again",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoPlayAgain = Value end
})

Tabs.Farm:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1)",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoAttack = Value end
})

Tabs.Farm:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoSkills = Value end
})

Tabs.Farm:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo",
    Default = ConfigModule.Settings.TweenSpeed,
    Min = 20, Max = 90, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.TweenSpeed = Value ConfigModule.Save() end
})

Tabs.Farm:AddSlider("BackDistance", {
    Title = "Distância das Costas",
    Default = ConfigModule.Settings.BackDistance,
    Min = 2, Max = 15, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.BackDistance = Value ConfigModule.Save() end
})

Tabs.Settings:AddButton({
    Title = "Encerrar Script",
    Callback = function()
        SharedState.IsRunning = false
        if getgenv then getgenv().HubDosRapazes_Loaded = nil end
        CharacterModule.StopMovement()
        if charConnection then charConnection:Disconnect() end
        if diedConnection then diedConnection:Disconnect() end
        if flightStabilizer then flightStabilizer:Disconnect() end
        pcall(function() Window:Destroy() end)
    end
})

Window:SelectTab(Tabs.Farm)
