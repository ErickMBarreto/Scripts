-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (FIX: LOADING INFINITO & ASYNC WEBHOOK)
-- ====================================================================

-- [[ 1. TRAVA GLOBAL SINGLETON ]]
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

local scriptURL = "https://raw.githubusercontent.com/ErickMBarreto/Scripts/refs/heads/main/Loader.lua"
local function queueNextExecution()
    local queueFunc = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queueFunc then
        pcall(function()
            queueFunc(string.format([[
                if getgenv then getgenv().HubDosRapazes_Loaded = nil end
                repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
                task.wait(2.5)
                loadstring(game:HttpGet("%s"))()
            ]], scriptURL))
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
    LastStartAttempt = 0
}

-- [[ 2. CONFIGURAÇÕES ]]
local ConfigModule = {}
ConfigModule.Settings = {
    SelectedPhase = "Incursão",
    PositionMode = "Nas Costas",
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
    BackDistance = 4.5,
    TweenSpeed = 60,
    AttackSpeed = 0.15,
    AutoClaimQuests = false,
    AutoSell = true,
    SellDelaySeconds = 10,
    AutoFavoriteSecrets = true,
    AutoFavoriteMythics = false,
    SellCommon = true,
    SellRare = true,
    SellEpic = true,
    SellLegendary = true,
    SellMythic = false,
    WebhookEnabled = true,
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

-- [[ 3. DISCORD WEBHOOK TOTALMENTE ASSÍNCRONO ]]
local WebhookModule = {}

function WebhookModule.Send(payloadTable)
    if not ConfigModule.Settings.WebhookEnabled or ConfigModule.Settings.WebhookURL == "" then return end
    
    -- Disparo isolado em thread independente para jamais travar o client
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

-- [[ 4. PERSONAGEM & FÍSICA ESTÁVEL ]]
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
    if char then params.FilterDescendantsInstances = {char} end
    
    local hit = workspace:Raycast(rayOrigin, rayDirection, params)
    local safeY = targetPosition.Y

    if hit then
        local floorY = hit.Position.Y
        if safeY < (floorY + 2.0) then safeY = floorY + 2.0 end
    end

    local safePos = Vector3.new(targetPosition.X, safeY, targetPosition.Z)
    return CFrame.new(safePos, lookAtPosition)
end

function CharacterModule.FlyToEnemy(targetPart, overrideMode)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.EnteringPortal or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not targetPart or not targetPart.Parent then return end

    local enemyPos = targetPart.Position
    local mode = overrideMode or ConfigModule.Settings.PositionMode
    local targetCFrame

    if mode == "Nas Costas" then
        local lookVec = targetPart.CFrame.LookVector
        local horizontalLook = Vector3.new(lookVec.X, 0, lookVec.Z)
        if horizontalLook.Magnitude > 0.05 then
            lookVec = horizontalLook.Unit
        end
        local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 0.8, 0)
        targetCFrame = CFrame.lookAt(enemyPos + backOffset, enemyPos)
    elseif mode == "Em Cima da Cabeça" then
        targetCFrame = CFrame.lookAt(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0.1), enemyPos)
    else
        targetCFrame = CharacterModule.GetSafeCFrame(enemyPos + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0), enemyPos)
    end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude

    if distance <= 0.8 then return end

    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 1.0 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.04, 2.0)

    if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    SharedState.CurrentTween:Play()
end

function CharacterModule.FollowBehindLive(targetPart)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.EnteringPortal or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not targetPart or not targetPart.Parent then return end

    local enemyPos = targetPart.Position
    local lookVec = targetPart.CFrame.LookVector
    local horizontalLook = Vector3.new(lookVec.X, 0, lookVec.Z)
    if horizontalLook.Magnitude > 0.05 then
        lookVec = horizontalLook.Unit
    end

    local backOffset = -lookVec * ConfigModule.Settings.BackDistance + Vector3.new(0, 0.8, 0)
    local desiredPos = enemyPos + backOffset
    local targetCFrame = CFrame.lookAt(desiredPos, enemyPos)

    local distance = (root.Position - desiredPos).Magnitude

    if distance > 1.2 then
        local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.03, 0.25)
        if SharedState.CurrentTween then SharedState.CurrentTween:Cancel() end
        SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        SharedState.CurrentTween:Play()
    else
        root.CFrame = targetCFrame
    end
end

function CharacterModule.FlyToPortal(targetCFrame)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not root.Parent then return end

    local targetPos = targetCFrame.Position
    local distance = (root.Position - targetPos).Magnitude
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 10), 0.1, 5.0)

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

-- [[ 5. DETECÇÃO DE INIMIGOS ]]
local TargetingModule = {}

function TargetingModule.IsAlive(obj)
    if not obj or not obj.Parent then return false end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then return (hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead) end
    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("CurrentHealth")
    if hpAttr then return tonumber(hpAttr) > 0 end
    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") then return tonumber(hpVal.Value) > 0 end
    return true
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
    local searchContainers = {
        gameFolder and gameFolder:FindFirstChild("Enemies"),
        workspace:FindFirstChild("Enemies"),
        gameFolder and gameFolder:FindFirstChild("Stages"),
        gameFolder and gameFolder:FindFirstChild("Boss"),
        gameFolder and gameFolder:FindFirstChild("Virus"),
        gameFolder and gameFolder:FindFirstChild("SecretBoss"),
        gameFolder and gameFolder:FindFirstChild("BossRush"),
        gameFolder and gameFolder:FindFirstChild("Raids")
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

-- [[ 6. MÓDULO DE COMBATE ]]
local CombatModule = {}
local attackRemote = ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Attack", 10)
local skillRemote = ReplicatedStorage:WaitForChild("Remotes", 10):FindFirstChild("Skill") or ReplicatedStorage:WaitForChild("Remotes", 10):FindFirstChild("Spell")
local lastSkillUse = 0
local comboIndex = 1

function CombatModule.DetectWeapon()
    local char = player.Character
    if char and char:FindFirstChildOfClass("Tool") then 
        return char:FindFirstChildOfClass("Tool").Name 
    end

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

    local bp = player:FindFirstChild("Backpack")
    if bp then
        local tool = bp:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
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

-- [[ 7. AUTO-SELL & AUTO-FAVORITE ]]
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

-- [[ 8. MÓDULO DE MISSÕES ]]
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

-- [[ 9. FLUXO DE FASES & ROTAS ]]
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

        root.CanCollide = true
        root.CFrame = targetCFrame * CFrame.new(0, -0.5, 0)
        triggerZoneTouch(targetCFrame.Position)

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
            if curRoot then triggerZoneTouch(targetCFrame.Position) end
        end

        if tpSuccess then task.wait(0.6) end

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

-- Rota Boss Rush
function FlowModule.RunBossRush()
    local _, enemyPart = TargetingModule.GetClosestEnemy("Boss Rush")
    if enemyPart and enemyPart.Parent then
        CharacterModule.FollowBehindLive(enemyPart)
    else
        CharacterModule.StopMovement()
    end
end

-- Rota Incursão
function FlowModule.RunIncursion()
    local _, root = CharacterModule.Get()
    if not root then return end

    local _, enemyPart = TargetingModule.GetClosestEnemy("Incursão")
    if enemyPart and enemyPart.Parent then
        CharacterModule.FlyToEnemy(enemyPart, ConfigModule.Settings.PositionMode)
    else
        CharacterModule.StopMovement()
    end
end

-- [[ 10. ESTADOS DA DUNGEON & AUTO-START ]]
local DungeonStateModule = {}

function DungeonStateModule.CheckStart()
    if not pgui or (tick() - SharedState.LastStartAttempt) < 1.0 then return end
    SharedState.LastStartAttempt = tick()
    
    local main = pgui:FindFirstChild("Main")
    if not main then return end

    local targetFrames = {
        main:FindFirstChild("DungeonFrame"),
        main:FindFirstChild("BossRushFrame"),
        main:FindFirstChild("RaidFrame")
    }

    for _, frame in ipairs(targetFrames) do
        if frame and frame.Visible then
            local startBtn = frame:FindFirstChild("Start", true) or frame:FindFirstChild("Play", true)
            if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
                CharacterModule.TriggerButton(startBtn)
                SharedState.IsVirusActive = false
                return
            end
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

    if ConfigModule.Settings.SelectedPhase == "Boss Rush" and ConfigModule.Settings.AutoPlayAgain then
        task.spawn(function()
            task.wait(1.5)
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
    CharacterModule.StopMovement()
    bindCharacterEvents(newChar)
    task.delay(0.8, function() SharedState.IsRespawning = false end)
end)

-- [[ 11. LOOPS PRINCIPAIS INDEPENDENTES ]]
local initialRoutinesScheduled = false

-- Loop 1: Ataque M1
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then 
                CombatModule.ExecuteM1() 
            end
        end
        task.wait(ConfigModule.Settings.AttackSpeed)
    end
end)

-- Loop 2: Skills
task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoSkills and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then 
                CombatModule.ExecuteSkills() 
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
                    CharacterModule.StopMovement()

                    pcall(WebhookModule.ProcessDungeonDrops)

                    if ConfigModule.Settings.AutoPlayAgain then
                        queueNextExecution()
                        task.wait(0.15)
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
                        elseif ConfigModule.Settings.SelectedPhase == "Boss Rush" then
                            FlowModule.RunBossRush()
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

-- [[ 12. INTERFACE VISUAL FLUENT ]]
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
    if getgenv then getgenv().HubDosRapazes_Loaded = nil end
    CharacterModule.StopMovement()
    if charConnection then charConnection:Disconnect() end
    if diedConnection then diedConnection:Disconnect() end
    if flightStabilizer then flightStabilizer:Disconnect() end
    if singletonTag and singletonTag.Parent then singletonTag:Destroy() end
    if toggleGui and toggleGui.Parent then toggleGui:Destroy() end
    
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
    Values = { "One Piece", "Bleach (Fase 4)", "Boss Rush", "Incursão" },
    Default = ConfigModule.Settings.SelectedPhase,
    Callback = function(Value) ConfigModule.Settings.SelectedPhase = Value ConfigModule.Save() end
})

PhaseSection:AddDropdown("PositionModeSelector", {
    Title = "Modo de Posicionamento (Incursão & Outras)",
    Values = { "Nas Costas", "Em Cima da Cabeça", "Padrão (Anterior)" },
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
    Callback = function(Value) ConfigModule.Settings.AutoSell = Value ConfigModule.Save() end
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

-- ABA WEBHOOK DISCORD
local WebhookSection = Tabs.Webhook:AddSection("Configuração do Webhook")
WebhookSection:AddToggle("WebhookEnableToggle", {
    Title = "Ativar Notificações no Discord",
    Default = ConfigModule.Settings.WebhookEnabled,
    Callback = function(Value) ConfigModule.Settings.WebhookEnabled = Value ConfigModule.Save() end
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
