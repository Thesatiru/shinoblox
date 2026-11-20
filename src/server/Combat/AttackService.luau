--!strict
-- Escolhe o golpe do combo de M1 e agenda as fases (preparação -> impacto -> recuperação).
-- Trabalha com personagens (Model), então serve para jogadores, bonecos e inimigos.
-- Também cuida de "seguir" o alvo lançado (requestFollow).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local StateService = require(script.Parent.StateService)
local HitboxService = require(script.Parent.HitboxService)
local HitService = require(script.Parent.HitService)
local MotionService = require(script.Parent.MotionService)
local ComboTracker = require(script.Parent.ComboTracker)

type AttackData = CombatTypes.AttackData
type AttackDirection = CombatTypes.AttackDirection
type HitData = CombatTypes.HitData
type CharacterState = CombatTypes.CharacterState

local COMBO = CombatConfig.COMBO
local ATTACKS = CombatConfig.ATTACKS
local FOLLOW = CombatConfig.FOLLOW
local VALIDATION = CombatConfig.VALIDATION

type BufferedInput = {
	direction: AttackDirection,
	jumpHeld: boolean,
}

type AttackerRecord = {
	comboIndex: number, -- golpes já feitos no combo atual (0 = o próximo é a abertura)
	lastAttackTime: number,
	recoveryEndTime: number?, -- fim da recuperação do golpe atual; nil fora da recuperação
	buffered: BufferedInput?,
	launchedTarget: Model?, -- último alvo lançado por este atacante, para seguir
	launchTime: number,
}

local records = setmetatable({} :: { [Model]: AttackerRecord }, { __mode = "k" })

local AttackService = {}

local function getRecord(character: Model): AttackerRecord
	local record = records[character]
	if not record then
		record = {
			comboIndex = 0,
			lastAttackTime = -math.huge,
			recoveryEndTime = nil,
			buffered = nil,
			launchedTarget = nil,
			launchTime = 0,
		}
		records[character] = record
	end
	return record
end

local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Direção para onde o personagem olha, sem a parte vertical.
local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0 then flat.Unit else Vector3.zAxis
end

-- Qual golpe sai, dada a posição na contagem (1 a 5) e o input.
local function chooseAttack(nextIndex: number, direction: AttackDirection, jumpHeld: boolean, inAir: boolean): AttackData
	local isLast = nextIndex >= COMBO.maxHits
	if inAir then
		if isLast then
			-- Espaço segurado = arremesso; solto antes do último M1 = cravada.
			return if jumpHeld then ATTACKS.airFinisherThrow else ATTACKS.airFinisherSlam
		end
		return ATTACKS.airHit
	end
	if isLast then
		return ATTACKS.groundFinishers[direction]
	end
	if jumpHeld and COMBO.launcherHits[nextIndex] then
		return ATTACKS.launcher
	end
	return ATTACKS.groundHits[nextIndex]
end

local function performAttack(character: Model, record: AttackerRecord, direction: AttackDirection, jumpHeld: boolean)
	local root = getRoot(character)
	if not root then
		return
	end

	local now = os.clock()
	if now - record.lastAttackTime > COMBO.resetTime then
		record.comboIndex = 0
	end
	record.lastAttackTime = now

	local nextIndex = record.comboIndex + 1
	-- No ar ou no chão é o servidor que decide, pelo controle do ar do MotionService.
	local inAir = MotionService.isInAirControl(character)
	local attack = chooseAttack(nextIndex, direction, jumpHeld, inAir)

	-- Preparação --------------------------------------------------------------
	StateService.setState(character, "Attacking")
	if inAir then
		MotionService.resetFall(character) -- atacante também fica suspenso a cada golpe aéreo
	end
	task.wait(attack.windup)

	-- Se levou um golpe durante a preparação, o estado mudou: o golpe é cancelado e não conta.
	if StateService.getState(character) ~= "Attacking" then
		record.buffered = nil
		return
	end

	-- Errar não reinicia o combo: a contagem avança mesmo sem acertar ninguém.
	record.comboIndex = if nextIndex >= COMBO.maxHits then 0 else nextIndex
	record.lastAttackTime = os.clock()

	-- Impacto -----------------------------------------------------------------
	local hitData: HitData = {
		attackName = attack.name,
		source = "M1",
		damage = attack.damage,
		stunDuration = attack.stunDuration,
		motion = attack.motion,
		direction = flatLook(root),
	}
	HitboxService.run(character, attack, function(target: Model)
		local connected = HitService.applyHit(character, target, hitData)
		if connected and attack.motion == "Launch" then
			record.launchedTarget = target
			record.launchTime = os.clock()
		end
	end)

	-- Recuperação -------------------------------------------------------------
	record.recoveryEndTime = os.clock() + attack.recovery
	task.wait(attack.recovery)
	record.recoveryEndTime = nil

	if StateService.getState(character) ~= "Attacking" then
		record.buffered = nil -- foi interrompido na recuperação
		return
	end

	local stateAfter: CharacterState = if MotionService.isInAirControl(character) then "Airborne" else "Idle"
	StateService.setState(character, stateAfter)

	local buffered = record.buffered
	record.buffered = nil
	if buffered then
		performAttack(character, record, buffered.direction, buffered.jumpHeld)
	end
end

-- Pede um M1. Devolve false e o motivo se o pedido foi recusado.
function AttackService.requestAttack(character: Model, direction: AttackDirection, jumpHeld: boolean): (boolean, string?)
	if not StateService.isRegistered(character) then
		return false, "personagem não registrado"
	end
	local record = getRecord(character)

	if StateService.canAttack(character) then
		-- task.spawn: o golpe leva décimos de segundo e não pode travar quem chamou.
		task.spawn(performAttack, character, record, direction, jumpHeld)
		return true, nil
	end

	-- Buffer: clique no fim da recuperação fica guardado e sai assim que o golpe atual termina.
	local recoveryEndTime = record.recoveryEndTime
	if
		StateService.getState(character) == "Attacking"
		and recoveryEndTime
		and recoveryEndTime - os.clock() <= COMBO.inputBufferWindow
	then
		record.buffered = { direction = direction, jumpHeld = jumpHeld }
		return true, nil
	end

	return false, `estado {StateService.getState(character)} não permite atacar`
end

-- Pede para seguir o alvo lançado. Sem alvo lançado devolve (false, nil): é só um pulo comum, não erro.
function AttackService.requestFollow(character: Model): (boolean, string?)
	local record = records[character]
	local target = if record then record.launchedTarget else nil
	if not record or not target then
		return false, nil
	end

	if os.clock() - record.launchTime > FOLLOW.window then
		record.launchedTarget = nil
		return false, "janela de seguir fechou"
	end
	if not ComboTracker.isInAirCombo(target) then
		record.launchedTarget = nil
		return false, "alvo não está mais no ar"
	end
	if StateService.getState(character) ~= "Idle" then
		return false, "atacante ocupado"
	end

	local root = getRoot(character)
	local targetRoot = getRoot(target)
	if not root or not targetRoot then
		return false, "sem HumanoidRootPart"
	end

	local toTarget = targetRoot.Position - root.Position
	if toTarget.Magnitude > FOLLOW.maxDistance + VALIDATION.followDistanceTolerance then
		return false, "alvo longe demais"
	end

	-- Mira generosa: o alvo precisa estar à frente e perto da linha para onde o atacante olha.
	local look = flatLook(root)
	local flatToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
	local forwardDistance = flatToTarget:Dot(look)
	if forwardDistance < 0 then
		return false, "alvo atrás do atacante"
	end
	local sideDistance = (flatToTarget - look * forwardDistance).Magnitude
	if sideDistance > FOLLOW.aimHalfWidth then
		return false, "alvo fora da mira"
	end

	record.launchedTarget = nil -- um seguir por lançamento
	StateService.setState(character, "Airborne")
	MotionService.follow(character, target, function()
		-- Pousou. Se estava no meio de um golpe, o próprio golpe devolve o estado no fim.
		if StateService.getState(character) == "Airborne" then
			StateService.setState(character, "Idle")
		end
	end)
	return true, nil
end

return AttackService
