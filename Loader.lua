local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Serviços
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
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

-- Configurações Gerais
local Settings = {
    AutoFarm = false,
    AutoAttack = true,
    HeightAboveEnemy = 8,
    TweenSpeed = 50, -- Velocidade em studs/s (suave)
    AttackSpeed = 0.15 -- Intervalo entre ataques
}

local currentTween = nil
local noclipConnection = nil

-- Noclip para voar sem colidir com paredes/teto
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

-- Voo suave via Tween (Sem teleporte brusco)
local function smoothFlyTo(targetCFrame)
    if not rootPart or not rootPart.Parent then return end
    
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / math.max(Settings.TweenSpeed, 5)

    if currentTween then
        currentTween:Cancel()
    end

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
    return currentTween
end

-- Parar qualquer movimento imediatamente
local function stopMovement()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    if rootPart and rootPart.AssemblyLinearVelocity then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Gatilho de ataque (Tool / Simulação M1 / Remote)
local function performAttack()
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end

    VirtualUser:CaptureController()
    VirtualUser:Button1Down(Vector2.new(0, 0))
    task.wait(0.02)
    VirtualUser:Button1Up(Vector2.new(0, 0))

    for _, remote in ipairs(game:GetDescendants()) do
        if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and string.lower(remote.Name):find("attack") then
            pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer()
                end
            end)
        end
    end
end

-- Busca o inimigo vivo mais próximo
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

-- Busca o portal da masmorra
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

-- Loop de Auto Ataque (Ataca apenas se houver inimigo ativo)
task.spawn(function()
    while true do
        if Settings.AutoFarm and Settings.AutoAttack and character and humanoid and humanoid.Health > 0 then
            local enemy = getClosestEnemy()
            if enemy then
                performAttack()
            end
        end
        task.wait(Settings.AttackSpeed)
    end
end)

-- Loop Principal de Checagem e Decisão
task.spawn(function()
    while true do
        if Settings.AutoFarm and rootPart and humanoid and humanoid.Health > 0 then
            local enemy = getClosestEnemy()
            local portal = getPortal()

            if enemy then
                -- 1. Tem inimigo: persegue e fica acima dele até derrotá-lo
                local enemyHum = enemy:FindFirstChildOfClass("Humanoid")
                local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                
                while Settings.AutoFarm and enemyHum and enemyHum.Health > 0 and enemyRoot and enemyRoot.Parent do
                    local abovePos = enemyRoot.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
                    local targetCFrame = CFrame.new(abovePos, enemyRoot.Position)
                    
                    smoothFlyTo(targetCFrame)
                    task.wait(0.1)
                end
            elseif portal then
                -- 2. Não tem inimigo, mas tem portal: move suavemente até o portal
                smoothFlyTo(portal.CFrame + Vector3.new(0, 3, 0))
            else
                -- 3. Não tem inimigo nem portal: FICA PARADO
                stopMovement()
            end
        else
            stopMovement()
        end
        task.wait(0.2)
    end
end)

-- Interface Fluent Compacta
local Window = Fluent:CreateWindow({
    Title = "IBdihP Hub",
    SubTitle = "Anime Dungeons",
    TabWidth = 90,
    Size = UDim2.fromOffset(360, 250),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Farm = Window:AddTab({ Title = "Farm", Icon = "crosshair" }),
    Info = Window:AddTab({ Title = "Info", Icon = "info" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Botão Flutuante Quadrado (Minimizar / Restaurar)
local toggleGui = Instance.new("ScreenGui")
local floatBtn = Instance.new("TextButton")
local uiCorner = Instance.new("UICorner")
local uiStroke = Instance.new("UIStroke")

toggleGui.Name = "IBdihP_ToggleBtn"
toggleGui.ResetOnSpawn = false
pcall(function() toggleGui.Parent = CoreGui end)
if not toggleGui.Parent then toggleGui.Parent = player:WaitForChild("PlayerGui") end

floatBtn.Name = "FloatButton"
floatBtn.Parent = toggleGui
floatBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
floatBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
floatBtn.Size = UDim2.new(0, 40, 0, 40)
floatBtn.Text = "HUB"
floatBtn.TextColor3 = Color3.fromRGB(0, 255, 150)
floatBtn.TextSize = 11
floatBtn.Font = Enum.Font.GothamBold
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Visible = false

uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = floatBtn
uiStroke.Color = Color3.fromRGB(0, 255, 150)
uiStroke.Thickness = 1.2
uiStroke.Parent = floatBtn

floatBtn.MouseButton1Click:Connect(function()
    Window:Minimize()
    floatBtn.Visible = false
end)

if Window.Frame then
    Window.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if not Window.Frame.Visible then
            floatBtn.Visible = true
        end
    end)
end

-- Controles na Aba Farm
local FarmSection = Tabs.Farm:AddSection("Auto Farm & Combat")

FarmSection:AddToggle("AutoFarmEnemies", {
    Title = "Auto Farm Enemies",
    Description = "Inimigo -> Portal -> Fica parado se não houver nenhum",
    Default = false,
    Callback = function(Value)
        Settings.AutoFarm = Value
        toggleNoclip(Value)
        if not Value then
            stopMovement()
        end
    end
})

FarmSection:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack (M1 / Skills)",
    Default = true,
    Callback = function(Value)
        Settings.AutoAttack = Value
    end
})

FarmSection:AddSlider("HeightAboveEnemy", {
    Title = "Altura acima do Inimigo",
    Default = 8,
    Min = 2,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        Settings.HeightAboveEnemy = Value
    end
})

FarmSection:AddSlider("TweenSpeed", {
    Title = "Velocidade do Voo Suave",
    Default = 50,
    Min = 15,
    Max = 150,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

-- Controles na Aba Info
local InfoSection = Tabs.Info:AddSection("Ajustes de UI")

InfoSection:AddSlider("UIScaleSlider", {
    Title = "Escala da UI (%)",
    Default = 80,
    Min = 50,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        local scale = Value / 100
        Window:SetSize(UDim2.fromOffset(math.floor(400 * scale), math.floor(280 * scale)))
    end
})

InfoSection:AddButton({
    Title = "Minimizar (Botão Flutuante)",
    Callback = function()
        Window:Minimize()
        floatBtn.Visible = true
    end
})

Window:SelectTab(Tabs.Farm)
