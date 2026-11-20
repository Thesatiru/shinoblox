--!strict
-- Anti-infinito, do ponto de vista da VÍTIMA:
--   golpes levados no combo atual -> escala de dano decrescente
--   tempo no ar desde o lançador -> gravidade crescente
--   invulnerabilidade curta ao levantar do chão
-- O combo da vítima recomeça quando ela leva um golpe estando livre (fora de Stunned e Knockdown).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local StateService = require(script.Parent.StateService)

local ANTI_INFINITE = CombatConfig.ANTI_INFINITE

type VictimRecord = {
	hits: number,
	airStartTime: number?, -- os.clock() do lançador; nil = não está num combo aéreo
	invulnerableUntil: number,
}

-- Tabela com chaves "fracas" (__mode = "k"): quando o personagem é destruído e ninguém mais
-- o referencia, a entrada some sozinha. Evita vazamento de memória a cada respawn.
local records = setmetatable({} :: { [Model]: VictimRecord }, { __mode = "k" })

local ComboTracker = {}

local function getRecord(character: Model): VictimRecord
	local record = records[character]
	if not record then
		record = { hits = 0, airStartTime = nil, invulnerableUntil = 0 }
		records[character] = record
	end
	return record
end

-- Chamar ANTES de trocar o estado da vítima. Devolve a escala de dano deste golpe (1 = dano cheio).
function ComboTracker.registerHit(target: Model): number
	local record = getRecord(target)
	local state = StateService.getState(target)
	if state ~= "Stunned" and state ~= "Knockdown" then
		-- Vítima estava livre: começa um combo novo.
		record.hits = 0
		record.airStartTime = nil
	end
	record.hits += 1
	return math.max(ANTI_INFINITE.minDamageScale, 1 - ANTI_INFINITE.damageDecayPerHit * (record.hits - 1))
end

function ComboTracker.getHits(target: Model): number
	local record = records[target]
	return if record then record.hits else 0
end

function ComboTracker.startAir(target: Model)
	getRecord(target).airStartTime = os.clock()
end

function ComboTracker.endAir(target: Model)
	local record = records[target]
	if record then
		record.airStartTime = nil
	end
end

function ComboTracker.isInAirCombo(target: Model): boolean
	local record = records[target]
	return record ~= nil and record.airStartTime ~= nil
end

-- Fração da gravidade normal para quem está no combo aéreo deste alvo. 1 = gravidade normal.
function ComboTracker.getGravityScale(target: Model): number
	local record = records[target]
	local airStartTime = if record then record.airStartTime else nil
	if not airStartTime then
		return 1
	end
	local airTime = os.clock() - airStartTime
	return math.min(
		ANTI_INFINITE.airGravityMax,
		ANTI_INFINITE.airGravityStart + ANTI_INFINITE.airGravityGrowthPerSecond * airTime
	)
end

function ComboTracker.setInvulnerable(target: Model, duration: number)
	local record = getRecord(target)
	record.invulnerableUntil = math.max(record.invulnerableUntil, os.clock() + duration)
end

function ComboTracker.isInvulnerable(target: Model): boolean
	local record = records[target]
	return record ~= nil and os.clock() < record.invulnerableUntil
end

return ComboTracker
