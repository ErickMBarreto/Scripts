local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
end)

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

-- Noclip
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

-- Movimento suave
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

-- Janela Principal Super Compacta
local Window = Fluent:CreateWindow({
    Title = "IBdihP Hub",
    SubTitle = "Anime Dungeons",
    TabWidth = 90,
    Size = UDim2.fromOffset(380, 260),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Info = Window:AddTab({ Title = "Info", Icon = "info" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "crosshair" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Botão Flutuante Quadrado para Minimizar / Reabrir
local toggleGui = Instance.new("ScreenGui")
local floatBtn = Instance.new("TextButton")
local uiCorner = Instance.new("UICorner")
local uiStroke = Instance.new("UIStroke")

toggleGui.Name = "IBdihP_ToggleBtn"
toggleGui.ResetOnSpawn = false
pcall(function()
    toggleGui.Parent = CoreGui
end)
if not toggleGui.Parent then
    toggleGui.Parent = player:WaitForChild("PlayerGui")
end

floatBtn.Name = "FloatButton"
floatBtn.Parent = toggleGui
floatBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
floatBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
floatBtn.Size = UDim2.new(0, 42, 0, 42)
floatBtn.Text = "HUB"
floatBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
floatBtn.TextSize = 12
floatBtn.Font = Enum.Font.GothamBold
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Visible = false

uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = floatBtn

uiStroke.Color = Color3.fromRGB(0, 255, 170)
uiStroke.Thickness = 1.2
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = floatBtn

-- Ação ao clicar no quadrado flutuante
floatBtn.MouseButton1Click:Connect(function()
    Window:Minimize()
    floatBtn.Visible = false
end)

-- Monitora quando a janela foi minimizada pelo topo da UI
if Window.Frame then
    Window.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if not Window.Frame.Visible then
            floatBtn.Visible = true
        end
    end)
end

-- Aba Info: Opção de Escala e Tamanho
local InfoSection = Tabs.Info:AddSection("Interface / UI Scale")

InfoSection:AddSlider("UIScaleSlider", {
    Title = "Tamanho da Interface (%)",
    Description = "Ajuste o tamanho geral da janela",
    Default = 80,
    Min = 50,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        local scale = Value / 100
        local baseWidth, baseHeight = 450, 320
        Window:SetSize(UDim2.fromOffset(math.floor(baseWidth * scale), math.floor(baseHeight * scale)))
    end
})

InfoSection:AddButton({
    Title = "Minimizar para Quadrado Flutuante",
    Description = "Recolhe a janela e exibe o botão rápido na lateral",
    Callback = function()
        Window:Minimize()
        floatBtn.Visible = true
    end
})

-- Aba Farm
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
