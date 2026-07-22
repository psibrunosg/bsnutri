# Plano complementar de desenvolvimento do BSNutri

Atualizado em 21/07/2026 após sincronização com `origin/main`. Este documento organiza a evolução posterior ao MVP. A fonte oficial para o fechamento já concluído é `docs/MVP_INDEX.md`, acompanhada por `docs/MVP_AUDITORIA_STATUS.md`, `docs/MVP_CHECKLIST_FINAL.md` e `docs/MVP_PILOTO_REPRODUCAO_FINAL.md`. Funcionalidade futura documentada, mas sem código e verificação, continua sendo considerada pendente.

## 1. Objetivo da próxima evolução

Preservar o MVP já fechado e ampliar o produto para uso clínico progressivo por Bruno, pelo nutricionista validador e pelos pacientes do piloto:

1. cadastrar paciente e avaliação;
2. calcular, montar, revisar e publicar um plano;
3. permitir consulta móvel, substituições e lista de compras;
4. registrar adesão e acompanhar alertas;
5. solicitar e administrar consultas;
6. provar isolamento entre clínicas, precisão dos cálculos, recuperação de acesso e rastreabilidade.

## 2. Estado atual comprovado

### Operacional no código

- React, TypeScript, Vite, Supabase e publicação pelo GitHub Pages.
- E-mail e senha, cadastro, recuperação de senha e criação inicial de clínica.
- Organizações, membros e papéis básicos com RLS multi-tenant.
- Cadastro e busca de pacientes, avaliações e antropometria básica.
- Catálogo próprio de alimentos e nutrientes principais.
- Motor nutricional determinístico por gramas, refeição e dia.
- Editor de planos, múltiplos dias, metas e reabertura de rascunhos.
- Revisão e publicação por RPC, snapshots e versão publicada imutável.
- Portal do paciente para leitura do plano vigente.
- Agenda básica com solicitação, aprovação, cancelamento e conflitos.
- Check-ins, alertas determinísticos e painel profissional.
- Substituições vinculadas ao plano e pedidos de troca.
- Lista de compras básica derivada da versão vigente.

### Evidência atual

- O MVP foi fechado e reproduzido conforme `docs/MVP_AUDITORIA_STATUS.md`.
- Os fluxos profissional, paciente e recepção foram provados no deploy publicado.
- As migrations posteriores de 14 a 17/07 estão presentes no repositório após a sincronização com `origin/main`.
- O commit funcional mais recente antes deste roadmap é `1767b3e`.

### Parcial ou ainda frágil

- Substituições não implementam toda a especificação: escolha por ocorrência, equivalência nutricional, tolerâncias, alergênicos, solicitação textual fora das opções e nova versão a partir da aprovação.
- Lista de compras cobre apenas períodos fixos e gramas. Não cobre datas personalizadas, pessoas da residência, receitas, unidades incompatíveis, exportação, histórico ou compartilhamento seguro.
- Agenda não cobre lista de espera, encaixes, lembretes ou integração com Google Agenda.
- Check-ins não possuem configuração por paciente, escolhas de substituição integradas ou todas as regras de alerta previstas.
- Recuperação de senha existe no frontend, mas o envio real e os redirects autorizados ainda precisam de teste sintético.
- O motor tem somente oito testes frontend no total e ainda não recebeu validação clínica ampla.
- Testes SQL existem, mas não há prova recente de execução completa porque o ambiente local depende de Docker.
- O frontend está concentrado em componentes grandes, com consultas Supabase embutidas e pouca tipagem gerada do banco.

## 3. Gate antes de novas funcionalidades

O desvio de migrations observado antes da sincronização foi resolvido pelos 32 commits existentes em `origin/main`. Antes de novo DDL, confirmar novamente `supabase migration list --linked`, executar o schema do zero e manter os testes SQL verdes. Isso é um gate preventivo, não um bloqueador atualmente aberto.

## 4. Decisões arquiteturais mantidas

- Supabase RLS é a fronteira real de segurança. Ocultar controles no React não é autorização.
- Toda entidade clínica possui `organization_id` e vínculos compostos quando necessário.
- Plano publicado e seus snapshots são imutáveis; mudanças geram nova versão.
- Cálculos clínicos são determinísticos e separados de sugestões de IA.
- IA nunca publica sem revisão profissional explícita.
- Recepção não acessa plano, nutrientes, adesão, sintomas ou solicitações clínicas.
- Dados reais não entram em fixtures, screenshots, logs, commits ou testes.
- GitHub Pages permanece apenas para o piloto; deve ser reavaliado antes de operação comercial com dados reais.

## 5. Fases e tarefas detalhadas

### Fase 0: reconciliar e estabilizar

#### Tarefa 0.1: confirmar histórico reconciliado

**Descrição:** confirmar que todas as migrations remotas recuperadas entre 14 e 17/07 permanecem versionadas e reproduzíveis.

**Critérios de aceite:**
- [ ] Cada versão remota possui arquivo local correspondente.
- [ ] Nenhuma migration aplicada foi reescrita ou reaplicada.
- [ ] `supabase migration list --linked` não mostra versões somente remotas.

**Verificação:** comparar migration list, schema diff e histórico do GitHub. **Dependências:** nenhuma. **Escopo:** M.

#### Tarefa 0.2: auditar schema, RLS e funções reais

**Descrição:** comparar o schema remoto com as migrations, gerar tipos TypeScript e revisar funções privilegiadas, grants, policies e índices.

**Critérios de aceite:**
- [ ] Não existe tabela clínica sem RLS ou acesso cruzado entre organizações.
- [ ] Funções privilegiadas usam `search_path` seguro e validam o ator.
- [ ] Advisors de segurança e desempenho estão sem alertas bloqueadores.

**Verificação:** advisors, consultas de catálogo e testes RLS. **Dependências:** 0.1. **Escopo:** M.

#### Tarefa 0.3: criar ambiente de testes SQL reproduzível

**Descrição:** instalar/usar Docker ou configurar CI para executar `supabase db reset` e `supabase test db` sem depender da máquina principal.

**Critérios de aceite:**
- [ ] Todas as migrations sobem do zero.
- [ ] Todas as suites pgTAP executam em CI.
- [ ] Falha de RLS bloqueia o deploy.

**Verificação:** execução limpa em CI e local alternativo. **Dependências:** 0.1. **Escopo:** M.

#### Checkpoint 0

- [ ] Banco remoto e repositório reconciliados.
- [ ] Lint, testes, build, pgTAP e advisors aprovados.
- [ ] Nenhum dado real usado na auditoria.

### Fase 1: concluir o núcleo nutricional

#### Tarefa 1.1: ampliar motor e casos de referência

Implementar micronutrientes escolhidos, dados ausentes diferentes de zero, arredondamento final, estados de preparo e casos clínicos de referência revisados pelo nutricionista.

**Aceite:** resultados reproduzíveis; ausência de dado sinalizada; bateria de casos assinada pelo validador. **Verificação:** testes unitários parametrizados e planilha de referência. **Dependências:** checkpoint 0. **Escopo:** M.

#### Tarefa 1.2: equações antropométricas e energéticas

Adicionar equações selecionáveis, memória do método, entradas obrigatórias, faixas de validade e explicação do resultado sem escolher silenciosamente pelo profissional.

**Aceite:** fórmula e parâmetros persistidos; aviso fora da população de validade; recálculo histórico reproduzível. **Verificação:** casos manuais publicados. **Dependências:** 1.1. **Escopo:** M.

#### Tarefa 1.3: medidas caseiras canônicas

Criar catálogo fechado de medidas e fatores explícitos por alimento/preparo, sem permitir conversão inventada quando o fator não existir.

**Aceite:** g, ml, unidade e porção preservam origem; incompatíveis não são somados; conversão tem fonte e versão. **Verificação:** testes de conversão. **Dependências:** 1.1. **Escopo:** M.

#### Tarefa 1.4: receitas versionadas

Criar receita, ingredientes, rendimento, peso final, número de porções e cálculo por porção; congelar snapshot quando usada em plano publicado.

**Aceite:** soma de ingredientes confere; rendimento zero é rejeitado; mudança futura não altera plano antigo. **Verificação:** testes SQL e unitários com três receitas de referência. **Dependências:** 1.1 e 1.3. **Escopo:** M.

#### Tarefa 1.5: fonte nutricional brasileira

Validar juridicamente licenças e atribuição de TACO/TBCA e definir estratégia USDA/Open Food Facts antes de importar dados.

**Aceite:** licença documentada; origem e versão visíveis; importador idempotente e sem segredo no frontend. **Verificação:** revisão documental e importação sintética. **Dependências:** checkpoint 0. **Escopo:** M.

#### Checkpoint 1

- [ ] Nutricionista validador aprovou casos de cálculo.
- [ ] Receitas e medidas integram editor e snapshots.
- [ ] Catálogo exibe fonte, versão e lacunas.

### Fase 2: editor profissional completo

#### Tarefa 2.1: modelos e cópias seguras

Adicionar modelos independentes, importação como cópia, duplicação anonimizada de outro paciente e cópia de dia/refeição.

**Aceite:** modelo não muda após edição do paciente; dados clínicos não são copiados; origem da cópia é auditável. **Verificação:** testes de cópia e RLS. **Dependências:** checkpoint 1. **Escopo:** M.

#### Tarefa 2.2: edição em massa e periodização

Implementar treino, descanso, plantão, fim de semana, datas de vigência, sequência futura e operações em múltiplos itens.

**Aceite:** calendário resolve um único dia vigente; operações permitem desfazer antes de salvar; publicação valida lacunas. **Verificação:** testes de calendário e QA móvel. **Dependências:** 2.1. **Escopo:** M.

#### Tarefa 2.3: histórico, comparação e restauração

Permitir comparar versões, visualizar alterações, restaurar uma versão anterior como nova versão e consultar versões anteriores conforme configuração.

**Aceite:** nenhuma versão antiga é sobrescrita; restauração cria novo número; acesso do paciente respeita liberação. **Verificação:** pgTAP e fluxo E2E. **Dependências:** 2.1. **Escopo:** M.

#### Tarefa 2.4: substituições completas

Adicionar equivalência visível, tolerâncias configuradas, checagem de restrições, escolha por ocorrência e solicitação textual fora das opções.

**Aceite:** escolha não altera prescrição; aprovação que muda plano exige nova versão; alergia/restrição gera bloqueio ou justificativa auditável. **Verificação:** matriz definida em `docs/substitutions-shopping-list-rules.md`. **Dependências:** 1.1 e 2.3. **Escopo:** M.

#### Checkpoint 2

- [ ] Profissional cria um plano realista completo sem SQL manual.
- [ ] Publicação, cópia, restauração e substituição preservam histórico.
- [ ] Fluxo principal funciona em computador, tablet e celular.

### Fase 3: experiência completa do paciente

#### Tarefa 3.1: preferências e configurações por paciente

Permitir preferências, horários, dificuldades, restrições, ocultação de calorias/peso/evolução e ativação do diário.

**Aceite:** configuração pertence ao vínculo; portal aplica ocultação no banco/DTO, não apenas CSS; alterações são auditáveis. **Dependências:** checkpoint 2. **Escopo:** M.

#### Tarefa 3.2: responsáveis e dependentes

Concluir convite, consentimento, troca de dependente, permissões de leitura/interação e revogação.

**Aceite:** responsável acessa somente dependentes ativos; paciente sem vínculo permanece isolado; recepção não ganha conteúdo clínico. **Verificação:** testes com dois responsáveis e duas organizações. **Dependências:** 0.2. **Escopo:** M.

#### Tarefa 3.3: lista de compras completa

Adicionar intervalo personalizado, número de pessoas, ingredientes de receitas, unidades canônicas, origem por refeição, impressão/exportação e histórico reprodutível.

**Aceite:** resultados determinísticos; unidades incompatíveis separadas; nenhum dado clínico em exportação compartilhável. **Verificação:** casos de 1, 7 e 31 dias e matriz de casos limítrofes. **Dependências:** 1.3, 1.4 e 2.4. **Escopo:** M.

#### Tarefa 3.4: PDF e impressão do plano

Gerar PDF versionado com logo, cores, assinatura, dados da clínica, opções configuradas e layout acessível.

**Aceite:** PDF corresponde ao snapshot publicado; não inclui campos ocultos; impressão móvel/desktop verificada. **Dependências:** 2.3 e identidade visual. **Escopo:** M.

#### Tarefa 3.5: tutorial, feedback e estados vazios

Adicionar onboarding sem treinamento, ajuda contextual, botão permanente de feedback e mensagens compreensíveis para carregamento/erro/offline.

**Aceite:** três pacientes sintéticos completam tarefas críticas sem instrução verbal; feedback registra contexto sem PHI. **Dependências:** 3.1. **Escopo:** S.

#### Checkpoint 3

- [ ] Paciente conclui plano, troca, check-in e lista pelo celular.
- [ ] Responsável alterna dependentes com isolamento comprovado.
- [ ] PDF e impressão conferem com o plano publicado.

### Fase 4: acompanhamento e agenda

#### Tarefa 4.1: adesão e alertas configuráveis

Vincular escolhas de substituição ao check-in, permitir regras por paciente e cobrir baixa ingestão, sintomas, fome intensa e perda rápida de peso.

**Aceite:** regra, dados de origem e estado do alerta são auditáveis; recepção não lê alertas; falso positivo pode ser encerrado com motivo. **Dependências:** 3.1 e 2.4. **Escopo:** M.

#### Tarefa 4.2: diário, medidas e exames

Permitir peso, medidas e exames com arquivos privados e links temporários; fotos corporais apenas para profissional.

**Aceite:** Storage RLS testado; links expiram; paciente não vê comparação de fotos restrita. **Dependências:** 0.2. **Escopo:** M.

#### Tarefa 4.3: agenda completa

Adicionar salas configuráveis, lista de espera, encaixe após cancelamento, recorrência, lembretes internos e estados concluído/não compareceu.

**Aceite:** conflitos bloqueados no banco; cancelamento preserva auditoria; lista de espera não confirma sem ação explícita. **Dependências:** checkpoint 0. **Escopo:** M.

#### Tarefa 4.4: Google Agenda e teleconsulta

Implementar OAuth no backend, sincronização idempotente, revogação e link externo de teleconsulta.

**Aceite:** tokens nunca vão ao frontend/log; duplicação e conflito tratados; desconexão revoga integração. **Dependências:** 4.3. **Escopo:** M.

#### Tarefa 4.5: mensagens e lembretes

Criar mensagens durante o acompanhamento, horário de atendimento e lembretes internos. Áudio, imagens, documentos, e-mail e WhatsApp entram em incrementos separados.

**Aceite:** texto isolado por vínculo; anexos privados; paciente vê prazo de resposta; notificações não expõem dados sensíveis. **Dependências:** 0.2 e 4.2. **Escopo:** M.

#### Checkpoint 4

- [ ] Agenda, alertas e mensagens funcionam de ponta a ponta.
- [ ] Storage, Realtime/OAuth e notificações foram revisados em segurança.

### Fase 5: segurança, LGPD e operação

#### Tarefa 5.1: MFA e sessões

Tornar MFA obrigatório para equipe, opcional para pacientes, listar dispositivos/sessões e permitir revogação.

**Aceite:** ações clínicas exigem nível adequado; recuperação não contorna MFA; sessão revogada perde acesso. **Dependências:** checkpoint 0. **Escopo:** M.

#### Tarefa 5.2: recuperação de conta e e-mail

Validar URLs autorizadas do Pages, templates, expiração, rate limits e entrega com contas sintéticas.

**Aceite:** fluxo completo funciona em produção; link usado/expirado falha com mensagem segura; nenhum segredo aparece no cliente. **Dependências:** 0.2. **Escopo:** S.

#### Tarefa 5.3: auditoria completa

Cobrir leitura, criação, alteração, publicação, exportação, exclusão, decisão de alerta e acesso a arquivo.

**Aceite:** evento possui ator, organização, entidade, horário e metadados mínimos sem conteúdo sensível desnecessário; logs não são alteráveis pela equipe clínica. **Dependências:** checkpoint 4. **Escopo:** M.

#### Tarefa 5.4: direitos do titular e retenção

Implementar exportação, pedido de exclusão, anonimização e política de retenção validada juridicamente.

**Aceite:** fluxo auditável; dependências legais registradas; exclusão não quebra registros que precisam ser preservados. **Dependências:** 5.3. **Escopo:** M.

#### Tarefa 5.5: backup e restauração

Definir backup independente compatível com o plano usado e executar teste periódico de restauração em ambiente isolado.

**Aceite:** RPO/RTO documentados; restauração testada; cópias criptografadas e acesso mínimo. **Dependências:** 0.1. **Escopo:** M.

#### Checkpoint 5

- [ ] MFA, recuperação, auditoria e direitos LGPD aprovados.
- [ ] Restauração testada com evidência.
- [ ] Revisão jurídica/ética das regras de estudante e supervisor concluída.

### Fase 6: qualidade do piloto e lançamento

#### Tarefa 6.1: testes E2E autenticados

Cobrir profissional, estudante, recepção, paciente, responsável, usuário suspenso e duas organizações com dados sintéticos.

**Aceite:** cinco tarefas críticas automatizadas; tentativas negativas de RLS incluídas; screenshots sem dados reais. **Dependências:** checkpoints 3 a 5. **Escopo:** M.

#### Tarefa 6.2: acessibilidade e responsividade

Auditar teclado, leitor de tela, contraste, zoom, mensagens, 320/375 px, tablet e desktop, claro e escuro.

**Aceite:** bloqueadores WCAG 2.2 A/AA corrigidos; alvos de toque adequados; nenhuma rolagem horizontal acidental. **Dependências:** checkpoint 4. **Escopo:** M.

#### Tarefa 6.3: observabilidade e feedback do piloto

Registrar erros técnicos, duração das tarefas e feedback sem gravar dados clínicos; criar painel de triagem.

**Aceite:** erros acionáveis com correlação; PHI redigida; métricas das cinco tarefas disponíveis. **Dependências:** 3.5 e 5.3. **Escopo:** M.

#### Tarefa 6.4: ensaio com quatro participantes sintéticos

Executar o roteiro completo com Bruno, validador e três identidades sintéticas antes de convidar pacientes reais.

**Aceite:** todos os bloqueadores corrigidos; cálculos assinados pelo validador; recuperação e restauração testadas. **Dependências:** 6.1 a 6.3. **Escopo:** M.

#### Tarefa 6.5: decisão de hospedagem e go/no-go

Reavaliar GitHub Pages, domínio, proteção do código, termos, privacidade, suporte e limites do Supabase antes de dados reais.

**Aceite:** decisão registrada; riscos aceitos explicitamente; checklist de lançamento aprovado. **Dependências:** 6.4. **Escopo:** S.

## 6. Depois do piloto

- IA para gerar plano, ler texto manuscrito e rótulos, sempre com revisão.
- Formulários personalizados, relatórios e produtividade.
- Integração com BS Financeiro, planos de acompanhamento e pacotes.
- E-mail e WhatsApp para avisos, código de barras e Open Food Facts.
- Base comunitária moderada, white-label, domínio próprio e API.
- Aplicativo/PWA aprimorado, biometria e modo offline.
- Custos aproximados, tempo de preparo, suplementos, água e fitoterápicos.

Esses itens não devem atrasar os checkpoints 0 a 6.

## 7. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Migrations remotas ausentes | Crítico | Reconciliar antes de qualquer DDL |
| Cálculo incorreto ou dado ausente tratado como zero | Crítico | Casos de referência e revisão do nutricionista |
| Vazamento entre clínicas | Crítico | RLS negativa, pgTAP e duas organizações |
| Escopo maior que o piloto | Alto | Checkpoints e fase pós-piloto separada |
| Estudante publicar sem regra ética validada | Alto | Parecer e identificação auditável do supervisor |
| Pages inadequado para operação comercial | Alto | Go/no-go e migração antes de dados reais |
| Dependência de plano gratuito | Alto | Limites monitorados, backup e plano de saída |
| Componentes frontend grandes | Médio | Refatorar por fluxo junto de testes, sem reescrita total |
| Poucos testes automatizados | Alto | CI SQL e E2E antes do piloto |

## 8. Definição de pronto do piloto

O piloto só está pronto quando:

- [ ] as migrations locais e remotas estão reconciliadas;
- [ ] lint, unitários, build, pgTAP e E2E passam no CI;
- [ ] cinco tarefas críticas funcionam com todos os papéis necessários;
- [ ] isolamento entre duas clínicas foi provado por testes negativos;
- [ ] o nutricionista validador aprovou cálculos e três planos sintéticos;
- [ ] recuperação de conta, MFA profissional e restauração foram testados;
- [ ] celular, tablet, desktop, tema claro/escuro e acessibilidade básica foram verificados;
- [ ] política ética, LGPD, retenção, hospedagem e uso de dados reais receberam go/no-go explícito.

## 9. Ordem de retomada recomendada

1. Confirmar rapidamente a Fase 0 sem refazer o fechamento já provado.
2. Usar `docs/PLANO_DESENVOLVIMENTO_BSNUTRI_V1.md` como roadmap principal e este arquivo como visão complementar.
3. Completar Fases 1 e 2 para estabilizar o núcleo clínico.
4. Fechar portal e acompanhamento nas Fases 3 e 4.
5. Não usar pacientes reais antes das Fases 5 e 6.
