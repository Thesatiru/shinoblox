# Contexto do projeto Shinoblox (para IAs)

> Envie este arquivo no início de qualquer conversa com uma IA sobre o projeto.
> Mantenha-o atualizado sempre que uma decisão importante mudar.

## Quem somos

- **Estúdio:** Ratworks, um grupo de amigos criando jogos no Roblox com o objetivo de lançar jogos que fogem das fórmulas saturadas (bandit beater, tower defense).
- **Experiência da equipe:** sabemos programar em outras linguagens, mas somos **iniciantes em Luau e no Roblox**. Ninguém do grupo sabe animar ainda.
- **Idioma:** responda sempre em **português**. Nomes de código (variáveis, funções, arquivos) em **inglês**.

## O jogo

**Shinoblox** (nome provisório): RPG ninja de ação para Roblox, com universo próprio **inspirado** em animes ninja. Nada pode copiar personagens, nomes ou técnicas de animes existentes (ex.: não usar "chakra", "hokage", "rasengan"; criar termos originais).

**Loop principal:** vila → aceita missão → viaja com o time → dungeon com salas (combate + escolha de cartas temporárias) → chefe → recompensa → evolui a árvore de habilidades permanente → nova missão ou PvP.

**Fase atual:** protótipo do **combate corpo a corpo** (Etapa 1), começando **só pelos M1s e suas variações, sem nenhuma habilidade**. Ainda não existem técnicas elementais, energia, cartas, dungeons nem vila. Postura, parry, substituição e dash ficam para as próximas etapas. Não implemente nada disso sem pedirem.

## Design do combate (o que está decidido)

- **Ataque (estilo Anime Battle Arena):** quem acerta primeiro tem o mérito do combo. Combo básico de M1 com **5 golpes** no mesmo botão e **contagem única** (chão e ar somam os mesmos 5): o 1º é a abertura, do 2º ao 4º são golpes normais e o 5º é o finalizador.
  - **Lançador:** Espaço segurado + M1 no **2º, 3º ou 4º golpe** joga o alvo para o alto. Não vale no 1º nem no 5º. Tem tempos próprios, mais longos (é um agarrão que levanta o alvo), e ocupa uma posição da contagem. Se errar, ninguém sobe e o combo continua no chão.
  - **Finalizador no chão (5º golpe):** parado = empurrão; frente = arremesso para longe.
  - A rasteira foi **cortada**; não existe entrada "baixo".
  - O atacante **pode se mover** durante os M1s.
  - **Errar não reinicia o combo:** um M1 no vento avança a contagem. O combo volta ao 1º golpe depois de **~2 s** sem M1.
  - Exemplo: `M1 → M1 → lançador → M1 no ar → finalizador aéreo`.
- **Combo aéreo:** depois do lançador o alvo sobe sozinho. **Seguir é manual e opcional:** um novo aperto de Espaço, olhando para o alvo, leva o atacante até ele. Só quem lançou pode seguir (aliados no futuro), a janela é de **2 s** e a mira é generosa (uns dois personagens, ~8 studs, para cada lado). Não seguir também é válido, para no futuro usar uma habilidade de longe. No ar, atacante e alvo ficam **suspensos** e o combo continua com os M1s que sobraram. Último golpe aéreo: **Espaço segurado = arremesso para longe; Espaço solto antes do último M1 = cravada no chão**.
- **Anti-infinito:** gravidade crescente no ar, dano decrescente ao longo do combo, invulnerabilidade curta ao levantar do chão.
  - O combo da vítima (escala de dano) recomeça quando ela leva um golpe estando livre (fora de atordoado e caído).
  - A vítima lançada fica atordoada até pousar; se o combo aéreo acaba sem finalizador, ela cai no chão (`Knockdown`).
  - Caída, a vítima fica invulnerável durante a queda e um pouco depois de levantar.
  - No ar, cada golpe zera a queda (suspensão); o atacante que seguiu usa a mesma gravidade do alvo e os dois caem juntos.
- **Leitura (estilo Hades):** todo golpe tem preparação, impacto e recuperação visíveis. Nenhum golpe pode ser impossível de reagir.

### Próximas etapas (não implementar agora; a Etapa 1 é só M1)

- **Defesa (postura):** bloquear gasta postura; postura zerada quebra a guarda (atordoa). Parry no tempo certo contra golpes básicos não gasta postura e desgasta a do atacante. Sem defesa infinita.
- **Fuga:** substituição com **3 cargas** que recarregam com o tempo; tira o jogador do meio de um combo. Dash com recarga curta para esquiva comum.
- **Combo em dupla (futuro, só PvE):** após um lançador, um aliado entra num quick time event em dupla.

### Bonecos de treino e pontos em aberto

- **Bonecos de treino:** três modos: passivo (recebe combos), atacando (repete o combo de M1) e defendendo (entra junto com a etapa de postura). São R15 gerados por código, nunca morrem (a vida volta ao máximo depois de um tempo) e mostram o dano total do combo atual.
- **Em aberto:** segurar Espaço no chão faz o personagem pular (padrão do Roblox); ver no protótipo se isso atrapalha o lançador.

Documento completo: Design do combate corpo a corpo (link na seção Links).

## Stack e ambiente

- **Roblox Studio** + **Luau**
- **Rojo** (sincroniza arquivos com o Studio), versão fixada pelo **Rokit** (`rokit.toml`)
- **VS Code** com as extensões Rojo e Luau Language Server
- **Git + GitHub**, quadro de tarefas no **Trello**

### Estrutura de pastas

| Pasta | Vira no Studio | Uso |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | Lógica autoritativa: hitbox, dano, estados, validação |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Input, câmera, efeitos visuais, UI |
| `src/shared` | `ReplicatedStorage.Shared` | Configurações, tipos e módulos usados pelos dois lados |

Exemplo de require: `require(ReplicatedStorage.Shared.Combat.CombatConfig)`. O mapeamento está no `default.project.json`. O Rojo está fixado em 7.7.1; rode `rokit install` e depois `rojo serve`.

### Nomes de arquivo (Rojo)

| Arquivo | Vira no Studio |
|---|---|
| `Name.server.luau` | Script (servidor) |
| `Name.client.luau` | LocalScript (cliente) |
| `Name.luau` | ModuleScript |

## Regras de código

1. **Servidor é a autoridade.** Nunca confie no cliente: dano, acerto, cargas, postura e estados são calculados e validados no servidor. O cliente só envia intenções (ex.: "apertei ataque") e mostra efeitos.
2. **Valide todo RemoteEvent no servidor:** tipos dos argumentos, tempo de recarga, distância e estado atual do jogador.
3. **Use `--!strict`** no topo dos arquivos e tipagem do Luau sempre que possível.
4. **Sem números mágicos:** tempos (preparação, impacto, recuperação), dano, recargas e janelas de parry ficam em tabelas de configuração em `src/shared`, nunca espalhados no código. Os valores ainda serão ajustados em playtests.
5. **Tempo dos golpes independente da animação final.** Usamos animações provisórias; o código não pode depender delas.
6. **APIs modernas:** use `task.wait`, `task.spawn`, `task.delay` (nunca `wait`, `spawn`, `delay`); `workspace:Raycast`, `GetPartBoundsInBox` ou `Shapecast` para hitbox (nunca `Touched` para hitbox de combate).
7. **Convenções de nome:** módulos e tipos em `PascalCase`, variáveis e funções em `camelCase`, constantes em `UPPER_SNAKE_CASE`.
8. **Código só no VS Code.** Nunca sugerir editar no Studio um script que vem do Rojo.

## Núcleo de combate (arquitetura aprovada)

O combate trabalha com **personagens (`Model` com `Humanoid`)**, nunca com `Player`, para que bonecos de treino e inimigos usem o mesmo código. `Player` só aparece onde o RemoteEvent é recebido e validado.

- **Estados do personagem:** `Idle`, `Attacking`, `Blocking`, `Stunned`, `Airborne`, `Knockdown`, publicados como atributo `CombatState` no personagem. O `StateService` ajusta velocidade e pulo a cada troca (`STATE_MOVEMENT` na config); atordoado, no ar ou caído, o personagem fica travado. A vítima lançada fica `Stunned` no ar; `Airborne` é só para quem pode atacar no ar (o atacante que seguiu). Todo personagem registrado recebe a tag `CombatCharacter`, que o cliente usa para achar quem pintar.
- **Hitbox:** módulo que detecta e valida acertos no servidor.
- **Aplicar golpe:** função única `HitService.applyHit(attacker, target, hitData)`. Nesta etapa trata dano, estado e movimento; tem um ponto marcado onde bloqueio, parry e postura entram depois.
- **Intenções do cliente:** `M1` (com direção e se o Espaço está segurado) e `Follow` (seguir o alvo lançado), pelo único RemoteEvent `CombatIntent`, criado pelo servidor em `ReplicatedStorage.Remotes`.

Convenção de nomes dos módulos: `Service` no servidor, `Controller` no cliente, sem sufixo para dados, tipos e utilitários. São ModuleScripts carregados com `require`, não serviços do Roblox.

| Arquivo | Responsabilidade |
|---|---|
| `src/shared/Combat/CombatTypes.luau` | Tipos e validação de valores recebidos do cliente |
| `src/shared/Combat/CombatConfig.luau` | Todos os números do combate |
| `src/shared/Combat/CombatRemotes.luau` | Cria e localiza os RemoteEvents |
| `src/server/Main.server.luau` | Ponto de entrada do servidor |
| `src/server/Combat/StateService.luau` | Máquina de estados por personagem |
| `src/server/Combat/HitboxService.luau` | `GetPartBoundsInBox` → personagens atingidos |
| `src/server/Combat/MotionService.luau` | Empurrão, arremesso, lançamento, seguir, cravada, gravidade crescente |
| `src/server/Combat/ComboTracker.luau` | Golpes no combo e tempo no ar de cada vítima |
| `src/server/Combat/HitService.luau` | `applyHit` |
| `src/server/Combat/AttackService.luau` | Escolhe o golpe e agenda preparação, impacto e recuperação |
| `src/server/Combat/InputHandler.luau` | Único ponto que escuta e valida o RemoteEvent |
| `src/server/Combat/TrainingDummy.luau` | Bonecos de treino |
| `src/client/Main.client.luau` | Ponto de entrada do cliente |
| `src/client/Combat/InputController.luau` | Lê o input e envia as intenções |
| `src/client/Combat/DebugController.luau` | Cor do personagem conforme o estado |

**Status:** prontos: `CombatTypes`, `CombatConfig`, `CombatRemotes`, `StateService`, `Main.server`, `DebugController`, `Main.client`, `HitboxService`, `TrainingDummy` (só modo passivo), `ComboTracker`, `MotionService`, `HitService`. Os outros arquivos existem só com `--!strict` e ainda não foram escritos. Ordem de implementação: config e remotes → estados e debug → hitbox e boneco passivo → movimento, combo tracker e `applyHit` → ataque com os M1s → lançador e seguir → combo aéreo e finalizadores → anti-infinito e boneco atacando.

Enquanto não há animações, o debug mostra a hitbox como bloco transparente e pinta o personagem conforme o estado. No futuro, as animações terão Animation Events no quadro do impacto, só para conferir a sincronia.

## Fluxo de trabalho

- **Uma branch por card do Trello**, com o nome do card (ex.: `e1-dash`). Nada direto na `main`.
- **Commits:** `tipo: descrição` (ex.: `feat: combo básico de 5 golpes`, `fix: hitbox do soco`, `chore: atualiza rokit`).
- A IA não faz commit nem push sem pedirem.
- Cada programador testa numa **cópia local** do place (`teste.rbxl`, ignorado pelo Git).

## Como a IA deve responder

- Explique os conceitos do Roblox quando aparecerem (servidor x cliente, serviços, eventos), porque a equipe está aprendendo.
- Sempre diga **o caminho do arquivo** (ex.: `src/server/Combat/Hitbox.luau`) e se é Script, LocalScript ou ModuleScript.
- Entregue código **completo e funcional**, com comentários curtos nas partes não óbvias.
- Diga como **testar** o que foi feito no Studio.
- Se uma decisão de design ainda não estiver neste arquivo, **pergunte** em vez de inventar.

## Arquivos de contexto

- `CLAUDE.md`, na raiz do repositório, é a versão lida pelo Claude Code. Os dois arquivos devem dizer a mesma coisa; ao mudar uma decisão, atualize ambos.

## Links

- Repositório: https://github.com/Thesatiru/shinoblox
- Design do combate: https://docs.google.com/document/d/1ylGZkkyNhz4GtF3LLCSIRGOg4TjeGZ837dM1sJ0tw_M/edit
- Ideia do jogo: https://docs.google.com/document/d/16kGKr9Xwq1GsZZgRJuEwjclbFIaJAVmB51I3yU4SwgU/edit
- Tutorial do ambiente: https://docs.google.com/document/d/1hM5Fe7SiBxTcuhs0VnIC2MiUoLMlVudk0tF4GbG0SCA/edit
