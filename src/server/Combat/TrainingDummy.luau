--!strict
-- Bonecos de treino. Usam o mesmo StateService que os jogadores, então recebem golpes pelo mesmo código.
-- Etapa atual: só o modo Passive (fica parado e recebe combos).
-- Mostram o dano total do combo atual e nunca morrem: a vida volta ao máximo depois de um tempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)
local StateService = require(script.Parent.StateService)

type DummyMode = CombatTypes.DummyMode

local DUMMY = CombatConfig.DUMMY
local FOLDER_NAME = "TrainingDummies"
local DUMMY_NAME = "TrainingDummy"
local MODE_ATTRIBUTE = "DummyMode"

-- Aparência do texto sobre a cabeça (só visual, não afeta o combate).
local DISPLAY_SIZE = UDim2.fromOffset(200, 40)
local DISPLAY_OFFSET = Vector3.new(0, 2.5, 0)

local TrainingDummy = {}

local function getFolder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

-- BillboardGui: interface 2D presa a uma peça 3D, sempre virada para a câmera.
local function createDisplay(head: BasePart): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Size = DISPLAY_SIZE
	billboard.StudsOffset = DISPLAY_OFFSET
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = billboard
	return label
end

-- Mede o dano pela queda de vida, sem depender de quem causou (HitService ainda não existe).
local function trackComboDamage(humanoid: Humanoid, label: TextLabel)
	local lastHealth = humanoid.Health
	local comboDamage = 0
	local comboHits = 0
	local hitToken = 0 -- sobe a cada golpe; os temporizadores antigos conferem e desistem

	humanoid.HealthChanged:Connect(function(health: number)
		local damage = lastHealth - health
		lastHealth = health
		if damage <= 0 then
			return -- cura ou reset da vida: não é golpe
		end

		comboDamage += damage
		comboHits += 1
		label.Text = string.format("Combo: %d golpes, %.1f de dano", comboHits, comboDamage)

		hitToken += 1
		local token = hitToken

		task.delay(DUMMY.comboDisplayResetTime, function()
			if token == hitToken then
				comboDamage = 0
				comboHits = 0
				label.Text = ""
			end
		end)

		task.delay(DUMMY.healthResetDelay, function()
			if token == hitToken then
				humanoid.Health = humanoid.MaxHealth
			end
		end)

		-- Nunca deixa a vida chegar a zero. Isso dispara HealthChanged de novo, mas como subida é ignorado.
		if health < DUMMY.minHealth then
			humanoid.Health = DUMMY.minHealth
		end
	end)
end

function TrainingDummy.spawn(cframe: CFrame, mode: DummyMode): Model?
	if mode ~= "Passive" then
		warn(`[TrainingDummy] modo {mode} ainda não implementado; boneco não criado`)
		return nil
	end

	-- Monta um R15 padrão. Só funciona no servidor e espera (yield) até o modelo ficar pronto.
	local dummy = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	dummy.Name = DUMMY_NAME
	dummy:SetAttribute(MODE_ATTRIBUTE, mode)

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local root = dummy:FindFirstChild("HumanoidRootPart")
	local head = dummy:FindFirstChild("Head")
	if not (humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart")) then
		warn("[TrainingDummy] modelo gerado sem Humanoid, HumanoidRootPart ou Head")
		dummy:Destroy()
		return nil
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- esconde nome e barra de vida padrão
	humanoid.BreakJointsOnDeath = false
	-- Vale porque o servidor é dono da física do boneco (ver SetNetworkOwner abaixo).
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	dummy:PivotTo(cframe)
	dummy.Parent = getFolder()

	-- Posse de rede: sem isto, o Roblox pode passar a física do boneco para o jogador mais próximo.
	-- nil = o servidor simula. Precisa ser chamado depois que o boneco está no workspace.
	root:SetNetworkOwner(nil)

	StateService.register(dummy)
	trackComboDamage(humanoid, createDisplay(head))
	return dummy
end

function TrainingDummy.spawnAll()
	for _, spawnInfo in DUMMY.spawns do
		TrainingDummy.spawn(spawnInfo.cframe, spawnInfo.mode)
	end
end

return TrainingDummy
