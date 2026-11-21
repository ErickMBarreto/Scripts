--!strict
-- ============================================================
-- AutoHub.client.luau
-- Sistema de automação sequencial de tarefas com HUB de controle
-- LocalScript em StarterPlayerScripts
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- MÓDULO 1: LOGGER
-- ============================================================
local Logger = {}

local LOG_LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
local CURRENT_LEVEL = LOG_LEVELS.INFO

function Logger.log(level: string, module: string, ...)
	if LOG_LEVELS[level] < CURRENT_LEVEL then return end
	print(("[%s][%s]"):format(level, module), ...)
end

function Logger.debug(mod: string, ...) Logger.log("DEBUG", mod, ...) end
function Logger.info(mod: string, ...)  Logger.log("INFO",  mod, ...) end
function Logger.warn(mod: string, ...)  Logger.log("WARN",  mod, ...) end
function Logger.error(mod: string, ...) Logger.log("ERROR", mod, ...) end

-- ============================================================
-- MÓDULO 2: ENTITY SANITIZER
-- ============================================================
local EntitySanitizer = {}

function EntitySanitizer.IsValid(entity: any): boolean
	if not entity or typeof(entity) ~= "Instance" then
		return false
	end
	if not entity:IsDescendantOf(Workspace) then
		return false
	end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	local root = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
	if not root then
		return false
	end
	return true
end

function EntitySanitizer.FilterValid(list: {any}): {any}
	local valid = {}
	for _, ent in ipairs(list) do
		if EntitySanitizer.IsValid(ent) then
			table.insert(valid, ent)
		end
	end
	return valid
end

function EntitySanitizer.GetClosestValidTarget(origin: Vector3, candidates: {any}): any?
	local closest, minDist = nil, math.huge
	for _, target in ipairs(candidates) do
		if EntitySanitizer.IsValid(target) then
			local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
			if root then
				local dist = (root.Position - origin).Magnitude
				if dist < minDist then
					minDist = dist
					closest = target
				end
			end
		end
	end
	return closest
end

-- ============================================================
-- MÓDULO 3: UI CONTROLLER
-- ============================================================
local UIController = {}

function UIController.ReadProgressText(guiName: string, labelName: string): number?
	local ok, result = pcall(function()
		local gui = PlayerGui:FindFirstChild(guiName, true)
		if not gui then return nil end
		local label = gui:FindFirstChild(labelName, true)
		if not label or not label:IsA("TextLabel") then return nil end
		local current, total = label.Text:match("(%d+)%s*/%s*(%d+)")
		if current and total then
			return tonumber(current) / math.max(tonumber(total), 1)
		end
		return tonumber(label.Text:match("%d+")) or nil
	end)
	if not ok then
		Logger.warn("UI", "Falha ao ler progresso:", result)
		return nil
	end
	return result
end

function UIController.PressButton(buttonName: string): boolean
	local ok, err = pcall(function()
		local button = PlayerGui:FindFirstChild(buttonName, true)
		if not button or not button:IsA("GuiButton") then
			error("Botão não encontrado: " .. buttonName)
		end
		button.Activated:Fire()
	end)
	if not ok then
		Logger.warn("UI", "Falha ao acionar botão:", err)
		return false
	end
	return true
end

-- ============================================================
-- MÓDULO 4: CHARACTER MOVER
-- ============================================================
local CharacterMover = {}

function CharacterMover.GetRoot(): BasePart?
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterMover.GetHumanoid(): Humanoid?
	local char = LocalPlayer.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

function CharacterMover.MoveTo(destination: Vector3, tolerance: number?): boolean
	local humanoid = CharacterMover.GetHumanoid()
	local root     = CharacterMover.GetRoot()
	if not (humanoid and root) then
		return false
	end
	tolerance = tolerance or 8

	if (root.Position - destination).Magnitude <= tolerance then
		return true
	end
	humanoid:MoveTo(destination)
	return false
end

-- ============================================================
-- MÓDULO 5: QUEST TASK
-- ============================================================
local QuestTask = {}
QuestTask.__index = QuestTask

export type TaskConfig = {
	name: string,
	repetitions: number?,
	destination: Vector3?,
	uiGuiName: string?,
	uiLabelName: string?,
	actionButtonName: string?,
	targetResolver: (() -> {any})?,
}

function QuestTask.new(config: TaskConfig)
	return setmetatable({
		config = config,
		_state = "IDLE",
		_repetitionsDone = 0,
	}, QuestTask)
end

function QuestTask:Reset()
	self._state = "IDLE"
	self._repetitionsDone = 0
end

function QuestTask:OnStart()
	if self.config.destination then
		self._state = "MOVING"
	else
		self._state = "EXECUTING"
		if self.config.actionButtonName then
			UIController.PressButton(self.config.actionButtonName)
		end
	end
end

function QuestTask:IsComplete(): boolean
	if self._state == "MOVING" then
		local dest = self.config.destination :: Vector3
		if CharacterMover.MoveTo(dest) then
			self._state = "EXECUTING"
			if self.config.actionButtonName then
				UIController.PressButton(self.config.actionButtonName)
			end
		end
		return false

	elseif self._state == "EXECUTING" then
		if self.config.targetResolver then
			local candidates = self.config.targetResolver()
			local root = CharacterMover.GetRoot()
			if root then
				local target = EntitySanitizer.GetClosestValidTarget(root.Position, candidates)
				if not target then
					Logger.debug("QuestTask",
						("Sem alvos válidos para '%s', aguardando..."):format(self.config.name))
					return false
				end
			end
		end

		if self.config.uiGuiName and self.config.uiLabelName then
			local progress = UIController.ReadProgressText(
				self.config.uiGuiName, self.config.uiLabelName)
			if progress and progress >= 1 then
				return true
			end
			return false
		end

		return true
	end
	return false
end

-- ============================================================
-- MÓDULO 6: FEATURE REGISTRY
-- ============================================================
local FeatureRegistry = {}
FeatureRegistry.__index = FeatureRegistry

function FeatureRegistry.new(featureNames: {string})
	local self = setmetatable({}, FeatureRegistry)
	self._state = {}
	self._listeners = {}
	for _, name in ipairs(featureNames) do
		self._state[name] = false
	end
	return self
end

function FeatureRegistry:IsEnabled(name: string): boolean
	return self._state[name] == true
end

function FeatureRegistry:GetAll(): {[string]: boolean}
	local copy = {}
	for k, v in pairs(self._state) do copy[k] = v end
	return copy
end

function FeatureRegistry:Toggle(name: string, enabled: boolean)
	if self._state[name] == nil then
		Logger.warn("Features", "Feature desconhecida:", name)
		return
	end
	if self._state[name] == enabled then return end
	self._state[name] = enabled
	Logger.info("Features", ("%s = %s"):format(name, tostring(enabled)))

	local list = self._listeners[name]
	if list then
		for _, cb in ipairs(list) do
			local ok, err = pcall(cb, enabled)
			if not ok then
				Logger.error("Features", "Listener de " .. name .. " falhou:", err)
			end
		end
	end
end

function FeatureRegistry:OnChanged(name: string, callback: (boolean) -> ())
	self._listeners[name] = self._listeners[name] or {}
	table.insert(self._listeners[name], callback)
end

-- ============================================================
-- MÓDULO 7: ORCHESTRATOR
-- ============================================================
local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator.new(queue: {QuestTask}, features: FeatureRegistry)
	return setmetatable({
		queue        = queue,
		features     = features,
		currentIndex = 1,
		state        = "RUNNING",
		currentRep   = 0,
		targetReps   = 1,
		_heartbeat   = nil,
	}, Orchestrator)
end

function Orchestrator:_startCurrentTask()
	local task = self.queue[self.currentIndex]
	if not task then
		self.state = "FINISHED"
		self:_stop()
		Logger.info("Orchestrator", "Fila concluída.")
		return
	end
	self.targetReps = task.config.repetitions or 1
	self.currentRep = 0
	task:Reset()
	local ok, err = pcall(function() task:OnStart() end)
	if not ok then
		Logger.error("Orchestrator", "Falha em OnStart:", err)
		self:_advance()
	end
end

function Orchestrator:_advance()
	self.currentIndex += 1
	if self.queue[self.currentIndex] then
		self:_startCurrentTask()
	else
		self.state = "FINISHED"
		self:_stop()
		Logger.info("Orchestrator", "Fila concluída.")
	end
end

function Orchestrator:_step()
	if self.state ~= "RUNNING" then return end

	-- Kill-switch: se AutoQuest estiver OFF, não processa nada
	if self.features and not self.features:IsEnabled("AutoQuest") then
		return
	end

	local task = self.queue[self.currentIndex]
	if not task then
		self:_advance()
		return
	end

	local ok, complete = pcall(function() return task:IsComplete() end)
	if not ok then
		Logger.error("Orchestrator", "IsComplete falhou:", complete)
		self:_advance()
		return
	end

	if complete then
		self.currentRep += 1
		if self.currentRep >= self.targetReps then
			Logger.info("Orchestrator",
				("Tarefa '%s' concluída (%d/%d)"):format(
					task.config.name, self.currentRep, self.targetReps))
			self:_advance()
		else
			local okStart, err = pcall(function() task:OnStart() end)
			if not okStart then
				Logger.error("Orchestrator", "Repetição falhou:", err)
				self:_advance()
			else
				Logger.debug("Orchestrator",
					("Repetição %d/%d de '%s'"):format(
						self.currentRep + 1, self.targetReps, task.config.name))
			end
		end
	end
end

function Orchestrator:Start()
	if self._heartbeat then return end
	self.state = "RUNNING"
	Logger.info("Orchestrator", "Iniciando automação.")
	self:_startCurrentTask()
	self._heartbeat = RunService.Heartbeat:Connect(function()
		self:_step()
	end)
end

function Orchestrator:Stop()
	self.state = "PAUSED"
	self:_stop()
	Logger.info("Orchestrator", "Automação pausada.")
end

function Orchestrator:_stop()
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
end

-- ============================================================
-- MÓDULO 8: HUB UI
-- ============================================================
local HubUI = {}
HubUI.__index = HubUI

function HubUI.new(features: FeatureRegistry, stateProvider: (() -> string)?)
	local self = setmetatable({}, HubUI)
	self.features = features
	self.stateProvider = stateProvider
	self.buttons = {}
	self:_build()
	return self
end

function HubUI:_build()
	local existing = PlayerGui:FindFirstChild("AutoHub")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AutoHub"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(260, 340)
	frame.Position = UDim2.new(0, 12, 0, 12)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = "Automação"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 1
	title.Parent = frame

	self:_makeToggleButton(frame, "AutoQuest", "Ligar/Desligar Tudo", 2)

	local order = 3
	for _, name in ipairs(self:_featureNames()) do
		if name ~= "AutoQuest" then
			self:_makeToggleButton(frame, name, name, order)
			order += 1
		end
	end

	local status = Instance.new("TextLabel")
	status.Name = "StatusLabel"
	status.Size = UDim2.new(1, 0, 0, 40)
	status.BackgroundTransparency = 1
	status.TextColor3 = Color3.fromRGB(180, 220, 180)
	status.Font = Enum.Font.Code
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.Text = ""
	status.LayoutOrder = order
	status.Parent = frame
	self._statusLabel = status

	task.spawn(function()
		while gui.Parent do
			if self.stateProvider then
				local ok, txt = pcall(self.stateProvider)
				status.Text = ok and txt or "?"
			end
			task.wait(0.5)
		end
	end)
end

function HubUI:_featureNames(): {string}
	local names = {}
	for name in pairs(self.features:GetAll()) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function HubUI:_makeToggleButton(parent: Instance, featureName: string,
	labelText: string, order: number)
	local btn = Instance.new("TextButton")
	btn.Name = featureName
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.LayoutOrder = order
	btn.Text = labelText
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local function refresh()
		local on = self.features:IsEnabled(featureName)
		btn.BackgroundColor3 = on
			and Color3.fromRGB(60, 160, 90)
			or  Color3.fromRGB(60, 60, 70)
		btn.Text = ("%s  [%s]"):format(labelText, on and "ON" or "OFF")
	end
	refresh()

	btn.Activated:Connect(function()
		local on = self.features:IsEnabled(featureName)
		self.features:Toggle(featureName, not on)
		refresh()
	end)

	self.features:OnChanged(featureName, refresh)
	self.buttons[featureName] = btn
end

-- ============================================================
-- BOOTSTRAP
-- ============================================================
local function buildQueue(): {QuestTask}
	local queue = {}

	table.insert(queue, QuestTask.new({
		name        = "Ir para Região A",
		repetitions = 1,
		destination = Vector3.new(100, 5, 100),
	}))

	table.insert(queue, QuestTask.new({
		name             = "Coletar recursos",
		repetitions      = 5,
		uiGuiName        = "QuestUI",
		uiLabelName      = "ProgressLabel",
		actionButtonName = "AcceptQuestButton",
		targetResolver   = function()
			local list = {}
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj.Name == "Crystal" and obj:IsA("Model") then
					table.insert(list, obj)
				end
			end
			return list
		end,
	}))

	return queue
end

local FEATURES = {
	"AutoQuest",    -- master kill-switch da fila
	"AutoCollect",  -- reservado p/ outros fluxos
	"AutoTravel",   -- reservado p/ outros fluxos
}

local features     = FeatureRegistry.new(FEATURES)
local orchestrator = Orchestrator.new(buildQueue(), features)

local hub = HubUI.new(features, function(): string
	if not features:IsEnabled("AutoQuest") then
		return "Automação PAUSADA"
	end
	local task = orchestrator.queue[orchestrator.currentIndex]
	if not task then return "Fila concluída" end
	return ("Tarefa: %s\nRepetição: %d/%d"):format(
		task.config.name,
		orchestrator.currentRep + 1,
		orchestrator.targetReps
	)
end)

orchestrator:Start()

-- Ligar automação por padrão (mude para false se preferir começar OFF)
features:Toggle("AutoQuest", true)
