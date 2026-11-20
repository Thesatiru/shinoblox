--!strict
-- applyHit: a função ÚNICA que aplica um golpe em um alvo. Jogadores, bonecos e inimigos passam por aqui.
-- Ordem: validação -> DEFESA (futuro) -> escala do combo -> dano -> estado -> movimento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local StateService = require(script.Parent.StateService)
local ComboTracker = require(script.Parent.ComboTracker)
local MotionService = require(script.Parent.MotionService)

type HitData = CombatTypes.HitData

local MOTION = CombatConfig.MOTION
local ANTI_INFINITE = CombatConfig.ANTI_INFINITE

local HitService = {}

-- Caído: fica em Knockdown e invulnerável durante a queda e um pouco depois de levantar.
local function knockDown(target: Model)
	StateService.setState(target, "Knockdown", MOTION.knockdownDuration)
	ComboTracker.setInvulnerable(target, MOTION.knockdownDuration + ANTI_INFINITE.getUpInvulnerability)
end

-- A vítima lançada tocou o chão sem levar finalizador: cai em Knockdown.
local function onLaunchedTargetLanded(target: Model)
	ComboTracker.endAir(target)
	if StateService.getState(target) == "Stunned" then
		knockDown(target)
	end
end

-- Devolve true se o golpe conectou.
function HitService.applyHit(attacker: Model, target: Model, hitData: HitData): boolean
	if target == attacker or not StateService.isRegistered(target) then
		return false
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if ComboTracker.isInvulnerable(target) then
		return false
	end

	-- DEFESA ---------------------------------------------------------------------
	-- Ponto único onde bloqueio, parry e postura entram (etapa de postura).
	-- Por enquanto todo golpe que chega aqui conecta.
	-- ----------------------------------------------------------------------------

	-- Antes de trocar o estado: o ComboTracker decide se é combo novo olhando o estado atual.
	local damageScale = ComboTracker.registerHit(target)
	humanoid:TakeDamage(hitData.damage * damageScale)

	-- Se o alvo estava em Attacking, a troca de estado abaixo interrompe o golpe dele
	-- (o AttackService confere o estado depois da preparação): quem acerta primeiro tem o mérito.
	local motion = hitData.motion
	if motion == "Launch" then
		-- Sem duração: fica Stunned até pousar ou levar o finalizador.
		StateService.setState(target, "Stunned")
		ComboTracker.startAir(target)
		MotionService.launch(target, function()
			onLaunchedTargetLanded(target)
		end)
	elseif motion == "Push" or motion == "Throw" or motion == "Slam" then
		ComboTracker.endAir(target)
		knockDown(target)
		MotionService.applyHitMotion(target, motion, hitData.direction)
	elseif ComboTracker.isInAirCombo(target) then
		-- Golpe aéreo comum: suspende a vítima e mantém Stunned até pousar.
		MotionService.resetFall(target)
		StateService.setState(target, "Stunned")
	else
		StateService.setState(target, "Stunned", hitData.stunDuration)
	end

	return true
end

return HitService
