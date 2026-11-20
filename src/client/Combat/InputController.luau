--!strict
-- Lê o input do jogador e envia só a INTENÇÃO ao servidor. Nada de dano ou acerto aqui.
--   M1                -> ("M1", direction, jumpHeld)
--   novo aperto de Espaço -> ("Follow"); o servidor ignora se não houver alvo lançado

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.Combat.CombatConfig)
local CombatRemotes = require(ReplicatedStorage.Shared.Combat.CombatRemotes)
local CombatTypes = require(ReplicatedStorage.Shared.Combat.CombatTypes)

type AttackDirection = CombatTypes.AttackDirection

local INPUT = CombatConfig.INPUT
local player = Players.LocalPlayer

local InputController = {}

local function isKeyboardOrMouse(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
end

-- Teclado: tecla de frente segurada. Controle e celular: andando para a frente do personagem.
local function getDirection(inputType: Enum.UserInputType): AttackDirection
	if isKeyboardOrMouse(inputType) then
		return if UserInputService:IsKeyDown(INPUT.forwardKey) then "Forward" else "Neutral"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		-- MoveDirection: direção em que o jogador está mandando andar (vetor unitário, ou zero parado).
		local forwardAmount = humanoid.MoveDirection:Dot(root.CFrame.LookVector)
		if forwardAmount >= INPUT.forwardMoveThreshold then
			return "Forward"
		end
	end
	return "Neutral"
end

function InputController.start()
	local intentEvent = CombatRemotes.getIntentEvent()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == INPUT.attackInput then
			-- gameProcessed = o clique foi em um botão da interface, não no jogo.
			if gameProcessed then
				return
			end
			local jumpHeld = UserInputService:IsKeyDown(INPUT.jumpKey)
			intentEvent:FireServer("M1", getDirection(input.UserInputType), jumpHeld)
		elseif input.KeyCode == INPUT.jumpKey then
			-- O pulo padrão do Roblox também usa o Espaço; aqui só ignoramos quando o jogador digita no chat.
			if UserInputService:GetFocusedTextBox() then
				return
			end
			intentEvent:FireServer("Follow")
		end
	end)
end

return InputController
