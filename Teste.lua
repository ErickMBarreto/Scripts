-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (HARDCORE: 23s DELAY)
-- ====================================================================

-- 1. TRAVA FÍSICA DE INSTÂNCIA ÚNICA (Singleton Anti-Duplicação)
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

-- 2. REEXECUÇÃO AUTOMÁTICA INFINITA (Delta / Mobile)
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

-- 3. ESPERA DE CARREGAMENTO E TRAVA DO LOBBY
if not game:IsLoaded() then
    game.Loaded:Wait()
end

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

-- 4. SISTEMA DE CONFIGURAÇÃO / PERSISTÊNCIA JSON
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "HubRapazes_Config.json"

local Settings = {
    SelectedPhase = "Bleach (Fase 4)",
    CustomWeaponName = "VoidRods",
    AutoFarm = true,
    AutoAttack = true,
    AutoSkills = true,
    AutoStart = true,
    AutoPlayAgain = true,
    AutoEngage = true,
    HardcoreMode = false,
    StartWaitTime = 3.5,
    SkillCooldown = 0.8,
    SkillMaxDistance = 20,
    HeightAboveEnemy = 8.5,
    TweenSpeed = 50,
    AttackSpeed = 0.15,
    AutoClaimQuests = false,
    AutoSell = false,
    SellRare = true,
    SellEpic = false,
    SellLegendary = false,
    SellMythic = false,
    SellWeapons = true,
    SellArmors = false,
    SellSpells = false
}

local function saveConfig()
    pcall(function()
        if writefile then
            local data = HttpService:JSONEncode({
                SelectedPhase = Settings.SelectedPhase,
                CustomWeaponName = Settings.CustomWeaponName,
                HeightAboveEnemy = Settings.HeightAboveEnemy,
                TweenSpeed = Settings.TweenSpeed,
                AttackSpeed = Settings.AttackSpeed,
                SkillCooldown = Settings.SkillCooldown,
                StartWaitTime = Settings.StartWaitTime,
                HardcoreMode = Settings.HardcoreMode,
                AutoClaimQuests = Settings.AutoClaimQuests,
                AutoSell = Settings.AutoSell,
                SellRare = Settings.SellRare,
                SellEpic = Settings.SellEpic,
                SellLegendary = Settings.SellLegendary,
                SellMythic = Settings.SellMythic,
                SellWeapons = Settings.SellWeapons,
                SellArmors = Settings.SellArmors,
                SellSpells = Settings.SellSpells
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
                if data.SelectedPhase ~= nil then Settings.SelectedPhase = data.SelectedPhase end
                if data.CustomWeaponName ~= nil then Settings.CustomWeaponName = data.CustomWeaponName end
                if data.HeightAboveEnemy ~= nil then Settings.HeightAboveEnemy = data.HeightAboveEnemy end
                if data.TweenSpeed ~= nil then Settings.TweenSpeed = data.TweenSpeed end
                if data.AttackSpeed ~= nil then Settings.AttackSpeed = data.AttackSpeed end
                if data.SkillCooldown ~= nil then Settings.SkillCooldown = data.SkillCooldown end
                if data.StartWaitTime ~= nil then Settings.StartWaitTime = data.StartWaitTime end
                if data.HardcoreMode ~= nil then Settings.HardcoreMode = data.HardcoreMode end
                if data.AutoClaimQuests ~= nil then Settings.AutoClaimQuests = data.AutoClaimQuests end
                if data.AutoSell ~= nil then Settings.AutoSell = data.AutoSell end
                if data.SellRare ~= nil then Settings.SellRare = data.SellRare end
                if data.SellEpic ~= nil then Settings.SellEpic = data.SellEpic end
                if data.SellLegendary ~= nil then Settings.SellLegendary = data.SellLegendary end
                if data.SellMythic ~= nil then Settings.SellMythic = data.SellMythic end
                if data.SellWeapons ~= nil then Settings.SellWeapons = data.SellWeapons end
                if data.SellArmors ~= nil then Settings.SellArmors = data.SellArmors end
                if data.SellSpells ~= nil then Settings.SellSpells = data.SellSpells end
            end
        end
    end)
end

loadConfig()

-- 5. SERVIÇOS E ESTADOS GLOBAIS
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local isScriptRunning = true
local currentTween = nil
local charConnection = nil
local diedConnection = nil

local equipRemote = ReplicatedStorage:WaitForChild("Remotes", 10) and ReplicatedStorage.Remotes:WaitForChild("Equip", 10)
local questRemote = ReplicatedStorage:WaitForChild("Remotes", 10) and ReplicatedStorage.Remotes:WaitForChild("Quest", 10)

-- COORDENADAS DOS PORTAIS (FASE 4 - BLEACH)
local PORTAL_1_WAVE8_POS = CFrame.new(4557.2, -305.5, 1925.0)
local PORTAL_2_BOSS_POS  = CFrame.new(5411.5, -561.0, 2550.0)

local dungeonStartTime = tick()
local isRespawning = false
local isTransitioning = false
local enteringPortal = false
local isVirusActive = false
local isSellingInProgress = false
local isQuestClaimInProgress = false
local initialRoutinesScheduled = false
local lastRoomState = "Room1"

local lastSkillUse = 0
local comboIndex = 1
local isDungeonEnded = false
local attackRemote = nil

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
    end
end

local function triggerGuiButton(btn)
    if not btn or not isScriptRunning then return end
    pcall(function()
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
            if btn[evName] and firesignal then
                pcall(function() firesignal(btn[evName]) end)
            end
            if btn[evName] and getconnections then
                for _, c in ipairs(getconnections(btn[evName])) do
                    pcall(function() c:Fire() end)
                end
            end
        end
    end)
end

local function findAnyPlayAgainButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return nil end

    local main = pguiRef:FindFirstChild("Main")
    local dungeonFrame = main and main:FindFirstChild("DungeonFrame")
    local dungeonStats = dungeonFrame and dungeonFrame:FindFirstChild("DungeonStats")
    local endActions = dungeonStats and dungeonStats:FindFirstChild("EndActions")
    local playAgainBtn = endActions and endActions:FindFirstChild("PlayAgain")

    if playAgainBtn and playAgainBtn:IsA("GuiObject") and playAgainBtn.Visible then
        return playAgainBtn
    end

    for _, desc in ipairs(pguiRef:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            local txt = desc:IsA("TextButton") and desc.Text:lower() or desc.Name:lower()
            if txt:find("playagain") or txt:find("play again") or txt:find("retry") or txt:find("jogar novamente") then
                return desc
            end
        end
    end

    return nil
end

local function onPlayerDied()
    if not Settings.HardcoreMode then return end

    stopMovement()
    task.spawn(function()
        task.wait(23)
        if not isScriptRunning or not Settings.HardcoreMode or not Settings.AutoPlayAgain then return end

        local retryBtn = findAnyPlayAgainButton()
        if retryBtn then
            queueNextExecution()
            task.wait(0.5)
            triggerGuiButton(retryBtn)
            task.wait(3.0)
        end
    end)
end

local function bindCharacter(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        if diedConnection then diedConnection:Disconnect() end
        diedConnection = hum.Died:Connect(onPlayerDied)
    end
end

if player.Character then
    bindCharacter(player.Character)
end

charConnection = player.CharacterAdded:Connect(function(newChar)
    isRespawning = true
    isTransitioning = false
    enteringPortal = false
    stopMovement()
    attackRemote = nil

    bindCharacter(newChar)

    task.delay(1.2, function()
        isRespawning = false
    end)
end)

local function smoothFlyTo(targetCFrame)
    if isDungeonEnded or isRespawning or isTransitioning or isSellingInProgress or not isScriptRunning then return end
    local _, root = getCharacter()
    if not root or not root.Parent then return end
    
    local distance = (root.Position - targetCFrame.Position).Magnitude
    local duration = math.clamp(distance / math.max(Settings.TweenSpeed, 5), 0.1, 10)

    if currentTween then
        currentTween:Cancel()
    end

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
end

local function pressKey(keyCode)
    if not isScriptRunning then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- 6. MOTOR DE COMBATE DIRETO E SCANNER DE ARMA
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

local function detectCurrentWeaponDetailed()
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
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        local tool = bp:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end

    return nil
end

local function getEffectiveWeaponName()
    if Settings.CustomWeaponName and Settings.CustomWeaponName ~= "" then
        return Settings.CustomWeaponName
    end
    local found = detectCurrentWeaponDetailed()
    return found or "VoidRods"
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

-- 7. DETECÇÃO DE INIMIGOS (BLEACH / INCURSÃO / VIRUS)
local function getCurrentWaveNumber()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if pguiRef then
        local stageAmountLabel = pguiRef:FindFirstChild("Main")
            and pguiRef.Main:FindFirstChild("DungeonFrame")
            and pguiRef.Main.DungeonFrame:FindFirstChild("StatsHolder")
            and pguiRef.Main.DungeonFrame.StatsHolder:FindFirstChild("Stage")
            and pguiRef.Main.DungeonFrame.StatsHolder.Stage:FindFirstChild("Amount")

        if stageAmountLabel and stageAmountLabel:IsA("TextLabel") and stageAmountLabel.Visible and stageAmountLabel.Text ~= "" then
            local cur = stageAmountLabel.Text:match("(%d+)%s*/%s*%d+") or stageAmountLabel.Text:match("(%d+)")
            if cur then
                local n = tonumber(cur)
                if n and n >= 1 and n <= 15 then
                    return n
                end
            end
        end
    end
    return 1
end

local function getEntityTargetPart(obj)
    if not obj or not obj.Parent then return nil end
    return obj:FindFirstChild("HumanoidRootPart")
        or obj:FindFirstChild("RootPart")
        or obj:FindFirstChild("Hitbox")
        or obj:FindFirstChild("HitBox")
        or obj:FindFirstChild("Bot")
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
        return (hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead)
    end

    local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP")
    if hpAttr then return tonumber(hpAttr) > 0 end

    local hpVal = obj:FindFirstChild("Health") or obj:FindFirstChild("HP")
    if hpVal and hpVal:IsA("ValueBase") then return tonumber(hpVal.Value) > 0 end

    return false
end

local function getAllLivingEnemiesBleach()
    local list = {}
    local char = player.Character

    local gameFolder = workspace:FindFirstChild("Game")
    local enemiesFolder = (gameFolder and gameFolder:FindFirstChild("Enemies")) or workspace:FindFirstChild("Enemies")

    if enemiesFolder then
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if isEntityAlive(enemy) then
                table.insert(list, enemy)
            end
        end
    end

    if isVirusActive then
        local virusFolder = (gameFolder and (gameFolder:FindFirstChild("Virus") or gameFolder:FindFirstChild("Boss") or gameFolder:FindFirstChild("SecretBoss"))) or workspace:FindFirstChild("Virus")
        if virusFolder then
            for _, mob in ipairs(virusFolder:GetChildren()) do
                if isEntityAlive(mob) then table.insert(list, mob) end
            end
            if isEntityAlive(virusFolder) then table.insert(list, virusFolder) end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= char and not Players:GetPlayerFromCharacter(obj) then
                local name = obj.Name:lower()
                if name:find("virus") or name:find("secret") or name:find("boss") then
                    if isEntityAlive(obj) then table.insert(list, obj) end
                end
            end
        end
    end

    if #list == 0 and gameFolder and gameFolder:FindFirstChild("Stages") then
        for _, stage in ipairs(gameFolder.Stages:GetChildren()) do
            local spawns = stage:FindFirstChild("Spawns") or stage
            for _, mob in ipairs(spawns:GetChildren()) do
                if mob:IsA("Model") and mob ~= char and isEntityAlive(mob) then
                    table.insert(list, mob)
                end
            end
        end
    end

    return list
end

local function getAllLivingEnemiesIncursion()
    local list = {}
    local char = player.Character
    local registered = {}

    local function addEntity(mob)
        if mob and mob:IsA("Model") and mob ~= char and not registered[mob] and not Players:GetPlayerFromCharacter(mob) then
            if isEntityAlive(mob) and getEntityTargetPart(mob) then
                registered[mob] = true
                table.insert(list, mob)
            end
        end
    end

    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder then
        local enemiesFolder = gameFolder:FindFirstChild("Enemies")
        if enemiesFolder then
            for _, enemy in ipairs(enemiesFolder:GetChildren()) do addEntity(enemy) end
        end

        local virusFolder = gameFolder:FindFirstChild("Virus") or gameFolder:FindFirstChild("Boss") or gameFolder:FindFirstChild("SecretBoss")
        if virusFolder then
            for _, enemy in ipairs(virusFolder:GetChildren()) do addEntity(enemy) end
            if isEntityAlive(virusFolder) then addEntity(virusFolder) end
        end

        local summonsFolder = gameFolder:FindFirstChild("Summons") or gameFolder:FindFirstChild("Minions") or gameFolder:FindFirstChild("Clones")
        if summonsFolder then
            for _, summon in ipairs(summonsFolder:GetChildren()) do addEntity(summon) end
        end

        local stagesFolder = gameFolder:FindFirstChild("Stages")
        if stagesFolder then
            for _, stage in ipairs(stagesFolder:GetChildren()) do
                local spawns = stage:FindFirstChild("Spawns") or stage
                for _, mob in ipairs(spawns:GetChildren()) do addEntity(mob) end
            end
        end
    end

    local wsEnemies = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Virus")
    if wsEnemies then
        for _, enemy in ipairs(wsEnemies:GetChildren()) do addEntity(enemy) end
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= char and not Players:GetPlayerFromCharacter(obj) then
            local name = obj.Name:lower()
            if name:find("mob") or name:find("enemy") or name:find("clone") or name:find("summon") or name:find("minion") or name:find("boss") or name:find("virus") or obj:FindFirstChildOfClass("Humanoid") then
                addEntity(obj)
            end
        end
    end

    return list
end

local function getClosestLivingEnemy()
    local _, root = getCharacter()
    if not root then return nil, nil end

    local enemies
    if Settings.SelectedPhase == "Incursão" then
        enemies = getAllLivingEnemiesIncursion()
    else
        enemies = getAllLivingEnemiesBleach()
    end

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

-- 8. MOTOR DE AUTO-SELL TRANCADO (FILTRO DE TIPO E RARIDADE)
local function getItemRarity(slot)
    local grad = slot:FindFirstChild("RarityGradient", true)
    if not grad or not grad:IsA("UIGradient") then return "Unknown" end

    local color = grad.Color.Keypoints[1].Value
    local r = math.round(color.R * 255)
    local g = math.round(color.G * 255)
    local b = math.round(color.B * 255)

    if r <= 50 and g >= 60 and b >= 190 then return "Rare" end
    if r >= 90 and r <= 160 and g <= 50 and b >= 190 then return "Epic" end
    if r >= 220 and g >= 140 and b <= 50 then return "Legendary" end
    if r >= 200 and g <= 50 and b <= 50 then return "Mythic" end
    return "Unknown"
end

local function getItemTypeFromSlot(slot)
    local attrType = slot:GetAttribute("Type") or slot:GetAttribute("ItemType") or slot:GetAttribute("Category")
    if attrType then return tostring(attrType):lower() end

    local typeVal = slot:FindFirstChild("Type") or slot:FindFirstChild("Category")
    if typeVal and typeVal:IsA("StringValue") then return typeVal.Value:lower() end

    local itemValObj = slot:FindFirstChild("Item")
    local realItem = (itemValObj and itemValObj:IsA("ObjectValue") and itemValObj.Value)
        or (itemValObj and typeof(itemValObj.Value) == "Instance" and itemValObj.Value)
        or (typeof(itemValObj) == "Instance" and itemValObj)

    if realItem and realItem.Parent then
        local pName = realItem.Parent.Name:lower()
        if pName:find("weapon") then return "weapon" end
        if pName:find("armor") then return "armor" end
        if pName:find("spell") then return "spell" end
        
        local itemTypeAttr = realItem:GetAttribute("Type")
        if itemTypeAttr then return tostring(itemTypeAttr):lower() end
    end

    return "unknown"
end

local function executeDirectAutoSell()
    if not Settings.AutoSell or isSellingInProgress or not isScriptRunning or not equipRemote then return end
    
    local main = pgui:FindFirstChild("Main")
    local itemsFrame = main and main:FindFirstChild("MainFrame") and main.MainFrame:FindFirstChild("Items")
    local buttonsFrame = itemsFrame and itemsFrame:FindFirstChild("Buttons")
    local scroll = itemsFrame and itemsFrame:FindFirstChild("Scroll")
    if not itemsFrame or not scroll then return end

    isSellingInProgress = true

    local categoriesToScan = {}
    if Settings.SellWeapons and buttonsFrame and buttonsFrame:FindFirstChild("Weapon") then
        table.insert(categoriesToScan, { Button = buttonsFrame.Weapon, TargetType = "weapon" })
    end
    if Settings.SellArmors and buttonsFrame and buttonsFrame:FindFirstChild("Armor") then
        table.insert(categoriesToScan, { Button = buttonsFrame.Armor, TargetType = "armor" })
    end
    if Settings.SellSpells and buttonsFrame and buttonsFrame:FindFirstChild("Spell") then
        table.insert(categoriesToScan, { Button = buttonsFrame.Spell, TargetType = "spell" })
    end

    local itemsToSell = {}
    local registered = {}

    for _, catData in ipairs(categoriesToScan) do
        triggerGuiButton(catData.Button)
        task.wait(0.15)

        for _, slot in ipairs(scroll:GetChildren()) do
            if slot:IsA("GuiObject") and slot:GetAttribute("Item") and slot.Name ~= "SteelSword" then
                if slot.Visible ~= false then
                    local eq = slot:FindFirstChild("EquippedSelection")
                    local isEquipped = eq and eq:IsA("ImageLabel") and eq.Visible and eq.ImageColor3 == Color3.fromRGB(0, 255, 0)
                    
                    local fav = slot:FindFirstChild("Favorite", true)
                    local isFav = fav and fav:IsA("ImageLabel") and fav.Visible and fav.ImageColor3 ~= Color3.fromRGB(255, 255, 255)

                    if not isEquipped and not isFav then
                        local detectedType = getItemTypeFromSlot(slot)
                        local typeAllowed = (detectedType == catData.TargetType) or (detectedType == "unknown")

                        if typeAllowed then
                            local rarity = getItemRarity(slot)
                            local rarityMatch = false
                            if rarity == "Rare" and Settings.SellRare then rarityMatch = true end
                            if rarity == "Epic" and Settings.SellEpic then rarityMatch = true end
                            if rarity == "Legendary" and Settings.SellLegendary then rarityMatch = true end
                            if rarity == "Mythic" and Settings.SellMythic then rarityMatch = true end

                            if rarityMatch then
                                local itemValObj = slot:FindFirstChild("Item")
                                local targetInstance = (itemValObj and itemValObj:IsA("ObjectValue") and itemValObj.Value)
                                    or (itemValObj and typeof(itemValObj.Value) == "Instance" and itemValObj.Value)
                                    or slot

                                if targetInstance and not registered[targetInstance] then
                                    registered[targetInstance] = true
                                    table.insert(itemsToSell, targetInstance)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if #itemsToSell > 0 then
        pcall(function()
            equipRemote:FireServer("Sell", itemsToSell)
        end)
        Fluent:Notify({
            Title = "Auto-Sell Concluído",
            Content = string.format("Vendidos %d itens filtrados com sucesso!", #itemsToSell),
            Duration = 3.5
        })
    end

    isSellingInProgress = false
end

-- 9. MOTOR DE AUTO-CLAIM SILENCIOSO (SEM MOVER MOUSE / SEM ABRIR JANELA)
local function executeAutoClaimQuests()
    if not Settings.AutoClaimQuests or isQuestClaimInProgress or not isScriptRunning then return end

    local main = pgui:FindFirstChild("Main")
    local questsFrame = main and main:FindFirstChild("MainFrame") and main.MainFrame:FindFirstChild("Quests")
    local questsHolder = questsFrame and questsFrame:FindFirstChild("QuestsHolder")
    local infoPanel = questsFrame and questsFrame:FindFirstChild("Information")
    local claimBtn = infoPanel and infoPanel:FindFirstChild("Claim")

    if not questsFrame or not questsHolder or not claimBtn then return end

    isQuestClaimInProgress = true

    local originalVisible = questsFrame.Visible
    questsFrame.Visible = false

    local tabs = {
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Hourly"),
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Daily"),
        questsFrame:FindFirstChild("Buttons") and questsFrame.Buttons:FindFirstChild("Weekly")
    }

    local claimedTotal = 0

    for _, tabBtn in ipairs(tabs) do
        if tabBtn then
            triggerGuiButton(tabBtn)
            task.wait(0.12)

            for _, slot in ipairs(questsHolder:GetChildren()) do
                if slot:IsA("GuiButton") then
                    local progressLabel = slot:FindFirstChild("QuestProgress", true)
                    if progressLabel and progressLabel:IsA("TextLabel") then
                        local txt = progressLabel.Text:lower()

                        if txt == "claim" or txt == "resgatar" then
                            triggerGuiButton(slot)
                            task.wait(0.1)

                            triggerGuiButton(claimBtn)
                            
                            if questRemote then
                                pcall(function()
                                    questRemote:FireServer("Claim", slot.Name)
                                    questRemote:FireServer(slot.Name)
                                    local num = tonumber(slot.Name:match("%d+"))
                                    if num then questRemote:FireServer(num) end
                                end)
                            end

                            claimedTotal = claimedTotal + 1
                            task.wait(0.12)
                        end
                    end
                end
            end
        end
    end

    questsFrame.Visible = originalVisible

    if claimedTotal > 0 then
        Fluent:Notify({
            Title = "Missões Resgatadas!",
            Content = string.format("%d recompensa(s) de missão coletada(s) em segundo plano!", claimedTotal),
            Duration = 3.5
        })
    end

    isQuestClaimInProgress = false
end

-- 10. CONTROLES DE INTERFACE (ENGAGE > PLAY AGAIN)
local function checkDungeonStartButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef then return end
    local main = pguiRef:FindFirstChild("Main")
    local df = main and main:FindFirstChild("DungeonFrame")
    if df and df.Visible then
        local startBtn = df:FindFirstChild("Start") or df:FindFirstChild("Play")
        if startBtn and startBtn:IsA("GuiObject") and startBtn.Visible then
            triggerGuiButton(startBtn)
            dungeonStartTime = tick()
            isVirusActive = false
        end
    end
end

local function checkAndClickEngageButton()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef or not isScriptRunning then return false end

    local main = pguiRef:FindFirstChild("Main")
    local virusFrame = main and main:FindFirstChild("VirusFrame")
    if virusFrame and virusFrame.Visible then
        local confirmBtn = virusFrame:FindFirstChild("Confirm", true) or virusFrame:FindFirstChild("Engage", true)
        if confirmBtn and confirmBtn:IsA("GuiObject") and confirmBtn.Visible then
            triggerGuiButton(confirmBtn)
            dungeonStartTime = tick()
            isVirusActive = true
            isDungeonEnded = false
            return true
        end
    end

    for _, desc in ipairs(pguiRef:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
            local txt = desc:IsA("TextButton") and desc.Text:lower() or desc.Name:lower()
            if txt:find("engage") or (txt:find("confirm") and desc:FindFirstAncestorWhichIsA("Frame") and desc:FindFirstAncestorWhichIsA("Frame").Name:lower():find("virus")) then
                triggerGuiButton(desc)
                dungeonStartTime = tick()
                isVirusActive = true
                isDungeonEnded = false
                return true
            end
        end
    end

    return false
end

local function checkDungeonEnd()
    local pguiRef = player:FindFirstChild("PlayerGui")
    if not pguiRef or not isScriptRunning then return false, nil end

    if isVirusActive then
        local enemies = (Settings.SelectedPhase == "Incursão") and getAllLivingEnemiesIncursion() or getAllLivingEnemiesBleach()
        if #enemies > 0 then
            return false, nil
        else
            isVirusActive = false
        end
    end

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

-- 11. TRAVA E EXECUÇÃO DE COMBATE
local function isPortalTransitionActive()
    if isRespawning or isTransitioning or enteringPortal or isSellingInProgress or isQuestClaimInProgress then return true end
    if (tick() - dungeonStartTime) < Settings.StartWaitTime then return true end

    if Settings.SelectedPhase == "Bleach (Fase 4)" and not isVirusActive then
        local _, root = getCharacter()
        if not root then return true end

        local wave = getCurrentWaveNumber()
        local inRoom1 = root.Position.Z < 2100 and root.Position.Y > -450
        local inBossRoom = root.Position.Y > -400 and root.Position.Z > 2800

        if wave >= 8 and inRoom1 then return true end
        if wave >= 12 and not inBossRoom then return true end
    end
    return false
end

local function executeNativeAttack()
    if isDungeonEnded or isRespawning or isTransitioning or enteringPortal or isSellingInProgress or isQuestClaimInProgress or not isScriptRunning or isPortalTransitionActive() then return end
    
    comboIndex = (comboIndex % 4) + 1
    local weapon = getEffectiveWeaponName()

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
        if Settings.AutoAttack and not isDungeonEnded and not isRespawning and not isTransitioning and not enteringPortal and not isSellingInProgress and not isQuestClaimInProgress and not isPortalTransitionActive() then
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
        if Settings.AutoSkills and not isDungeonEnded and not isRespawning and not isTransitioning and not enteringPortal and not isSellingInProgress and not isQuestClaimInProgress and not isPortalTransitionActive() then
            local char, root, hum = getCharacter()
            if char and root and hum and hum.Health > 0 then
                if (tick() - lastSkillUse) >= Settings.SkillCooldown then
                    local _, enemyPart = getClosestLivingEnemy()
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

-- 12. MÁQUINAS DE ESTADOS & NAVEGAÇÃO
local function passThroughPortalSafely(targetPortalCFrame)
    local char, root, hum = getCharacter()
    if not root or not hum or enteringPortal then return end

    local dist = (root.Position - targetPortalCFrame.Position).Magnitude

    if dist > 8 then
        smoothFlyTo(targetPortalCFrame)
    else
        enteringPortal = true
        stopMovement()
        
        root.CFrame = targetPortalCFrame * CFrame.new(0, 0, 2)
        local forwardDir = (targetPortalCFrame.LookVector * 16)
        root.AssemblyLinearVelocity = forwardDir
        
        if hum then
            hum:MoveTo(targetPortalCFrame.Position + (targetPortalCFrame.LookVector * 6))
        end

        task.wait(0.8)
        enteringPortal = false
    end
end

local function runBleachPhaseFlow()
    local char, root = getCharacter()
    if not root then return end

    if (tick() - dungeonStartTime) < Settings.StartWaitTime then
        stopMovement()
        return
    end

    local currentRoom = "Room1"
    if root.Position.Y < -450 then
        currentRoom = "Room2"
    elseif root.Position.Y > -400 and root.Position.Z > 2800 then
        currentRoom = "BossRoom"
    end

    if currentRoom ~= lastRoomState then
        lastRoomState = currentRoom
        stopMovement()
        enteringPortal = false
        isTransitioning = true
        task.wait(0.6)
        isTransitioning = false
        return
    end

    if enteringPortal then return end

    if isVirusActive then
        local enemies = getAllLivingEnemiesBleach()
        if #enemies > 0 then
            local enemy, enemyPart = getClosestLivingEnemy()
            if enemy and enemyPart then
                local abovePos = enemyPart.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
                local targetCFrame = CFrame.new(abovePos, enemyPart.Position)
                smoothFlyTo(targetCFrame)
            end
        else
            stopMovement()
        end
        return
    end

    local wave = getCurrentWaveNumber()

    if wave >= 12 and currentRoom ~= "BossRoom" then
        passThroughPortalSafely(PORTAL_2_BOSS_POS)
        return
    end

    if wave >= 8 and currentRoom == "Room1" then
        passThroughPortalSafely(PORTAL_1_WAVE8_POS)
        return
    end

    local enemies = getAllLivingEnemiesBleach()
    if #enemies > 0 then
        local enemy, enemyPart = getClosestLivingEnemy()
        if enemy and enemyPart then
            while isScriptRunning and Settings.AutoFarm and not isDungeonEnded and not isRespawning and not isTransitioning and not enteringPortal and not isSellingInProgress and not isQuestClaimInProgress and enemy.Parent and enemyPart.Parent and isEntityAlive(enemy) and not isPortalTransitionActive() do
                local _, currentRoot = getCharacter()
                if not currentRoot then break end

                local currentWave = getCurrentWaveNumber()
                local isR1 = currentRoot.Position.Z < 2100 and currentRoot.Position.Y > -450
                local isBoss = currentRoot.Position.Y > -400 and currentRoot.Position.Z > 2800

                if (currentWave >= 8 and isR1) or (currentWave >= 12 and not isBoss) then
                    break
                end

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

local function runIncursionPhaseFlow()
    if (tick() - dungeonStartTime) < Settings.StartWaitTime then
        stopMovement()
        return
    end

    local enemies = getAllLivingEnemiesIncursion()

    if #enemies > 0 then
        local enemy, enemyPart = getClosestLivingEnemy()
        if enemy and enemyPart then
            local abovePos = enemyPart.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
            local targetCFrame = CFrame.new(abovePos, enemyPart.Position)
            smoothFlyTo(targetCFrame)
        end
    else
        stopMovement()
    end
end

-- LOOP PRINCIPAL
task.spawn(function()
    while isScriptRunning do
        if Settings.AutoFarm and not isRespawning then
            local char, root, hum = getCharacter()
            if char and root and hum and hum.Health > 0 then
                
                if not initialRoutinesScheduled then
                    initialRoutinesScheduled = true
                    
                    -- 1. Auto-Sell aos 10 segundos
                    task.spawn(function()
                        task.wait(10)
                        if isScriptRunning and Settings.AutoSell and not isDungeonEnded then
                            executeDirectAutoSell()
                        end
                    end)

                    -- 2. Auto-Claim Quests aos 13 segundos
                    task.spawn(function()
                        task.wait(13)
                        if isScriptRunning and Settings.AutoClaimQuests and not isDungeonEnded then
                            executeAutoClaimQuests()
                        end
                    end)
                end

                if Settings.AutoStart then
                    checkDungeonStartButton()
                end

                local engaged = false
                if Settings.AutoEngage then
                    engaged = checkAndClickEngageButton()
                end

                if engaged then
                    isDungeonEnded = false
                    isVirusActive = true
                    dungeonStartTime = tick()
                    task.wait(1.5)
                else
                    local ended, playAgainBtn = checkDungeonEnd()
                    if ended then
                        isDungeonEnded = true
                        isVirusActive = false
                        stopMovement()
                        
                        if Settings.AutoClaimQuests then
                            pcall(executeAutoClaimQuests)
                            task.wait(0.2)
                        end

                        if Settings.AutoEngage and checkAndClickEngageButton() then
                            isDungeonEnded = false
                            isVirusActive = true
                            dungeonStartTime = tick()
                            task.wait(1.5)
                        elseif Settings.AutoPlayAgain and playAgainBtn then
                            queueNextExecution()
                            task.wait(0.8)
                            triggerGuiButton(playAgainBtn)
                            task.wait(3.0)
                        end
                    else
                        isDungeonEnded = false
                        
                        if Settings.SelectedPhase == "Bleach (Fase 4)" then
                            runBleachPhaseFlow()
                        elseif Settings.SelectedPhase == "Incursão" then
                            runIncursionPhaseFlow()
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

-- 13. INTERFACE FLUENT
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
    AutoSell = Window:AddTab({ Title = "Auto Sell" }),
    Settings = Window:AddTab({ Title = "Settings" })
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
    Settings.AutoSell = false
    Settings.AutoClaimQuests = false
    
    stopMovement()
    
    if charConnection then
        charConnection:Disconnect()
        charConnection = nil
    end

    if diedConnection then
        diedConnection:Disconnect()
        diedConnection = nil
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

-- ABA FARM
local PhaseSection = Tabs.Farm:AddSection("Fase Ativa")
PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "Bleach (Fase 4)", "Incursão" },
    Default = Settings.SelectedPhase,
    Callback = function(Value)
        Settings.SelectedPhase = Value
        saveConfig()
    end
})

local WeaponSection = Tabs.Farm:AddSection("Configuração de Arma")
local WeaponInput = WeaponSection:AddInput("WeaponInputBox", {
    Title = "Arma Equipada / Nome",
    Default = Settings.CustomWeaponName,
    Placeholder = "Ex: VoidRods, Katana...",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        Settings.CustomWeaponName = Value
        saveConfig()
    end
})

WeaponSection:AddButton({
    Title = "🔍 Detectar Arma da Mão",
    Description = "Lê automaticamente o nome da arma do personagem/inventário",
    Callback = function()
        local detected = detectCurrentWeaponDetailed()
        if detected and detected ~= "" then
            Settings.CustomWeaponName = detected
            WeaponInput:SetValue(detected)
            saveConfig()
            Fluent:Notify({
                Title = "Arma Detectada!",
                Content = "Arma identificada: " .. tostring(detected),
                Duration = 4
            })
        else
            Fluent:Notify({
                Title = "Nenhuma Arma Encontrada",
                Content = "Digite o nome exato da arma na caixa de texto.",
                Duration = 4
            })
        end
    end
})

local CombatSection = Tabs.Farm:AddSection("Controles de Farm")
CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Description = "Executa a rota mapeada da fase selecionada",
    Default = true,
    Callback = function(Value)
        Settings.AutoFarm = Value
        if not Value then stopMovement() end
    end
})

CombatSection:AddToggle("HardcoreToggle", {
    Title = "Modo Hardcore",
    Description = "Se morrer, aguarda 23s e clica em Play Again para reiniciar",
    Default = Settings.HardcoreMode,
    Callback = function(Value)
        Settings.HardcoreMode = Value
        saveConfig()
    end
})

CombatSection:AddToggle("AutoEngageToggle", {
    Title = "Auto Engage (Boss Secreto)",
    Description = "Prioridade: Clica em Engage antes do Play Again",
    Default = true,
    Callback = function(Value) Settings.AutoEngage = Value end
})

CombatSection:AddToggle("AutoPlayAgainToggle", {
    Title = "Auto Play Again",
    Description = "Reinicia a partida automaticamente ao vencer/perder",
    Default = true,
    Callback = function(Value) Settings.AutoPlayAgain = Value end
})

CombatSection:AddToggle("AutoStartToggle", {
    Title = "Auto Start Dungeon",
    Description = "Inicia a fase sozinho",
    Default = true,
    Callback = function(Value) Settings.AutoStart = Value end
})

CombatSection:AddSlider("StartWaitTimeSlider", {
    Title = "Espera Inicial (segundos)",
    Default = Settings.StartWaitTime,
    Min = 1.0,
    Max = 8.0,
    Rounding = 1,
    Callback = function(Value)
        Settings.StartWaitTime = Value
        saveConfig()
    end
})

CombatSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1)",
    Description = "Dispara os ataques básicos continuamente",
    Default = true,
    Callback = function(Value) Settings.AutoAttack = Value end
})

CombatSection:AddToggle("AutoSkillsToggle", {
    Title = "Auto Skills (Z, X e Ultimate)",
    Description = "Dispara skills apenas perto de inimigos",
    Default = true,
    Callback = function(Value) Settings.AutoSkills = Value end
})

CombatSection:AddSlider("SkillMaxDistSlider", {
    Title = "Distância das Skills (studs)",
    Default = Settings.SkillMaxDistance,
    Min = 8,
    Max = 40,
    Rounding = 0,
    Callback = function(Value) Settings.SkillMaxDistance = Value end
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
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
        saveConfig()
    end
})

-- ABA AUTO-SELL
local AutoSellMainSection = Tabs.AutoSell:AddSection("Controle Geral de Venda")

AutoSellMainSection:AddToggle("AutoSellToggle", {
    Title = "Venda Automática (10s pós-início)",
    Description = "Aguarda 10 segundos de partida e vende os itens configurados",
    Default = Settings.AutoSell,
    Callback = function(Value)
        Settings.AutoSell = Value
        saveConfig()
    end
})

AutoSellMainSection:AddButton({
    Title = "⚡ Executar Venda Direta Agora",
    Description = "Dispara a venda instantânea dos itens filtrados",
    Callback = function()
        pcall(executeDirectAutoSell)
    end
})

local AutoSellRaritySection = Tabs.AutoSell:AddSection("Filtro de Raridades (Vender)")

AutoSellRaritySection:AddToggle("SellRareToggle", {
    Title = "Vender Raro (Rare)",
    Default = Settings.SellRare,
    Callback = function(Value)
        Settings.SellRare = Value
        saveConfig()
    end
})

AutoSellRaritySection:AddToggle("SellEpicToggle", {
    Title = "Vender Épico (Epic)",
    Default = Settings.SellEpic,
    Callback = function(Value)
        Settings.SellEpic = Value
        saveConfig()
    end
})

AutoSellRaritySection:AddToggle("SellLegendaryToggle", {
    Title = "Vender Lendário (Legendary)",
    Default = Settings.SellLegendary,
    Callback = function(Value)
        Settings.SellLegendary = Value
        saveConfig()
    end
})

AutoSellRaritySection:AddToggle("SellMythicToggle", {
    Title = "Vender Mítico (Mythic)",
    Default = Settings.SellMythic,
    Callback = function(Value)
        Settings.SellMythic = Value
        saveConfig()
    end
})

local AutoSellTypeSection = Tabs.AutoSell:AddSection("Tipos de Item Permitidos")

AutoSellTypeSection:AddToggle("SellWeaponsToggle", {
    Title = "Incluir Armas (Weapons)",
    Default = Settings.SellWeapons,
    Callback = function(Value)
        Settings.SellWeapons = Value
        saveConfig()
    end
})

AutoSellTypeSection:AddToggle("SellArmorsToggle", {
    Title = "Incluir Armaduras (Armors)",
    Default = Settings.SellArmors,
    Callback = function(Value)
        Settings.SellArmors = Value
        saveConfig()
    end
})

AutoSellTypeSection:AddToggle("SellSpellsToggle", {
    Title = "Incluir Spells (Magias)",
    Default = Settings.SellSpells,
    Callback = function(Value)
        Settings.SellSpells = Value
        saveConfig()
    end
})

-- ABA SETTINGS
local QuestsSection = Tabs.Settings:AddSection("Automação de Missões (Quests)")

QuestsSection:AddToggle("AutoClaimQuestsToggle", {
    Title = "Auto-Claim de Missões (13s pós-início)",
    Description = "Resgata missões prontas (Hourly/Daily/Weekly) no início e ao vencer",
    Default = Settings.AutoClaimQuests,
    Callback = function(Value)
        Settings.AutoClaimQuests = Value
        saveConfig()
    end
})

QuestsSection:AddButton({
    Title = "⚡ Resgatar Missões Agora",
    Description = "Verifica e resgata imediatamente todas as abas",
    Callback = function()
        pcall(executeAutoClaimQuests)
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
