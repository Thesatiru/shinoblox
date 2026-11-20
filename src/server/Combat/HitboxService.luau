--!strict
-- Detecta quem um golpe atinge, usando uma caixa à frente do atacante (GetPartBoundsInBox).
-- Procura a cada quadro durante a fase de impacto (attack.active) e acerta cada alvo no máximo uma vez.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)

type AttackData = CombatTypes.AttackData

local DEBUG = CombatConfig.DEBUG
local CHARACTER_TAG = CombatTypes.CHARACTER_TAG
local DEBUG_FOLDER_NAME = "DebugHitboxes"

local HitboxService = {}

local debugFolder: Folder? = nil

local function getDebugFolder(): Folder
	local folder = debugFolder
	if folder and folder.Parent then
		return folder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = DEBUG_FOLDER_NAME
	newFolder.Parent = workspace
	debugFolder = newFolder
	return newFolder
end

-- Bloco só visual: não colide, não é encontrado por consultas de física e não dispara Touched.
local function createDebugPart(size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = DEBUG.hitboxColor
	part.Transparency = DEBUG.hitboxTransparency
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = getDebugFolder()
	return part
end

-- Sobe a partir da peça atingida até achar um Model com a tag de personagem de combate.
-- Acessórios (chapéu, cabelo) ficam dentro do personagem, então também levam até ele.
local function getCharacterFromPart(part: BasePart): Model?
	local current: Instance? = part.Parent
	while current do
		if current:IsA("Model") and current:HasTag(CHARACTER_TAG) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Roda a hitbox de um golpe. ESPERA (yield) attack.active segundos e devolve todos os alvos atingidos.
-- onHit é chamado na hora de cada acerto, sem esperar o fim da fase de impacto.
function HitboxService.run(attacker: Model, attack: AttackData, onHit: (target: Model) -> ()): { Model }
	local root = attacker:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return {}
	end

	-- Filtro da consulta: ignora todas as peças do próprio atacante.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }

	local hitTargets: { Model } = {}
	local alreadyHit: { [Model]: boolean } = {}
	local debugPart = if DEBUG.enabled and DEBUG.showHitboxes then createDebugPart(attack.hitboxSize) else nil

	local elapsed = 0
	repeat
		-- A caixa acompanha o atacante, que pode estar andando durante o golpe.
		local boxCFrame = root.CFrame * attack.hitboxOffset
		if debugPart then
			debugPart.CFrame = boxCFrame
		end

		for _, part in workspace:GetPartBoundsInBox(boxCFrame, attack.hitboxSize, params) do
			local target = getCharacterFromPart(part)
			if target and not alreadyHit[target] and isAlive(target) then
				alreadyHit[target] = true
				table.insert(hitTargets, target)
				task.spawn(onHit, target)
			end
		end

		-- Heartbeat dispara uma vez por quadro do servidor; :Wait() devolve o tempo do quadro.
		elapsed += RunService.Heartbeat:Wait()
	until elapsed >= attack.active or root.Parent == nil

	if debugPart then
		task.delay(DEBUG.hitboxLifetime, debugPart.Destroy, debugPart)
	end

	return hitTargets
end

return HitboxService
