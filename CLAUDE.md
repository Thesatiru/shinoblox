# Shinoblox

RPG ninja de ação para Roblox, do estúdio Ratworks (grupo de amigos). Universo próprio, **inspirado** em animes ninja: nunca use nomes, personagens ou técnicas de animes existentes (nada de "chakra", "hokage", "rasengan"); crie termos originais.

Loop planejado: vila → missão → dungeon em time com cartas temporárias → chefe → árvore de habilidades permanente → nova missão ou PvP.

**Fase atual: Etapa 1, protótipo do combate corpo a corpo, sem nenhuma habilidade.** Só M1s e suas variações. Não implemente técnicas elementais, energia, cartas, dungeons, vila, postura, parry, substituição ou dash sem que peçam.

## Como responder

- Sempre em **português**. Nomes de código (variáveis, funções, arquivos) em **inglês**.
- A equipe programa em outras linguagens, mas é **iniciante em Luau e no Roblox**: explique os conceitos do Roblox quando aparecerem (servidor x cliente, serviços, eventos, replicação, posse de rede), passo a passo e aplicados a este projeto.
- Diga o caminho de cada arquivo e o tipo (Script, LocalScript ou ModuleScript).
- Entregue código completo e funcional, com comentários curtos só nas partes não óbvias.
- Diga como testar no Studio o que foi feito.
- Se uma decisão de design não estiver neste arquivo nem no documento de design, **pergunte em vez de inventar**.
- Antes de criar um módulo novo ou mudar a arquitetura, proponha e espere aprovação. Um módulo por vez.

## Stack e ambiente

- Roblox Studio + Luau
- Rojo, com a versão fixada pelo Rokit (`rokit.toml`)
- VS Code com as extensões Rojo e Luau Language Server
- Git + GitHub, tarefas no Trello

Comandos:

```bash
rokit install   # instala as ferramentas nas versões do rokit.toml
rojo serve      # sincroniza src/ com o Studio (conectar pelo plugin do Rojo)
```

Você não consegue abrir o Roblox Studio nem rodar o jogo. Nunca diga que algo foi testado: descreva o teste para a pessoa executar no Studio e espere o resultado.

## Estrutura

| Pasta | Vira no Studio | Uso |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | Lógica autoritativa: hitbox, dano, estados, validação |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Input, câmera, efeitos visuais, UI |
| `src/shared` | `ReplicatedStorage.Shared` | Configurações, tipos e módulos usados pelos dois lados |

Exemplo de require: `require(ReplicatedStorage.Shared.Combat.CombatConfig)`.

| Arquivo | Vira no Studio |
|---|---|
| `Name.server.luau` | Script |
| `Name.client.luau` | LocalScript |
| `Name.luau` | ModuleScript |

Modelos (katana e bainha) ficam em `ReplicatedStorage/Assets`, criados no Studio. O mapeamento exato está no arquivo de projeto do Rojo (`*.project.json`); leia-o antes de assumir caminhos.

## Regras de código

1. **Servidor é a autoridade.** Dano, acerto, cargas, postura e estados são calculados no servidor. O cliente só envia intenções ("apertei M1" + direção) e mostra efeitos.
2. **Valide todo RemoteEvent no servidor:** tipos dos argumentos, tempo de recarga, distância e estado atual.
3. **`--!strict`** no topo de todo arquivo, com tipagem do Luau.
4. **Sem números mágicos.** Tempos (preparação, impacto, recuperação), dano, alcance, atordoamento e recargas ficam em tabelas de configuração em `src/shared`.
5. **O tempo dos golpes não depende da animação.** As animações são provisórias; o servidor agenda as fases pela configuração.
6. **APIs modernas:** `task.wait`, `task.spawn`, `task.delay` (nunca `wait`, `spawn`, `delay`). Hitbox com `GetPartBoundsInBox`, `Shapecast` ou `workspace:Raycast` (nunca `Touched`).
7. **Nomes:** módulos e tipos em `PascalCase`, variáveis e funções em `camelCase`, constantes em `UPPER_SNAKE_CASE`.
8. **Código só no VS Code.** Nunca sugira editar no Studio um script que vem do Rojo.

## Design do combate (decidido)

- **Ataque (estilo Anime Battle Arena):** quem acerta primeiro tem o mérito do combo. Combo básico de M1 com **5 golpes** no mesmo botão: o 1º é a abertura, 2º a 4º são normais e o 5º é o finalizador.
  - **Lançador:** Espaço segurado + M1 no **2º, 3º ou 4º golpe** joga o alvo para o alto e leva o combo para o ar. Não vale no 1º (abertura) nem no 5º (finalizador). O lançador tem tempos próprios e mais longos na configuração (é um agarrão que levanta/arremessa o alvo).
  - **Lançador que erra:** ninguém sobe, a contagem avança e o atacante continua no chão até o finalizador normal.
  - **Contagem única:** chão e ar somam os mesmos 5 golpes; o lançador conta como um deles. Exemplo: `M1 + M1 + lançador + M1 no ar + finalizador aéreo`.
  - **Finalizador no chão (5º golpe):** parado = empurrão; frente = arremesso para longe.
  - A rasteira foi **cortada** e não existe entrada "baixo".
- **Movimento:** o atacante pode se mover durante os M1s (o multiplicador de velocidade fica na configuração).
- **Errar um golpe não reinicia o combo:** um M1 no vento avança para o golpe seguinte do mesmo jeito. O combo volta ao primeiro golpe depois de cerca de 2 s sem apertar M1 (valor inicial, na configuração).
- **Combo aéreo (estilo Anime Battle Arena):** depois do lançador, o alvo sobe sozinho. **Seguir é uma ação manual:** apertar Espaço (um novo aperto, não o que já estava segurado no lançador) olhando para o alvo lançado leva o atacante até ele. Seguir é opcional, para dar margem a combos: o jogador pode só lançar e, no futuro, usar uma habilidade de longe. Regras de seguir: **só quem lançou** pode seguir (abrir para aliados fica para o futuro); a janela é de **2 s** depois do lançador; a mira é **generosa**, aceitando o alvo a até uns dois personagens de distância para cada lado de onde o atacante olha, para ajudar quem não é bom de mira. Todos esses valores são iniciais e ficam na configuração. Quem segue continua no ar com os M1s que sobraram da contagem (no futuro, também com habilidades); atacante e alvo ficam suspensos. O último golpe depende do Espaço: **segurado = arremessa o alvo para longe**; **solto antes do último M1 = cravada**, que afunda o alvo no chão.
- **Bonecos de treino:** três modos: passivo (recebe combos), atacando (repete o combo de M1) e defendendo. O modo defendendo só entra junto com a etapa de postura.
- **Anti-infinito:** gravidade crescente no ar, dano decrescente ao longo do combo, invulnerabilidade curta ao levantar do chão.
- **Leitura (estilo Hades):** todo golpe tem preparação, impacto e recuperação visíveis. Nenhum golpe pode ser impossível de reagir.

Etapas seguintes (não agora): postura com parry e guarda quebrada, substituição com 3 cargas, dash, katana, combo em dupla no PvE.

Documento completo: https://docs.google.com/document/d/1ylGZkkyNhz4GtF3LLCSIRGOg4TjeGZ837dM1sJ0tw_M/edit

## Arquitetura do núcleo de combate

> Status: **arquitetura e nomes aprovados.** Prontos: `CombatTypes`, `CombatConfig`, `CombatRemotes`, `StateService`, `Main.server`, `DebugController`, `Main.client`, `HitboxService`, `TrainingDummy` (só modo passivo), `ComboTracker`, `MotionService`, `HitService`, `AttackService`, `InputHandler`, `InputController`. Os demais arquivos existem só com `--!strict` e ainda não foram escritos.

Convenção de nomes dos módulos: sufixo `Service` para módulos do servidor que existem uma vez só e guardam estado; `Controller` para o equivalente no cliente; sem sufixo para dados, tipos e utilitários. São ModuleScripts comuns carregados com `require`, não serviços do Roblox (`game:GetService`).

Princípio: o combate trabalha com **personagens (`Model` com `Humanoid`)**, nunca com `Player`. O boneco de treino e os futuros inimigos usam o mesmo código de ataque que o jogador. `Player` só aparece onde o RemoteEvent é recebido e validado.

Estados do personagem: `Idle`, `Attacking`, `Blocking`, `Stunned`, `Airborne`, `Knockdown`. O estado é publicado como atributo `CombatState` no personagem.

```
src/shared/Combat/
  CombatTypes.luau     tipos: CharacterState, AttackDirection (Neutral, Forward), AttackData, HitData
  CombatConfig.luau    todos os números de golpes, anti-infinito, validação e debug
  CombatRemotes.luau   cria (servidor) e localiza (cliente) os RemoteEvents
src/server/
  Main.server.luau     ponto de entrada do servidor
  Combat/
    StateService.luau    máquina de estados por personagem
    HitboxService.luau   GetPartBoundsInBox -> personagens atingidos, sem repetição
    MotionService.luau   empurrão, arremesso, lançamento, cravada, gravidade crescente
    ComboTracker.luau    por vítima: golpes no combo e tempo no ar -> escala de dano e gravidade
    HitService.luau      applyHit(attacker, target, hitData): a função única de aplicar golpe
    AttackService.luau   requestAttack(character, direction, jumpHeld): escolhe o golpe e agenda as fases
    InputHandler.luau    único lugar que escuta o RemoteEvent e valida
    TrainingDummy.luau   bonecos de treino com modo (Passive, Attacking, Blocking); mostram o dano
src/client/
  Main.client.luau     ponto de entrada do cliente
  Combat/
    InputController.luau  lê M1 + direção + Espaço segurado e envia a intenção
    DebugController.luau  pinta o personagem conforme CombatState
```

Além do M1, o cliente envia a intenção `("Follow")` ao apertar Espaço; o servidor valida (alvo lançado há pouco, distância, direção em que o atacante olha) e move o atacante pelo `MotionService`.

Fluxo de um M1: cliente envia `("M1", direction, jumpHeld)` → `InputHandler` valida → `AttackService` põe o atacante em `Attacking`, espera a preparação e pede a hitbox → `HitService.applyHit` em cada alvo (dano, estado, movimento) → recuperação → volta a `Idle` ou `Airborne`.

Detalhes que já estão combinados:

- Um único RemoteEvent, `CombatIntent`, criado pelo servidor em `ReplicatedStorage.Remotes` (fora da pasta `Shared` do Rojo). A ação vai no 1º argumento: `("M1", direction, jumpHeld)` ou `("Follow")`.
- O `StateService` também ajusta `WalkSpeed` e pulo a cada troca de estado, pela tabela `STATE_MOVEMENT` da config. `Stunned`, `Airborne` e `Knockdown` travam o personagem (sem andar e sem pular).
- A vítima lançada fica `Stunned` no ar; `Airborne` é só para quem pode atacar no ar (o atacante que seguiu).
- Todo personagem registrado no `StateService` recebe a tag `CombatCharacter` (CollectionService); o cliente usa a tag para achar quem pintar. Os nomes da tag e do atributo ficam no `CombatTypes`.
- Hitbox: procura alvos a cada quadro durante a fase `active` do golpe; cada alvo é atingido no máximo uma vez por golpe.
- Boneco de treino: R15 gerado por código (`CreateHumanoidModelFromDescription`), física do servidor (`SetNetworkOwner(nil)`), nunca morre (vida volta ao máximo depois de um tempo) e mostra o dano total do combo atual. Posições e tempos em `CombatConfig.DUMMY`.
- Combo da vítima (escala de dano): recomeça quando ela leva um golpe estando livre, ou seja, fora de `Stunned` e `Knockdown`.
- Vítima lançada fica `Stunned` até pousar. Se o combo aéreo acaba sem finalizador, ela cai em `Knockdown`.
- `Knockdown` (depois de empurrão, arremesso, cravada ou queda do combo aéreo): a vítima fica invulnerável **a M1** durante a queda e por `getUpInvulnerability` depois de levantar. Habilidades (etapas futuras) ignoram essa invulnerabilidade, para servir de extensor de combo. Cada `HitData` informa `source` (`"M1"` ou `"Skill"`).
- No ar, o servidor controla a velocidade vertical com o `LinearVelocity`: a queda acelera conforme a gravidade crescente, e cada golpe aéreo zera a queda (suspensão). O atacante que seguiu usa a mesma gravidade do alvo, então os dois caem juntos.
- Buffer de input: um M1 apertado nos últimos `COMBO.inputBufferWindow` s da recuperação fica guardado e sai assim que o golpe atual termina.
- Direção "Forward" do finalizador: no teclado, tecla W segurada; no controle e no celular, andando para a frente do personagem (`Humanoid.MoveDirection`). Por enquanto só o clique do mouse dispara o M1; os botões de controle e celular ainda não foram definidos.
- O personagem **não** vira para a câmera ao atacar: o golpe sai para onde ele já está virado.
- Golpe interrompido na preparação não conta na contagem. Seguir só é aceito com o atacante em `Idle` (depois da recuperação do lançador) e uma vez por lançamento.
- Se o personagem está no ar é decidido pelo servidor, pelo estado; o cliente não informa.
- `applyHit` terá um ponto único e marcado onde bloqueio, parry e postura entram depois.
- Movimento forçado da vítima: o servidor insere um `LinearVelocity` no personagem (a física do personagem é simulada pelo cliente dono).
- Debug enquanto não há animações: hitbox como bloco transparente e cor do personagem por estado, atrás de uma flag na configuração.
- No futuro, as animações terão Animation Events no quadro do impacto para conferir a sincronia e serão publicadas na comunidade The Ratworks; o código usará os IDs.

Ordem de implementação: config e remotes → estados e debug → hitbox e boneco passivo → movimento, combo tracker e `applyHit` → ataque com os M1s → lançador e seguir → combo aéreo e finalizadores → anti-infinito e boneco atacando.

## Decisões em aberto

Pergunte antes de assumir qualquer uma destas:

- Segurar Espaço no chão faz o personagem pular (padrão do Roblox). Isso atrapalha o lançador? Decidir no protótipo.

## Git

- Uma branch por card do Trello, com o nome do card (ex.: `e1-dash`). Nada direto na `main`.
- Commits no formato `tipo: descrição` (ex.: `feat: combo básico de 5 golpes`, `fix: hitbox do soco`, `chore: atualiza rokit`).
- `teste.rbxl` é a cópia local de teste de cada programador e é ignorado pelo Git.
- Não faça commit nem push sem pedirem.

## Manter este arquivo

Quando uma decisão for tomada, mova-a de "Decisões em aberto" para a seção certa. Quando a arquitetura for aprovada ou um módulo for criado, atualize o status. O `CONTEXTO_IA.md` é a versão para outras IAs; mantenha os dois coerentes.