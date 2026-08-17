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

-- Configurações
local Settings = {
    AutoFarm = false,
    AutoAttack = true,
    HeightAboveEnemy = 8,
    TweenSpeed = 50,
    AttackSpeed = 0.15
}

local currentTween = nil
local noclipConnection = nil
local isMoving = false

-- Noclip seguro: só ativa quando o personagem está ativamente indo a um alvo
local function toggleNoclip(enable)
    if enable then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                if character and Settings.AutoFarm and isMoving then
                    for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- Parada total e travamento físico
local function stopMovement()
    isMoving = false
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
    if rootPart and rootPart.Parent then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end
end

-- Voo suave via Tween (Sem teleporte brusco)
local function smoothFlyTo(targetCFrame)
    if not rootPart or not rootPart.Parent then return end
    
    isMoving = true
    local distance = (rootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / math.max(Settings.TweenSpeed, 5)

    if currentTween then
        currentTween:Cancel()
    end

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    currentTween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    currentTween:Play()
end

-- Localiza o inimigo vivo mais próximo
local function getClosestEnemy()
    local closest, minDistance = nil, math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= character and not obj:IsDescendantOf(character) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            
            -- Garante que é um mob real, com vida e não é player
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

-- Localiza o teleporte exato (Workspace.Game.Teleports.[Teleport].HitBox)
local function getActiveTeleport()
    local gameFolder = workspace:FindFirstChild("Game")
    if not gameFolder then return nil end

    local teleportsFolder = gameFolder:FindFirstChild("Teleports")
    if not teleportsFolder then return nil end

    local bestHitbox = nil
    local minDistance = math.huge

    for _, teleportObj in ipairs(teleportsFolder:GetChildren()) do
        -- Busca a peça HitBox dentro de cada Teleport
        local hitbox = teleportObj:FindFirstChild("HitBox") or (teleportObj:IsA("BasePart") and teleportObj.Name == "HitBox" and teleportObj)
        
        if hitbox and hitbox:IsA("BasePart") then
            local dist = (rootPart.Position - hitbox.Position).Magnitude
            if dist < minDistance then
                minDistance = dist
                bestHitbox = hitbox
            end
        end
    end

    return bestHitbox
end

-- Mecânica de Ataque
local function performAttack()
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end

    VirtualUser:CaptureController()
    VirtualUser:Button1Down(Vector2.new(0, 0))
    task.wait(0.02)
    VirtualUser:Button1Up(Vector2.new(0, 0))

    for _, remote in ipairs(game:GetDescendants()) do
        if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) and string.lower(remote.Name):find("attack") then
            pcall(function()
                if remote:IsA("RemoteEvent") then remote:FireServer() end
            end)
        end
    end
end

-- Loop de Ataque contínuo
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

-- Loop Principal de Lógica: Inimigo -> Teleport HitBox -> Parar
task.spawn(function()
    while true do
        if Settings.AutoFarm and rootPart and humanoid and humanoid.Health > 0 then
            local enemy = getClosestEnemy()

            if enemy then
                -- 1. Tem inimigo: voa suavemente e posiciona acima dele
                local enemyHum = enemy:FindFirstChildOfClass("Humanoid")
                local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                
                if enemyHum and enemyHum.Health > 0 and enemyRoot then
                    local abovePos = enemyRoot.Position + Vector3.new(0, Settings.HeightAboveEnemy, 0)
                    local targetCFrame = CFrame.new(abovePos, enemyRoot.Position)
                    smoothFlyTo(targetCFrame)
                end
            else
                -- 2. Não tem inimigo: busca o teleporte exato (Workspace.Game.Teleports)
                local teleportHitbox = getActiveTeleport()
                if teleportHitbox then
                    -- Voa até o centro da HitBox do portal para acionar o teleporte
                    smoothFlyTo(teleportHitbox.CFrame)
                else
                    -- 3. Não tem monstro nem teleporte: FICA 100% PARADO
                    stopMovement()
                end
            end
        else
            stopMovement()
        end
        task.wait(0.15)
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

-- Seção de Farm
local FarmSection = Tabs.Farm:AddSection("Auto Farm")

FarmSection:AddToggle("AutoFarmEnemies", {
    Title = "Auto Farm Enemies",
    Description = "Inimigos -> Teleports.HitBox -> Parar",
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
    Title = "Auto Attack",
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
    Title = "Velocidade do Voo",
    Default = 50,
    Min = 15,
    Max = 150,
    Rounding = 0,
    Callback = function(Value)
        Settings.TweenSpeed = Value
    end
})

-- Seção Info
local InfoSection = Tabs.Info:AddSection("Ajustes")

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
    Title = "Minimizar para Botão Flutuante",
    Callback = function()
        Window:Minimize()
        floatBtn.Visible = true
    end
})

Window:SelectTab(Tabs.Farm)
