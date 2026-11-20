--!strict
-- Tipos compartilhados do combate. Servidor e cliente fazem require deste módulo.

export type CharacterState = "Idle" | "Attacking" | "Blocking" | "Stunned" | "Airborne" | "Knockdown"

-- Direção segurada no golpe. Só faz diferença no finalizador do chão.
export type AttackDirection = "Neutral" | "Forward"

-- Modos do boneco de treino. Blocking só entra junto com a etapa de postura.
export type DummyMode = "Passive" | "Attacking" | "Blocking"

-- Intenções que o cliente pode enviar ao servidor.
export type CombatAction = "M1" | "Follow"

-- Movimento forçado que um golpe aplica na vítima.
export type MotionKind = "None" | "Push" | "Throw" | "Launch" | "Slam"

-- Descrição de um golpe. Os valores ficam no CombatConfig.
export type AttackData = {
	name: string,
	windup: number, -- preparação, em segundos
	active: number, -- impacto: tempo em que a hitbox procura alvos
	recovery: number, -- recuperação, em segundos
	damage: number,
	stunDuration: number,
	hitboxSize: Vector3,
	hitboxOffset: CFrame, -- relativo ao HumanoidRootPart do atacante
	motion: MotionKind,
}

-- De onde vem o golpe. A invulnerabilidade de quem está caído só vale contra M1;
-- habilidades (etapas futuras) acertam o alvo caído e servem de extensor de combo.
export type HitSource = "M1" | "Skill"

-- O que o HitService recebe para aplicar um golpe em um alvo.
export type HitData = {
	attackName: string,
	source: HitSource,
	damage: number, -- dano base, antes da escala do combo
	stunDuration: number,
	motion: MotionKind,
	direction: Vector3, -- unitário: para onde a vítima é empurrada
}

-- Os tipos somem quando o jogo roda, então a validação precisa destas tabelas reais.
local VALID_STATES: { [string]: boolean } = {
	Idle = true,
	Attacking = true,
	Blocking = true,
	Stunned = true,
	Airborne = true,
	Knockdown = true,
}

local VALID_DIRECTIONS: { [string]: boolean } = {
	Neutral = true,
	Forward = true,
}

local VALID_ACTIONS: { [string]: boolean } = {
	M1 = true,
	Follow = true,
}

local CombatTypes = {}

-- Nomes usados pelos dois lados. O servidor grava; o cliente lê.
CombatTypes.STATE_ATTRIBUTE = "CombatState" -- atributo do Model com o CharacterState atual
CombatTypes.CHARACTER_TAG = "CombatCharacter" -- tag do CollectionService em todo personagem registrado

function CombatTypes.isCharacterState(value: unknown): boolean
	return typeof(value) == "string" and VALID_STATES[value] == true
end

function CombatTypes.isAttackDirection(value: unknown): boolean
	return typeof(value) == "string" and VALID_DIRECTIONS[value] == true
end

function CombatTypes.isCombatAction(value: unknown): boolean
	return typeof(value) == "string" and VALID_ACTIONS[value] == true
end

return CombatTypes
