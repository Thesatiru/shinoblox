--!strict
-- Máquina de estados de combate por personagem (jogador, boneco ou inimigo).
-- O estado é publicado no atributo "CombatState" do Model, que replica sozinho para os clientes.
-- Todo personagem registrado recebe a tag "CombatCharacter", para o cliente saber quem observar.
-- Ao trocar de estado, ajusta WalkSpeed e pulo conforme CombatConfig.STATE_MOVEMENT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)

type CharacterState = CombatTypes.CharacterState

local STATE_ATTRIBUTE = CombatTypes.STATE_ATTRIBUTE
local CHARACTER_TAG = CombatTypes.CHARACTER_TAG

type CharacterRecord = {
	humanoid: Humanoid,
	-- Valores originais do Humanoid, para restaurar ao voltar para Idle.
	baseWalkSpeed: number,
	baseJumpPower: number,
	baseJumpHeight: number,
	-- Sobe a cada setState; um retorno agendado só vale se o número ainda for o mesmo.
	revertToken: number,
	ancestryConnection: RBXScriptConnection,
}

local records: { [Model]: CharacterRecord } = {}

local StateService = {}

local function applyMovement(record: CharacterRecord, state: CharacterState)
	local rules = CombatConfig.STATE_MOVEMENT[state]
	local humanoid = record.humanoid
	humanoid.WalkSpeed = record.baseWalkSpeed * rules.speedMultiplier

	-- O Humanoid usa JumpPower ou JumpHeight conforme UseJumpPower; ajustamos os dois.
	if rules.canJump then
		humanoid.JumpPower = record.baseJumpPower
		humanoid.JumpHeight = record.baseJumpHeight
	else
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function writeState(character: Model, record: CharacterRecord, state: CharacterState)
	character:SetAttribute(STATE_ATTRIBUTE, state)
	applyMovement(record, state)
end

function StateService.unregister(character: Model)
	local record = records[character]
	if record then
		record.ancestryConnection:Disconnect()
		records[character] = nil
		character:RemoveTag(CHARACTER_TAG)
	end
end

-- Chamar uma vez quando o personagem aparece (CharacterAdded ou boneco criado).
function StateService.register(character: Model)
	if records[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[StateService] {character:GetFullName()} não tem Humanoid; não foi registrado`)
		return
	end

	local record: CharacterRecord = {
		humanoid = humanoid,
		baseWalkSpeed = humanoid.WalkSpeed,
		baseJumpPower = humanoid.JumpPower,
		baseJumpHeight = humanoid.JumpHeight,
		revertToken = 0,
		-- Quando o personagem sai do workspace (morreu, respawnou, foi destruído), esquece ele.
		ancestryConnection = character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(workspace) then
				StateService.unregister(character)
			end
		end),
	}
	records[character] = record
	writeState(character, record, "Idle")
	character:AddTag(CHARACTER_TAG)
end

function StateService.isRegistered(character: Model): boolean
	return records[character] ~= nil
end

-- Devolve nil se o personagem não foi registrado.
function StateService.getState(character: Model): CharacterState?
	if not records[character] then
		return nil
	end
	local value = character:GetAttribute(STATE_ATTRIBUTE)
	if CombatTypes.isCharacterState(value) then
		return value :: CharacterState
	end
	return nil
end

-- Troca o estado. Com duration, volta sozinho para nextState (padrão: Idle) depois desse tempo,
-- a menos que outro setState aconteça antes: aí o retorno antigo é cancelado.
function StateService.setState(
	character: Model,
	state: CharacterState,
	duration: number?,
	nextState: CharacterState?
)
	local record = records[character]
	if not record then
		warn(`[StateService] setState em personagem não registrado: {character:GetFullName()}`)
		return
	end

	record.revertToken += 1
	local token = record.revertToken
	writeState(character, record, state)

	if duration then
		local stateAfter: CharacterState = nextState or "Idle"
		task.delay(duration, function()
			-- Ignora se o personagem sumiu ou se o estado foi trocado nesse meio-tempo.
			if records[character] ~= record or record.revertToken ~= token then
				return
			end
			StateService.setState(character, stateAfter)
		end)
	end
end

-- Pode começar um M1 agora? No chão só parado; no ar, entre os golpes do combo aéreo.
-- A vítima lançada fica Stunned, não Airborne, então não passa por aqui.
function StateService.canAttack(character: Model): boolean
	local state = StateService.getState(character)
	return state == "Idle" or state == "Airborne"
end

return StateService
