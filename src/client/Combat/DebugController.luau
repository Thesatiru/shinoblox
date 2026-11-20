--!strict
-- Debug visual: pinta cada personagem de combate com a cor do seu CombatState.
-- Só roda no cliente e só se CombatConfig.DEBUG.enabled e colorByState estiverem ligados.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)

type CharacterState = CombatTypes.CharacterState

local DEBUG = CombatConfig.DEBUG
local STATE_ATTRIBUTE = CombatTypes.STATE_ATTRIBUTE
local CHARACTER_TAG = CombatTypes.CHARACTER_TAG
local HIGHLIGHT_NAME = "CombatStateDebug"

type Watched = {
	highlight: Highlight,
	connection: RBXScriptConnection,
}

local watched: { [Model]: Watched } = {}

local DebugController = {}

local function paint(character: Model, highlight: Highlight)
	local state = character:GetAttribute(STATE_ATTRIBUTE)
	if CombatTypes.isCharacterState(state) then
		local color = DEBUG.stateColors[state :: CharacterState]
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end

local function onTagAdded(instance: Instance)
	if not instance:IsA("Model") or watched[instance] then
		return
	end

	-- Highlight: contorno e preenchimento colorido. Criado aqui no cliente, só este jogador vê.
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillTransparency = DEBUG.stateFillTransparency
	highlight.Adornee = instance
	highlight.Parent = instance
	paint(instance, highlight)

	watched[instance] = {
		highlight = highlight,
		connection = instance:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(function()
			paint(instance, highlight)
		end),
	}
end

local function onTagRemoved(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = watched[instance]
	if entry then
		entry.connection:Disconnect()
		entry.highlight:Destroy()
		watched[instance] = nil
	end
end

function DebugController.start()
	if not (DEBUG.enabled and DEBUG.colorByState) then
		return
	end

	CollectionService:GetInstanceAddedSignal(CHARACTER_TAG):Connect(onTagAdded)
	CollectionService:GetInstanceRemovedSignal(CHARACTER_TAG):Connect(onTagRemoved)
	-- Personagens que já tinham a tag antes deste script rodar.
	for _, instance in CollectionService:GetTagged(CHARACTER_TAG) do
		onTagAdded(instance)
	end
end

return DebugController
