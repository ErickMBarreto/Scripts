-- ====================================================================
-- HUB DOS RAPAZES - ANIME DUNGEONS (ANTI-GROUND CLIP & RAYCAST SYSTEM)
-- ====================================================================

-- [[ 1. SINGLETON & BOOTSTRAP ]]
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    CurrentTargetPos = nil
}

-- [[ 2. MÓDULO DE CONFIGURAÇÃO (ConfigModule) ]]
local ConfigModule = {}
ConfigModule.Settings = {
    SelectedPhase = "Bleach (Fase 4)",
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
    SkillMaxDistance = 20,
    HeightAboveEnemy = 8.5,
    TweenSpeed = 50,
    AttackSpeed = 0.15,
    AutoClaimQuests = false,
    AutoSell = false,
    SellRare = true,
    SellEpic = true,
    SellLegendary = false,
    SellMythic = false,
    SellWeapons = true,
    SellArmors = false,
    SellSpells = false
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

-- [[ 3. MÓDULO DE BANCO DE DADOS DIRETO (DatabaseModule) ]]
local DatabaseModule = {}
DatabaseModule.Items = {}

local function cleanKey(str)
    if not str then return "" end
    return tostring(str):lower():gsub("[%s%-_%p]", "")
end

function DatabaseModule.Init()
    local stats = ReplicatedStorage:WaitForChild("Stats", 10)
    if not stats then return end

    local targetModules = {
        stats:FindFirstChild("WeaponStats"),
        stats:FindFirstChild("SpellStats"),
        stats:FindFirstChild("MaterialStats"),
        stats:FindFirstChild("ArmorStats")
    }

    for _, mod in ipairs(targetModules) do
        if mod and mod:IsA("ModuleScript") then
            local ok, data = pcall(require, mod)
            if ok and type(data) == "table" then
                for rawName, itemData in pairs(data) do
                    if type(itemData) == "table" then
                        local r = itemData.Rarity or itemData.rarity or itemData.Tier or "Unknown"
                        local t = itemData.Type or itemData.type or (mod.Name:lower():find("weapon") and "Weapon") or (mod.Name:lower():find("spell") and "Spell") or (mod.Name:lower():find("armor") and "Armor") or "Unknown"
                        local displayName = itemData.Name or rawName

                        local entry = {
                            TechnicalName = tostring(rawName),
                            DisplayName = tostring(displayName),
                            Rarity = tostring(r),
                            Type = tostring(t):lower()
                        }

                        DatabaseModule.Items[cleanKey(rawName)] = entry
                        DatabaseModule.Items[cleanKey(displayName)] = entry
                    end
                end
            end
        end
    end
end
DatabaseModule.Init()

-- [[ 4. MÓDULO DE PERSONAGEM & FÍSICA (CharacterModule) ]]
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
    local _, root = CharacterModule.Get()
    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Raycast para garantir que o ponto de voo nunca fique colado ou abaixo do chão
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

function CharacterModule.FlyTo(targetCFrame)
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.IsSelling or not SharedState.IsRunning then return end
    local _, root = CharacterModule.Get()
    if not root or not root.Parent then return end

    local targetPos = targetCFrame.Position
    if SharedState.CurrentTargetPos and (SharedState.CurrentTargetPos - targetPos).Magnitude < 3.5 and SharedState.CurrentTween then
        return
    end

    SharedState.CurrentTargetPos = targetPos
    local distance = (root.Position - targetPos).Magnitude
    local duration = math.clamp(distance / math.max(ConfigModule.Settings.TweenSpeed, 5), 0.08, 8)

    if SharedState.CurrentTween then 
        SharedState.CurrentTween:Cancel() 
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    SharedState.CurrentTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = targetCFrame})
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

-- [[ 5. MÓDULO DE DETECÇÃO DE INIMIGOS (TargetingModule) ]]
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
        or obj:FindFirstChild("Bot")
        or obj:FindFirstChild("Torso")
        or obj:FindFirstChild("UpperTorso")
        or obj:FindFirstChild("Head")
        or (obj:IsA("Model") and obj.PrimaryPart)
        or (obj:IsA("BasePart") and obj)
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

-- [[ 6. MÓDULO DE COMBATE (CombatModule) ]]
local CombatModule = {}
local attackRemote = nil
local lastSkillUse = 0
local comboIndex = 1

function CombatModule.FindAttackRemote()
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
    if SharedState.IsDungeonEnded or SharedState.IsRespawning or SharedState.IsTransitioning or SharedState.EnteringPortal or SharedState.IsSelling or not SharedState.IsRunning then return end
    comboIndex = (comboIndex % 4) + 1
    local weapon = CombatModule.GetEffectiveWeapon()
    local rem = CombatModule.FindAttackRemote()
    if rem then pcall(function() rem:FireServer("M1", weapon, comboIndex, 0, 0, 2) end) end

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

-- [[ 7. MÓDULO DE AUTO-SELL AUDITADO (AutoSellModule) ]]
local AutoSellModule = {}

function AutoSellModule.ResolveSlotData(slot)
    local k1 = cleanKey(slot.Name)
    local titleLabel = slot:FindFirstChild("Title", true)
    local k2 = (titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text ~= "") and cleanKey(titleLabel.Text) or ""

    local data = DatabaseModule.Items[k1] or (k2 ~= "" and DatabaseModule.Items[k2])
    if data then
        local r = data.Rarity:lower()
        local resolvedRarity = "Unknown"
        if r:find("secret") then resolvedRarity = "Secret"
        elseif r:find("mythic") then resolvedRarity = "Mythic"
        elseif r:find("legendary") then resolvedRarity = "Legendary"
        elseif r:find("epic") then resolvedRarity = "Epic"
        elseif r:find("rare") then resolvedRarity = "Rare"
        elseif r:find("common") then resolvedRarity = "Common"
        end

        return resolvedRarity, data.Type
    end

    local directAttr = slot:GetAttribute("Rarity") or slot:GetAttribute("Tier")
    if directAttr then
        local r = tostring(directAttr):lower()
        if r:find("secret") then return "Secret", nil
        elseif r:find("mythic") then return "Mythic", nil
        elseif r:find("legendary") then return "Legendary", nil
        elseif r:find("epic") then return "Epic", nil
        elseif r:find("rare") then return "Rare", nil
        elseif r:find("common") then return "Common", nil
        end
    end

    return "Unknown", nil
end

function AutoSellModule.ResolveType(slot, dbType)
    if dbType and dbType ~= "" and dbType ~= "unknown" then return dbType end
    local attrType = slot:GetAttribute("Type") or slot:GetAttribute("ItemType") or slot:GetAttribute("Category")
    if attrType then return tostring(attrType):lower() end
    local itemValObj = slot:FindFirstChild("Item")
    local realItem = (itemValObj and itemValObj:IsA("ObjectValue") and itemValObj.Value)
        or (itemValObj and typeof(itemValObj.Value) == "Instance" and itemValObj.Value)
        or (typeof(itemValObj) == "Instance" and itemValObj)
    if realItem and realItem.Parent then
        local pName = realItem.Parent.Name:lower()
        if pName:find("weapon") then return "weapon" end
        if pName:find("armor") then return "armor" end
        if pName:find("spell") then return "spell" end
    end
    return "unknown"
end

function AutoSellModule.Execute()
    if not ConfigModule.Settings.AutoSell or SharedState.IsSelling or not SharedState.IsRunning or not equipRemote then return end
    local main = pgui:FindFirstChild("Main")
    local itemsFrame = main and main:FindFirstChild("MainFrame") and main.MainFrame:FindFirstChild("Items")
    local buttonsFrame = itemsFrame and itemsFrame:FindFirstChild("Buttons")
    local scroll = itemsFrame and itemsFrame:FindFirstChild("Scroll")
    if not itemsFrame or not scroll then return end

    SharedState.IsSelling = true
    local categories = {}
    if ConfigModule.Settings.SellWeapons and buttonsFrame and buttonsFrame:FindFirstChild("Weapon") then
        table.insert(categories, { Button = buttonsFrame.Weapon, TargetType = "weapon" })
    end
    if ConfigModule.Settings.SellArmors and buttonsFrame and buttonsFrame:FindFirstChild("Armor") then
        table.insert(categories, { Button = buttonsFrame.Armor, TargetType = "armor" })
    end
    if ConfigModule.Settings.SellSpells and buttonsFrame and buttonsFrame:FindFirstChild("Spell") then
        table.insert(categories, { Button = buttonsFrame.Spell, TargetType = "spell" })
    end

    local itemsToSell, registered = {}, {}

    for _, cat in ipairs(categories) do
        CharacterModule.TriggerButton(cat.Button)
        task.wait(0.2)

        for _, slot in ipairs(scroll:GetChildren()) do
            if slot:IsA("GuiObject") and slot:GetAttribute("Item") and slot.Name ~= "SteelSword" and slot.Visible ~= false then
                local eq = slot:FindFirstChild("EquippedSelection")
                local isEquipped = eq and eq:IsA("ImageLabel") and eq.Visible and eq.ImageColor3 == Color3.fromRGB(0, 255, 0)
                local fav = slot:FindFirstChild("Favorite", true)
                local isFav = fav and fav:IsA("ImageLabel") and fav.Visible and fav.ImageColor3 ~= Color3.fromRGB(255, 255, 255)

                if not isEquipped and not isFav then
                    local rarity, dbType = AutoSellModule.ResolveSlotData(slot)

                    if rarity == "Secret" then
                        continue
                    end

                    if rarity == "Mythic" and not ConfigModule.Settings.SellMythic then
                        continue
                    end

                    if rarity == "Unknown" or rarity == "Common" then
                        continue
                    end

                    local detectedType = AutoSellModule.ResolveType(slot, dbType)
                    if detectedType == cat.TargetType or detectedType == "unknown" then
                        local allow = (rarity == "Rare" and ConfigModule.Settings.SellRare)
                            or (rarity == "Epic" and ConfigModule.Settings.SellEpic)
                            or (rarity == "Legendary" and ConfigModule.Settings.SellLegendary)
                            or (rarity == "Mythic" and ConfigModule.Settings.SellMythic)

                        if allow then
                            local itemValObj = slot:FindFirstChild("Item")
                            local targetItem = (itemValObj and itemValObj:IsA("ObjectValue") and itemValObj.Value)
                                or (itemValObj and typeof(itemValObj.Value) == "Instance" and itemValObj.Value)
                                or (itemValObj and itemValObj.Value)
                                or slot.Name

                            if targetItem and not registered[targetItem] then
                                registered[targetItem] = true
                                table.insert(itemsToSell, targetItem)
                            end
                        end
                    end
                end
            end
        end
    end

    if #itemsToSell > 0 then
        pcall(function() equipRemote:FireServer("Sell", itemsToSell) end)
        Fluent:Notify({ Title = "Auto-Sell", Content = string.format("Vendidos %d itens com dados oficiais!", #itemsToSell), Duration = 3.5 })
    end
    SharedState.IsSelling = false
end

-- [[ 8. MÓDULO DE MISSÕES (QuestModule) ]]
local QuestModule = {}

function QuestModule.ClaimAll()
    if not ConfigModule.Settings.AutoClaimQuests or SharedState.IsClaiming or not SharedState.IsRunning then return end
    local main = pgui:FindFirstChild("Main")
    local questsFrame = main and main:FindFirstChild("MainFrame") and main.MainFrame:FindFirstChild("Quests")
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
                        if txt == "claim" or txt == "resgatar" then
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

-- [[ 9. MÓDULO DE FLUXO E NAVEGAÇÃO DA FASE (FlowModule) ]]
local FlowModule = {}

-- Posições absolutas dos portais
local PORTAL_1_WAVE8_POS = CFrame.new(4557.2, -305.5, 1925.0)
local PORTAL_2_BOSS_POS  = CFrame.new(5411.5, -561.0, 2550.0)

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

function FlowModule.PassPortal(targetCFrame)
    local _, root, hum = CharacterModule.Get()
    if not root or not hum or SharedState.EnteringPortal then return end

    local dist = (root.Position - targetCFrame.Position).Magnitude

    if dist > 6 then
        local safeCFrame = CharacterModule.GetSafeCFrame(targetCFrame.Position, targetCFrame.Position + targetCFrame.LookVector * 10)
        CharacterModule.FlyTo(safeCFrame)
    else
        SharedState.EnteringPortal = true
        CharacterModule.StopMovement()

        local forwardGoal = targetCFrame * CFrame.new(0, 0, -8)
        local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Linear)
        local passTween = TweenService:Create(root, tweenInfo, {CFrame = forwardGoal})
        passTween:Play()
        passTween.Completed:Wait()

        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.4)
        SharedState.EnteringPortal = false
    end
end

function FlowModule.RunBleach()
    local _, root = CharacterModule.Get()
    if not root then return end

    if SharedState.IsVirusActive then
        local enemy, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
        if enemy and enemyPart then
            local abovePos = enemyPart.Position + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0)
            local safeCFrame = CharacterModule.GetSafeCFrame(abovePos, enemyPart.Position)
            CharacterModule.FlyTo(safeCFrame)
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
        task.wait(0.6)
        SharedState.IsTransitioning = false
        return
    end

    if SharedState.EnteringPortal then return end
    local wave = FlowModule.GetWave()

    if wave >= 12 and currentRoom ~= "BossRoom" then
        FlowModule.PassPortal(PORTAL_2_BOSS_POS)
        return
    end
    if wave >= 8 and currentRoom == "Room1" then
        FlowModule.PassPortal(PORTAL_1_WAVE8_POS)
        return
    end

    local enemy, enemyPart = TargetingModule.GetClosestEnemy("Bleach (Fase 4)")
    if enemy and enemyPart then
        local abovePos = enemyPart.Position + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0)
        local safeCFrame = CharacterModule.GetSafeCFrame(abovePos, enemyPart.Position)
        CharacterModule.FlyTo(safeCFrame)
    else
        CharacterModule.StopMovement()
    end
end

function FlowModule.RunIncursion()
    local enemy, enemyPart = TargetingModule.GetClosestEnemy("Incursão")
    if enemy and enemyPart then
        local abovePos = enemyPart.Position + Vector3.new(0, ConfigModule.Settings.HeightAboveEnemy, 0)
        local safeCFrame = CharacterModule.GetSafeCFrame(abovePos, enemyPart.Position)
        CharacterModule.FlyTo(safeCFrame)
    else
        CharacterModule.StopMovement()
    end
end

-- [[ 10. MÓDULO DE ESTADOS DA DUNGEON (DungeonStateModule) ]]
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
    CharacterModule.StopMovement()
    attackRemote = nil
    bindCharacterEvents(newChar)
    task.delay(1.0, function() SharedState.IsRespawning = false end)
end)

-- [[ 11. MOTOR PRINCIPAL DE LOOPS (Orchestration) ]]
local initialRoutinesScheduled = false

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoAttack and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal and not SharedState.IsSelling then
            local _, _, hum = CharacterModule.Get()
            if hum and hum.Health > 0 then CombatModule.ExecuteM1() end
        end
        task.wait(ConfigModule.Settings.AttackSpeed)
    end
end)

task.spawn(function()
    while SharedState.IsRunning do
        if ConfigModule.Settings.AutoSkills and not SharedState.IsDungeonEnded and not SharedState.IsRespawning and not SharedState.IsTransitioning and not SharedState.EnteringPortal and not SharedState.IsSelling then
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
                        task.wait(10)
                        if SharedState.IsRunning and ConfigModule.Settings.AutoSell and not SharedState.IsDungeonEnded then
                            AutoSellModule.Execute()
                        end
                    end)
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
                        if ConfigModule.Settings.SelectedPhase == "Bleach (Fase 4)" then
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
        task.wait(0.05)
    end
end)

-- [[ 12. MÓDULO DE INTERFACE VISUAL (UIModule) ]]
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
    AutoSell = Window:AddTab({ Title = "Auto Sell" }),
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
local PhaseSection = Tabs.Farm:AddSection("Fase Ativa")
PhaseSection:AddDropdown("PhaseSelector", {
    Title = "Selecionar Fase",
    Values = { "Bleach (Fase 4)", "Incursão" },
    Default = ConfigModule.Settings.SelectedPhase,
    Callback = function(Value) ConfigModule.Settings.SelectedPhase = Value ConfigModule.Save() end
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

local CombatSection = Tabs.Farm:AddSection("Controles de Farm")
CombatSection:AddToggle("AutoFarmToggle", {
    Title = "Iniciar Auto Farm",
    Default = true,
    Callback = function(Value) ConfigModule.Settings.AutoFarm = Value if not Value then CharacterModule.StopMovement() end end
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
CombatSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura acima do Inimigo",
    Default = ConfigModule.Settings.HeightAboveEnemy,
    Min = 1, Max = 20, Rounding = 1,
    Callback = function(Value) ConfigModule.Settings.HeightAboveEnemy = Value ConfigModule.Save() end
})
CombatSection:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo",
    Default = ConfigModule.Settings.TweenSpeed,
    Min = 20, Max = 120, Rounding = 0,
    Callback = function(Value) ConfigModule.Settings.TweenSpeed = Value ConfigModule.Save() end
})

-- ABA AUTO-SELL
local AutoSellMainSection = Tabs.AutoSell:AddSection("Controle Geral de Venda")
AutoSellMainSection:AddToggle("AutoSellToggle", {
    Title = "Venda Automática (10s pós-início)",
    Default = ConfigModule.Settings.AutoSell,
    Callback = function(Value) ConfigModule.Settings.AutoSell = Value ConfigModule.Save() end
})
AutoSellMainSection:AddButton({
    Title = "⚡ Executar Venda Direta Agora",
    Callback = function() pcall(AutoSellModule.Execute) end
})

local AutoSellRaritySection = Tabs.AutoSell:AddSection("Filtro de Raridades (Vender)")
AutoSellRaritySection:AddToggle("SellRareToggle", {
    Title = "Vender Raro (Rare)",
    Default = ConfigModule.Settings.SellRare,
    Callback = function(Value) ConfigModule.Settings.SellRare = Value ConfigModule.Save() end
})
AutoSellRaritySection:AddToggle("SellEpicToggle", {
    Title = "Vender Épico (Epic)",
    Default = ConfigModule.Settings.SellEpic,
    Callback = function(Value) ConfigModule.Settings.SellEpic = Value ConfigModule.Save() end
})
AutoSellRaritySection:AddToggle("SellLegendaryToggle", {
    Title = "Vender Lendário (Legendary)",
    Default = ConfigModule.Settings.SellLegendary,
    Callback = function(Value) ConfigModule.Settings.SellLegendary = Value ConfigModule.Save() end
})
AutoSellRaritySection:AddToggle("SellMythicToggle", {
    Title = "Vender Mítico (Mythic)",
    Description = "Secrets NUNCA são vendidos.",
    Default = ConfigModule.Settings.SellMythic,
    Callback = function(Value) ConfigModule.Settings.SellMythic = Value ConfigModule.Save() end
})

local AutoSellTypeSection = Tabs.AutoSell:AddSection("Tipos de Item Permitidos")
AutoSellTypeSection:AddToggle("SellWeaponsToggle", {
    Title = "Incluir Armas (Weapons)",
    Default = ConfigModule.Settings.SellWeapons,
    Callback = function(Value) ConfigModule.Settings.SellWeapons = Value ConfigModule.Save() end
})
AutoSellTypeSection:AddToggle("SellArmorsToggle", {
    Title = "Incluir Armaduras (Armors)",
    Default = ConfigModule.Settings.SellArmors,
    Callback = function(Value) ConfigModule.Settings.SellArmors = Value ConfigModule.Save() end
})
AutoSellTypeSection:AddToggle("SellSpellsToggle", {
    Title = "Incluir Spells (Magias)",
    Default = ConfigModule.Settings.SellSpells,
    Callback = function(Value) ConfigModule.Settings.SellSpells = Value ConfigModule.Save() end
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
