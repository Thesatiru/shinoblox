--!strict
-- Cria (no servidor) e localiza (no cliente) os RemoteEvents do combate.
-- Fica em ReplicatedStorage.Remotes, fora da pasta Shared que o Rojo sincroniza.
--
-- CombatIntent é o único canal cliente -> servidor do combate:
--   FireServer("M1", direction: AttackDirection, jumpHeld: boolean)
--   FireServer("Follow")
-- Tudo que chega por ele deve ser validado no InputHandler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local INTENT_EVENT_NAME = "CombatIntent"

local CombatRemotes = {}

local function getOrCreateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:IsA("Folder") then
			return existing
		end
		error(`[CombatRemotes] ReplicatedStorage.{FOLDER_NAME} existe, mas não é uma Folder`)
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getOrCreateEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		end
		error(`[CombatRemotes] {FOLDER_NAME}.{name} existe, mas não é um RemoteEvent`)
	end

	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

-- O cliente pode carregar antes de o servidor criar o evento, por isso espera.
-- Se demorar mais de ~5 s, o próprio Roblox avisa "Infinite yield possible" no Output.
local function waitForEvent(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local event = folder:WaitForChild(name)
	if event:IsA("RemoteEvent") then
		return event
	end
	error(`[CombatRemotes] {FOLDER_NAME}.{name} não é um RemoteEvent`)
end

function CombatRemotes.getIntentEvent(): RemoteEvent
	if RunService:IsServer() then
		return getOrCreateEvent(getOrCreateFolder(), INTENT_EVENT_NAME)
	end
	return waitForEvent(INTENT_EVENT_NAME)
end

return CombatRemotes
