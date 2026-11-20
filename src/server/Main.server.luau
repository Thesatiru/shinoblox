--!strict
-- Ponto de entrada do servidor: prepara o combate e registra os personagens dos jogadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatRemotes = require(ReplicatedStorage.Shared.Combat.CombatRemotes)
local StateService = require(script.Parent.Combat.StateService)
local TrainingDummy = require(script.Parent.Combat.TrainingDummy)

-- Cria o RemoteEvent já no início, para o cliente não ficar esperando.
CombatRemotes.getIntentEvent()

-- Criar o modelo do boneco espera o Roblox montar o personagem; task.spawn não trava o resto.
task.spawn(TrainingDummy.spawnAll)

local function onCharacterAdded(character: Model)
	-- No respawn, o Humanoid pode ainda não estar dentro do Model quando o evento dispara.
	character:WaitForChild("Humanoid")
	StateService.register(character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Jogadores que entraram antes deste script rodar (acontece no Play Solo do Studio).
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
