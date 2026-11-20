--!strict
-- Todos os números do combate. Nenhum outro módulo deve ter tempo, dano ou distância fixos no código.
-- Valores marcados com "PLAYTEST" são palpites iniciais e devem ser ajustados jogando.
-- Tempos em segundos, distâncias em studs, velocidades em studs/s.

local CombatTypes = require(script.Parent.CombatTypes)

type AttackData = CombatTypes.AttackData
type AttackDirection = CombatTypes.AttackDirection
type CharacterState = CombatTypes.CharacterState
type DummyMode = CombatTypes.DummyMode

-- Tipos de cada seção ----------------------------------------------------------

export type ComboConfig = {
	maxHits: number, -- contagem única: chão + ar
	resetTime: number, -- sem M1 por este tempo, o combo volta ao 1º golpe
	launcherHits: { [number]: boolean }, -- posições da contagem em que o lançador vale
}

export type AttackTable = {
	groundHits: { AttackData }, -- índice = posição na contagem (1 = abertura, 2 a 4 = normais)
	launcher: AttackData,
	groundFinishers: { [AttackDirection]: AttackData }, -- 5º golpe no chão
	airHit: AttackData, -- golpes no ar antes do último
	airFinisherThrow: AttackData, -- último golpe no ar com Espaço segurado
	airFinisherSlam: AttackData, -- último golpe no ar com Espaço solto
}

export type MotionConfig = {
	pushSpeed: number,
	pushDuration: number,
	throwSpeed: number,
	throwUpSpeed: number, -- componente vertical, para o arremesso fazer um arco
	throwDuration: number,
	launchUpSpeed: number,
	launchDuration: number,
	slamDownSpeed: number,
	slamDuration: number,
	knockdownDuration: number, -- tempo caído depois de empurrão, arremesso, cravada ou queda do combo aéreo
	groundCheckMargin: number, -- folga do raio para baixo que detecta o chão
	minAirTime: number, -- no ar, só procura o chão depois deste tempo (evita "pousar" na decolagem)
}

export type FollowConfig = {
	window: number, -- tempo depois do lançador em que dá para seguir
	aimHalfWidth: number, -- distância lateral máxima entre o alvo e a linha para onde o atacante olha
	maxDistance: number, -- distância máxima até o alvo lançado
	travelTime: number, -- quanto o atacante leva para chegar no alvo
	arrivalOffset: number, -- para onde o atacante vai: esta distância à frente do alvo, de frente para ele
}

export type AntiInfiniteConfig = {
	damageDecayPerHit: number, -- cada golpe do combo tira esta fração a mais do dano
	minDamageScale: number, -- o dano nunca cai abaixo desta fração
	airGravityStart: number, -- fração da gravidade normal logo depois do lançador (suspenso)
	airGravityGrowthPerSecond: number, -- quanto a fração cresce a cada segundo no ar
	airGravityMax: number,
	getUpInvulnerability: number, -- invulnerável por este tempo ao levantar do Knockdown
}

export type ValidationConfig = {
	rateLimitWindow: number, -- janela da contagem de pedidos
	maxRequestsPerWindow: number, -- acima disso, os pedidos do jogador são ignorados
	followDistanceTolerance: number, -- folga somada a maxDistance por causa do atraso da rede
}

export type DebugConfig = {
	enabled: boolean, -- liga tudo abaixo
	showHitboxes: boolean,
	hitboxColor: Color3,
	hitboxTransparency: number,
	hitboxLifetime: number, -- quanto tempo o bloco da hitbox fica visível
	colorByState: boolean,
	stateFillTransparency: number, -- transparência do preenchimento do Highlight de estado
	stateColors: { [CharacterState]: Color3 },
	printValidationFailures: boolean, -- avisa no Output quando o servidor recusa um pedido
}

-- Como cada estado afeta o movimento do personagem. Aplicado pelo StateService.
export type StateMovement = {
	speedMultiplier: number, -- fração da WalkSpeed original do personagem
	canJump: boolean,
}

export type DummySpawn = {
	cframe: CFrame, -- posição e para onde o boneco olha
	mode: DummyMode,
}

export type DummyConfig = {
	spawns: { DummySpawn },
	minHealth: number, -- a vida nunca fica abaixo disto: o boneco não morre
	healthResetDelay: number, -- sem levar golpe por este tempo, a vida volta ao máximo
	comboDisplayResetTime: number, -- sem levar golpe por este tempo, o dano do combo mostrado zera
}

export type Config = {
	COMBO: ComboConfig,
	STATE_MOVEMENT: { [CharacterState]: StateMovement },
	ATTACKS: AttackTable,
	MOTION: MotionConfig,
	FOLLOW: FollowConfig,
	ANTI_INFINITE: AntiInfiniteConfig,
	VALIDATION: ValidationConfig,
	DUMMY: DummyConfig,
	DEBUG: DebugConfig,
}

-- Hitbox padrão: um bloco à frente do atacante. No Roblox, "frente" é o eixo -Z do CFrame.
local DEFAULT_HITBOX_SIZE = Vector3.new(5, 5, 5) -- PLAYTEST
local DEFAULT_HITBOX_OFFSET = CFrame.new(0, 0, -3) -- PLAYTEST

-- Valores ----------------------------------------------------------------------

local CombatConfig: Config = {
	COMBO = {
		maxHits = 5,
		resetTime = 2, -- PLAYTEST
		launcherHits = { [2] = true, [3] = true, [4] = true },
	},

	STATE_MOVEMENT = {
		Idle = { speedMultiplier = 1, canJump = true },
		-- O atacante pode se mover durante os M1s.
		-- canJump fica true por enquanto: se o Espaço segurado atrapalha o lançador ainda é decisão em aberto.
		Attacking = { speedMultiplier = 0.6, canJump = true }, -- PLAYTEST
		Blocking = { speedMultiplier = 1, canJump = true }, -- definir na etapa de postura; não usado na Etapa 1
		Stunned = { speedMultiplier = 0, canJump = false },
		Airborne = { speedMultiplier = 0, canJump = false }, -- no ar quem move é o MotionService
		Knockdown = { speedMultiplier = 0, canJump = false },
	},

	-- Regra para o combo ser "verdadeiro": stunDuration de um golpe > recovery dele + windup do próximo.
	-- O aviso no fim do arquivo confere isso.
	ATTACKS = {
		groundHits = {
			{
				name = "Opener",
				windup = 0.18, -- PLAYTEST: abertura um pouco mais lenta, para dar leitura
				active = 0.1,
				recovery = 0.2,
				damage = 4, -- PLAYTEST
				stunDuration = 0.6, -- PLAYTEST: cobre recuperação + preparação do lançador (0.2 + 0.3)
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "None",
			},
			{
				name = "Hit2",
				windup = 0.15, -- PLAYTEST
				active = 0.1,
				recovery = 0.2,
				damage = 4, -- PLAYTEST
				stunDuration = 0.6, -- PLAYTEST: cobre recuperação + preparação do lançador (0.2 + 0.3)
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "None",
			},
			{
				name = "Hit3",
				windup = 0.15, -- PLAYTEST
				active = 0.1,
				recovery = 0.2,
				damage = 4, -- PLAYTEST
				stunDuration = 0.6, -- PLAYTEST: cobre recuperação + preparação do lançador (0.2 + 0.3)
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "None",
			},
			{
				name = "Hit4",
				windup = 0.15, -- PLAYTEST
				active = 0.1,
				recovery = 0.2,
				damage = 4, -- PLAYTEST
				stunDuration = 0.6, -- PLAYTEST: cobre o windup mais longo dos finalizadores
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "None",
			},
		},

		-- Agarrão: tempos mais longos e alcance menor que um soco.
		launcher = {
			name = "Launcher",
			windup = 0.3, -- PLAYTEST
			active = 0.15, -- PLAYTEST
			recovery = 0.45, -- PLAYTEST
			damage = 5, -- PLAYTEST
			stunDuration = 2.2, -- PLAYTEST: maior que FOLLOW.window, para o alvo não se mexer antes de quem segue chegar
			hitboxSize = Vector3.new(4, 5, 3), -- PLAYTEST
			hitboxOffset = CFrame.new(0, 0, -2.5), -- PLAYTEST
			motion = "Launch",
		},

		groundFinishers = {
			Neutral = {
				name = "FinisherPush",
				windup = 0.25, -- PLAYTEST
				active = 0.12,
				recovery = 0.4, -- PLAYTEST
				damage = 7, -- PLAYTEST
				stunDuration = 0.4, -- PLAYTEST
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "Push",
			},
			Forward = {
				name = "FinisherThrow",
				windup = 0.3, -- PLAYTEST
				active = 0.12,
				recovery = 0.45, -- PLAYTEST
				damage = 7, -- PLAYTEST
				stunDuration = 0.4, -- PLAYTEST
				hitboxSize = DEFAULT_HITBOX_SIZE,
				hitboxOffset = DEFAULT_HITBOX_OFFSET,
				motion = "Throw",
			},
		},

		airHit = {
			name = "AirHit",
			windup = 0.15, -- PLAYTEST
			active = 0.1,
			recovery = 0.2,
			damage = 4, -- PLAYTEST
			stunDuration = 0.6, -- PLAYTEST
			hitboxSize = DEFAULT_HITBOX_SIZE,
			hitboxOffset = DEFAULT_HITBOX_OFFSET,
			motion = "None", -- no ar os dois ficam suspensos; a gravidade vem do ANTI_INFINITE
		},

		airFinisherThrow = {
			name = "AirFinisherThrow",
			windup = 0.25, -- PLAYTEST
			active = 0.12,
			recovery = 0.4, -- PLAYTEST
			damage = 7, -- PLAYTEST
			stunDuration = 0.4, -- PLAYTEST
			hitboxSize = DEFAULT_HITBOX_SIZE,
			hitboxOffset = DEFAULT_HITBOX_OFFSET,
			motion = "Throw",
		},

		airFinisherSlam = {
			name = "AirFinisherSlam",
			windup = 0.25, -- PLAYTEST
			active = 0.12,
			recovery = 0.4, -- PLAYTEST
			damage = 8, -- PLAYTEST: um pouco mais, porque exige soltar o Espaço no tempo certo
			stunDuration = 0.4, -- PLAYTEST
			hitboxSize = DEFAULT_HITBOX_SIZE,
			hitboxOffset = DEFAULT_HITBOX_OFFSET,
			motion = "Slam",
		},
	},

	MOTION = {
		pushSpeed = 30, -- PLAYTEST
		pushDuration = 0.2, -- PLAYTEST
		throwSpeed = 60, -- PLAYTEST
		throwUpSpeed = 15, -- PLAYTEST
		throwDuration = 0.3, -- PLAYTEST
		launchUpSpeed = 50, -- PLAYTEST: com launchDuration 0.3, sobe uns 15 studs
		launchDuration = 0.3, -- PLAYTEST
		slamDownSpeed = 80, -- PLAYTEST
		slamDuration = 0.25, -- PLAYTEST
		knockdownDuration = 1.0, -- PLAYTEST
		groundCheckMargin = 0.5,
		minAirTime = 0.1,
	},

	FOLLOW = {
		window = 2, -- PLAYTEST
		aimHalfWidth = 8, -- PLAYTEST: uns dois personagens para cada lado
		maxDistance = 30, -- PLAYTEST
		travelTime = 0.2, -- PLAYTEST
		arrivalOffset = 4, -- PLAYTEST
	},

	ANTI_INFINITE = {
		damageDecayPerHit = 0.1, -- PLAYTEST: 1º golpe 100%, 2º 90%, 3º 80%...
		minDamageScale = 0.5, -- PLAYTEST
		airGravityStart = 0.1, -- PLAYTEST
		airGravityGrowthPerSecond = 0.5, -- PLAYTEST
		airGravityMax = 1.5, -- PLAYTEST
		getUpInvulnerability = 0.5, -- PLAYTEST
	},

	VALIDATION = {
		rateLimitWindow = 1,
		maxRequestsPerWindow = 12, -- bem acima do que um humano aperta; serve só contra spam de exploit
		followDistanceTolerance = 4,
	},

	DUMMY = {
		-- O chão (Baseplate) fica em Y = 0; Y = 3 põe o centro do R15 em pé. Todos olham para a origem.
		spawns = {
			{ cframe = CFrame.lookAt(Vector3.new(-8, 3, -15), Vector3.new(0, 3, 0)), mode = "Passive" },
			{ cframe = CFrame.lookAt(Vector3.new(8, 3, -15), Vector3.new(0, 3, 0)), mode = "Passive" },
		},
		minHealth = 1,
		healthResetDelay = 3, -- PLAYTEST
		comboDisplayResetTime = 2, -- PLAYTEST
	},

	DEBUG = {
		enabled = true, -- desligar antes de publicar
		showHitboxes = true,
		hitboxColor = Color3.fromRGB(255, 0, 0),
		hitboxTransparency = 0.7,
		hitboxLifetime = 0.15,
		colorByState = true,
		stateFillTransparency = 0.5,
		stateColors = {
			Idle = Color3.fromRGB(255, 255, 255),
			Attacking = Color3.fromRGB(255, 220, 0),
			Blocking = Color3.fromRGB(0, 120, 255),
			Stunned = Color3.fromRGB(255, 130, 0),
			Airborne = Color3.fromRGB(170, 0, 255),
			Knockdown = Color3.fromRGB(200, 0, 0),
		},
		printValidationFailures = true,
	},
}

-- Avisa no Output se um par de golpes seguidos não forma combo verdadeiro.
-- Usa warn e não error: durante o playtest pode ser proposital testar um combo "quebrado".
local function checkChain(first: AttackData, nextAttack: AttackData)
	local gap = first.recovery + nextAttack.windup
	if first.stunDuration <= gap then
		warn(
			string.format(
				"[CombatConfig] %s -> %s: atordoamento %.2f s <= recuperação + preparação %.2f s; o alvo escapa",
				first.name,
				nextAttack.name,
				first.stunDuration,
				gap
			)
		)
	end
end

local attacks = CombatConfig.ATTACKS
local groundHits = attacks.groundHits
for index = 1, #groundHits - 1 do
	checkChain(groundHits[index], groundHits[index + 1])
	checkChain(groundHits[index], attacks.launcher)
end
for _, finisher in attacks.groundFinishers do
	checkChain(groundHits[#groundHits], finisher)
end
checkChain(attacks.airHit, attacks.airHit)
checkChain(attacks.airHit, attacks.airFinisherThrow)
checkChain(attacks.airHit, attacks.airFinisherSlam)

-- Congela as tabelas para ninguém alterar a config em tempo de execução por engano.
local function deepFreeze(value: any)
	if typeof(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
end
deepFreeze(CombatConfig)

return CombatConfig
