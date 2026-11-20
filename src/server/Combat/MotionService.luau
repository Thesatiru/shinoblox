--!strict
-- Movimento forçado dos personagens: empurrão, arremesso, lançamento, cravada, seguir e o controle no ar.
--
-- Tudo usa um LinearVelocity no HumanoidRootPart, criado pelo servidor. Para personagens de jogador
-- a física roda no cliente dono, mas o LinearVelocity replica e o cliente o aplica.
--
-- Controle no ar (combo aéreo): o servidor dita a velocidade vertical a cada quadro. Ela vai ficando
-- mais negativa conforme a gravidade crescente do ComboTracker; resetFall() a zera (suspensão no golpe).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local ComboTracker = require(script.Parent.ComboTracker)

type MotionKind = CombatTypes.MotionKind

local MOTION = CombatConfig.MOTION
local FOLLOW = CombatConfig.FOLLOW
local ATTACHMENT_NAME = "MotionAttachment"
local VELOCITY_NAME = "MotionVelocity"

type MotionRecord = {
	root: BasePart,
	velocity: LinearVelocity,
	token: number, -- sobe a cada movimento novo; o anterior percebe e para
	airConnection: RBXScriptConnection?,
	fallSpeed: number, -- velocidade vertical no controle do ar (negativa = descendo)
}

local records = setmetatable({} :: { [Model]: MotionRecord }, { __mode = "k" })

local MotionService = {}

local function getRecord(character: Model): MotionRecord?
	local existing = records[character]
	if existing and existing.velocity.Parent then
		return existing
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = VELOCITY_NAME
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	velocity.MaxForce = math.huge -- vence atrito, andar e gravidade
	velocity.Enabled = false
	velocity.Parent = root

	local record: MotionRecord = {
		root = root,
		velocity = velocity,
		token = 0,
		airConnection = nil,
		fallSpeed = 0,
	}
	records[character] = record
	return record
end

-- Cancela qualquer movimento em andamento. Devolve o token do próximo movimento.
local function cancel(record: MotionRecord): number
	record.token += 1
	local connection = record.airConnection
	if connection then
		connection:Disconnect()
		record.airConnection = nil
	end
	record.velocity.Enabled = false
	return record.token
end

local function isGrounded(character: Model, root: BasePart): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local length = root.Size.Y / 2 + hipHeight + MOTION.groundCheckMargin
	return workspace:Raycast(root.Position, Vector3.new(0, -length, 0), params) ~= nil
end

-- Velocidade fixa por um tempo. planar = só no plano horizontal (a gravidade continua agindo).
local function playTimed(
	character: Model,
	velocity: Vector3,
	duration: number,
	planar: boolean,
	onDone: ((record: MotionRecord) -> ())?
)
	local record = getRecord(character)
	if not record then
		return
	end
	local token = cancel(record)
	local constraint = record.velocity

	if planar then
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		constraint.PrimaryTangentAxis = Vector3.xAxis
		constraint.SecondaryTangentAxis = Vector3.zAxis
		constraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	else
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		constraint.VectorVelocity = velocity
	end
	constraint.Enabled = true

	task.delay(duration, function()
		if record.token ~= token then
			return -- outro movimento começou no meio
		end
		constraint.Enabled = false
		if onDone then
			onDone(record)
		end
	end)
end

local function startAirControl(character: Model, record: MotionRecord, gravitySource: Model, onLanded: () -> ())
	local token = cancel(record)
	local constraint = record.velocity
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	constraint.VectorVelocity = Vector3.zero
	constraint.Enabled = true
	record.fallSpeed = 0

	local airTime = 0
	record.airConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if record.token ~= token then
			return
		end
		airTime += deltaTime
		-- Gravidade escalada: quanto mais tempo o alvo está no ar, mais rápido os dois caem.
		record.fallSpeed -= workspace.Gravity * ComboTracker.getGravityScale(gravitySource) * deltaTime
		constraint.VectorVelocity = Vector3.new(0, record.fallSpeed, 0)

		if airTime >= MOTION.minAirTime and isGrounded(character, record.root) then
			cancel(record)
			onLanded()
		end
	end)
end

-- Golpes do chão: a vítima sai na direção do golpe.
function MotionService.push(target: Model, direction: Vector3)
	playTimed(target, direction * MOTION.pushSpeed, MOTION.pushDuration, true)
end

function MotionService.throw(target: Model, direction: Vector3)
	local velocity = direction * MOTION.throwSpeed + Vector3.yAxis * MOTION.throwUpSpeed
	playTimed(target, velocity, MOTION.throwDuration, false)
end

function MotionService.slam(target: Model)
	playTimed(target, Vector3.new(0, -MOTION.slamDownSpeed, 0), MOTION.slamDuration, false)
end

-- Joga o alvo para cima e, no topo, passa para o controle do ar. onLanded é chamado ao tocar o chão.
function MotionService.launch(target: Model, onLanded: () -> ())
	playTimed(target, Vector3.yAxis * MOTION.launchUpSpeed, MOTION.launchDuration, false, function(record)
		startAirControl(target, record, target, onLanded)
	end)
end

-- Leva o atacante até o alvo lançado e o mantém no ar com a mesma gravidade do alvo.
function MotionService.follow(attacker: Model, target: Model, onLanded: () -> ())
	local attackerRecord = getRecord(attacker)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not (attackerRecord and targetRoot and targetRoot:IsA("BasePart")) then
		return
	end

	-- Para o atacante parar na frente do alvo, do lado de onde ele veio.
	local fromTarget = attackerRecord.root.Position - targetRoot.Position
	local horizontal = Vector3.new(fromTarget.X, 0, fromTarget.Z)
	local side = if horizontal.Magnitude > 0 then horizontal.Unit else Vector3.zAxis
	local goal = targetRoot.Position + side * FOLLOW.arrivalOffset

	local velocity = (goal - attackerRecord.root.Position) / FOLLOW.travelTime
	playTimed(attacker, velocity, FOLLOW.travelTime, false, function(record)
		startAirControl(attacker, record, target, onLanded)
	end)
end

-- Suspensão: zera a queda de quem está no controle do ar (chamado a cada golpe aéreo).
function MotionService.resetFall(character: Model)
	local record = records[character]
	if record and record.airConnection then
		record.fallSpeed = 0
	end
end

function MotionService.isInAirControl(character: Model): boolean
	local record = records[character]
	return record ~= nil and record.airConnection ~= nil
end

-- Para qualquer movimento forçado e devolve o personagem à física normal.
function MotionService.stop(character: Model)
	local record = records[character]
	if record then
		cancel(record)
	end
end

-- Atalho usado pelo HitService: aplica o movimento de um golpe.
-- Launch não entra aqui porque precisa do callback de pouso.
function MotionService.applyHitMotion(target: Model, motion: MotionKind, direction: Vector3)
	if motion == "Push" then
		MotionService.push(target, direction)
	elseif motion == "Throw" then
		MotionService.throw(target, direction)
	elseif motion == "Slam" then
		MotionService.slam(target)
	end
end

return MotionService
