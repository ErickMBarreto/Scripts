-- Carrega a biblioteca Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Serviços
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Tabela de Configurações
local Settings = {
    AutoFarm = false,
    FarmMode = "Above Head",
    HeightAboveEnemy = 12,
    TweenSpeed = 60,
    ForceTeleport = true,
    ForceTPEvery = 3,
    OrbitRadius = 14,
    OrbitSpeed = 1.8
}

local currentTween = nil
local lastForceTP = tick()
local orbitAngle = 0

-- Noclip durante o Farm
local noclipConnection = nil
local function toggleNoclip(enable)
    if enable then
        noclipConnection = RunService.Stepped:Connect(function()
            if character and Settings.AutoFarm then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- Movimentação por Tween
local function tweenTo(targetCFrame)
    if not rootPart or not rootPart.Parent then return end
    
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local timeToTravel = math.clamp(distance / math.max(Settings.TweenSpeed, 1), 0.05, 5)

    if Settings.ForceTeleport and (tick() - lastForceTP >= Settings.ForceTPEvery) then
        lastForceTP = tick()
        if currentTween then currentTween:Cancel() end
        rootPart.CFrame = targetCFrame
        return
    end

    if currentTween then currentTween:Cancel() end
    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    currentTween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
end

-- Busca inimigo
local function getClosestEnemy()
    local closest, minDistance = nil, math.huge
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and hum.Health > 0 and hrp and not Players:GetPlayerFromCharacter(obj) then
                local dist = (rootPart.Position - hrp.Position).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closest = obj
                end
            end
        end
    end
    return closest
end

-- Busca portal
local function getPortal()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = string.lower(obj.Name)
            if string.find(name, "portal") or string.find(name, "gate") or string.find(name, "door") then
                return obj:IsA("BasePart") and obj or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
    return nil
end

-- Loop de Farm
task.spawn(function()
    while true do
        if Settings.AutoFarm and rootPart and humanoid and humanoid.Health > 0 then
            local enemy = getClosestEnemy()
            if enemy then
                local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                if enemyRoot then
                    local targetCFrame = enemyRoot.CFrame

                    if Settings.FarmMode == "Above Head" then
                        targetCFrame = enemyRoot.CFrame * CFrame.new(0, Settings.HeightAboveEnemy, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                    elseif Settings.FarmMode == "Orbit" then
                        orbitAngle = orbitAngle + math.rad(Settings.OrbitSpeed * 5)
                        local offset = Vector3.new(math.cos(orbitAngle) * Settings.OrbitRadius, Settings.HeightAboveEnemy, math.sin(orbitAngle) * Settings.OrbitRadius)
                        targetCFrame = CFrame.new(enemyRoot.Position + offset, enemyRoot.Position)
                    end

                    tweenTo(targetCFrame)
                end
            else
                local portal = getPortal()
                if portal then
                    tweenTo(portal.CFrame)
                end
            end
        else
            if currentTween then currentTween:Cancel() end
        end
        task.wait(0.05)
    end
end)

-- Janela compacta e reduzida
local Window = Fluent:CreateWindow({
    Title = "IBdihP Hub",
    SubTitle = "Anime Dungeons",
    TabWidth = 110, -- Largura lateral reduzida
    Size = UDim2.fromOffset(450, 320), -- Tamanho total compacto
    Acrylic = false, -- Desativar blur melhora performance em mobile/Delta
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Farm", Icon = "crosshair" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Seção Auto Farm
local FarmSection = Tabs.Farm:AddSection("Auto Farm")

FarmSection:AddDropdown("FarmMode", {
    Title = "Farm Mode",
    Values = {"Above Head", "Orbit"},
    Default = "Above Head",
    Callback = function(Value)
        Settings.FarmMode = Value
    end
})

FarmSection:AddSlider("HeightAboveEnemy", {
    Title = "Height Above Enemy",
    Default = 12,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        Settings.HeightAboveEnemy = Value
    end
})

FarmSection:AddSlider("TweenSpeed", {
    Title = "Tween Speed",
    Default = 60,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

local ForceTPSection = Tabs.Farm:AddSection("Force Teleport")

ForceTPSection:AddToggle("EnableForceTP", {
    Title = "Enable Force Teleport",
    Default = true,
    Callback = function(Value)
        Settings.ForceTeleport = Value
    end
})

ForceTPSection:AddSlider("ForceTPEvery", {
    Title = "Force TP Every (s)",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        Settings.ForceTPEvery = Value
    end
})

local OrbitSection = Tabs.Farm:AddSection("Orbit")

OrbitSection:AddSlider("OrbitRadius", {
    Title = "Orbit Radius",
    Default = 14,
    Min = 2,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        Settings.OrbitRadius = Value
    end
})

OrbitSection:AddSlider("OrbitSpeed", {
    Title = "Orbit Speed",
    Default = 1.8,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        Settings.OrbitSpeed = Value
    end
})

FarmSection:AddToggle("AutoFarmEnemies", {
    Title = "Auto Farm Enemies",
    Default = false,
    Callback = function(Value)
        Settings.AutoFarm = Value
        toggleNoclip(Value)
    end
})

Window:SelectTab(Tabs.Farm)
