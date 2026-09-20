-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (BOSS RUSH CONFLITOS ELIMINADOS)
-- ====================================================================

local CurrentSessionId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))

if getgenv then
    if getgenv().HubDosRapazes_ActiveSession and getgenv().HubDosRapazes_Running then
        return
    end
    getgenv().HubDosRapazes_ActiveSession = CurrentSessionId
    getgenv().HubDosRapazes_Running = true
    
    if getgenv().HubDosRapazes_Shutdown then
        pcall(getgenv().HubDosRapazes_Shutdown)
    end
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

local hasQueuedTeleport = false
local function queueNextExecution()
    if hasQueuedTeleport then return end
    hasQueuedTeleport = true

    local queueFunc = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queueFunc then
        pcall(function()
            queueFunc(string.format([[
                if getgenv then 
                    getgenv().HubDosRapazes_Running = nil 
                    getgenv().HubDosRapazes_ActiveSession = nil
                end
                repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
                task.wait(2.0)
                
                local success = false
                if readfile and isfile and isfile("%s") then
                    local content = readfile("%s")
                    if content and #content > 500 then
                        local fn = loadstring(content)
                        if fn then
                            success = true
                            pcall(fn)
                        end
                    end
                end
                
                if not success then
                    loadstring(game:HttpGet("%s"))()
                end
            ]], SCRIPT_NAME, SCRIPT_NAME, scriptURL))
        end)
    end
end

if not game:IsLoaded() then game.Loaded:Wait() end
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pgui = player:WaitForChild("PlayerGui", 20)

for _, gui in ipairs({CoreGui, pgui}) do
    if gui then
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local successFluent, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not successFluent or not Fluent then
    if getgenv then 
        getgenv().HubDosRapazes_Running = nil 
        getgenv().HubDosRapazes_ActiveSession = nil
    end
    warn("[Hub dos Rapazes] Falha ao carregar a interface.")
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
    SkillMaxDistance = 25,
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
                txt.Text = "MODO AFK ATIVO (ECONOMIZANDO BATERIA E RAM)"
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
    task.wait(3.0)
    OptimizerModule.ApplyAll()
end)

-- [[ 4. WEBHOOK ]]
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

-- [[ 5. PERSONAGEM E MOVIMENTO ESTÁVEL ]]
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
    if tick() < SharedState.RespawnLockUntil then return true end
    return SharedState.IsRespawning or SharedState.EnteringPortal or SharedState.IsTransitioning or SharedState.IsDungeonEnded or not SharedState.IsRunning
end

flightStabilizer = RunService.Stepped:Connect(function()
    if SharedState.IsRunning and ConfigModule.Settings.AutoFarm and not CharacterModule.IsActionBlocked() then
        local _, root, hum = CharacterModule.Get()
        if root and hum and hum.Health > 0 then
            root.AssemblyAngularVelocity = Vector3.zero
            if not SharedState.CurrentTween and not SharedState.HasTarget then
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
end)

function CharacterModule.GetSafeCFrame(targetPosition, lookAtPosition)
    local safeY = targetPosition.Y
    if ConfigModule.Settings.SelectedPhase == "SAO" and safeY < 1005 then
        safeY = 1005.5
    end
    return CFrame.new(Vector3.new(targetPosition.X, safeY, targetPosition.Z), lookAtPosition)
end

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
        local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 1.5, 0)
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + backOffset, enemyPos)
    elseif mode == "Em Cima da Cabeça" then
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1), enemyPos)
    else
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0), enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude

    if distance <= 1.8 then 
        root.CFrame = targetCFrame
        return 
    end

    if SharedState.CurrentTween and SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 3.5 then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 15), 0.1, 2.0)

    if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.FlyToPortal(targetCFrame)
    if CharacterModule.IsActionBlocked() then return end
    local _, root = CharacterModule.Get()
    if not root or not root.Parent then return end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.2, 4.0)

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 2.0 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
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
        end
        if getconnections then
            for _, evName in ipairs({"Activated", "MouseButton1Click"}) do
                if btn[evName] then
                    for _, c in ipairs(getconnections(btn[evName])) do c:Fire() end
                end
            end
        end
    end)
end

-- [[ 6. MÓDULOS INFINITY E SAO ]]
local InfinityMovement = {}
local orbitAngle = 0

function InfinityMovement.Step(targetPart)
    if CharacterModule.IsActionBlocked() then 
        InfinityMovement.HoldCenter()
        return 
    end
    local _, root = CharacterModule.Get()
    if not root or not targetPart or not targetPart.Parent then 
        InfinityMovement.HoldCenter()
        return 
    end

    local enemyPos = targetPart.Position
    local speed = ConfigModule.Settings.InfinityOrbitSpeed or 3.0
    local radius = ConfigModule.Settings.InfinityOrbitRadius or 10.0
    local height = ConfigModule.Settings.InfinityOrbitHeight or 12.5

    orbitAngle = (orbitAngle + (RunService.Heartbeat:Wait() * speed)) % (math.pi * 2)
    local desiredPosition = enemyPos + Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
    local targetCFrame = CFrame.lookAt(desiredPosition, enemyPos)
    local distance = (root.Position - desiredPosition).Magnitude

    if distance > 14 then
        if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
        local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 20), 0.2, 1.2)
        SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
        SharedState.CurrentTween:Play()
    else
        if SharedState.CurrentTween then
            SharedState.CurrentTween:Cancel()
            SharedState.CurrentTween = nil
        end
        root.CFrame = root.CFrame:Lerp(targetCFrame, 0.18)
    end
end

function InfinityMovement.HoldCenter()
    CharacterModule.StopMovement()
end

local InfinityModule = {}
local dungeonRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Dungeon", 10)

function InfinityModule.CheckBonus()
    local main = pgui:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local bonuses = dungeonFrame and dungeonFrame:FindFirstChild("Bonuses")

    if bonuses and bonuses.Visible then
        SharedState.IsSelectingBonus = true
        CharacterModule.StopMovement()

        local slotIndex = ConfigModule.Settings.InfinityCardSlot or 1
        local targetCardName = "Bonus" .. tostring(slotIndex)
        local cardButton = bonuses:FindFirstChild(targetCardName) or bonuses:FindFirstChild("Bonus1")

        if cardButton and cardButton.Visible then
            CharacterModule.TriggerButton(cardButton)
        end
        return true
    end

    SharedState.IsSelectingBonus = false
    return false
end

function InfinityModule.ForceSkip()
    local executed = false
    if dungeonRemote then
        pcall(function()
            dungeonRemote:FireServer("InfinitySkipWave")
            executed = true
        end)
    end
    local main = pgui:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local skipBtn = dungeonFrame and dungeonFrame:FindFirstChild("SkipWave")
    if skipBtn and skipBtn:IsA("GuiObject") then
        CharacterModule.TriggerButton(skipBtn)
        executed = true
    end
    return executed
end

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.SelectedPhase == "Infinity" and ConfigModule.Settings.InfinityAutoSkipWave then
            local main = pgui:FindFirstChild("Main")
            local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
            local skipBtn = dungeonFrame and dungeonFrame:FindFirstChild("SkipWave")

            if skipBtn and skipBtn:IsA("GuiObject") and skipBtn.Visible then
                InfinityModule.ForceSkip()
                task.wait(1.5)
            end
        end
        task.wait(0.25)
    end
end)

local SAOModule = {}

function SAOModule.CheckBonus()
    local main = pgui:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local bonuses = dungeonFrame and dungeonFrame:FindFirstChild("Bonuses")

    if bonuses and bonuses.Visible then
        SharedState.IsSelectingBonus = true
        CharacterModule.StopMovement()

        local timeCard, damageCard, fallbackCard = nil, nil, nil
        for _, card in ipairs(bonuses:GetChildren()) do
            if card:IsA("GuiObject") and card.Visible and card.Name:find("Bonus") then
                if not fallbackCard then fallbackCard = card end

                local bName = card:FindFirstChild("BonusName")
                local bDesc = card:FindFirstChild("BonusDescription")
                local combinedText = (((bName and bName:IsA("TextLabel")) and bName.Text or "") .. " " ..
                                     ((bDesc and bDesc:IsA("TextLabel")) and bDesc.Text or "")):lower()

                if combinedText:find("second") or combinedText:find("tempo") or combinedText:find("timer") then
                    timeCard = card
                elseif combinedText:find("damage") or combinedText:find("dano") or combinedText:find("atk") or combinedText:find("attack") then
                    damageCard = card
                end
            end
        end

        local targetToClick = timeCard or damageCard or fallbackCard
        if targetToClick then
            CharacterModule.TriggerButton(targetToClick)
            task.wait(0.4)
        end
        return true
    end

    SharedState.IsSelectingBonus = false
    return false
end

-- [[ 7. DETECÇÃO DE INIMIGOS DEFINITIVA ]]
local TargetingModule = {}

function TargetingModule.GetTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    
    -- Peça "Bot" descoberta pelo scanner + fallbacks
    local part = obj:FindFirstChild("Bot")
        or obj:FindFirstChild("bot")
        or obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("Head")
        or obj:FindFirstChild("Torso")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or obj:FindFirstChildWhichIsA("BasePart")
    
    return part
end

function TargetingModule.GetLivingEnemies(phase)
    local list = {}
    local char = player.Character

    -- ROTA BOSS RUSH: Pega direto em Game.Enemies sem filtros restritivos
    if phase == "Boss Rush" then
        local gameFolder = workspace:FindFirstChild("Game")
        local enemiesFolder = gameFolder and gameFolder:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, obj in ipairs(enemiesFolder:GetChildren()) do
                if obj:IsA("Model") and obj ~= char and TargetingModule.GetTargetPart(obj) then
                    table.insert(list, obj)
                end
            end
        end
        return list
    end

    -- OUTRAS FASES (SAO, Infinity, etc)
    local gameFolder = workspace:FindFirstChild("Game")
    local searchContainers = {
        gameFolder and gameFolder:FindFirstChild("Enemies"),
        workspace:FindFirstChild("Enemies"),
        gameFolder and gameFolder:FindFirstChild("Stages"),
        gameFolder and gameFolder:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("Virus"),
        workspace:FindFirstChild("SAO")
    }

    for _, container in ipairs(searchContainers) do
        if container then
            for _, desc in ipairs(container:GetDescendants()) do
                if desc:IsA("Model") and desc ~= char and not Players:GetPlayerFromCharacter(desc) then
                    local hum = desc:FindFirstChildOfClass("Humanoid")
                    if (not hum or hum.Health > 0.1) and TargetingModule.GetTargetPart(desc) then
                        table.insert(list, desc)
                    end
                end
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

-- [[ 8. COMBATE ]]
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
    if CharacterModule.IsActionBlocked() or SharedState.IsSelectingBonus then return end
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
    if CharacterModule.IsActionBlocked() or SharedState.IsSelectingBonus then return end
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
end

-- [[ 9. AUTO-SELL ]]
local AutoSellModule = {}
local equipRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Equip", 10)
local lastSellTick = 0

function AutoSellModule.ResolveRarity(slot, itemObj)
    if not itemObj then return "Unknown" end
    local rAttr = itemObj:GetAttribute("Rarity") or itemObj:GetAttribute("Tier")
    if rAttr then
        local r = tostring(rAttr):lower()
        if r:find("secret") then return "Secret"
        elseif r:find("mythic") then return "Mythic"
        elseif r:find("legendary") then return "Legendary"
        elseif r:find("epic") then return "Epic"
        elseif r:find("rare") then return "Rare"
        elseif r:find("common") then return "Common"
        end
    end
    return "Unknown"
end

function AutoSellModule.LockHighTierItems()
    if not equipRemote then return end
    local scroll = pgui:FindFirstChild("Main")
        and pgui.Main:FindFirstChild("MainFrame")
        and pgui.Main.MainFrame:FindFirstChild("Items")
        and pgui.Main.MainFrame.Items:FindFirstChild("Scroll")

    if not scroll then return end
    for _, slot in ipairs(scroll:GetChildren()) do
        if (slot:IsA("ImageButton") or slot:IsA("Frame")) and slot:FindFirstChild("Item") and slot.Item:IsA("ObjectValue") then
            local itemObj = slot.Item.Value
            if itemObj and itemObj.Parent then
                local isFav = itemObj:GetAttribute("Favorite") == true
                if not isFav then
                    local rarity = AutoSellModule.ResolveRarity(slot, itemObj)
                    local shouldLock = (rarity == "Secret" and ConfigModule.Settings.AutoFavoriteSecrets) or (rarity == "Mythic" and ConfigModule.Settings.AutoFavoriteMythics)
                    if shouldLock then
                        pcall(function()
                            equipRemote:FireServer("Favorite", itemObj)
                            local favIcon = slot:FindFirstChild("Favorite", true)
                            if favIcon then CharacterModule.TriggerButton(favIcon) end
                        end)
                        task.wait(0.1)
                    end
                end
            end
        end
    end
end

function AutoSellModule.Execute()
    if not ConfigModule.Settings.AutoSell or SharedState.IsSelling or not SharedState.IsRunning or not equipRemote then return end
    if (tick() - lastSellTick) < 10 then return end

    SharedState.IsSelling = true
    lastSellTick = tick()
    pcall(AutoSellModule.LockHighTierItems)
    task.wait(0.3)

    local scroll = pgui:FindFirstChild("Main")
        and pgui.Main:FindFirstChild("MainFrame")
        and pgui.Main.MainFrame:FindFirstChild("Items")
        and pgui.Main.MainFrame.Items:FindFirstChild("Scroll")

    local itemsToSell = {}
    local processed = {}

    if scroll then
        for _, slot in ipairs(scroll:GetChildren()) do
            if (slot:IsA("ImageButton") or slot:IsA("Frame")) and slot:FindFirstChild("Item") and slot.Item:IsA("ObjectValue") then
                local itemObj = slot.Item.Value
                if itemObj and itemObj.Parent and not processed[itemObj] then
                    processed[itemObj] = true
                    local isEquipped = itemObj:GetAttribute("Equipped") == true
                    local isFav = itemObj:GetAttribute("Favorite") == true
                    local itemType = tostring(itemObj:GetAttribute("Type") or ""):lower()

                    if not isEquipped and not isFav and itemType ~= "material" then
                        local rarity = AutoSellModule.ResolveRarity(slot, itemObj)
                        local shouldSell = (rarity == "Common" and ConfigModule.Settings.SellCommon) or
                                           (rarity == "Rare" and ConfigModule.Settings.SellRare) or
                                           (rarity == "Epic" and ConfigModule.Settings.SellEpic) or
                                           (rarity == "Legendary" and ConfigModule.Settings.SellLegendary) or
                                           (rarity == "Mythic" and ConfigModule.Settings.SellMythic)

                        if shouldSell and rarity ~= "Secret" then
                            table.insert(itemsToSell, itemObj)
                        end
                    end
                end
            end
        end
    end

    if #itemsToSell > 0 then
        pcall(function() equipRemote:FireServer("Sell", itemsToSell) end)
        Fluent:Notify({ Title = "Auto-Sell", Content = string.format("%d itens vendidos!", #itemsToSell), Duration = 3 })
    end

    SharedState.IsSelling = false
end

-- [[ 10. MISSÕES ]]
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
        questsFrame:FindFirstChild("Weekly")
    }

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
                                end)
                            end
                            task.wait(0.12)
                        end
                    end
                end
            end
        end
    end

    questsFrame.Visible = originalVisible
    SharedState.IsClaiming = false
end

-- [[ 11. FLUXO DAS FASES ]]
local FlowModule = {}

function FlowModule.RunBossRush()
    local closestBoss, bossPart = TargetingModule.GetClosestEnemy("Boss Rush")
    if closestBoss and bossPart and bossPart.Parent then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(bossPart)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

function FlowModule.RunSAO()
    local _, root = CharacterModule.Get()
    if not root or CharacterModule.IsActionBlocked() then return end
    if SAOModule.CheckBonus() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end
    local currentMob, mobPart = TargetingModule.GetClosestEnemy("SAO")
    if currentMob and mobPart then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(mobPart)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

function FlowModule.RunInfinity()
    if CharacterModule.IsActionBlocked() then return end
    if InfinityModule.CheckBonus() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end
    local _, enemyPart = TargetingModule.GetClosestEnemy("Infinity")
    if enemyPart and enemyPart.Parent then
        SharedState.HasTarget = true
        InfinityMovement.Step(enemyPart)
    else
        SharedState.HasTarget = false
        InfinityMovement.HoldCenter()
    end
end

-- [[ 12. CHECAGEM DE START & PLAYAGAIN ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    if not pgui or (tick() - SharedState.LastStartAttempt) < 0.8 then return end
    SharedState.LastStartAttempt = tick()
    
    local main = pgui:FindFirstChild("Main")
    if not main then return end

    -- CAMINHO REAL DO BOSS RUSH DO SCANNER:
    local brCreator = main:FindFirstChild("BossRushCreator")
    local brStart = brCreator and brCreator:FindFirstChild("Start", true)
    if brStart and brStart:IsA("GuiButton") and brStart.Visible then
        CharacterModule.TriggerButton(brStart)
        return
    end

    -- OUTRAS FASES:
    for _, btn in ipairs(main:GetDescendants()) do
        if btn:IsA("GuiButton") and btn.Visible and (btn.Name == "Start" or btn.Name == "Play") then
            CharacterModule.TriggerButton(btn)
            return
        end
    end
end

function DungeonStateModule.CheckEnd()
    local main = pgui and pgui:FindFirstChild("Main")
    if not main then return false, nil end

    -- CAMINHO REAL DO SCANNER:
    local df = main:FindFirstChild("DungeonFrame")
    local playAgainBtn = df and df:FindFirstChild("PlayAgain", true)
    if playAgainBtn and playAgainBtn:IsA("GuiButton") and playAgainBtn.Visible then
        return true, playAgainBtn
    end

    for _, btn in ipairs(main:GetDescendants()) do
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
                        local dr = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Dungeon")
                        if dr then dr:FireServer("PlayAgain") end
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
    hasQueuedTeleport = false
    CharacterModule.StopMovement()
    bindCharacterEvents(newChar)
    SharedState.RespawnLockUntil = tick() + 1.0
    task.delay(1.0, function() SharedState.IsRespawning = false end)
end)

-- [[ 13. LOOPS PRINCIPAIS ]]
local isHandlingPlayAgain = false

-- Loop 1: M1
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not CharacterModule.IsActionBlocked() then
            if SharedState.HasTarget then
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
            if SharedState.HasTarget then
                CombatModule.ExecuteSkills()
            end
        end
        task.wait(0.1)
    end
end)

-- Loop 3: Farm & Movimentação
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoStart then 
            DungeonStateModule.CheckStart() 
        end

        if ConfigModule.Settings.AutoFarm and not SharedState.IsRespawning then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then
                local ended, playAgainBtn = DungeonStateModule.CheckEnd()
                if ended and playAgainBtn then
                    SharedState.IsDungeonEnded = true
                    SharedState.HasTarget = false
                    CharacterModule.StopMovement()

                    pcall(WebhookModule.ProcessDungeonDrops)

                    if ConfigModule.Settings.AutoPlayAgain and not isHandlingPlayAgain then
                        isHandlingPlayAgain = true
                        task.spawn(function()
                            task.wait(2.5)
                            if SharedState.IsRunning then
                                queueNextExecution()
                                task.wait(0.2)
                                CharacterModule.TriggerButton(playAgainBtn)
                                pcall(function()
                                    local dr = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Dungeon")
                                    if dr then dr:FireServer("PlayAgain") end
                                end)
                            end
                            task.wait(3.0)
                            isHandlingPlayAgain = false
                        end)
                    end
                else
                    if ConfigModule.Settings.SelectedPhase == "Boss Rush" then
                        FlowModule.RunBossRush()
                    elseif ConfigModule.Settings.SelectedPhase == "SAO" then
                        FlowModule.RunSAO()
                    elseif ConfigModule.Settings.SelectedPhase == "Infinity" then
                        FlowModule.RunInfinity()
                    end
                end
            else
                SharedState.HasTarget = false
                CharacterModule.StopMovement()
            end
        end
        task.wait(0.04)
    end
end)

-- [[ 14. INTERFACE VISUAL FLUENT ]]
local UIModule = {}

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
    Infinity = Window:AddTab({ Title = "Infinity" }),
    Sell = Window:AddTab({ Title = "Auto-Sell" }),
    Performance = Window:AddTab({ Title = "Otimização" }),
    Webhook = Window:AddTab({ Title = "Discord" }),
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
    if getgenv then 
        getgenv().HubDosRapazes_Running = nil 
        getgenv().HubDosRapazes_ActiveSession = nil
    end
    CharacterModule.StopMovement()
    if charConnection then charConnection:Disconnect() end
    if diedConnection then diedConnection:Disconnect() end
    if flightStabilizer then flightStabilizer:Disconnect() end
    if toggleGui and toggleGui.Parent then toggleGui:Destroy() end
    OptimizerModule.SetBlackScreen(false)
    
    pcall(function()
        if Window and Window.Destroy then Window:Destroy() end
    end)

    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

if getgenv then getgenv().HubDosRapazes_Shutdown = UIModule.Shutdown end

-- ABA FARM
local PhaseSection = Tabs.Farm:AddSection("Fase & Posição")
PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "Boss Rush", "SAO", "Infinity" },
    Default = ConfigModule.Settings.SelectedPhase,
    Callback = function(Value) ConfigModule.Settings.SelectedPhase = Value ConfigModule.Save() end
})

PhaseSection:AddDropdown("PositionModeSelector", {
    Title = "Modo de Posicionamento",
    Values = { "Nas Costas", "Em Cima da Cabeça", "Padrão (Anterior)" },
    Default = ConfigModule.Settings.PositionMode,
    Callback = function(Value) ConfigModule.Settings.PositionMode = Value ConfigModule.Save() end
})

local WeaponSection = Tabs.Farm:AddSection("Arma")
WeaponSection:AddDropdown("WeaponSelector", {
    Title = "Arma Equipada",
    Values = { "Yoru", "EmperorBisento" },
    Default = ConfigModule.Settings.CustomWeaponName,
    Callback = function(Value) ConfigModule.Settings.CustomWeaponName = Value ConfigModule.Save() end
})

local CombatSection = Tabs.Farm:AddSection("Combate & Movimento")
CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoFarm = Value if not Value then CharacterModule.StopMovement() end end
})
CombatSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura Vertical (Y)",
    Default = ConfigModule.Settings.HeightAboveEnemy,
    Min = 1, Max = 18, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.HeightAboveEnemy = Value ConfigModule.Save() end
})
CombatSection:AddSlider("BackDistance", {
    Title = "Distância das Costas",
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
CombatSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1)",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoAttack = Value end
})
CombatSection:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoSkills = Value end
})

-- ABA OTIMIZAÇÃO
local PerformanceSection = Tabs.Performance:AddSection("Otimizador de Desempenho")
PerformanceSection:AddToggle("FPSBoostToggle", {
    Title = "FPS Boost & Anti-Crash",
    Default = ConfigModule.Settings.FPSBoost,
    Callback = function(Value) ConfigModule.Settings.FPSBoost = Value ConfigModule.Save() if Value then OptimizerModule.ApplyAll() end end
})
PerformanceSection:AddToggle("BlackScreenToggle", {
    Title = "Tela Preta AFK",
    Default = ConfigModule.Settings.BlackScreenAFK,
    Callback = function(Value) ConfigModule.Settings.BlackScreenAFK = Value ConfigModule.Save() OptimizerModule.SetBlackScreen(Value) end
})

-- ABA SETTINGS
local SettingsSection = Tabs.Settings:AddSection("Gerenciamento")
SettingsSection:AddButton({
    Title = "Encerrar Script",
    Callback = UIModule.Shutdown
})

Window:SelectTab(Tabs.Farm)
