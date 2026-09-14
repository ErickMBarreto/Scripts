-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (COM OTIMIZADOR DE FPS & ANTI-CRASH)
-- ====================================================================

-- [[ 1. TRAVA SINGLETON & LIMPEZA DE AMBIENTE ]]
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
    warn("[Hub dos Rapazes] Falha ao carregar a interface. Tente executar novamente.")
    return
end

local FIXED_START_WAIT_TIME = 5.0

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
    StartLockUntil = tick() + FIXED_START_WAIT_TIME,
    RespawnLockUntil = 0,
    HasTarget = false,
    IsSelectingBonus = false,
    HasPassedPortal1 = false,
    HasEnteredBossRoom = false
}

-- [[ 2. CONFIGURAÇÕES ]]
local ConfigModule = {}
ConfigModule.Settings = {
    SelectedPhase = "SAO",
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
    TweenSpeed = 48,
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
    -- Configurações Anti-Crash (Mobile)
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

-- [[ 3. MÓDULO OTIMIZADOR DE FPS & ANTI-CRASH (MOBILE) ]]
local OptimizerModule = {}
local blackScreenFrame = nil

function OptimizerModule.CleanInstance(v)
    if not ConfigModule.Settings.FPSBoost then return end
    pcall(function()
        if ConfigModule.Settings.DisableParticles then
            if v:IsA("ParticleEmitter") or v:IsA("Sparkles") or v:IsA("Smoke") or v:IsA("Fire") then
                v.Enabled = false
            elseif v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = false
            end
        end

        if v:IsA("Light") then
            v.Enabled = false
        end

        if v:IsA("MeshPart") or v:IsA("Part") then
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
        end

        if v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        end
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

    -- Libera RAM retida no garbage collector do Lua
    collectgarbage("collect")
end

-- Listener para novos efeitos instanciados (skills de mobs/armas)
workspace.DescendantAdded:Connect(function(child)
    if ConfigModule.Settings.FPSBoost then
        task.delay(0.1, function()
            OptimizerModule.CleanInstance(child)
        end)
    end
end)

-- Black Screen AFK (Economia extrema de bateria e GPU)
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

-- Executa uma otimização inicial suave após o carregamento
task.spawn(function()
    task.wait(3.0)
    OptimizerModule.ApplyAll()
end)

-- [[ 4. DISCORD WEBHOOK ]]
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
    local hasSecret = false
    local hasMythic = false

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

    local shouldNotify = false
    if ConfigModule.Settings.NotifyEveryRun then
        shouldNotify = true
    elseif ConfigModule.Settings.NotifySecrets and hasSecret then
        shouldNotify = true
    elseif ConfigModule.Settings.NotifyMythics and hasMythic then
        shouldNotify = true
    end

    if shouldNotify then
        SharedState.HasSentWebhook = true
        local dropsText = #droppedItems > 0 and table.concat(droppedItems, "\n") or "Nenhum item especial"
        local embedColor = hasSecret and 16711680 or (hasMythic and 16744192 or 65450)

        local embed = {
            ["title"] = "⚔️ Fase Concluída - " .. tostring(ConfigModule.Settings.SelectedPhase),
            ["color"] = embedColor,
            ["fields"] = {
                { ["name"] = "👤 Jogador", ["value"] = player.Name, ["inline"] = true },
                { ["name"] = "🗺️ Fase", ["value"] = ConfigModule.Settings.SelectedPhase, ["inline"] = true },
                { ["name"] = "🎁 Drops da Partida", ["value"] = dropsText, ["inline"] = false }
            },
            ["footer"] = { ["text"] = "Hub dos Rapazes • " .. os.date("%X") }
        }

        WebhookModule.Send({
            ["username"] = "Hub dos Rapazes Bot",
            ["avatar_url"] = "https://i.imgur.com/8Qf9Z2N.png",
            ["embeds"] = { embed }
        })
    end
end

-- [[ 5. PERSONAGEM & FÍSICA ESTÁVEL ]]
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
    local now = tick()
    if now < SharedState.StartLockUntil then return true end
    if now < SharedState.RespawnLockUntil then return true end
    if SharedState.IsRespawning or SharedState.EnteringPortal or SharedState.IsTransitioning or SharedState.IsDungeonEnded or not SharedState.IsRunning then
        return true
    end
    return false
end

flightStabilizer = RunService.Stepped:Connect(function()
    if SharedState.IsRunning and ConfigModule.Settings.AutoFarm and not CharacterModule.IsActionBlocked() then
        if SharedState.HasTarget and not SharedState.IsSelectingBonus then
            local _, root, hum = CharacterModule.Get()
            if root and hum and hum.Health > 0 then
                root.AssemblyAngularVelocity = Vector3.zero
                if not SharedState.CurrentTween then
                    root.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0)
                end
            end
        else
            local _, root = CharacterModule.Get()
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    else
        local _, root = CharacterModule.Get()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

function CharacterModule.GetSafeCFrame(targetPosition, lookAtPosition)
    local char = player.Character
    local rayOrigin = targetPosition + Vector3.new(0, 15, 0)
    local rayDirection = Vector3.new(0, -35, 0)
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if char then params.FilterDescendantsInstances = {char} end
    
    local hit = workspace:Raycast(rayOrigin, rayDirection, params)
    local safeY = targetPosition.Y

    if hit then
        local floorY = hit.Position.Y
        if safeY < (floorY + 2.5) then 
            safeY = floorY + 2.5 
        end
    end

    if ConfigModule.Settings.SelectedPhase == "SAO" and safeY < 1005 then
        safeY = 1005.5
    end

    local safePos = Vector3.new(targetPosition.X, safeY, targetPosition.Z)
    return CFrame.new(safePos, lookAtPosition)
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

    if ConfigModule.Settings.SelectedPhase == "SAO" and targetPart.Position.Y < 985 then
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
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + backOffset, enemyPos)
    elseif mode == "Em Cima da Cabeça" then
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1), enemyPos)
    else
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0), enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude

    if distance <= 1.2 then return end

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 2.0 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 15), 0.15, 2.0)

    if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.FollowBehindLive(targetPart)
    CharacterModule.FlyToEnemy(targetPart, "Nas Costas")
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

-- [[ 6. MÓDULOS ESPECÍFICOS: INFINITY E SAO ]]
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

    local offsetX = math.cos(orbitAngle) * radius
    local offsetZ = math.sin(orbitAngle) * radius
    local desiredPosition = enemyPos + Vector3.new(offsetX, height, offsetZ)

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

        local timeCard = nil
        local damageCard = nil
        local fallbackCard = nil

        for _, card in ipairs(bonuses:GetChildren()) do
            if card:IsA("GuiObject") and card.Visible and card.Name:find("Bonus") then
                if not fallbackCard then fallbackCard = card end

                local bName = card:FindFirstChild("BonusName")
                local bDesc = card:FindFirstChild("BonusDescription")
                local combinedText = ((bName and bName:IsA("TextLabel")) and bName.Text or "") .. " " ..
                                     ((bDesc and bDesc:IsA("TextLabel")) and bDesc.Text or "")
                combinedText = combinedText:lower()

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

-- [[ 7. DETECÇÃO DE INIMIGOS (ORIGINAL + FILTRO DE BAÚ) ]]
local TargetingModule = {}

local function isChest(objName)
    local n = objName:lower()
    return n:find("chest") or n:find("crate") or n:find("reward") or n:find("loot") or n:find("box")
end

function TargetingModule.IsAlive(obj)
    if not obj or not obj.Parent then return false end
    if isChest(obj.Name) then return false end
    
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then 
        if hum.Health <= 0.1 or hum:GetState() == Enum.HumanoidStateType.Dead then
            return false
        end
    end
    
    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("CurrentHealth")
    if hpAttr and tonumber(hpAttr) <= 0.1 then 
        return false 
    end
    
    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") and tonumber(hpVal.Value) <= 0.1 then 
        return false 
    end
    
    return true
end

function TargetingModule.GetTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    local part = obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("HitBox")
        or obj:FindFirstChild("Head")
        or obj:FindFirstChild("Torso")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or obj:FindFirstChildWhichIsA("BasePart")
    
    if not part then return nil end

    if ConfigModule.Settings.SelectedPhase == "SAO" and part.Position.Y < 985 then
        return nil
    end

    if part.Position.Y > -2000 then
        return part
    end
    return nil
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
    local searchContainers = {
        gameFolder and gameFolder:FindFirstChild("Enemies"),
        workspace:FindFirstChild("Enemies"),
        gameFolder and gameFolder:FindFirstChild("Stages"),
        gameFolder and gameFolder:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("Virus"),
        gameFolder and gameFolder:FindFirstChild("SecretBoss"),
        gameFolder and gameFolder:FindFirstChild("BossRush"),
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

    if #list == 0 and gameFolder then
        for _, desc in ipairs(gameFolder:GetDescendants()) do
            if desc:IsA("Model") and desc ~= char and not Players:GetPlayerFromCharacter(desc) then
                if desc.Name ~= "Clothing" and not desc:FindFirstAncestor("Players") then
                    addEntity(desc)
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

-- [[ 8. MÓDULO DE COMBATE ]]
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

-- [[ 9. AUTO-SELL & AUTO-FAVORITE ]]
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
    local favoritedCount = 0

    for _, slot in ipairs(scroll:GetChildren()) do
        if (slot:IsA("ImageButton") or slot:IsA("Frame")) and slot:FindFirstChild("Item") and slot.Item:IsA("ObjectValue") then
            local itemObj = slot.Item.Value
            if itemObj and itemObj.Parent then
                local isFav = itemObj:GetAttribute("Favorite") == true
                if not isFav then
                    local rarity = AutoSellModule.ResolveRarity(slot, itemObj)
                    local shouldLock = false

                    if rarity == "Secret" and ConfigModule.Settings.AutoFavoriteSecrets then
                        shouldLock = true
                    elseif rarity == "Mythic" and ConfigModule.Settings.AutoFavoriteMythics then
                        shouldLock = true
                    end

                    if shouldLock then
                        pcall(function()
                            equipRemote:FireServer("Favorite", itemObj)
                            local favIcon = slot:FindFirstChild("Favorite", true)
                            if favIcon then CharacterModule.TriggerButton(favIcon) end
                        end)
                        favoritedCount = favoritedCount + 1
                        task.wait(0.1)
                    end
                end
            end
        end
    end

    if favoritedCount > 0 then
        Fluent:Notify({
            Title = "🔒 Auto-Favorite",
            Content = string.format("%d itens de alto valor protegidos!", favoritedCount),
            Duration = 4
        })
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
                        local shouldSell = false

                        if rarity == "Common" and ConfigModule.Settings.SellCommon then
                            shouldSell = true
                        elseif rarity == "Rare" and ConfigModule.Settings.SellRare then
                            shouldSell = true
                        elseif rarity == "Epic" and ConfigModule.Settings.SellEpic then
                            shouldSell = true
                        elseif rarity == "Legendary" and ConfigModule.Settings.SellLegendary then
                            shouldSell = true
                        elseif rarity == "Mythic" and ConfigModule.Settings.SellMythic then
                            shouldSell = true
                        end

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
        task.wait(2.0)
    end

    SharedState.IsSelling = false
end

-- [[ 10. MÓDULO DE MISSÕES ]]
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

-- [[ 11. FLUXO DE FASES & ROTAS ]]
local FlowModule = {}

local BLEACH_PORTAL_1 = CFrame.new(4557.2, -305.5, 1925.0)
local BLEACH_PORTAL_2 = CFrame.new(5411.5, -561.0, 2550.0)

local OP_PORTAL_1_WAVE7  = CFrame.new(1196.6, -240.9, 1855.1)
local OP_PORTAL_2_WAVE12 = CFrame.new(2909.3, -105.7, 2151.7)

local SAO_PORTAL_1 = CFrame.new(3460.3, 1006.1, 197.2)
local SAO_PORTAL_2 = CFrame.new(1430.5, 1006.1, 905.6)

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
            if n and n >= 1 and n <= 100 then 
                return n 
            end
        end
    end
    return 1
end

function FlowModule.PassPortal(targetCFrame, onCompleteCallback)
    local _, root = CharacterModule.Get()
    if not root then return end

    if SharedState.EnteringPortal and (tick() - SharedState.LastPortalAttempt) > 4.0 then
        SharedState.EnteringPortal = false
    end

    if SharedState.EnteringPortal then return end

    local dist = (root.Position - targetCFrame.Position).Magnitude

    if dist > 3.0 then
        CharacterModule.FlyToPortal(targetCFrame)
    else
        SharedState.EnteringPortal = true
        SharedState.LastPortalAttempt = tick()
        CharacterModule.StopMovement()

        local oldPos = root.Position
        local startWait = tick()

        while (tick() - startWait) < 2.5 do
            task.wait(0.08)
            local _, curRoot = CharacterModule.Get()
            if curRoot and (curRoot.Position - oldPos).Magnitude > 8 then
                break
            end
        end

        task.wait(0.5)

        local _, finalRoot = CharacterModule.Get()
        if finalRoot then
            finalRoot.AssemblyLinearVelocity = Vector3.zero
            finalRoot.AssemblyAngularVelocity = Vector3.zero
        end

        SharedState.EnteringPortal = false
        if onCompleteCallback then
            onCompleteCallback()
        end
    end
end

function FlowModule.RunSAO()
    local _, root = CharacterModule.Get()
    if not root then return end

    if CharacterModule.IsActionBlocked() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end

    -- 1. Cartas Automáticas
    if SAOModule.CheckBonus() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end

    -- 2. Boss Secreto / Virus
    if SharedState.IsVirusActive then
        local _, enemyPart = TargetingModule.GetClosestEnemy("SAO")
        if enemyPart then
            SharedState.HasTarget = true
            CharacterModule.FlyToEnemy(enemyPart)
        else
            SharedState.HasTarget = false
            CharacterModule.StopMovement()
        end
        return
    end

    local wave = FlowModule.GetWave()

    -- 3. COMBATE REGULAR (Varre apenas monstros com vida ativa confirmada)
    local currentMob, mobPart = TargetingModule.GetClosestEnemy("SAO")
    if currentMob and mobPart then
        if wave >= 16 then
            SharedState.HasEnteredBossRoom = true
        end
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(mobPart)
        return
    end

    CharacterModule.StopMovement()

    -- 4. TRANSIÇÃO DE PORTAIS
    if wave >= 16 and not SharedState.HasEnteredBossRoom then
        local distToP2 = (root.Position - SAO_PORTAL_2.Position).Magnitude
        if distToP2 < 300 and distToP2 > 2.0 then
            SharedState.HasTarget = true
            FlowModule.PassPortal(SAO_PORTAL_2, function()
                SharedState.HasEnteredBossRoom = true
                task.wait(0.5)
            end)
            return
        end
    elseif wave >= 12 and wave < 16 and not SharedState.HasPassedPortal1 then
        local distToP1 = (root.Position - SAO_PORTAL_1.Position).Magnitude
        if distToP1 < 350 and distToP1 > 2.0 then
            SharedState.HasTarget = true
            FlowModule.PassPortal(SAO_PORTAL_1, function()
                SharedState.HasPassedPortal1 = true
                task.wait(0.5)
            end)
            return
        end
    end

    -- 5. STANDBY SEGURO
    SharedState.HasTarget = false
    CharacterModule.StopMovement()
end

-- Rota Bleach
function FlowModule.RunBleach()
    local _, root = CharacterModule.Get()
    if not root or CharacterModule.IsActionBlocked() then return end

    if SharedState.IsVirusActive then
        local _, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
        if enemyPart then
            SharedState.HasTarget = true
            CharacterModule.FlyToEnemy(enemyPart)
        else
            SharedState.HasTarget = false
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
        SharedState.HasTarget = true
        FlowModule.PassPortal(BLEACH_PORTAL_2)
        return
    end
    if wave >= 8 and currentRoom == "Room1" then
        SharedState.HasTarget = true
        FlowModule.PassPortal(BLEACH_PORTAL_1)
        return
    end

    local _, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
    if enemyPart then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(enemyPart)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

-- Rota One Piece
function FlowModule.RunOnePiece()
    local _, root = CharacterModule.Get()
    if not root or CharacterModule.IsActionBlocked() then return end

    if SharedState.IsVirusActive then
        local _, enemyPart = TargetingModule.GetClosestEnemy("One Piece")
        if enemyPart then
            SharedState.HasTarget = true
            CharacterModule.FlyToEnemy(enemyPart)
        else
            SharedState.HasTarget = false
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

    if wave >= 12 then
        if currentRoom == "Room1" then
            SharedState.HasTarget = true
            FlowModule.PassPortal(OP_PORTAL_1_WAVE7)
            return
        elseif currentRoom == "Room2" then
            SharedState.HasTarget = true
            FlowModule.PassPortal(OP_PORTAL_2_WAVE12)
            return
        end
    elseif wave >= 7 and currentRoom == "Room1" then
        SharedState.HasTarget = true
        FlowModule.PassPortal(OP_PORTAL_1_WAVE7)
        return
    end

    local _, enemyPart = TargetingModule.GetClosestEnemy("One Piece")
    if enemyPart then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(enemyPart)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

-- Rota Boss Rush
function FlowModule.RunBossRush()
    if CharacterModule.IsActionBlocked() then return end
    local _, enemyPart = TargetingModule.GetClosestEnemy("Boss Rush")
    if enemyPart and enemyPart.Parent then
        SharedState.HasTarget = true
        CharacterModule.FollowBehindLive(enemyPart)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

-- Rota Incursão
function FlowModule.RunIncursion()
    if CharacterModule.IsActionBlocked() then return end
    local _, enemyPart = TargetingModule.GetClosestEnemy("Incursão")
    if enemyPart and enemyPart.Parent then
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(enemyPart, ConfigModule.Settings.PositionMode)
    else
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
    end
end

-- Rota Infinity
function FlowModule.RunInfinity()
    if CharacterModule.IsActionBlocked() then return end
    if InfinityModule.CheckBonus() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end

    local _, enemyPart = TargetingModule.GetClosestEnemy("Infinity")
    if enemyPart and enemyPart.Parent and enemyPart.Position.Y > -2000 then
        SharedState.HasTarget = true
        InfinityMovement.Step(enemyPart)
    else
        SharedState.HasTarget = false
        InfinityMovement.HoldCenter()
    end
end

-- [[ 12. ESTADOS DA DUNGEON & AUTO-START ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    if not pgui or (tick() - SharedState.LastStartAttempt) < 1.0 then return end
    SharedState.LastStartAttempt = tick()
    
    local main = pgui:FindFirstChild("Main")
    if not main then return end

    local targetFrames = {
        main:FindFirstChild("DungeonFrame"),
        main:FindFirstChild("BossRushFrame"),
        main:FindFirstChild("RaidFrame"),
        main:FindFirstChild("InfinityCreator")
    }

    for _, frame in ipairs(targetFrames) do
        if frame and frame.Visible then
            local startBtn = frame:FindFirstChild("Start", true) 
                or frame:FindFirstChild("Play", true) 
                or (frame:FindFirstChild("DungeonStart") and frame.DungeonStart:FindFirstChild("Play"))
                
            if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
                CharacterModule.TriggerButton(startBtn)
                SharedState.IsVirusActive = false
                SharedState.HasClickedStart = true
                SharedState.HasPassedPortal1 = false
                SharedState.HasEnteredBossRoom = false
                SharedState.StartLockUntil = tick() + FIXED_START_WAIT_TIME
                CharacterModule.StopMovement()
                return
            end
        end
    end
end

function DungeonStateModule.CheckEngage()
    if not ConfigModule.Settings.AutoEngage then return false end
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
    if not main then return false, nil end

    local df = main:FindFirstChild("DungeonFrame") or main:FindFirstChild("RaidFrame") or main:FindFirstChild("BossRushFrame")
    local dungeonStats = (df and df:FindFirstChild("DungeonStats")) or main:FindFirstChild("DungeonStats", true)

    if dungeonStats and dungeonStats.Visible then
        for _, obj in ipairs(dungeonStats:GetDescendants()) do
            if obj:IsA("GuiButton") and obj.Visible then
                local name = obj.Name:lower()
                if name:find("playagain") or name:find("retry") or name:find("again") then
                    return true, obj
                end
                local label = obj:FindFirstChildOfClass("TextLabel")
                if label and (label.Text:lower():find("play again") or label.Text:lower():find("jogar novamente")) then
                    return true, obj
                end
            end
        end
    end
    return false, nil
end

local function onPlayerDiedHandler()
    CharacterModule.StopMovement()
    SharedState.EnteringPortal = false
    SharedState.IsTransitioning = false
    SharedState.LastRoomState = "Room1"
    SharedState.HasTarget = false
    SharedState.IsSelectingBonus = false

    local curWave = FlowModule.GetWave()
    if curWave < 16 then
        SharedState.HasEnteredBossRoom = false
    end
    if curWave < 12 then
        SharedState.HasPassedPortal1 = false
    end

    if (ConfigModule.Settings.SelectedPhase == "Boss Rush" or ConfigModule.Settings.SelectedPhase == "Infinity" or ConfigModule.Settings.SelectedPhase == "SAO") and ConfigModule.Settings.AutoPlayAgain then
        task.spawn(function()
            task.wait(3.0)
            for _ = 1, 15 do
                if not SharedState.IsRunning then break end
                local ended, retryBtn = DungeonStateModule.CheckEnd()
                if ended and retryBtn then
                    SharedState.IsDungeonEnded = true
                    queueNextExecution()
                    task.wait(0.2)
                    CharacterModule.TriggerButton(retryBtn)
                    break
                end
                task.wait(0.5)
            end
        end)
        return
    end

    if ConfigModule.Settings.SelectedPhase == "Incursão" then
        return
    end

    if not ConfigModule.Settings.HardcoreMode then return end
    task.spawn(function()
        task.wait(23)
        if not SharedState.IsRunning or not ConfigModule.Settings.HardcoreMode or not ConfigModule.Settings.AutoPlayAgain then return end
        CharacterModule.StopMovement()
        local _, retryBtn = DungeonStateModule.CheckEnd()
        if retryBtn then
            queueNextExecution()
            task.wait(0.2)
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
    SharedState.HasSentWebhook = false
    SharedState.LastRoomState = "Room1"
    SharedState.HasTarget = false
    SharedState.IsSelectingBonus = false

    local curWave = FlowModule.GetWave()
    if curWave < 16 then
        SharedState.HasEnteredBossRoom = false
    end
    if curWave < 12 then
        SharedState.HasPassedPortal1 = false
    end

    CharacterModule.StopMovement()
    bindCharacterEvents(newChar)

    SharedState.RespawnLockUntil = tick() + 1.0
    task.delay(1.0, function() 
        SharedState.IsRespawning = false 
    end)
end)

-- [[ 13. LOOPS PRINCIPAIS INDEPENDENTES ]]
local initialRoutinesScheduled = false
local isHandlingPlayAgain = false

-- Loop 1: Ataque M1
task.spawn(function()
    while SharedState.IsRunning do
        if not CharacterModule.IsActionBlocked() and SharedState.HasTarget and not SharedState.IsSelectingBonus then
            if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded then
                local _, _, hum = CharacterModule.Get()
                if hum and hum.Health > 0 then 
                    CombatModule.ExecuteM1() 
                end
            end
        end
        task.wait(ConfigModule.Settings.AttackSpeed)
    end
end)

-- Loop 2: Skills
task.spawn(function()
    while SharedState.IsRunning do
        if not CharacterModule.IsActionBlocked() and SharedState.HasTarget and not SharedState.IsSelectingBonus then
            if ConfigModule.Settings.AutoSkills and not SharedState.IsDungeonEnded then
                local _, _, hum = CharacterModule.Get()
                if hum and hum.Health > 0 then 
                    CombatModule.ExecuteSkills() 
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Loop 3: Farm, Movimento e Estados
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoStart then DungeonStateModule.CheckStart() end

        if ConfigModule.Settings.AutoFarm and not SharedState.IsRespawning then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then
                if not initialRoutinesScheduled then
                    initialRoutinesScheduled = true
                    
                    task.spawn(function()
                        task.wait(13)
                        if SharedState.IsRunning and ConfigModule.Settings.AutoClaimQuests and not SharedState.IsDungeonEnded and not SharedState.HasExecutedQuests then
                            SharedState.HasExecutedQuests = true
                            QuestModule.ClaimAll()
                        end
                    end)

                    task.spawn(function()
                        task.wait(ConfigModule.Settings.SellDelaySeconds)
                        if SharedState.IsRunning and not SharedState.IsDungeonEnded and not SharedState.HasExecutedSell then
                            SharedState.HasExecutedSell = true
                            if ConfigModule.Settings.AutoFavoriteSecrets or ConfigModule.Settings.AutoFavoriteMythics then
                                AutoSellModule.LockHighTierItems()
                            end
                            if ConfigModule.Settings.AutoSell then
                                AutoSellModule.Execute()
                            end
                        end
                    end)
                end

                local ended, playAgainBtn = DungeonStateModule.CheckEnd()
                if ended and playAgainBtn then
                    SharedState.IsDungeonEnded = true
                    SharedState.IsVirusActive = false
                    SharedState.HasTarget = false
                    SharedState.HasPassedPortal1 = false
                    SharedState.HasEnteredBossRoom = false
                    CharacterModule.StopMovement()

                    pcall(WebhookModule.ProcessDungeonDrops)

                    -- Coleta de lixo e limpeza de memória após o término da partida
                    task.spawn(function()
                        collectgarbage("collect")
                    end)

                    if ConfigModule.Settings.AutoPlayAgain and not isHandlingPlayAgain then
                        isHandlingPlayAgain = true
                        task.spawn(function()
                            task.wait(3.0)
                            if SharedState.IsRunning then
                                queueNextExecution()
                                task.wait(0.2)
                                CharacterModule.TriggerButton(playAgainBtn)
                            end
                            task.wait(3.0)
                            isHandlingPlayAgain = false
                        end)
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
                        if ConfigModule.Settings.SelectedPhase == "SAO" then
                            FlowModule.RunSAO()
                        elseif ConfigModule.Settings.SelectedPhase == "Infinity" then
                            FlowModule.RunInfinity()
                        elseif ConfigModule.Settings.SelectedPhase == "One Piece" then
                            FlowModule.RunOnePiece()
                        elseif ConfigModule.Settings.SelectedPhase == "Bleach (Fase 4)" then
                            FlowModule.RunBleach()
                        elseif ConfigModule.Settings.SelectedPhase == "Boss Rush" then
                            FlowModule.RunBossRush()
                        elseif ConfigModule.Settings.SelectedPhase == "Incursão" then
                            FlowModule.RunIncursion()
                        end
                    end
                end
            else
                SharedState.HasTarget = false
                CharacterModule.StopMovement()
            end
        else
            SharedState.HasTarget = false
            CharacterModule.StopMovement()
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
        if Window and Window.Destroy then
            Window:Destroy()
        end
    end)

    for _, gui in ipairs({CoreGui, player.PlayerGui}) do
        for _, child in ipairs(gui:GetChildren()) do
            if child.Name == "IBdihP_PersistentToggle" or child.Name:find("Fluent") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

if getgenv then
    getgenv().HubDosRapazes_Shutdown = UIModule.Shutdown
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

-- ABA FARM
local PhaseSection = Tabs.Farm:AddSection("Configurações de Fase & Posição")
PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "SAO", "Infinity", "One Piece", "Bleach (Fase 4)", "Boss Rush", "Incursão" },
    Default = ConfigModule.Settings.SelectedPhase,
    Callback = function(Value) ConfigModule.Settings.SelectedPhase = Value ConfigModule.Save() end
})

PhaseSection:AddDropdown("PositionModeSelector", {
    Title = "Modo de Posicionamento",
    Values = { "Nas Costas", "Em Cima da Cabeça", "Padrão (Anterior)" },
    Default = ConfigModule.Settings.PositionMode,
    Callback = function(Value) ConfigModule.Settings.PositionMode = Value ConfigModule.Save() end
})

local WeaponSection = Tabs.Farm:AddSection("Configuração de Arma")
WeaponSection:AddDropdown("WeaponSelector", {
    Title = "Selecionar Arma Equipada",
    Values = { "Yoru", "EmperorBisento" },
    Default = ConfigModule.Settings.CustomWeaponName,
    Callback = function(Value)
        ConfigModule.Settings.CustomWeaponName = Value
        ConfigModule.Save()
    end
})

local CombatSection = Tabs.Farm:AddSection("Controles de Combate & Movimento")
CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoFarm = Value if not Value then CharacterModule.StopMovement() end end
})
CombatSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura Vertical Padrão (Y)",
    Default = ConfigModule.Settings.HeightAboveEnemy,
    Min = 1, Max = 18, Rounding = 1,
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
    Description = "Espera 23s após a morte e clica em Play Again (Bleach/One Piece)",
    Default = ConfigModule.Settings.HardcoreMode,
    Callback = function(Value) ConfigModule.Settings.HardcoreMode = Value ConfigModule.Save() end
})
CombatSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Boss Secreto)",
    Default = ConfigModule.Settings.AutoEngage,
    Callback = function(Value) 
        ConfigModule.Settings.AutoEngage = Value 
        ConfigModule.Save()
    end
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

-- ABA INFINITY (EXCLUSIVA)
local InfinitySection = Tabs.Infinity:AddSection("Ações de Wave (Infinity)")

InfinitySection:AddButton({
    Title = "⚡ Forçar Skip Agora",
    Description = "Dispara o Remote e clica no SkipWave imediatamente",
    Callback = function()
        local ok = InfinityModule.ForceSkip()
        if ok then
            Fluent:Notify({
                Title = "Skip Acionado",
                Content = "Comando de Skip Wave executado!",
                Duration = 2.5
            })
        end
    end
})

InfinitySection:AddToggle("InfinitySkipWaveToggle", {
    Title = "Auto Skip Wave (Automático)",
    Description = "Aciona o Skip automaticamente assim que ele aparecer na tela",
    Default = ConfigModule.Settings.InfinityAutoSkipWave,
    Callback = function(Value)
        ConfigModule.Settings.InfinityAutoSkipWave = Value
        ConfigModule.Save()
    end
})

InfinitySection:AddDropdown("CardSlotSelector", {
    Title = "Carta Padrão para Seleção",
    Description = "Qual das 3 opções de bônus o script escolhe automaticamente",
    Values = { "Carta 1 (Esquerda)", "Carta 2 (Centro)", "Carta 3 (Direita)" },
    Default = "Carta 1 (Esquerda)",
    Callback = function(Value)
        if Value == "Carta 1 (Esquerda)" then ConfigModule.Settings.InfinityCardSlot = 1
        elseif Value == "Carta 2 (Centro)" then ConfigModule.Settings.InfinityCardSlot = 2
        elseif Value == "Carta 3 (Direita)" then ConfigModule.Settings.InfinityCardSlot = 3
        end
        ConfigModule.Save()
    end
})

local KitingSection = Tabs.Infinity:AddSection("Kiting Orbital 3D (Desvio de AoE)")

KitingSection:AddSlider("InfinityRadiusSlider", {
    Title = "Raio da Órbita (Studs)",
    Description = "Distância horizontal ao redor do monstro",
    Default = ConfigModule.Settings.InfinityOrbitRadius,
    Min = 6.0, Max = 18.0, Rounding = 1,
    Callback = function(Value)
        ConfigModule.Settings.InfinityOrbitRadius = Value
        ConfigModule.Save()
    end
})

KitingSection:AddSlider("InfinityHeightSlider", {
    Title = "Altura da Órbita (Studs)",
    Description = "Elevação vertical segura acima do monstro",
    Default = ConfigModule.Settings.InfinityOrbitHeight,
    Min = 8.0, Max = 20.0, Rounding = 1,
    Callback = function(Value)
        ConfigModule.Settings.InfinityOrbitHeight = Value
        ConfigModule.Save()
    end
})

KitingSection:AddSlider("InfinitySpeedSlider", {
    Title = "Velocidade da Rotação Orbital",
    Description = "Quão rápido o boneco circula para desviar dos cones de ataque",
    Default = ConfigModule.Settings.InfinityOrbitSpeed,
    Min = 1.0, Max = 7.0, Rounding = 1,
    Callback = function(Value)
        ConfigModule.Settings.InfinityOrbitSpeed = Value
        ConfigModule.Save()
    end
})

-- ABA AUTO-SELL & FAVORITE
local FavoriteSection = Tabs.Sell:AddSection("Proteção de Itens (Auto-Favorite)")
FavoriteSection:AddToggle("AutoFavSecretsToggle", {
    Title = "Auto-Favorite Secretos",
    Description = "Bloqueia e favorita automaticamente qualquer item Secreto",
    Default = ConfigModule.Settings.AutoFavoriteSecrets,
    Callback = function(Value) ConfigModule.Settings.AutoFavoriteSecrets = Value ConfigModule.Save() end
})
FavoriteSection:AddToggle("AutoFavMythicsToggle", {
    Title = "Auto-Favorite Míticos",
    Description = "Bloqueia e favorita automaticamente qualquer item Mítico",
    Default = ConfigModule.Settings.AutoFavoriteMythics,
    Callback = function(Value) ConfigModule.Settings.AutoFavoriteMythics = Value ConfigModule.Save() end
})
FavoriteSection:AddButton({
    Title = "🔒 Bloquear / Favoritar Raros Agora",
    Description = "Varre o inventário e protege itens Secretos e Míticos",
    Callback = function() pcall(AutoSellModule.LockHighTierItems) end
})

local SellMainSection = Tabs.Sell:AddSection("Controle Geral de Venda")
SellMainSection:AddToggle("AutoSellToggle", {
    Title = "Ativar Auto-Sell",
    Description = "Vende automaticamente 1 vez logo após iniciar a dungeon",
    Default = ConfigModule.Settings.AutoSell,
    Callback = function(Value) 
        ConfigModule.Settings.AutoSell = Value 
        ConfigModule.Save()
    end
})
SellMainSection:AddSlider("SellDelaySlider", {
    Title = "Tempo pós-início para Vender (s)",
    Description = "Quantos segundos esperar após entrar na fase para disparar a venda única",
    Default = ConfigModule.Settings.SellDelaySeconds,
    Min = 1, Max = 30, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.SellDelaySeconds = Value ConfigModule.Save() end
})
SellMainSection:AddButton({
    Title = "💰 Executar Venda Imediata",
    Description = "Varre o inventário e vende os itens configurados agora",
    Callback = function() pcall(AutoSellModule.Execute) end
})

local SellRaritiesSection = Tabs.Sell:AddSection("Filtro de Raridades para Venda")
SellRaritiesSection:AddToggle("SellCommonToggle", {
    Title = "Vender Comuns",
    Default = ConfigModule.Settings.SellCommon,
    Callback = function(Value) ConfigModule.Settings.SellCommon = Value ConfigModule.Save() end
})
SellRaritiesSection:AddToggle("SellRareToggle", {
    Title = "Vender Raros",
    Default = ConfigModule.Settings.SellRare,
    Callback = function(Value) ConfigModule.Settings.SellRare = Value ConfigModule.Save() end
})
SellRaritiesSection:AddToggle("SellEpicToggle", {
    Title = "Vender Épicos",
    Default = ConfigModule.Settings.SellEpic,
    Callback = function(Value) ConfigModule.Settings.SellEpic = Value ConfigModule.Save() end
})
SellRaritiesSection:AddToggle("SellLegendaryToggle", {
    Title = "Vender Lendários",
    Default = ConfigModule.Settings.SellLegendary,
    Callback = function(Value) ConfigModule.Settings.SellLegendary = Value ConfigModule.Save() end
})
SellRaritiesSection:AddToggle("SellMythicToggle", {
    Title = "Vender Míticos",
    Default = ConfigModule.Settings.SellMythic,
    Callback = function(Value) ConfigModule.Settings.SellMythic = Value ConfigModule.Save() end
})

-- ABA OTIMIZAÇÃO (NOVA - ANTI-CRASH MOBILE)
local PerformanceSection = Tabs.Performance:AddSection("Otimizador de Desempenho & RAM")

PerformanceSection:AddToggle("FPSBoostToggle", {
    Title = "FPS Boost & Anti-Crash",
    Description = "Desativa partículas, luzes dinâmicas e texturas pesadas",
    Default = ConfigModule.Settings.FPSBoost,
    Callback = function(Value)
        ConfigModule.Settings.FPSBoost = Value
        ConfigModule.Save()
        if Value then OptimizerModule.ApplyAll() end
    end
})

PerformanceSection:AddToggle("DisableShadowsToggle", {
    Title = "Desativar Sombras & Pós-Processamento",
    Description = "Remove sombras em tempo real e névoa da iluminação",
    Default = ConfigModule.Settings.DisableShadows,
    Callback = function(Value)
        ConfigModule.Settings.DisableShadows = Value
        ConfigModule.Save()
        if Value then OptimizerModule.ApplyAll() end
    end
})

PerformanceSection:AddToggle("BlackScreenToggle", {
    Title = "Tela Preta AFK (Poupe Bateria/RAM)",
    Description = "Desativa a renderização 3D do mapa. O bot continua farmando.",
    Default = ConfigModule.Settings.BlackScreenAFK,
    Callback = function(Value)
        ConfigModule.Settings.BlackScreenAFK = Value
        ConfigModule.Save()
        OptimizerModule.SetBlackScreen(Value)
    end
})

PerformanceSection:AddButton({
    Title = "🧹 Limpar Memória RAM Agora",
    Description = "Força a coleta de lixo do Lua para aliviar a memória",
    Callback = function()
        OptimizerModule.ApplyAll()
        Fluent:Notify({ Title = "RAM", Content = "Memória do jogo limpa com sucesso!", Duration = 3 })
    end
})

-- ABA WEBHOOK DISCORD
local WebhookSection = Tabs.Webhook:AddSection("Configuração do Webhook")
WebhookSection:AddToggle("WebhookEnableToggle", {
    Title = "Ativar Notificações no Discord",
    Default = ConfigModule.Settings.WebhookEnabled,
    Callback = function(Value) 
        ConfigModule.Settings.WebhookEnabled = Value 
        ConfigModule.Save()
    end
})
local WebhookInput = WebhookSection:AddInput("WebhookURLBox", {
    Title = "URL do Webhook Discord",
    Default = ConfigModule.Settings.WebhookURL,
    Placeholder = "Cole o link https://discord.com/api/webhooks/...",
    Finished = true,
    Callback = function(Value) ConfigModule.Settings.WebhookURL = Value ConfigModule.Save() end
})
WebhookSection:AddButton({
    Title = "🧪 Testar Envio no Discord",
    Description = "Envia uma mensagem de teste imediata para verificar seu link",
    Callback = function()
        if ConfigModule.Settings.WebhookURL ~= "" then
            WebhookModule.Send({
                ["username"] = "Hub dos Rapazes Bot",
                ["avatar_url"] = "https://i.imgur.com/8Qf9Z2N.png",
                ["embeds"] = {{
                    ["title"] = "✅ Webhook Conectado com Sucesso!",
                    ["description"] = "As notificações de drops raros estão ativas.",
                    ["color"] = 65450,
                    ["footer"] = { ["text"] = "Hub dos Rapazes • Teste" }
                }}
            })
            Fluent:Notify({ Title = "Webhook", Content = "Mensagem de teste enviada!", Duration = 4 })
        else
            Fluent:Notify({ Title = "Erro", Content = "Cole a URL do webhook primeiro.", Duration = 4 })
        end
    end
})

local WebhookFilters = Tabs.Webhook:AddSection("Filtros de Alerta")
WebhookFilters:AddToggle("NotifySecretsToggle", {
    Title = "Avisar Drops Secretos",
    Default = ConfigModule.Settings.NotifySecrets,
    Callback = function(Value) ConfigModule.Settings.NotifySecrets = Value ConfigModule.Save() end
})
WebhookFilters:AddToggle("NotifyMythicsToggle", {
    Title = "Avisar Drops Míticos",
    Default = ConfigModule.Settings.NotifyMythics,
    Callback = function(Value) ConfigModule.Settings.NotifyMythics = Value ConfigModule.Save() end
})
WebhookFilters:AddToggle("NotifyEveryRunToggle", {
    Title = "Avisar Todas as Runs (Resumo Geral)",
    Default = ConfigModule.Settings.NotifyEveryRun,
    Callback = function(Value) ConfigModule.Settings.NotifyEveryRun = Value ConfigModule.Save() end
})

-- ABA SETTINGS
local QuestsSection = Tabs.Settings:AddSection("Automação de Missões (Quests)")
QuestsSection:AddToggle("AutoClaimQuestsToggle", {
    Title = "Auto-Claim de Missões (13s pós-início)",
    Default = ConfigModule.Settings.AutoClaimQuests,
    Callback = function(Value) 
        ConfigModule.Settings.AutoClaimQuests = Value 
        ConfigModule.Save()
    end
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
