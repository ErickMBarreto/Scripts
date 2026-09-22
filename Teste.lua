-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (ANTI-SUSPICIOUS MOVEMENT / BYPASS)
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

    if getgenv and getgenv().HubDosRapazes_Shutdown then
        pcall(getgenv().HubDosRapazes_Shutdown)
    end

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
    LastBonusCheck = 0,
    LastBonusClick = 0,
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
    SkillMaxDistance = 25,
    HeightAboveEnemy = 8.5,
    BackDistance = 4.5,
    TweenSpeed = 38, -- Velocidade segura para evitar checagem de anti-speed
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
    WebhookEnabled = false,
    WebhookURL = "https://discord.com/api/webhooks/1542138848195248258/Xqpgk33GsjM5UrMxT0IqIvkKvKulvSJQVc6CSuPmrf6lmrjNXwjxCwGCOK0aJun-Y83o",
    NotifySecrets = true,
    NotifyMythics = true,
    NotifyEveryRun = false
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

-- [[ 3. GERENCIADOR DE MEMÓRIA ]]
task.spawn(function()
    while SharedState.IsRunning do
        task.wait(25)
        pcall(function()
            collectgarbage("step", 100)
        end)
    end
end)

-- [[ 4. HIERARQUIA VISÍVEL ]]
local function isActuallyVisible(guiObj)
    if not guiObj then return false end
    local current = guiObj
    while current and not current:IsA("ScreenGui") do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end
    if current and current:IsA("ScreenGui") then
        return current.Enabled
    end
    return true
end

-- [[ 5. DISCORD WEBHOOK ]]
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
    if not rewardedHolder or not isActuallyVisible(rewardedHolder) then return end

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

-- [[ 6. MOVIMENTAÇÃO NATURAL (SEM DISPARAR ANTICHEAT) ]]
local CharacterModule = {}
local diedConnection = nil
local charConnection = nil

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
end

function CharacterModule.ApplyPhysicsStabilizers(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end
end

function CharacterModule.IsActionBlocked()
    if tick() < SharedState.RespawnLockUntil then return true end
    return SharedState.IsRespawning or SharedState.EnteringPortal or SharedState.IsTransitioning or SharedState.IsDungeonEnded or not SharedState.IsRunning
end

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
        local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 1.5, 0)
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + backOffset, enemyPos)
    elseif mode == "Em Cima da Cabeça" then
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1), enemyPos)
    else
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0), enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude

    -- Se já estiver muito perto, usa Lerp suave em vez de Snap bruto para não dar kick por teleporte
    if distance <= 2.5 then 
        root.CFrame = root.CFrame:Lerp(targetCFrame, 0.35)
        return 
    end

    if SharedState.CurrentTween and SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 4.0 then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local speed = math.clamp(ConfigModule.Settings.TweenSpeed, 20, 45)
    local duration = math.clamp(distance / speed, 0.18, 2.5)

    if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.FlyToPortal(targetCFrame)
    if CharacterModule.IsActionBlocked() then return end
    local _, root = CharacterModule.Get()
    if not root or not root.Parent then return end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude
    local speed = math.clamp(ConfigModule.Settings.TweenSpeed, 20, 40)
    local duration = math.clamp(distance / speed, 0.25, 4.0)

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 2.5 and SharedState.CurrentTween then
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
            if btn.InputBegan then
                local dummyInput = {
                    UserInputType = Enum.UserInputType.Touch,
                    UserInputState = Enum.UserInputState.Begin,
                    Position = Vector3.new(btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2, 0)
                }
                pcall(function() firesignal(btn.InputBegan, dummyInput) end)
            end
            if btn.MouseButton1Down then firesignal(btn.MouseButton1Down) end
            if btn.Activated then firesignal(btn.Activated) end
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
        end
        if getconnections then
            for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "InputBegan"}) do
                if btn[evName] then
                    for _, c in ipairs(getconnections(btn[evName])) do
                        pcall(function() c:Fire() end)
                    end
                end
            end
        end
    end)
end

-- [[ 7. DETECÇÃO DE INIMIGOS COM CACHE ]]
local TargetingModule = {}
local cachedEnemies = {}
local lastEnemyScan = 0

function TargetingModule.GetTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    return obj:FindFirstChild("Bot")
        or obj:FindFirstChild("bot")
        or obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("Head")
        or obj:FindFirstChild("Torso")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or obj:FindFirstChildWhichIsA("BasePart")
end

function TargetingModule.GetLivingEnemies(phase)
    if (tick() - lastEnemyScan) < 0.25 and #cachedEnemies > 0 then
        return cachedEnemies
    end
    lastEnemyScan = tick()

    local list = {}
    local char = player.Character

    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = gameFolder and gameFolder:FindFirstChild("Enemies")

    if phase == "Boss Rush" and enemiesFolder then
        for _, obj in ipairs(enemiesFolder:GetChildren()) do
            if obj:IsA("Model") and obj ~= char and TargetingModule.GetTargetPart(obj) then
                table.insert(list, obj)
            end
        end
        cachedEnemies = list
        return list
    end

    local searchContainers = {
        enemiesFolder,
        workspace:FindFirstChild("Enemies"),
        gameFolder and gameFolder:FindFirstChild("Stages"),
        gameFolder and gameFolder:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("Virus"),
        workspace:FindFirstChild("SAO")
    }

    for _, container in ipairs(searchContainers) do
        if container then
            for _, desc in ipairs(container:GetChildren()) do
                if desc:IsA("Model") and desc ~= char and not Players:GetPlayerFromCharacter(desc) then
                    local hum = desc:FindFirstChildOfClass("Humanoid")
                    if (not hum or hum.Health > 0.1) and TargetingModule.GetTargetPart(desc) then
                        table.insert(list, desc)
                    end
                end
            end
        end
    end

    cachedEnemies = list
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
        if targetPart and targetPart:IsA("BasePart") and targetPart.Parent then
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

-- [[ 10. FLUXO DAS FASES ]]
local FlowModule = {}

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

    if stageLabel and stageLabel:IsA("TextLabel") and isActuallyVisible(stageLabel) and stageLabel.Text ~= "" then
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

        SharedState.EnteringPortal = false
        if onCompleteCallback then
            onCompleteCallback()
        end
    end
end

-- SELETOR SAO ULTRA-ESTÁVEL
local SAOModule = {}

function SAOModule.CheckBonus()
    if (tick() - SharedState.LastBonusCheck) < 0.4 then 
        return SharedState.IsSelectingBonus 
    end
    SharedState.LastBonusCheck = tick()

    local main = pgui and pgui:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local bonuses = dungeonFrame and dungeonFrame:FindFirstChild("Bonuses")

    if bonuses and isActuallyVisible(bonuses) then
        SharedState.IsSelectingBonus = true
        CharacterModule.StopMovement()

        if (tick() - SharedState.LastBonusClick) < 1.0 then
            return true
        end

        local cards = {
            bonuses:FindFirstChild("Bonus1"),
            bonuses:FindFirstChild("Bonus2"),
            bonuses:FindFirstChild("Bonus3")
        }

        local timeCard = nil
        local damageCard = nil
        local fallbackCard = nil

        for _, card in ipairs(cards) do
            if card and isActuallyVisible(card) then
                if not fallbackCard then fallbackCard = card end

                local gatheredText = ""
                for _, desc in ipairs(card:GetChildren()) do
                    if desc:IsA("TextLabel") then
                        if desc.Text and desc.Text ~= "" then
                            gatheredText = gatheredText .. " " .. desc.Text:lower()
                        end
                        if desc.ContentText and desc.ContentText ~= "" then
                            gatheredText = gatheredText .. " " .. desc.ContentText:lower()
                        end
                    end
                end

                pcall(function()
                    for k, v in pairs(card:GetAttributes()) do
                        gatheredText = gatheredText .. " " .. tostring(k):lower() .. " " .. tostring(v):lower()
                    end
                end)

                if gatheredText:find("second") or gatheredText:find("tempo") or gatheredText:find("timer") or gatheredText:find("segundo") or gatheredText:find("120") then
                    timeCard = card
                elseif gatheredText:find("damage") or gatheredText:find("dano") or gatheredText:find("atk") or gatheredText:find("attack") or gatheredText:find("strength") then
                    damageCard = card
                end
            end
        end

        local targetCard = timeCard or damageCard or fallbackCard

        if targetCard then
            SharedState.LastBonusClick = tick()
            CharacterModule.TriggerButton(targetCard)

            local dr = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Dungeon")
            if dr then
                pcall(function()
                    dr:FireServer("ChooseBonus", targetCard.Name)
                end)
            end
            return true
        end
    end

    SharedState.IsSelectingBonus = false
    return false
end

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

function FlowModule.RunOnePiece()
    local _, root = CharacterModule.Get()
    if not root or CharacterModule.IsActionBlocked() then return end

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

function FlowModule.RunSAO()
    local _, root = CharacterModule.Get()
    if not root or CharacterModule.IsActionBlocked() then return end

    if SAOModule.CheckBonus() then
        SharedState.HasTarget = false
        CharacterModule.StopMovement()
        return
    end

    local wave = FlowModule.GetWave()
    local currentMob, mobPart = TargetingModule.GetClosestEnemy("SAO")
    if currentMob and mobPart then
        if wave >= 16 then SharedState.HasEnteredBossRoom = true end
        SharedState.HasTarget = true
        CharacterModule.FlyToEnemy(mobPart)
        return
    end

    CharacterModule.StopMovement()

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

    SharedState.HasTarget = false
    CharacterModule.StopMovement()
end

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

-- [[ 11. CHECAGEM DE START, ENGAGE & PLAYAGAIN ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    if not pgui or (tick() - SharedState.LastStartAttempt) < 1.0 then return end
    SharedState.LastStartAttempt = tick()
    
    local main = pgui:FindFirstChild("Main")
    if not main then return end

    local brCreator = main:FindFirstChild("BossRushCreator")
    local brStart = brCreator and brCreator:FindFirstChild("Start", true)
    if brStart and isActuallyVisible(brStart) then
        CharacterModule.TriggerButton(brStart)
        return
    end

    for _, btn in ipairs(main:GetDescendants()) do
        if btn:IsA("GuiButton") and (btn.Name == "Start" or btn.Name == "Play") and isActuallyVisible(btn) then
            CharacterModule.TriggerButton(btn)
            return
        end
    end
end

function DungeonStateModule.CheckEngage()
    if not ConfigModule.Settings.AutoEngage then return false end
    local main = pgui and pgui:FindFirstChild("Main")
    local virusFrame = main and main:FindFirstChild("VirusFrame")
    if virusFrame and isActuallyVisible(virusFrame) then
        local confirmBtn = virusFrame:FindFirstChild("Confirm", true) or virusFrame:FindFirstChild("Engage", true)
        if confirmBtn and confirmBtn:IsA("GuiObject") and isActuallyVisible(confirmBtn) then
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

    local df = main:FindFirstChild("DungeonFrame")
    local stats = df and df:FindFirstChild("DungeonStats")
    local endActions = stats and stats:FindFirstChild("EndActions")
    local playAgainBtn = endActions and endActions:FindFirstChild("PlayAgain")

    if playAgainBtn and isActuallyVisible(playAgainBtn) then
        return true, playAgainBtn
    end

    for _, btn in ipairs(main:GetDescendants()) do
        if btn:IsA("GuiButton") and btn.Name == "PlayAgain" and isActuallyVisible(btn) then
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

-- [[ 12. LOOPS PRINCIPAIS ]]
local isHandlingPlayAgain = false

-- Loop 1: M1
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not CharacterModule.IsActionBlocked() then
            if SharedState.HasTarget and not SharedState.IsSelectingBonus then
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
            if SharedState.HasTarget and not SharedState.IsSelectingBonus then
                CombatModule.ExecuteSkills()
            end
        end
        task.wait(0.12)
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
                        if ConfigModule.Settings.SelectedPhase == "Boss Rush" then
                            FlowModule.RunBossRush()
                        elseif ConfigModule.Settings.SelectedPhase == "One Piece" then
                            FlowModule.RunOnePiece()
                        elseif ConfigModule.Settings.SelectedPhase == "SAO" then
                            FlowModule.RunSAO()
                        elseif ConfigModule.Settings.SelectedPhase == "Incursão" then
                            FlowModule.RunIncursion()
                        end
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

-- [[ 13. INTERFACE VISUAL FLUENT ]]
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
    Sell = Window:AddTab({ Title = "Auto-Sell" }),
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
    if toggleGui and toggleGui.Parent then toggleGui:Destroy() end
    
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
    Values = { "SAO", "Boss Rush", "One Piece", "Incursão" },
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
    Title = "Velocidade do Voo (Anti-Ban)",
    Default = ConfigModule.Settings.TweenSpeed,
    Min = 15, Max = 55, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.TweenSpeed = Value ConfigModule.Save() end
})
CombatSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Boss Secreto)",
    Description = "Confirma a entrada no boss secreto automaticamente",
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
    Title = "Auto Skills",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoSkills = Value end
})

-- ABA AUTO-SELL
local FavoriteSection = Tabs.Sell:AddSection("Proteção de Itens (Auto-Favorite)")
FavoriteSection:AddToggle("AutoFavSecretsToggle", {
    Title = "Auto-Favorite Secretos",
    Description = "Bloqueia e favorita itens Secretos",
    Default = ConfigModule.Settings.AutoFavoriteSecrets,
    Callback = function(Value) ConfigModule.Settings.AutoFavoriteSecrets = Value ConfigModule.Save() end
})
FavoriteSection:AddToggle("AutoFavMythicsToggle", {
    Title = "Auto-Favorite Míticos",
    Description = "Bloqueia e favorita itens Míticos",
    Default = ConfigModule.Settings.AutoFavoriteMythics,
    Callback = function(Value) ConfigModule.Settings.AutoFavoriteMythics = Value ConfigModule.Save() end
})
FavoriteSection:AddButton({
    Title = "🔒 Bloquear / Favoritar Raros Agora",
    Callback = function() pcall(AutoSellModule.LockHighTierItems) end
})

local SellMainSection = Tabs.Sell:AddSection("Controle de Venda")
SellMainSection:AddToggle("AutoSellToggle", {
    Title = "Ativar Auto-Sell",
    Description = "Vende automaticamente ao entrar na fase",
    Default = ConfigModule.Settings.AutoSell,
    Callback = function(Value) ConfigModule.Settings.AutoSell = Value ConfigModule.Save() end
})
SellMainSection:AddSlider("SellDelaySlider", {
    Title = "Tempo de Espera para Venda (s)",
    Default = ConfigModule.Settings.SellDelaySeconds,
    Min = 1, Max = 30, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.SellDelaySeconds = Value ConfigModule.Save() end
})
SellMainSection:AddButton({
    Title = "💰 Executar Venda Imediata",
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

-- ABA WEBHOOK DISCORD
local WebhookSection = Tabs.Webhook:AddSection("Configuração do Webhook")
WebhookSection:AddToggle("WebhookEnableToggle", {
    Title = "Ativar Notificações no Discord",
    Default = ConfigModule.Settings.WebhookEnabled,
    Callback = function(Value) ConfigModule.Settings.WebhookEnabled = Value ConfigModule.Save() end
})
WebhookSection:AddInput("WebhookURLBox", {
    Title = "URL do Webhook",
    Default = ConfigModule.Settings.WebhookURL,
    Placeholder = "Cole o link https://discord.com/api/webhooks/...",
    Finished = true,
    Callback = function(Value) ConfigModule.Settings.WebhookURL = Value ConfigModule.Save() end
})
WebhookSection:AddButton({
    Title = "🧪 Testar Envio no Discord",
    Callback = function()
        if ConfigModule.Settings.WebhookURL ~= "" then
            WebhookModule.Send({
                ["username"] = "Hub dos Rapazes Bot",
                ["avatar_url"] = "https://i.imgur.com/8Qf9Z2N.png",
                ["embeds"] = {{
                    ["title"] = "✅ Webhook Conectado com Sucesso!",
                    ["description"] = "As notificações de drops estão ativas.",
                    ["color"] = 65450,
                    ["footer"] = { ["text"] = "Hub dos Rapazes • Teste" }
                }}
            })
            Fluent:Notify({ Title = "Webhook", Content = "Mensagem de teste enviada!", Duration = 4 })
        else
            Fluent:Notify({ Title = "Erro", Content = "Cole a URL primeiro.", Duration = 4 })
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
local QuestsSection = Tabs.Settings:AddSection("Gerenciamento")
SettingsSection = Tabs.Settings:AddSection("Script")
SettingsSection:AddButton({
    Title = "Encerrar Script",
    Callback = UIModule.Shutdown
})

Window:SelectTab(Tabs.Farm)
