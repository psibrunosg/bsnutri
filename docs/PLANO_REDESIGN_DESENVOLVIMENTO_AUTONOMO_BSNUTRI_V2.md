# Plano mestre de redesign e desenvolvimento autônomo do BSNutri

Versão: 2  
Data: 30 de julho de 2026  
Prioridade: profissional de nutrição  
Estado: plano de execução

## 1. Decisão de produto

O próximo ciclo do BSNutri deve priorizar o profissional de nutrição. O paciente continua no escopo apenas como destinatário do plano alimentar publicado. Diário, mensagens, gamificação, marketplace, aplicativo nativo e outras expansões do portal ficam fora do núcleo deste ciclo.

O produto precisa deixar de funcionar como uma sequência de cadastros e passar a funcionar como um workspace clínico. O profissional informa o que depende de julgamento ou observação; o sistema calcula, recupera, compara, sugere estruturas e verifica consistência. A decisão final continua sendo do profissional.

A jornada central será:

1. localizar ou cadastrar o paciente;
2. revisar os dados disponíveis;
3. registrar a avaliação necessária para o caso;
4. calcular estimativas com método, premissas e fonte visíveis;
5. transformar estimativas em metas profissionais editáveis;
6. iniciar um rascunho vazio, anterior ou baseado em modelo;
7. montar refeições com totais atualizados em tempo real;
8. revisar alertas, faixas e incompatibilidades;
9. aprovar e publicar um snapshot imutável;
10. entregar ao paciente o plano e o PDF correspondente.

## 2. Diagnóstico do sistema atual

### 2.1 O que já existe e deve ser preservado

1. React, TypeScript, Vite, Tailwind CSS e Supabase.
2. Autenticação, organizações, papéis e isolamento por organização.
3. Cadastro e busca de pacientes.
4. Avaliações, antropometria, exames, consentimentos, metas e resumos.
5. Planos, versões, dias, refeições, itens, revisão e publicação imutável.
6. Catálogo nutricional, preparações, medidas caseiras e composição por porção.
7. Totais nutricionais por item, refeição e dia.
8. Modelos de plano, filtros e aplicação a pacientes.
9. Rascunho local, comparação entre versões e recuperação de alterações.
10. Portal do paciente e exportação clínica.
11. Testes unitários, testes de interface e testes SQL de RLS.

O redesign deve evoluir esse núcleo. Criar um segundo editor, um segundo fluxo de publicação ou um banco paralelo para modelos aumentaria o custo e criaria divergência.

### 2.2 Evidências que explicam o problema atual

1. `NutritionWorkspace.tsx` concentra o editor, 16 estados locais, catálogo, modelos, persistência, revisão, publicação e 19 operações diretas no Supabase.
2. `PatientDetail.tsx` reúne 10 coleções clínicas e 20 operações diretas no Supabase em uma única superfície.
3. `CareWorkspace.tsx` tem cerca de 455 linhas e mistura agenda, alertas e acompanhamento.
4. A navegação principal depende de estado interno da aplicação. Isso dificulta localização, retorno pelo navegador e acesso direto a uma tarefa.
5. O motor atual calcula composição por porção e soma nutrientes, mas não calcula uma cadeia clínica completa de estimativas.
6. Os modelos básicos usam metas fixas, por exemplo 2.000 kcal, sem derivação individual.
7. Modelos dietéticos, modelos de plano, presets, catálogo e orientações ainda aparecem próximos demais na experiência e na linguagem.
8. O profissional precisa preencher metas que poderiam partir de dados já registrados e de um método calculado.
9. O código já contém recursos avançados, mas eles aparecem em uma interface densa, com hierarquia insuficiente e muitas ações simultâneas.

### 2.3 Causa principal

O problema não é apenas visual. A interface está refletindo um modelo de trabalho fragmentado:

1. dados são coletados em uma área;
2. metas são digitadas em outra;
3. modelos aparecem como estruturas prontas;
4. o editor calcula totais depois da montagem;
5. a revisão acontece no fim;
6. a publicação depende de o profissional lembrar o que falta.

O novo sistema deve encadear essas decisões. Cada etapa deve aproveitar o resultado da anterior.

## 3. Princípios fixos do redesign

1. O profissional é o usuário principal.
2. O sistema reduz trabalho repetitivo, mas não publica conduta automaticamente.
3. Toda estimativa mostra método, entradas, premissas, fonte e versão.
4. Toda meta pode ser revisada pelo profissional e registra o motivo quando divergir da estimativa.
5. Modelos criam rascunhos independentes. Atualizar um modelo nunca altera retroativamente um plano.
6. Publicações permanecem imutáveis.
7. Dados ausentes não equivalem a zero.
8. Restrições, alergias e incompatibilidades bloqueiam sugestões inseguras antes do ranqueamento.
9. O sistema deve funcionar por fatias completas, sem módulos especulativos para uma fase futura.
10. Nenhum cálculo novo entra em produção sem caso de teste independente e fonte técnica registrada.
11. Nenhum PDF ou livro entra como "fonte" sem edição, localização da regra, situação de licença e revisão.
12. O portal do paciente não deve determinar a arquitetura do workspace profissional nesta fase.

## 4. Objetivos mensuráveis

### 4.1 Objetivo principal

Reduzir o tempo e a carga cognitiva para criar, revisar e publicar um plano individualizado, sem perder rastreabilidade clínica.

### 4.2 Métricas de produto

1. Tempo mediano entre abrir o paciente e criar o primeiro rascunho.
2. Tempo mediano entre abrir o rascunho e publicar.
3. Número de campos digitados manualmente por plano.
4. Percentual de planos iniciados por cópia anterior, modelo ou cálculo assistido.
5. Número de retornos a telas anteriores para buscar informação.
6. Taxa de abandono de rascunhos.
7. Número de alertas resolvidos antes da publicação.
8. Frequência de correções depois da revisão.
9. Taxa de sucesso das jornadas sem ajuda externa.
10. Escore de facilidade percebida pelos nutricionistas do piloto.

### 4.3 Metas iniciais para o piloto

As metas devem ser confirmadas após medir a linha de base. Como referência inicial:

1. reduzir em 40% o tempo de criação do primeiro plano;
2. reduzir em 50% a quantidade de metas digitadas do zero;
3. permitir que 80% dos planos do piloto sejam iniciados por uma estrutura reutilizável;
4. manter 100% das publicações com fonte do cálculo e snapshot preservados;
5. concluir as tarefas principais apenas com teclado;
6. manter zero vazamento entre organizações e papéis nos testes SQL.

## 5. Arquitetura de informação

### 5.1 Menu principal do profissional

O menu deve representar tarefas recorrentes, não tabelas do banco.

1. **Hoje**
   1. consultas e retornos próximos;
   2. rascunhos recentes;
   3. planos aguardando revisão;
   4. pendências que exigem ação;
   5. acesso rápido aos últimos pacientes.

2. **Pacientes**
   1. busca;
   2. filtros úteis;
   3. cadastro;
   4. acesso ao workspace do paciente.

3. **Planejamento**
   1. rascunhos;
   2. em revisão;
   3. publicados;
   4. arquivados.

4. **Biblioteca**
   1. modelos de plano;
   2. modelos dietéticos;
   3. catálogo nutricional;
   4. preparações e receitas;
   5. orientações e anexos;
   6. fontes técnicas.

5. **Agenda**
   1. agenda do profissional;
   2. solicitações;
   3. estados de atendimento.

6. **Configurações**
   1. clínica e marca;
   2. equipe e papéis;
   3. integrações;
   4. preferências do editor;
   5. segurança e sessões.

Recepção e paciente devem receber menus próprios, menores e definidos por papel. Itens clínicos não devem apenas ficar visualmente escondidos; o acesso precisa ser negado no banco.

### 5.2 Workspace do paciente

Ao abrir um paciente, o profissional entra em um contexto persistente. Nome, código, idade calculada, alertas relevantes e ação principal permanecem no cabeçalho.

Abas:

1. **Resumo**
   1. última avaliação;
   2. medidas recentes;
   3. metas ativas;
   4. plano vigente;
   5. pendências;
   6. linha do tempo curta.

2. **Avaliação**
   1. dados clínicos;
   2. antropometria;
   3. rotina e atividade;
   4. preferências;
   5. restrições e alergias;
   6. exames;
   7. dados faltantes.

3. **Cálculos**
   1. estimativas disponíveis;
   2. método selecionado;
   3. comparação entre métodos;
   4. premissas;
   5. metas definidas pelo profissional;
   6. histórico da decisão.

4. **Plano alimentar**
   1. rascunho ativo;
   2. versões;
   3. revisão;
   4. publicação;
   5. comparação.

5. **Evolução**
   1. medidas;
   2. exames;
   3. metas;
   4. adesão disponível;
   5. linha do tempo.

6. **Documentos**
   1. planos publicados;
   2. PDFs;
   3. consentimentos;
   4. orientações entregues.

### 5.3 Workspace de construção do plano

No desktop, a tela deve usar três regiões:

1. **Contexto**, recolhível à esquerda:
   1. paciente;
   2. restrições;
   3. preferências;
   4. estimativas;
   5. metas;
   6. modelo aplicado.

2. **Construção**, no centro:
   1. dias;
   2. refeições;
   3. itens;
   4. porções;
   5. duplicação e ordenação;
   6. busca no catálogo.

3. **Análise**, fixável à direita:
   1. energia e macros;
   2. faixas;
   3. distribuição por refeição;
   4. nutrientes prioritários;
   5. incompatibilidades;
   6. checklist para revisão.

No celular, as três regiões viram etapas. O desktop é a prioridade produtiva. O mobile precisa permitir consulta e ajustes simples, sem tentar reproduzir toda a densidade do desktop.

### 5.4 Regras da navegação

1. Toda superfície importante precisa de URL própria.
2. Voltar e avançar do navegador devem funcionar.
3. O estado do paciente selecionado não pode desaparecer ao alternar entre avaliação, cálculo e plano.
4. Breadcrumbs aparecem apenas quando houver três ou mais níveis reais.
5. O menu principal deve ter no máximo seis grupos.
6. Ações raras ficam em menu secundário.
7. A ação primária de cada tela deve ser única e visível.
8. Busca global só entra quando a busca de pacientes e biblioteca estiver validada.
9. O produto deve preservar contexto depois de salvar, revisar ou publicar.
10. Estados vazios devem orientar a próxima ação possível.

## 6. Redesign visual e de interação

### 6.1 Direção visual

O workspace deve parecer clínico, calmo e eficiente. Não deve parecer uma landing page, um aplicativo de hábitos ou uma planilha bruta.

Parâmetros:

1. densidade 8 de 10 para desktop;
2. movimento 3 de 10, restrito a feedback e transição de estado;
3. variação visual 4 de 10;
4. prioridade para leitura rápida, comparação e edição;
5. uso do design system existente como ponto de partida;
6. verde como cor de ação e confirmação;
7. cores de alerta reservadas para significado clínico ou operacional;
8. superfícies neutras e bordas discretas;
9. tipografia legível em 16 px como base;
10. números e unidades alinhados para facilitar comparação.

A busca da skill UI/UX Pro Max sugeriu um estilo de dashboard denso e acessível. A recomendação de padrão de newsletter foi descartada por não corresponder ao produto.

### 6.2 Componentes prioritários

1. cabeçalho de contexto do paciente;
2. navegação lateral por papel;
3. cards de tarefa para a tela Hoje;
4. tabela ou lista densa de pacientes;
5. barra de progresso do fluxo clínico;
6. painel de estimativa com método e premissas;
7. editor de metas por valor e faixa;
8. card de refeição com edição direta;
9. buscador de alimentos com filtros visíveis;
10. painel de análise nutricional;
11. checklist de revisão;
12. histórico de versões;
13. galeria de modelos;
14. ficha de fonte técnica;
15. estados de carregamento, vazio, erro, sucesso e conflito.

### 6.3 Formulários

1. Exibir somente campos necessários para a etapa atual.
2. Manter rótulos visíveis.
3. Validar em `blur` quando a regra puder ser resolvida no campo.
4. Mostrar o erro ao lado do campo.
5. Diferenciar obrigatório, recomendado e opcional.
6. Usar unidades dentro da estrutura do campo, sem depender de placeholder.
7. Preencher valores derivados quando já houver dados confiáveis.
8. Não pedir novamente informação presente na avaliação vigente.
9. Salvar rascunhos automaticamente com estado visível: salvando, salvo, conflito ou falha.
10. Preservar alterações locais em falhas de rede.
11. Não limpar formulário depois de erro parcial.
12. Confirmar ações irreversíveis ou clínicas relevantes.

### 6.4 Acessibilidade

1. Contraste mínimo WCAG AA.
2. Foco visível.
3. Ordem de tabulação coerente.
4. Botões de ícone com nome acessível.
5. Alvos de toque de pelo menos 44 por 44 px.
6. Não depender apenas de cor.
7. Suportar zoom e largura de 375 px.
8. Respeitar `prefers-reduced-motion`.
9. Anunciar erros, salvamento e publicação por regiões de status.
10. Permitir montar e publicar um plano usando teclado.

## 7. Redesign do sistema

### 7.1 Módulos de domínio

Os módulos abaixo são responsabilidades desejadas, não uma ordem para criar pastas vazias.

1. **Registro do paciente**
   1. interface: carregar o contexto clínico necessário para uma tarefa;
   2. implementação: paciente, avaliações, antropometria, exames, preferências, restrições e consentimentos;
   3. resultado: um snapshot explícito, sem obrigar cada tela a montar 10 consultas.

2. **Estimativa nutricional**
   1. interface: calcular estimativas a partir de uma avaliação e de um método identificado;
   2. implementação: validação de entradas, fórmulas, arredondamento, premissas, contraindicações de uso e proveniência;
   3. resultado: estimativas reproduzíveis, avisos e dados faltantes.

3. **Definição de metas**
   1. interface: criar metas profissionais a partir de estimativas ou valores informados;
   2. implementação: faixas, distribuição, justificativa e histórico;
   3. resultado: alvo explícito usado pelo editor e pela revisão.

4. **Construção do plano**
   1. interface: criar e editar um rascunho;
   2. implementação: dias, refeições, itens, totais, rascunho local, comparação e persistência;
   3. resultado: rascunho consistente e recuperável.

5. **Biblioteca de modelos**
   1. interface: pesquisar, visualizar, aplicar, copiar e versionar modelos;
   2. implementação: escopo pessoal ou da clínica, dimensões, regras, fontes e estado de validação;
   3. resultado: novo rascunho independente.

6. **Catálogo nutricional**
   1. interface: pesquisar itens e calcular composição de porção;
   2. implementação: alimentos, preparações, combinações, medidas, composição e proveniência;
   3. resultado: candidato compatível com o contexto e nutrientes calculados.

7. **Revisão e publicação**
   1. interface: revisar um rascunho e publicar um snapshot;
   2. implementação: gates, alertas, confirmação profissional, auditoria e PDF;
   3. resultado: publicação imutável.

### 7.2 Regras de profundidade

1. Componentes React não devem conhecer detalhes de 15 tabelas.
2. Cálculos devem receber dados e retornar resultados, sem salvar no banco.
3. Persistência de uma versão deve acontecer em um ponto coordenado.
4. Um erro na gravação parcial não pode deixar plano aparentemente válido.
5. O seam principal de teste deve representar uma capacidade do profissional.
6. Não criar interfaces TypeScript apenas para uma implementação.
7. Não criar um repositório genérico para o Supabase.
8. Não criar motor universal de workflows.
9. Não criar um sistema genérico de regras antes de dois modelos reais exigirem variação.
10. Quando duas telas precisarem montar o mesmo contexto, concentrar a leitura em um único módulo ou RPC.

### 7.3 Estado e persistência

1. Separar estado de edição do estado remoto.
2. Manter um identificador estável para rascunho e versão.
3. Salvar automaticamente depois de uma janela curta de inatividade.
4. Exibir o estado do salvamento.
5. Detectar conflito de versão antes de sobrescrever.
6. Preservar o rascunho local somente pelo tempo necessário.
7. Avaliar se dados clínicos em armazenamento local são aceitáveis. Se forem mantidos, limitar conteúdo, expiração e acesso.
8. Preferir uma operação transacional ou RPC para salvar estruturas relacionadas quando a falha parcial puder corromper o rascunho.
9. Manter publicação separada de edição.
10. Não duplicar o snapshot publicado em estruturas mutáveis.

## 8. Motor de estimativas e cálculos

### 8.1 Situação atual

O núcleo atual:

1. calcula nutrientes por porção;
2. soma item, refeição e dia;
3. compara totais com metas;
4. verifica faixas;
5. ranqueia substituições por proximidade;
6. oferece metas fixas em modelos básicos.

O núcleo ainda não transforma avaliação em estimativas clínicas versionadas.

### 8.2 Primeira entrega do motor

A primeira versão deve atender adulto geral. Populações especiais entram depois de o contrato do motor estar validado.

Entradas candidatas:

1. data de nascimento e idade calculada;
2. sexo ou variável exigida pelo método escolhido;
3. peso atual;
4. altura;
5. composição corporal, quando o método exigir;
6. nível ou fator de atividade;
7. objetivo;
8. condição de uso do método;
9. dados faltantes;
10. data da avaliação.

Saídas:

1. estimativa basal;
2. estimativa de gasto total, quando sustentada;
3. faixa ou intervalo de incerteza quando o método permitir;
4. distribuição inicial de macronutrientes como proposta editável;
5. água e fibra como propostas separadas;
6. alertas de aplicabilidade;
7. método, versão e fonte;
8. entradas usadas;
9. arredondamentos;
10. justificativa da meta profissional.

### 8.3 Métodos candidatos a pesquisar

Esta lista é um backlog de validação, não uma autorização para implementar:

1. Mifflin St Jeor;
2. Harris Benedict revisada;
3. Schofield ou equações adotadas por documentos oficiais aplicáveis;
4. Cunningham quando composição corporal válida estiver disponível;
5. métodos de gasto total e fatores de atividade;
6. recomendações de proteína por objetivo e população;
7. referências de fibra e água;
8. distribuição de energia por refeição;
9. métodos pediátricos;
10. gestação e lactação;
11. pessoa idosa;
12. esporte e disponibilidade energética;
13. bariátrica;
14. doença renal;
15. vegetarianismo e veganismo.

Cada método só entra depois de:

1. fonte primária ou diretriz oficial;
2. revisão por população;
3. entradas obrigatórias definidas;
4. condições de não aplicação registradas;
5. exemplos calculados de forma independente;
6. teste de unidade e teste de integração;
7. revisão profissional;
8. versão e data de vigência.

### 8.4 Contrato mínimo do cálculo

O motor deve aceitar:

1. snapshot da avaliação;
2. identificador do método;
3. parâmetros configuráveis aprovados;
4. data do cálculo.

O motor deve retornar:

1. resultado;
2. unidade;
3. precisão;
4. entradas utilizadas;
5. entradas ignoradas;
6. avisos;
7. erros impeditivos;
8. fonte;
9. versão;
10. hash ou identificador reproduzível.

O cálculo não deve:

1. acessar diretamente a interface;
2. publicar plano;
3. escolher sozinho a conduta;
4. ocultar premissas;
5. tratar ausência como zero;
6. misturar fórmula com persistência;
7. depender de um modelo dietético para funcionar.

### 8.5 Relação entre estimativa, meta e plano

1. A estimativa é calculada.
2. A meta é escolhida pelo profissional.
3. O modelo ajuda a estruturar o plano.
4. O editor mostra a aderência do rascunho à meta.
5. A revisão verifica inconsistências.
6. A publicação preserva todos os valores usados.

Essa separação precisa existir na linguagem, na interface e no banco.

## 9. Modelos, referências e práticas dietéticas

### 9.1 Problema de gestão

Hoje o termo "modelo" pode significar:

1. uma abordagem dietética;
2. um plano reutilizável;
3. uma meta fixa;
4. uma lista de alimentos;
5. um preset clínico;
6. uma orientação entregue ao paciente.

O redesign separa esses conceitos.

### 9.2 Tipos de recurso

1. **Modelo dietético**
   1. princípios;
   2. população;
   3. objetivos;
   4. restrições;
   5. alertas;
   6. referências.

2. **Modelo de plano**
   1. estrutura de dias e refeições;
   2. distribuições;
   3. faixas;
   4. regras;
   5. sugestões;
   6. escopo pessoal ou da clínica.

3. **Preset de metas**
   1. nutrientes prioritários;
   2. faixas candidatas;
   3. condições de uso;
   4. revisão obrigatória.

4. **Preparação**
   1. ingredientes;
   2. rendimento;
   3. porções;
   4. composição calculada.

5. **Orientação**
   1. texto versionado;
   2. público;
   3. tags;
   4. publicação.

6. **Fonte técnica**
   1. referência bibliográfica;
   2. edição;
   3. ano;
   4. DOI, ISBN ou URL;
   5. página, tabela, capítulo ou seção;
   6. licença;
   7. data de consulta;
   8. situação de revisão.

### 9.3 Estados de um modelo

1. rascunho;
2. em revisão;
3. validado para piloto;
4. publicado para a clínica;
5. descontinuado;
6. substituído por versão mais recente.

Um modelo descontinuado não inicia novos planos, mas continua identificável em publicações antigas.

### 9.4 Metadados mínimos

1. nome;
2. tipo;
3. resumo;
4. população;
5. objetivo;
6. critérios de inclusão;
7. condições que exigem avaliação adicional;
8. regras;
9. faixas;
10. nutrientes prioritários;
11. fontes;
12. autor da versão;
13. revisor;
14. data de revisão;
15. versão;
16. estado;
17. observações de uso.

### 9.5 Workflow para PDFs e livros

1. Definir a pergunta clínica ou de produto antes da busca.
2. Priorizar diretrizes oficiais, consensos, artigos primários e documentos de órgãos reconhecidos.
3. Registrar a referência completa.
4. Obter o documento por acesso aberto, biblioteca, compra ou cópia legal fornecida pelo usuário.
5. Não armazenar cópia integral de obra protegida no repositório público.
6. Extrair apenas os dados necessários para a regra, com página, tabela ou seção.
7. Registrar o texto derivado em linguagem própria.
8. Separar regra explícita da interpretação da equipe.
9. Marcar população, contexto, data e limitações.
10. Criar exemplo independente de cálculo.
11. Submeter a revisão profissional.
12. Vincular a regra aprovada ao modelo ou método.
13. Definir data de reavaliação.
14. Preservar a versão anterior.

### 9.6 Ordem de pesquisa por população

1. adulto geral;
2. emagrecimento e composição corporal;
3. esporte e desempenho;
4. vegetariano e vegano;
5. gestação e lactação;
6. pessoa idosa;
7. pediatria;
8. bariátrica;
9. doença renal;
10. controle glicêmico e outras condições priorizadas pelo piloto.

Essa ordem pode mudar depois das entrevistas com nutricionistas.

### 9.7 Política de fontes nutricionais

1. Manter TACO como base brasileira inicial quando aplicável.
2. Usar publicações regionais para alimentos e preparações locais.
3. Usar USDA para lacunas identificadas.
4. Tratar TBCA conforme licença e termos vigentes, sem copiar a base integral por padrão.
5. Exigir estado de preparo e base de referência.
6. Diferenciar dado analisado, dado calculado e cadastro próprio.
7. Preservar fonte e versão em cada valor.
8. Não liberar item com descrição ambígua.
9. Não tratar receita composta como alimento simples.
10. Manter revisão clínica por lote antes de expansão em massa.

## 10. Workflow de desenvolvimento autônomo

### 10.1 Preflight de cada tarefa

1. Ler `AGENTS.md`.
2. Ler `CONTEXT.md`.
3. Ler `docs/agents/planning-workflow.md`.
4. Ler ADRs e especificações relacionadas.
5. Consultar o handoff mais recente.
6. Verificar estado do Git e preservar mudanças existentes.
7. Localizar a issue no GitHub.
8. Confirmar o comportamento atual no código e, quando necessário, na interface.
9. Localizar callers, testes, políticas RLS e migrations relacionadas.
10. Registrar o seam que a tarefa deve alterar.

### 10.2 Preparação

1. Escrever uma frase de problema.
2. Definir quem realiza a ação.
3. Definir o resultado observável.
4. Escrever o que fica fora.
5. Listar riscos.
6. Fixar critérios de aceite.
7. Escolher a menor fatia de ponta a ponta.
8. Criar branch `codex/<numero>-<slug>`.

### 10.3 Execução

1. Criar o teste que falha quando houver lógica não trivial.
2. Fazer uma migration incremental se o contrato de dados exigir.
3. Criar ou ajustar RLS e grants.
4. Escrever testes SQL positivos e negativos.
5. Implementar a regra no módulo mais profundo adequado.
6. Integrar a persistência.
7. Construir a interface.
8. Implementar carregamento, vazio, erro, sucesso e conflito.
9. Verificar teclado, foco e contraste.
10. Medir antes de otimizar.

### 10.4 Verificação

1. Rodar o teste específico durante o ciclo.
2. Rodar `npm test`.
3. Rodar `npm run lint`.
4. Rodar `npm run build`.
5. Rodar testes SQL aplicáveis.
6. Rodar advisors do Supabase quando houver mudança de banco.
7. Reproduzir a jornada com dados sintéticos.
8. Testar outro papel e outra organização.
9. Verificar falha de rede e recuperação de rascunho quando aplicável.
10. Comparar o resultado com os critérios da issue.

### 10.5 Revisão e entrega

1. Revisar o diff contra a especificação.
2. Executar Ponytail Review no diff.
3. Executar revisão de segurança proporcional ao risco.
4. Remover código especulativo e comentários temporários.
5. Atualizar documentação e changelog da feature quando necessário.
6. Atualizar a issue com evidências.
7. Criar commit pequeno e intencional.
8. Abrir PR com riscos, testes e passos de validação.
9. Atualizar o handoff.
10. Não iniciar outra fatia enquanto a atual não tiver evidência suficiente.

### 10.6 Regras de autonomia

O agente pode decidir sem interromper:

1. nomes locais coerentes com `CONTEXT.md`;
2. organização interna que não altere contrato;
3. uso de helper já existente;
4. teste adicional necessário para uma regra;
5. correção de acessibilidade diretamente ligada à tela alterada;
6. remoção de código morto criado pela própria tarefa;
7. documentação da decisão.

O agente deve parar e pedir direção quando:

1. houver conflito entre uma ADR e o pedido;
2. a decisão clínica não estiver sustentada por fonte;
3. duas opções alterarem de forma relevante a conduta do produto;
4. for necessário ampliar o acesso a dados;
5. uma migration puder perder ou reinterpretar dados;
6. uma dependência nova tiver custo permanente significativo;
7. o trabalho exigir material protegido não disponibilizado legalmente;
8. um achado indicar exposição real de dado clínico;
9. os testes não conseguirem reproduzir o comportamento;
10. a issue precisar ser ampliada para outro módulo.

## 11. Skills por fase

### 11.1 Planejamento e domínio

1. **Domain Modeling**
   1. manter `CONTEXT.md`;
   2. separar estimativa, meta, modelo dietético e modelo de plano;
   3. confrontar linguagem da interface com o código.

2. **Codebase Design**
   1. encontrar seams;
   2. concentrar cálculo e persistência;
   3. desenhar módulos profundos;
   4. evitar adaptadores e interfaces hipotéticas.

3. **Ponytail**
   1. verificar se a feature precisa existir;
   2. reutilizar antes de criar;
   3. preferir nativo e dependência instalada;
   4. manter o menor diff correto.

### 11.2 Pesquisa técnico-científica

1. **Research**
   1. buscar fontes primárias;
   2. registrar citações;
   3. produzir um arquivo por pergunta clínica;
   4. separar achado, inferência e lacuna.

2. **File Intel**, quando houver acervo local autorizado
   1. indexar PDF, DOCX e EPUB;
   2. localizar capítulos, tabelas e fórmulas;
   3. produzir inventário sem copiar a obra inteira.

3. **Humanizer**
   1. revisar orientações e documentação;
   2. preservar precisão;
   3. retirar tom artificial e conclusões genéricas.

### 11.3 UX e interface

1. **UI/UX Pro Max**
   1. pesquisar padrões;
   2. revisar navegação, formulários, densidade e acessibilidade;
   3. verificar o checklist antes da entrega.

2. **UI Styling**
   1. implementar tokens e estados;
   2. manter consistência;
   3. revisar componentes interativos.

3. **Computer Use ou Browser**
   1. validar a aplicação real;
   2. executar jornadas;
   3. registrar evidências visuais.

### 11.4 Implementação e testes

1. **TDD**
   1. fixar o seam;
   2. executar um ciclo por fatia;
   3. usar resultados independentes para cálculos.

2. **Diagnosing Bugs**
   1. construir reprodução;
   2. reduzir o caso;
   3. testar hipóteses;
   4. deixar regressão.

3. **Supabase**
   1. verificar documentação atual;
   2. tratar RLS, grants, funções e storage;
   3. criar migrations pelo CLI;
   4. rodar advisors e testes.

4. **Supabase Postgres Best Practices**
   1. revisar índices;
   2. analisar planos de consulta;
   3. evitar consultas repetidas e políticas caras.

### 11.5 Revisão

1. **Code Review**
   1. comparar o diff com a issue;
   2. revisar padrões e escopo separadamente.

2. **Ponytail Review**
   1. localizar generalização especulativa;
   2. remover wrappers, flags e camadas sem necessidade.

3. **Security Audit**
   1. procurar vulnerabilidades exploráveis;
   2. validar cada achado de forma independente;
   3. separar vulnerabilidade de hardening.

## 12. Roadmap de execução

### Fase 0: linha de base e alinhamento, 1 semana

Objetivo: medir o trabalho real antes de redesenhar.

Tarefas:

1. entrevistar de três a cinco nutricionistas;
2. observar duas construções de plano;
3. registrar cliques, tempo, campos e retornos;
4. listar os dez maiores atritos;
5. escolher o perfil adulto inicial;
6. fechar vocabulário;
7. mapear a jornada atual e a desejada;
8. congelar expansão do portal do paciente.

Skills:

1. Domain Modeling;
2. UI/UX Pro Max;
3. Humanizer;
4. Ponytail.

Gate:

1. linha de base registrada;
2. jornada priorizada;
3. população inicial definida;
4. escopo fora documentado.

### Fase 1: nova arquitetura de navegação, 1 a 2 sprints

Objetivo: permitir que o profissional saiba onde está e qual é a próxima ação.

Tarefas:

1. criar contrato de rotas;
2. reorganizar menu por tarefas;
3. criar workspace persistente do paciente;
4. mover modelos e catálogo para Biblioteca;
5. padronizar cabeçalho, estados e ação primária;
6. preservar papéis;
7. validar teclado e navegador;
8. manter funcionalidades existentes.

Skills:

1. UI/UX Pro Max;
2. Codebase Design;
3. TDD;
4. Supabase;
5. Ponytail Review.

Gate:

1. todas as áreas principais têm URL;
2. voltar e avançar funcionam;
3. tarefas atuais continuam disponíveis;
4. acesso por papel permanece isolado;
5. cinco nutricionistas localizam as tarefas principais sem orientação.

### Fase 2: avaliação e motor de estimativas para adulto, 2 a 3 sprints

Objetivo: reduzir digitação manual e tornar cálculos rastreáveis.

Tarefas:

1. definir dataset mínimo da avaliação;
2. pesquisar e validar os primeiros métodos;
3. implementar contrato puro do motor;
4. criar testes com exemplos independentes;
5. exibir comparação de métodos quando aplicável;
6. transformar estimativa em meta editável;
7. registrar justificativa de override;
8. persistir método, entradas e versão;
9. conectar metas ao editor.

Skills:

1. Research;
2. File Intel;
3. Domain Modeling;
4. TDD;
5. Supabase;
6. Security Audit para o fluxo de dados.

Gate:

1. resultados reproduzíveis;
2. nenhuma fórmula sem fonte;
3. dados faltantes impedem cálculo indevido;
4. override preserva justificativa;
5. publicação preserva a cadeia de decisão.

### Fase 3: construtor profissional do plano, 2 a 3 sprints

Objetivo: montar e ajustar o plano com menos troca de contexto.

Tarefas:

1. implementar regiões de contexto, construção e análise;
2. manter totais em tempo real;
3. adicionar edição direta de porção;
4. melhorar busca de catálogo;
5. duplicar refeição, dia e estrutura;
6. consolidar autosave;
7. tratar conflito e recuperação;
8. mostrar alertas durante a montagem;
9. revisar performance;
10. preservar fluxo de publicação.

Skills:

1. UI/UX Pro Max;
2. Codebase Design;
3. TDD;
4. Diagnosing Bugs;
5. Supabase Postgres Best Practices;
6. Ponytail.

Gate:

1. plano completo sem navegar para outra área;
2. nenhuma perda em falha de rede simulada;
3. totais atualizam com resultado conhecido;
4. edição por teclado funciona;
5. tempo de montagem melhora contra a linha de base.

### Fase 4: biblioteca de modelos e fontes, 2 sprints

Objetivo: tornar reutilização e proveniência compreensíveis.

Tarefas:

1. separar tipos de recurso;
2. criar filtros por população, objetivo, abordagem e estado;
3. implementar ciclo de versão e validação;
4. vincular fontes;
5. transformar plano em modelo sem dados do paciente;
6. copiar modelo para rascunho independente;
7. indicar modelos descontinuados;
8. validar primeiro lote adulto;
9. criar fila de pesquisa das populações seguintes.

Skills:

1. Domain Modeling;
2. Research;
3. File Intel;
4. Supabase;
5. UI/UX Pro Max;
6. Ponytail.

Gate:

1. nenhum modelo contém identificador de paciente;
2. toda regra clínica tem fonte ou está marcada como não validada;
3. editar modelo não altera plano existente;
4. modelo descontinuado não inicia novo plano;
5. profissional encontra um modelo adequado em menos de um minuto.

### Fase 5: revisão, publicação e entrega, 1 a 2 sprints

Objetivo: concluir o plano com segurança e clareza.

Tarefas:

1. consolidar checklist de revisão;
2. classificar alerta em impeditivo, importante e informativo;
3. mostrar diferença entre estimativa, meta e total;
4. revisar substituições;
5. publicar snapshot imutável;
6. gerar PDF legível;
7. manter portal do paciente simples;
8. registrar entrega e acesso;
9. testar reimpressão de versão antiga.

Skills:

1. UI/UX Pro Max;
2. Documents ou PDF;
3. Supabase;
4. TDD;
5. Security Audit;
6. Humanizer.

Gate:

1. publicação exige revisão;
2. PDF corresponde ao snapshot;
3. paciente vê somente a versão autorizada;
4. versão antiga permanece reproduzível;
5. nenhum conteúdo interno aparece na entrega.

### Fase 6: estabilização e piloto, 2 semanas

Objetivo: provar uso real antes de expandir populações ou portal.

Tarefas:

1. executar auditoria completa;
2. corrigir P0 e P1;
3. rodar piloto com dados sintéticos e depois ambiente controlado;
4. medir tempo e erros;
5. registrar dúvidas recorrentes;
6. revisar navegação;
7. revisar restauração e backup;
8. fechar documentação;
9. decidir próxima população.

Skills:

1. Security Audit;
2. Ponytail Audit;
3. Diagnosing Bugs;
4. UI/UX Pro Max;
5. Supabase;
6. Humanizer.

Gate:

1. zero P0 ou P1 aberto;
2. metas de tempo avaliadas;
3. restauração testada;
4. RLS e papéis aprovados;
5. decisão de expansão baseada em dados.

## 13. Backlog inicial recomendado

1. Medir jornada atual do profissional.
2. Fixar glossário no produto e na documentação.
3. Criar contrato de rotas e menu.
4. Implementar workspace do paciente.
5. Criar resumo clínico agregado para o workspace.
6. Definir contrato de estimativa nutricional.
7. Pesquisar e validar primeiro método para adulto.
8. Implementar motor puro e testes.
9. Persistir estimativa e meta profissional.
10. Conectar meta ao editor.
11. Reorganizar editor em três regiões.
12. Consolidar autosave e conflitos.
13. Separar recursos da Biblioteca.
14. Versionar modelo e fonte.
15. Criar checklist único de revisão.
16. Revisar publicação e PDF.
17. Executar auditoria de segurança.
18. Executar Ponytail Audit.
19. Rodar piloto.
20. Decidir a próxima população.

Cada item deve virar uma issue pequena. Itens 6 a 10 formam a primeira fatia de cálculo; itens 13 e 14 formam a primeira fatia de modelos.

## 14. Definição de pronto

Uma fatia está pronta quando:

1. resolve uma tarefa real de ponta a ponta;
2. atende aos critérios da issue;
3. usa o vocabulário do domínio;
4. tem teste no seam adequado;
5. possui testes SQL quando altera acesso ou banco;
6. passou em `npm test`, `npm run lint` e `npm run build`;
7. não amplia acesso indevidamente;
8. trata carregamento, vazio, erro, sucesso e conflito;
9. funciona por teclado;
10. preserva publicação imutável;
11. registra fonte quando há cálculo ou regra clínica;
12. não contém abstração especulativa;
13. foi validada com dados sintéticos;
14. atualizou documentação e handoff;
15. possui evidência anexada à issue ou PR.

## 15. Riscos e lacunas

### 15.1 Riscos técnicos

1. Componentes grandes dificultam mudança segura.
2. Muitas operações diretas no Supabase podem produzir falhas parciais.
3. Estado local e remoto podem divergir.
4. Navegação sem URL pode manter acoplamento entre telas.
5. RLS pode estar correta em uma tabela e incompleta em uma relação.
6. Funções `SECURITY DEFINER` exigem revisão rigorosa de grants e autenticação.
7. Rascunhos locais podem conter dados clínicos além do necessário.
8. Catálogo maior pode tornar busca e renderização lentas.
9. PDF pode divergir da publicação se for gerado a partir de estado mutável.
10. Migrações antigas não devem ser reescritas.

### 15.2 Riscos clínicos e científicos

1. Fórmula correta pode ser aplicada à população errada.
2. Meta fixa pode parecer recomendação individual.
3. PDF ou livro pode estar desatualizado.
4. Regra secundária pode ser confundida com fonte primária.
5. Ausência de dado pode ser interpretada como normalidade.
6. Arredondamento pode produzir divergência entre tela e PDF.
7. Um modelo pode ocultar premissas.
8. Um item do catálogo pode misturar estados de preparo.
9. Valores de marca podem ser tratados como universais.
10. Atualização de diretriz pode tornar um modelo obsoleto.

### 15.3 Riscos de produto

1. Tentar atender todas as populações antes de validar o motor.
2. Redesenhar visualmente sem reduzir trabalho manual.
3. Criar muitas abas e apenas mudar o lugar da complexidade.
4. Tornar o assistente rígido demais para consultas reais.
5. Exibir alertas demais e produzir fadiga.
6. Priorizar o portal do paciente cedo demais.
7. Confundir automação com decisão clínica.
8. Medir quantidade de features em vez de tempo e segurança.

### 15.4 Dados que ainda precisam ser confirmados

1. quais perfis de nutricionista participarão do piloto;
2. qual população adulta será a primeira;
3. tempo atual de montagem;
4. conjunto mínimo de avaliação;
5. métodos aceitos pela equipe;
6. quais livros ou PDFs já estão disponíveis legalmente;
7. frequência de uso de modelos anteriores;
8. necessidade real de agenda no menu principal;
9. volume esperado do catálogo;
10. formato preferido de PDF.

## 16. Ideias frágeis registradas

Estas ideias não entram no núcleo, mas permanecem registradas:

1. assistente de IA para montar rascunho;
2. extração automática de dados de exames;
3. recomendação automática de modelo;
4. busca semântica em livros;
5. comparação visual de pratos;
6. geração de lista de compras;
7. integração com relógios;
8. aplicativo nativo;
9. chat com paciente;
10. marketplace de modelos;
11. modelos compartilhados entre clínicas;
12. cálculo avançado de periodização esportiva;
13. motor de regras clínicas configurável;
14. gamificação;
15. relatórios populacionais.

Critério para reavaliar: evidência de uso, fonte válida, dados suficientes e núcleo profissional estável.

## 17. Melhorias sugeridas por grupo

### 17.1 Produtividade do profissional

1. comandos rápidos;
2. duplicação contextual;
3. favoritos do catálogo;
4. modelos recentes;
5. histórico de decisões;
6. atalhos de teclado;
7. salvamento automático visível.

### 17.2 Qualidade clínica

1. comparação entre estimativa e meta;
2. faixa de incerteza;
3. dados faltantes destacados;
4. alerta por população;
5. fonte visível;
6. versão de método;
7. justificativa de override.

### 17.3 Modelos e biblioteca

1. estado de validação;
2. responsável pela revisão;
3. filtros;
4. comparação entre versões;
5. descontinuação;
6. cópia segura;
7. lote de revisão.

### 17.4 Operação

1. rascunhos abandonados;
2. planos aguardando revisão;
3. publicações recentes;
4. falhas de entrega;
5. auditoria de exportação;
6. backup e restauração.

### 17.5 Paciente, sem ampliar o escopo

1. plano responsivo;
2. PDF claro;
3. medidas caseiras compreensíveis;
4. substituições autorizadas;
5. identificação da versão;
6. contato da clínica;
7. acessibilidade básica.

## 18. Primeira decisão executável

O primeiro ciclo não deve começar pelo CSS. Deve começar por duas issues:

1. medir e documentar a jornada atual do nutricionista;
2. criar o workspace do paciente com nova navegação, preservando o comportamento existente.

Em paralelo, a trilha científica prepara o contrato e a fonte do primeiro cálculo para adulto. O motor só entra no produto depois de a navegação e o seam de avaliação estarem claros.
