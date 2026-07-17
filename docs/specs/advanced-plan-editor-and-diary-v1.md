# Spec: editor avançado de plano e diário do paciente V1

## Problem Statement

O BSNutri já tem o fluxo básico de plano alimentar, publicação imutável, portal do paciente, substituições, check-ins e alertas. O próximo problema é transformar isso em rotina clínica real: o nutricionista precisa montar um plano completo durante a consulta ou logo depois, revisar metas e pendências sem travar o atendimento, publicar uma versão clara para o paciente e acompanhar o que aconteceu entre consultas.

Hoje o editor atual prova a base, mas ainda não separa bem o modo de consulta rápida do modo técnico, não exige um caminho mínimo de revisão antes de publicar, não permite configurar o que o paciente verá sobre cálculos e ainda não liga o diário ampliado com foto, fome, saciedade, sintomas e fila de acompanhamento.

## Solution

Criar uma evolução V1 do editor de plano e do diário do paciente, mantendo a publicação imutável e o isolamento por organização.

O editor terá uma única tela com dois modos de densidade:

1. Consulta rápida, para montar o plano durante o atendimento.
2. Técnico, para revisar metas, micronutrientes, pendências, equivalentes, visibilidade do paciente e publicação.

O assistente será obrigatório até a publicação. Ele conduz o nutricionista por objetivo, metas nutricionais, refeições, equivalentes, revisão e publicação. Depois da publicação, o plano segue bloqueado para edição direta.

O diário do paciente permitirá foto, fome, saciedade e sintomas. As fotos usam Google Drive como armazenamento principal, configurável por organização. Sem Drive conectado, o paciente registra diário sem foto. Alertas entram em uma fila de acompanhamento organizada por risco clínico simples e recência.

## User Stories

1. Como nutricionista, quero iniciar um plano em modo consulta rápida, para montar a estrutura durante o atendimento sem perder tempo.
2. Como nutricionista, quero alternar para modo técnico na mesma tela, para revisar cálculos e pendências sem abrir outro fluxo.
3. Como nutricionista, quero um assistente obrigatório até publicar, para não esquecer objetivo, metas, refeições, equivalentes e revisão.
4. Como nutricionista, quero definir objetivo clínico do plano, para guiar metas e micronutrientes prioritários.
5. Como nutricionista, quero escolher presets clínicos, para começar com critérios adequados ao caso.
6. Como nutricionista, quero usar presets de emagrecimento, hipertrofia, resistência à insulina, hipertensão, vegetariano e criança/adolescente, para cobrir os cenários iniciais.
7. Como nutricionista, quero editar os micronutrientes sugeridos pelo preset, para ajustar a conduta ao paciente.
8. Como nutricionista, quero definir kcal, macros, fibras, água e micronutrientes prioritários, para publicar com metas mínimas claras.
9. Como nutricionista, quero montar refeições com alimentos calculáveis e orientações qualitativas, para combinar prescrição precisa e orientação clínica.
10. Como nutricionista, quero salvar rascunho durante a consulta, para continuar depois sem perder estrutura.
11. Como nutricionista, quero ver pendências de qualidade, para decidir o que precisa ser revisado antes de publicar.
12. Como nutricionista, quero publicar mesmo sem substituições revisadas em todas as refeições, para não travar o atendimento quando isso for aceitável.
13. Como nutricionista, quero receber confirmação extra quando faltarem substituições revisadas, para assumir a decisão conscientemente.
14. Como nutricionista, quero configurar por plano se o paciente vê kcal totais, macros totais e cálculos por refeição, para adaptar a comunicação clínica.
15. Como paciente, quero ver o plano publicado em linguagem limpa, para entender o que fazer sem excesso de informação técnica.
16. Como paciente, quero pedir substituição, para sinalizar dificuldade sem alterar o plano por conta própria.
17. Como paciente, quero registrar refeição com foto, fome, saciedade, sintomas e observação, para mostrar o contexto real entre consultas.
18. Como paciente, quero registrar diário sem foto quando a clínica não conectou o Drive, para continuar acompanhando minha rotina.
19. Como gestor da clínica, quero configurar o Google Drive por organização, para controlar onde fotos clínicas ficam armazenadas.
20. Como gestor da clínica, quero organizar fotos por organização, nutricionista, paciente e ano-mês, para manter rastreabilidade e exportação simples.
21. Como nutricionista, quero receber alerta apenas quando houver desvio relevante, para não ser interrompido por todo registro normal.
22. Como nutricionista, quero uma fila de acompanhamento, para responder alertas clínicos sem depender de WhatsApp solto.
23. Como nutricionista, quero priorizar a fila por risco clínico simples e recência, para começar pelo que exige atenção.
24. Como nutricionista, quero responder com orientação curta, solicitar revisão/substituição ou marcar como acompanhado, para resolver alertas sem criar um chat completo agora.
25. Como recepção, quero continuar sem acesso a plano, diário, sintomas e fotos, para preservar o limite clínico do papel.

## Implementation Decisions

1. Reusar o núcleo atual de planos, versões, dias, refeições, itens, publicação imutável e portal do paciente.
2. Evoluir o editor existente em vez de criar um editor paralelo.
3. Guardar o progresso do assistente no rascunho da versão do plano.
4. Tratar "modo consulta rápida" e "modo técnico" como densidade de interface, não como dois modelos de dados.
5. Manter o fluxo de publicação via RPC, adicionando validações e avisos de qualidade onde fizer sentido.
6. Publicação continua exigindo versão revisada e bloqueando edição direta depois de publicada.
7. Metas obrigatórias para publicar: energia, proteínas, carboidratos, gorduras, fibras, água e micronutrientes prioritários escolhidos.
8. Presets clínicos sugerem micronutrientes, mas o profissional pode editar a seleção antes de publicar.
9. Substituições revisadas são recomendadas, não bloqueantes. Se faltarem, a publicação mostra aviso e confirmação extra.
10. A visibilidade do paciente fica gravada no snapshot publicado do plano, com três controles: kcal totais, macros totais e cálculos por refeição.
11. O portal respeita a visibilidade gravada na versão publicada, não uma preferência mutável externa.
12. Diário ampliado usa os vínculos já existentes de paciente, plano publicado, refeição e check-in.
13. Foto de diário usa Google Drive como armazenamento principal, com integração configurável por organização.
14. Sem Drive conectado, o upload de foto fica bloqueado e o diário textual continua permitido.
15. Banco guarda metadados da foto, ID do arquivo no Drive, hash ou identificador técnico, paciente, refeição, ocorrência e autor.
16. Estrutura de pastas no Drive: organização, nutricionista, paciente, ano-mês.
17. Nome do arquivo: data, refeição e ID curto do registro.
18. A fila de acompanhamento nasce de gatilhos objetivos: refeição pulada, troca não aprovada, fome ou saciedade extrema, sintoma moderado ou forte, ou pedido de ajuda.
19. Prioridade da fila: sintomas fortes, pedido de ajuda, refeição pulada recorrente, troca não aprovada, fome/saciedade extrema, depois recência.
20. Ações rápidas da fila: orientação curta, solicitar revisão/substituição e marcar como acompanhado.
21. WhatsApp fica fora do primeiro ciclo desta spec. A conduta precisa ficar registrada no BSNutri.
22. Não criar motor genérico de workflows. O assistente atende este fluxo específico primeiro.

## Testing Decisions

1. Testar comportamento externo, não detalhes internos de componentes.
2. Usar testes SQL para validar RLS, publicação, imutabilidade, Drive configurado por organização, diário e alertas.
3. Usar testes de regra para metas obrigatórias, presets, pendências de substituição e prioridade da fila.
4. Usar testes de interface para o fluxo profissional: criar rascunho, completar assistente, revisar, confirmar aviso e publicar.
5. Usar testes de interface para o fluxo paciente: ver plano com visibilidade configurada, registrar diário com e sem foto e pedir ajuda.
6. Manter cobertura negativa para recepção: sem acesso a plano, diário, sintomas, fotos e fila clínica.
7. Reusar os padrões já existentes em `publication_portal`, `appointments_adherence` e testes do portal.
8. Simular Google Drive nos testes de frontend e isolar a chamada externa em um cliente mínimo.

## Out of Scope

1. Chat completo entre paciente e profissional.
2. WhatsApp oficial ou envio automático de mensagens clínicas.
3. Supabase Storage como fallback para fotos.
4. IA clínica para sugerir plano, interpretar exames ou aprovar substituições.
5. App nativo.
6. Financeiro, cobrança ou pacote de serviços.
7. Importação massiva de TACO/TBCA ou base comercial nova.
8. Micronutrientes obrigatórios para todos os cenários além dos presets escolhidos.
9. Diagnóstico automático por sintomas ou foto.

## Further Notes

O ponto delicado é o Google Drive como armazenamento principal. Essa escolha atende ao pedido de organização por clínica, mas aumenta a dependência de OAuth, permissões, falha externa e governança de dados sensíveis. O primeiro desenho deve tratar integração ausente como estado normal: sem Drive, não há upload de foto, mas o diário continua funcionando.

O editor deve continuar rápido. Se a etapa obrigatória começar a parecer formulário longo demais, o ajuste correto é reduzir campos ou melhorar defaults, não criar uma exceção silenciosa que permita publicar sem rastreabilidade.
