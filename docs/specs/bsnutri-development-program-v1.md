# Spec: programa de desenvolvimento total do BSNutri V1

## Problem Statement

O BSNutri já possui uma base funcional para cadastro de pacientes, planos alimentares versionados, portal do paciente, substituições, diário, metas, exames, conteúdos e identidade da clínica. Essa base, porém, ainda combina recursos maduros, protótipos e fluxos incompletos. O problema imediato é de confiabilidade: uma falha em um recurso opcional, como a identidade visual, consegue impedir o carregamento de informações clínicas essenciais.

O problema de produto é mais amplo. A construção do plano ainda exige trabalho manual demais, o catálogo alimentar precisa ganhar escala e rastreabilidade, as substituições precisam considerar contexto nutricional e cultural, e o acompanhamento entre consultas deve transformar registros dispersos em informação clínica revisável.

Se todas as frentes forem tratadas como igualmente urgentes, o projeto tende a acumular telas e tabelas sem fechar jornadas completas. O desenvolvimento precisa seguir fatias verticais, começando pelo núcleo nutricionista-paciente, mantendo o editor prioritariamente desktop e deixando recepção, gestão, integrações e ideias experimentais para fases posteriores.

## Solution

Executar um programa incremental organizado em seis fases:

1. Confiabilidade do Portal do Paciente.
2. Prescrição, catálogo e substituições.
3. Acompanhamento do paciente e rotina clínica.
4. Conteúdo, relatórios, comunicação e automações.
5. Operação, gestão, segurança e mobilidade.
6. Modelos clínicos especializados, condicionados à validação das regras.

Cada entrega deve completar uma jornada observável em banco, regras, interface e testes. O sistema continuará usando o núcleo atual de planos, versões, dias, refeições, itens, snapshots publicados e políticas de acesso. Não será criado um segundo editor ou um domínio paralelo.

O diferencial do BSNutri será a prescrição flexível, culturalmente coerente e controlada pelo nutricionista. Sugestões automáticas serão explicáveis e revisáveis. Dados ausentes não serão tratados como zero. Nenhuma sugestão clínica será publicada sem decisão humana.

## User Stories

### Confiabilidade e carregamento

1. Como paciente, quero acessar meu plano mesmo quando a marca da clínica não carregar, para não perder uma informação essencial por causa de um recurso visual.
2. Como paciente, quero que conteúdos, imagens ou gráficos com falha não ocultem os demais módulos, para continuar usando o que está disponível.
3. Como paciente, quero saber qual módulo não carregou, para entender o problema sem receber uma mensagem genérica.
4. Como paciente, quero tentar carregar novamente apenas o módulo com falha, para não reiniciar toda a página.
5. Como equipe técnica, quero testes de falhas parciais do Supabase, storage e imagens, para impedir regressões.

### Motor de plano alimentar

6. Como nutricionista, quero montar o plano por refeições, horários, grupos e objetivos, para representar diferentes condutas.
7. Como nutricionista, quero usar modelos de emagrecimento, hipertrofia, controle glicêmico e abordagens gerais, para reduzir o trabalho repetitivo.
8. Como nutricionista, quero distribuir energia e macronutrientes por refeição, para revisar a proposta ao longo do dia.
9. Como nutricionista, quero trabalhar com faixas nutricionais, para evitar uma falsa precisão rígida.
10. Como nutricionista, quero prescrever alimentos, preparações, receitas ou grupos, para adaptar o nível de detalhe.
11. Como nutricionista, quero relacionar medidas caseiras e peso, para comunicar porções compreensíveis.
12. Como nutricionista, quero definir mínimo, máximo e incremento de porção, para ajustar quantidades com controle.
13. Como nutricionista, quero duplicar refeições, dias e planos, para montar propostas mais rapidamente.
14. Como nutricionista, quero aplicar refeições a vários dias, para evitar repetição manual.
15. Como nutricionista, quero salvar modelos pessoais e compartilhados pela clínica, para reutilizar estruturas aprovadas.
16. Como nutricionista, quero comparar versões, para enxergar mudanças antes de publicar.
17. Como nutricionista, quero visualizar exatamente o que o paciente verá, para revisar a comunicação.
18. Como equipe clínica, quero histórico de criação, revisão e publicação, para manter rastreabilidade.
19. Como nutricionista, quero alertas de inconsistência não bloqueantes, para decidir e justificar exceções.

### Catálogo alimentar

20. Como nutricionista, quero pesquisar alimentos brasileiros e regionais, para prescrever opções culturalmente próximas.
21. Como nutricionista, quero navegar por grupos e subgrupos, para encontrar alternativas coerentes.
22. Como nutricionista, quero encontrar alimentos por sinônimos e nomes regionais, para não depender de uma nomenclatura única.
23. Como nutricionista, quero separar alimentos genéricos e marcas comerciais, para não confundir suas fontes.
24. Como nutricionista, quero cadastrar preparações e receitas com rendimento, para calcular porções reais.
25. Como nutricionista, quero converter peso, unidade e medida caseira, para comunicar a mesma porção em formatos diferentes.
26. Como nutricionista, quero consultar a fonte e a revisão dos dados, para avaliar sua confiabilidade.
27. Como nutricionista, quero acessar favoritos, recentes e mais prescritos, para ganhar velocidade.
28. Como nutricionista, quero filtrar por cultura, preparo, custo, disponibilidade, restrições e preferências, para encontrar opções viáveis.
29. Como administrador do catálogo, quero revisar, mesclar e desativar duplicidades, para preservar a qualidade.
30. Como administrador do catálogo, quero importar dados em lote com validação prévia, para ampliar a base sem publicar erros.
31. Como paciente, quero ver renders WebP com fallback adequado, para reconhecer alimentos sem depender da imagem.

### Substituições

32. Como nutricionista, quero sugerir substituições por grupo e papel culinário, para manter a coerência da refeição.
33. Como nutricionista, quero comparar energia, proteínas, carboidratos, lipídios e fibras, para avaliar o impacto da troca.
34. Como nutricionista, quero configurar tolerâncias nutricionais, para adaptar o ranqueamento ao caso.
35. Como nutricionista, quero que alergias, restrições e preferências eliminem sugestões incompatíveis, para preservar segurança e adesão.
36. Como nutricionista, quero considerar cultura, custo, acesso e facilidade de preparo, para propor trocas aplicáveis.
37. Como nutricionista, quero aprovar, ordenar ou bloquear alternativas, para manter controle profissional.
38. Como paciente, quero entender por que uma alternativa foi autorizada, para realizar a troca corretamente.
39. Como paciente, quero ver o impacto nutricional antes da troca, quando o profissional permitir, para tomar uma decisão informada.
40. Como nutricionista, quero saber quais substituições foram usadas, para revisar a adesão real.

### Portal e acompanhamento

41. Como paciente, quero uma página Hoje com minha próxima refeição e ações prioritárias, para saber o que fazer.
42. Como paciente, quero navegar pelo plano publicado por dia, para localizar as refeições rapidamente.
43. Como paciente, quero acessar uma lista de compras por período, para me organizar.
44. Como nutricionista, quero controlar por paciente a visibilidade de calorias, macros, IMC, peso e diário, para adaptar a comunicação clínica.
45. Como paciente, quero registrar se segui, adaptei, omiti ou acrescentei algo, para representar o que aconteceu sem julgamento.
46. Como paciente, quero adicionar foto e comentário opcional, para registrar contexto quando for útil.
47. Como paciente, quero informar fome, saciedade, sintomas e contexto, para enriquecer o acompanhamento.
48. Como nutricionista, quero diferenciar o prescrito do realizado, para interpretar o diário corretamente.
49. Como nutricionista, quero um resumo diário e semanal, para revisar padrões sem ler cada registro.
50. Como nutricionista, quero identificar refeições frequentemente omitidas ou substituídas, para priorizar intervenções.
51. Como nutricionista, quero uma fila clínica baseada em regras explicáveis, para saber por que um paciente precisa de revisão.
52. Como nutricionista, quero marcar registros revisados e transformar achados em tarefas, para fechar o ciclo de acompanhamento.

### Metas, exames e evolução

53. Como nutricionista, quero criar metas quantitativas e comportamentais, para acompanhar diferentes tipos de mudança.
54. Como nutricionista, quero definir unidade, frequência, prazo e revisão, para tornar a meta verificável.
55. Como nutricionista, quero registrar histórico e motivo de encerramento, para preservar a evolução.
56. Como paciente, quero realizar check-in rápido de metas, para participar do acompanhamento.
57. Como nutricionista, quero uma linha do tempo de exames com valor, unidade, referência, laboratório, data e fonte, para comparar resultados com contexto.
58. Como nutricionista, quero anexar o documento original, para preservar a fonte.
59. Como nutricionista, quero gráficos apenas entre unidades compatíveis, para evitar comparações enganosas.
60. Como nutricionista, quero comentários clínicos privados e indicadores de completude, para preparar a consulta sem gerar diagnóstico automático.

### Conteúdo, relatórios e comunicação

61. Como nutricionista, quero organizar materiais em pastas, tags e versões, para reutilizar conteúdos revisados.
62. Como nutricionista, quero pré-visualizar e enviar uma versão estável ao paciente, para evitar mudanças retroativas.
63. Como nutricionista, quero saber quando um conteúdo precisa de revisão, para não enviar material desatualizado.
64. Como nutricionista, quero gerar o plano completo e orientações em PDF, para compartilhar uma versão profissional.
65. Como nutricionista, quero gerar relatório de evolução e resumo para prontuário, para documentar o acompanhamento.
66. Como gestor, quero que exportações sejam auditadas, para rastrear o acesso a informações clínicas.
67. Como paciente, quero receber lembretes solicitados pelo profissional, para não depender de memória.
68. Como equipe, quero modelos de mensagens e tarefas pós-consulta, para padronizar rotinas sem automatizar tudo.

### Experiência profissional, operação e gestão

69. Como nutricionista, quero um painel de pendências clínicas separado das administrativas, para priorizar o cuidado.
70. Como nutricionista, quero resumo longitudinal e comparação com a consulta anterior, para preparar o atendimento.
71. Como nutricionista, quero busca global, atalhos, salvamento automático e edição em massa, para trabalhar com menos interrupções.
72. Como recepcionista, quero agenda, confirmações e pendências cadastrais sem acesso ao conteúdo clínico, para executar meu trabalho com limite de acesso.
73. Como gestor, quero administrar equipe, papéis, convites e modelos compartilhados, para controlar a operação.
74. Como gestor, quero relatórios operacionais sem exposição clínica indevida, para acompanhar a clínica.
75. Como usuário, quero interface acessível, consistente e prioritariamente desktop para edição, para trabalhar com clareza.
76. Como profissional em mobilidade, quero revisar e executar ações rápidas no celular, para não depender do editor completo.

### Inteligência artificial e modelos especializados

77. Como nutricionista, quero receber rascunhos baseados em fatos estruturados, para acelerar a preparação sem delegar a decisão clínica.
78. Como nutricionista, quero aceitar, editar, rejeitar ou excluir cada sugestão, para manter controle.
79. Como nutricionista, quero ver os dados usados pelo rascunho, para avaliar sua procedência.
80. Como equipe clínica, quero que nenhum rascunho seja publicado automaticamente, para manter revisão humana.
81. Como nutricionista, quero modelos especializados validados para Low FODMAP, cetogênica, doença renal, bariátrica, gestação, lactação e pediatria, para apoiar casos que exigem regras próprias.
82. Como responsável clínico, quero revisar fontes, regras, contraindicações, fases e limites de cada modelo especializado, para impedir que um rótulo simplifique uma conduta complexa.

## Implementation Decisions

1. Evoluir os módulos existentes. Não criar um novo portal, editor ou catálogo paralelo.
2. Tratar plano publicado e seus snapshots como fonte imutável do que foi entregue ao paciente.
3. Separar dados essenciais e módulos opcionais no carregamento do portal.
4. O plano publicado é essencial. Marca, imagens, conteúdos, gráficos, Drive, resumos e módulos auxiliares são independentes e não podem ocultá-lo.
5. Cada módulo assíncrono terá estado identificável de carregamento, sucesso, vazio e erro, com nova tentativa no menor escopo possível.
6. Mensagens de erro serão apresentadas por domínio, sem expor detalhes técnicos ou dados clínicos.
7. Manter React, TypeScript, Supabase e o conjunto atual de dependências. Não adicionar biblioteca de estado, formulários ou componentes sem necessidade demonstrada.
8. Priorizar o desktop para edição clínica. Mobile mantém as jornadas essenciais e ações rápidas.
9. Consolidar tokens visuais, estados, feedback e acessibilidade antes de ampliar a quantidade de telas.
10. Manter abordagem, objetivo, restrição, preferência, contexto, custo e rotina como dimensões independentes.
11. Usar modelos padrão, da organização e pessoais. Aplicar um modelo cria um rascunho independente.
12. Dados nutricionais ausentes permanecem ausentes e geram indicação de incompletude.
13. Registrar fonte, versão, data de consulta, estado de preparo e revisão dos dados nutricionais.
14. Usar medidas caseiras como conversões explícitas, preservando o valor de referência.
15. Renders WebP ficam versionados no repositório e usam chave estável do catálogo.
16. Uma falha de imagem usa fallback visual e não altera cálculos nem bloqueia a interface.
17. Substituição é alternativa prescrita, não equivalência perfeita.
18. O ranqueamento de substituições considera proximidade nutricional, papel culinário, restrições, preferências, cultura, custo, disponibilidade e preparo.
19. Toda sugestão automática é explicável, revisável e aprovada pelo nutricionista antes de aparecer ao paciente.
20. O diário referencia paciente, versão publicada, refeição e ocorrência.
21. Os estados do diário usam linguagem neutra e distinguem conforme, adaptado, omitido e extra.
22. Foto continua opcional. Sem Drive ou storage disponível, o registro textual permanece funcional.
23. A fila clínica usa regras objetivas, mostra a razão da prioridade e permite marcar revisão e conduta.
24. Preferências de visibilidade são versionadas com a publicação aplicável ao paciente.
25. Exames preservam unidade, referência, laboratório e fonte. Gráficos não combinam séries incompatíveis.
26. Conteúdos enviados são snapshots versionados.
27. Exportações são geradas a partir de versões estáveis e deixam trilha de auditoria.
28. IA produz somente rascunho. Não publica, não inventa dados ausentes e não interpreta exames autonomamente.
29. Recepção e gestão entram depois do núcleo nutricionista-paciente.
30. Segurança básica não é adiada: RLS, armazenamento privado, auditoria, validação de uploads e testes negativos acompanham cada fatia.
31. Modelos especializados exigem uma ficha validada de finalidade, população, fases, regras, fontes, alertas, limites e responsável pela revisão.
32. Integrações com WhatsApp, laboratórios, wearables, pagamentos, agenda externa e assinatura eletrônica dependem de demanda comprovada e especificação própria.
33. Aplicativo nativo, comunidade, marketplace, loja, gamificação e avaliação por fotos ficam registrados como ideias frágeis, sem implementação neste programa.

## Testing Decisions

1. A fronteira principal será o comportamento observável das jornadas completas, usando os testes de interface já existentes para o workspace nutricional e o Portal do Paciente.
2. O primeiro teste de confiabilidade provará que uma falha de `organization_branding` não oculta o plano publicado.
3. A mesma fronteira cobrirá falhas parciais de conteúdo, resumo, Drive e imagem, verificando dados essenciais, mensagem específica e nova tentativa.
4. Regras numéricas de receitas, faixas e ranqueamento de substituições terão testes unitários puros.
5. Contratos de banco, imutabilidade, RLS, auditoria e isolamento por organização terão testes SQL.
6. Cada fatia com upload simulará sucesso, recusa, indisponibilidade e arquivo inválido.
7. Cada papel terá ao menos um teste negativo de acesso a dados que não lhe pertencem.
8. Testes devem verificar resultados percebidos pelo usuário, não detalhes internos de componentes.
9. A Definition of Done de cada ticket inclui testes relevantes, lint, build e teste SQL quando houver mudança de banco.
10. Jornadas críticas terão validação desktop. O mobile receberá verificação funcional e de acessibilidade, sem exigir paridade com o editor técnico.

## Out of Scope

1. Publicação automática de prescrição ou interpretação clínica por IA.
2. Aplicativo nativo antes de a PWA demonstrar limitação real.
3. Financeiro completo, marketplace, comunidade, cursos, loja e afiliados.
4. Integrações externas sem demanda validada e contrato específico.
5. Avaliação corporal automatizada por imagem.
6. Importação indiscriminada de bases nutricionais sem procedência e revisão.
7. Modelos especializados sem validação de regras e fontes.

## Further Notes

### Resultado do grill

1. A melhor sequência é confiabilidade, substituições, diário, fila clínica e visibilidade.
2. O catálogo e o editor existentes devem ser aprofundados, não substituídos.
3. Interface desktop recebe prioridade; mobile profissional fica focado em revisão e ação rápida.
4. Legal e operação administrativa não são o centro desta fase, mas controles de segurança acompanham toda entrega.
5. Recursos futuros permanecem registrados para não serem esquecidos, sem ocupar a fronteira de desenvolvimento antes da hora.

### Roadmap

#### Fase 0: confiabilidade

1. T01, Portal do Paciente resiliente a falhas parciais. Sem bloqueadores.

#### Fase 1: prescrição e catálogo

2. Reusar #2, novo shell desktop do construtor, concluído.
3. Reusar #3, catálogo com alimento, preparação e combinação.
4. Reusar #4, galeria e dimensões dos modelos.
5. Reusar #5, aplicação adaptável do modelo ao paciente.
6. Reusar #6, modelos pessoais e da clínica.
7. T02, sistema visual e estados compartilhados. Bloqueado por T01.
8. T03, procedência, revisão e importação segura do catálogo. Bloqueado por #3.
9. T04, busca cultural, tags, favoritos e renders com fallback. Bloqueado por #3 e T02.
10. T05, receitas, rendimento e medidas caseiras. Bloqueado por #3 e T03.
11. T06, faixas nutricionais, distribuição por refeição e edição rápida. Bloqueado por #2 e #5.
12. T07, comparação, pré-visualização e auditoria de versões. Bloqueado por T06.
13. T08, motor explicável de substituições. Bloqueado por T04, T05 e T06.
14. T09, curadoria e uso de substituições pelo paciente. Bloqueado por T08.

#### Fase 2: paciente e acompanhamento

15. T10, visibilidade clínica configurável por paciente. Bloqueado por T01 e T07.
16. T11, diário vinculado ao plano publicado. Bloqueado por T01 e T09.
17. T12, fotos, fome, saciedade, sintomas e fallbacks. Bloqueado por T11.
18. T13, resumo semanal e fila clínica explicável. Bloqueado por T11 e T12.
19. T14, ciclo completo de metas. Bloqueado por T01.
20. T15, página Hoje e lista de compras. Bloqueado por T10, T11 e T14.
21. T16, exames e evolução longitudinal. Bloqueado por T02.
22. T17, biblioteca de conteúdo e sequências educativas. Bloqueado por T02.

#### Fase 3: rotina clínica e comunicação

23. T18, pré-consulta, resumo longitudinal e comparação de consultas. Bloqueado por T13, T14 e T16.
24. T19, assistente de rascunhos clínicos auditáveis. Bloqueado por T18.
25. T20, PDFs, relatórios e exportações auditadas. Bloqueado por T07, T16 e T17.
26. T21, mensagens, lembretes e tarefas configuráveis. Bloqueado por T18.

#### Fase 4: operação, gestão e plataforma

27. T22, recepção e operação sem acesso clínico. Bloqueado por T21.
28. T23, equipe, convites, modelos compartilhados e relatórios operacionais. Bloqueado por T22.
29. T24, hardening de RLS, storage, auditoria, backup e monitoramento. Bloqueado pela conclusão das fases 1 a 3.
30. T25, PWA resiliente e ações profissionais rápidas no mobile. Bloqueado por T15, T18 e T24.

#### Fase 5: modelos especializados

31. T26, contrato de validação de modelos especializados. Bloqueado por T05, T06 e T08.
32. T27, modelo Low FODMAP por fases. Bloqueado por T26.
33. T28, modelo cetogênico revisável. Bloqueado por T26.
34. T29, modelo renal revisável. Bloqueado por T26.
35. T30, modelo bariátrico por fases. Bloqueado por T26.
36. T31, modelos de gestação e lactação. Bloqueado por T26.
37. T32, modelos pediátricos e abordagens avançadas. Bloqueado por T26.

### Gates de execução

1. A Fase 0 deve ser concluída antes de novas funcionalidades do portal.
2. A Fase 1 só avança com dados rastreáveis, publicação imutável e aprovação profissional.
3. A Fase 2 só avança com linguagem neutra e separação entre prescrito e realizado.
4. A Fase 4 não pode ampliar acesso da recepção a dados clínicos.
5. A Fase 5 exige validação clínica documentada para cada modelo.

### Definition of Done

1. Jornada demonstrável de ponta a ponta.
2. Critérios de aceitação atendidos.
3. Teste de interface ou regra no maior seam adequado.
4. Teste SQL positivo e negativo quando houver mudança de banco ou acesso.
5. `npm test`, `npm run lint` e `npm run build` aprovados.
6. Publicação imutável e auditoria preservadas.
7. Acessibilidade básica verificada.
8. Handoff atualizado no Google Drive.
