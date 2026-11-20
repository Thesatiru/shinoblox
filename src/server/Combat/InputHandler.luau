--!strict
-- Único lugar do servidor que escuta o RemoteEvent CombatIntent.
-- Tudo que vem do cliente pode ter sido forjado por um exploit, então tudo é validado:
-- limite de pedidos, tipos dos argumentos, personagem existente e registrado.
-- Estado, recarga, distância e mira são validados pelo AttackService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatRemotes = require(ReplicatedStorage.Shared.Combat.CombatRemotes)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local StateService = require(script.Parent.StateService)
local AttackService = require(script.Parent.AttackService)

type AttackDirection = CombatTypes.AttackDirection

local VALIDATION = CombatConfig.VALIDATION
local DEBUG = CombatConfig.DEBUG

type RateRecord = {
	windowStart: number,
	count: number,
}

local rateRecords: { [Player]: RateRecord } = {}

local InputHandler = {}

local function reject(player: Player, reason: string)
	if DEBUG.enabled and DEBUG.printValidationFailures then
		warn(`[InputHandler] pedido de {player.Name} recusado: {reason}`)
	end
end

-- Janela fixa: conta os pedidos em cada intervalo de rateLimitWindow segundos.
local function allowRequest(player: Player): boolean
	local now = os.clock()
	local record = rateRecords[player]
	if not record or now - record.windowStart >= VALIDATION.rateLimitWindow then
		rateRecords[player] = { windowStart = now, count = 1 }
		return true
	end
	record.count += 1
	return record.count <= VALIDATION.maxRequestsPerWindow
end

local function getCharacter(player: Player): Model?
	local character = player.Character
	if character and StateService.isRegistered(character) then
		return character
	end
	return nil
end

-- O Roblox sempre passa o Player de verdade como 1º argumento; o resto vem do cliente.
local function onIntent(player: Player, action: unknown, directionArg: unknown, jumpHeldArg: unknown)
	if not allowRequest(player) then
		reject(player, "pedidos demais")
		return
	end
	if not CombatTypes.isCombatAction(action) then
		reject(player, `ação inválida: {tostring(action)}`)
		return
	end
	local character = getCharacter(player)
	if not character then
		reject(player, "sem personagem registrado")
		return
	end

	if action == "M1" then
		if not CombatTypes.isAttackDirection(directionArg) then
			reject(player, `direção inválida: {tostring(directionArg)}`)
			return
		end
		if typeof(jumpHeldArg) ~= "boolean" then
			reject(player, "jumpHeld não é boolean")
			return
		end
		local ok, reason = AttackService.requestAttack(character, directionArg :: AttackDirection, jumpHeldArg)
		if not ok and reason then
			reject(player, reason)
		end
	elseif action == "Follow" then
		local ok, reason = AttackService.requestFollow(character)
		if not ok and reason then
			reject(player, reason)
		end
	end
end

function InputHandler.start()
	CombatRemotes.getIntentEvent().OnServerEvent:Connect(onIntent)
	Players.PlayerRemoving:Connect(function(player: Player)
		rateRecords[player] = nil
	end)
end

return InputHandler
