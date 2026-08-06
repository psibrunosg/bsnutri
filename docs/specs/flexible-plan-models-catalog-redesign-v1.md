# Spec: modelos flexíveis, catálogo alimentar e novo construtor de planos V1

## Problem Statement

O BSNutri já permite cadastrar alimentos, montar refeições, calcular nutrientes, publicar versões imutáveis e disponibilizar o plano ao paciente. Essa base funciona, mas o nutricionista ainda precisa construir planos de forma excessivamente manual. O editor atual é rígido, tem baixa densidade produtiva e aparência amadora, dificultando o uso durante a consulta e a revisão técnica posterior.

Também falta uma biblioteca ampla e organizada de modelos, preparações, combinações, grupos alimentares e substituições. Sem essa estrutura, abordagens dietéticas, objetivos clínicos, preferências, restrições, cultura alimentar e realidade financeira acabam misturados em planos isolados que não podem ser combinados nem reaproveitados com segurança.

O problema central não é apenas cadastrar mais alimentos. O nutricionista precisa partir de uma estrutura clínica reutilizável, adaptá-la ao paciente, enxergar os efeitos nutricionais das mudanças em tempo real e publicar somente depois de revisar a proposta. O paciente precisa receber um plano visualmente claro, culturalmente coerente e com alternativas aplicáveis à sua rotina.

## Solution

Evoluir o editor existente para um construtor desktop de planos em três áreas recolhíveis:

1. contexto do paciente, metas, restrições e modelo aplicado;
2. refeições, alimentos, preparações, combinações e substituições;
3. totais nutricionais, alertas e qualidade do plano.

O nutricionista poderá iniciar por uma galeria de modelos, duplicar um plano anterior ou começar do zero. A galeria reunirá modelos padrão do BSNutri, modelos da clínica e modelos pessoais, com filtros por abordagem dietética, objetivo, restrição, preferência, contexto cultural, custo e rotina.

Os modelos guardarão estrutura, regras e faixas adaptáveis. Ao aplicá-los, o sistema criará um rascunho independente para o paciente, calculará uma proposta com base nas metas definidas e exigirá revisão profissional antes da publicação. Abordagem, objetivo, restrições, preferências e metas continuarão sendo dimensões distintas, embora apareçam em uma experiência única e combinável.

O catálogo distinguirá alimento, preparação e combinação ou refeição-modelo. Cada registro nutricional preservará origem, versão, estado de preparo e base de cálculo. A primeira entrega usará um conjunto inicial coerente, priorizando alimentos brasileiros e permitindo expansão posterior. Renders WebP padronizados serão armazenados no repositório e associados aos registros do catálogo.

As substituições serão alternativas prescritas e revisáveis. O sistema poderá ranqueá-las por proximidade nutricional, papel culinário, restrições, preferências, cultura, custo, disponibilidade e facilidade de preparo, sem declarar equivalência perfeita nem aprovar automaticamente uma troca.

## User Stories

1. Como nutricionista, quero iniciar um plano a partir de uma galeria de modelos, para reduzir o trabalho manual.
2. Como nutricionista, quero duplicar um plano anterior do paciente, para aproveitar uma conduta que já funcionou.
3. Como nutricionista, quero começar um plano vazio, para atender casos que não combinam com modelos existentes.
4. Como nutricionista, quero filtrar modelos por abordagem dietética, para encontrar uma estrutura coerente com minha conduta.
5. Como nutricionista, quero filtrar modelos por objetivo, para localizar propostas de emagrecimento, hipertrofia, desempenho ou controle glicêmico.
6. Como nutricionista, quero combinar abordagem e objetivo, para aplicar, por exemplo, hipertrofia vegetariana.
7. Como nutricionista, quero considerar restrições e preferências separadamente, para não confundir necessidade clínica com escolha do paciente.
8. Como nutricionista, quero filtrar modelos por custo e rotina, para construir planos viáveis.
9. Como nutricionista, quero considerar contexto cultural e regional, para evitar prescrições desconectadas da alimentação do paciente.
10. Como nutricionista, quero visualizar modelos padrão do BSNutri, para começar com opções prontas.
11. Como nutricionista, quero criar modelos pessoais, para reutilizar meu próprio método.
12. Como responsável pela clínica, quero disponibilizar modelos compartilhados, para padronizar boas práticas da equipe.
13. Como nutricionista, quero transformar um plano existente em modelo, para preservar uma estrutura útil sem copiar dados do paciente.
14. Como nutricionista, quero editar uma cópia independente do modelo aplicado, para que alterações futuras no modelo não mudem o plano do paciente.
15. Como nutricionista, quero usar modelos com regras e faixas, para adaptar a proposta às metas individuais.
16. Como nutricionista, quero definir metas em valores absolutos, percentuais ou por peso corporal, para usar critérios diferentes conforme o caso.
17. Como nutricionista, quero revisar todos os valores calculados antes de publicar, para manter controle profissional da prescrição.
18. Como nutricionista, quero distinguir abordagem dietética, objetivo, restrição, preferência e meta, para combinar dimensões sem ambiguidade.
19. Como nutricionista, quero usar o modelo Alimentação Brasileira Equilibrada, para partir de combinações culturalmente familiares.
20. Como nutricionista, quero usar modelos Mediterrâneo e DASH, para trabalhar com padrões alimentares reconhecidos.
21. Como nutricionista, quero usar modelos vegetariano e vegano, para atender escolhas alimentares específicas.
22. Como nutricionista, quero usar modelos de emagrecimento, hipertrofia, desempenho e controle glicêmico, para acelerar objetivos frequentes.
23. Como nutricionista, quero usar modelos de baixo custo e rotina corrida, para considerar barreiras práticas.
24. Como nutricionista, quero ver modelos especializados marcados como fase futura, para conhecer a evolução prevista sem utilizá-los prematuramente.
25. Como nutricionista, quero trabalhar em um editor desktop com contexto, conteúdo e análise simultâneos, para reduzir trocas de tela.
26. Como nutricionista, quero recolher as áreas laterais, para ampliar o espaço de edição quando necessário.
27. Como nutricionista, quero organizar refeições em blocos visuais, para entender rapidamente a estrutura do dia.
28. Como nutricionista, quero reordenar refeições e itens com interação direta, para ajustar o plano com menos cliques.
29. Como nutricionista, quero buscar alimentos por nome, sinônimo, grupo e estado de preparo, para encontrar o registro correto.
30. Como nutricionista, quero adicionar alimentos, preparações e combinações sem confundi-los, para usar cada entidade de forma adequada.
31. Como nutricionista, quero ver imagem, medida caseira, porção e nutrientes essenciais durante a busca, para escolher com segurança.
32. Como nutricionista, quero editar quantidades e ver os totais atualizados imediatamente, para ajustar a proposta durante a consulta.
33. Como nutricionista, quero duplicar refeições e combinações, para montar variações com rapidez.
34. Como nutricionista, quero salvar automaticamente o rascunho, para não perder trabalho.
35. Como nutricionista, quero desfazer uma alteração recente, para corrigir erros de edição sem reconstruir a refeição.
36. Como nutricionista, quero cadastrar um alimento da clínica com fonte e estado de preparo, para ampliar o catálogo de forma rastreável.
37. Como nutricionista, quero cadastrar uma preparação com ingredientes e rendimento, para calcular sua composição por porção.
38. Como nutricionista, quero cadastrar uma combinação reutilizável, para representar uma refeição completa.
39. Como nutricionista, quero associar um render WebP ao item do catálogo, para tornar a busca e o plano mais visuais.
40. Como nutricionista, quero identificar registros sem imagem, para priorizar a produção de renders.
41. Como nutricionista, quero saber a fonte e a versão dos dados nutricionais, para avaliar sua adequação.
42. Como nutricionista, quero diferenciar alimento cru, cozido, drenado ou preparado, para evitar cálculos incorretos.
43. Como nutricionista, quero usar medidas caseiras além de gramas, para prescrever porções compreensíveis.
44. Como nutricionista, quero que o sistema preserve o valor original por 100 g e converta a apresentação, para manter reprodutibilidade.
45. Como nutricionista, quero comparar registros candidatos de fontes diferentes, para selecionar conscientemente qual utilizar.
46. Como nutricionista, quero criar substituições dentro da refeição, para oferecer alternativas aplicáveis ao paciente.
47. Como nutricionista, quero ver a diferença nutricional entre o item original e a alternativa, para revisar a troca.
48. Como nutricionista, quero filtrar substituições por restrição e preferência, para não sugerir opções inadequadas.
49. Como nutricionista, quero considerar o papel culinário da alternativa, para evitar trocas nutricionalmente próximas mas impraticáveis.
50. Como nutricionista, quero considerar cultura, custo, disponibilidade e preparo, para melhorar a adesão.
51. Como nutricionista, quero ajustar os critérios de ranqueamento, para adequar sugestões ao caso.
52. Como nutricionista, quero aprovar manualmente as substituições, para manter responsabilidade sobre o plano publicado.
53. Como nutricionista, quero ver alertas de metas não atingidas ou excedidas, para revisar a qualidade do plano.
54. Como nutricionista, quero distinguir dado ausente de valor zero, para não interpretar incorretamente micronutrientes.
55. Como nutricionista, quero publicar por meio do fluxo imutável existente, para preservar o histórico clínico.
56. Como paciente, quero receber somente a versão publicada, para não visualizar rascunhos.
57. Como paciente, quero visualizar alimentos e preparações com imagens consistentes, para reconhecer melhor o plano.
58. Como paciente, quero entender porções em medidas caseiras, para executar a orientação.
59. Como paciente, quero visualizar substituições aprovadas, para adaptar a alimentação sem sair da prescrição.
60. Como paciente, quero uma interface clara e acolhedora, para usar o plano sem aparência de sistema administrativo.
61. Como membro de outra organização, quero permanecer isolado dos modelos, alimentos próprios e planos que não me pertencem, para preservar privacidade e segurança.
62. Como recepcionista, quero continuar sem acesso a dados clínicos e nutricionais, para respeitar os limites do papel.
63. Como equipe de desenvolvimento, quero ampliar o catálogo por lotes rastreáveis, para evitar registros sem origem ou revisão.
64. Como equipe de desenvolvimento, quero adicionar novos modelos sem alterar o motor central, para incluir abordagens especializadas posteriormente.

## Implementation Decisions

1. Evoluir o núcleo atual de plano, versão, dia, refeição, item, publicação imutável e portal; não criar um editor paralelo.
2. Tratar o novo editor como uma evolução do workspace nutricional existente.
3. Usar três áreas recolhíveis no desktop: contexto, construção e análise.
4. Manter o mobile funcional, mas concentrar o refinamento visual e produtivo desta fase no desktop.
5. Adotar identidade clínica contemporânea e acolhedora, com verde profundo, tons naturais, tipografia limpa e hierarquia visual clara.
6. Manter abordagem dietética, objetivo, restrição, preferência, contexto e meta como dimensões independentes e combináveis.
7. Exibir essas dimensões em uma galeria única de modelos com filtros.
8. Suportar modelos com escopo padrão do BSNutri, organização e pessoal.
9. Copiar o modelo para um rascunho independente quando ele for aplicado a um paciente.
10. Permitir criar modelo a partir de plano sem copiar identificadores ou dados pessoais do paciente.
11. Representar regras do modelo por estrutura de refeições, faixas, proporções, fórmulas e marcadores qualitativos revisáveis.
12. Não gerar nem publicar prescrição automaticamente. A aplicação do modelo produz somente uma proposta em rascunho.
13. Preservar o fluxo atual de publicação imutável e seus snapshots.
14. Separar alimento, preparação e combinação ou refeição-modelo no domínio.
15. Reusar o catálogo nutricional existente e expandi-lo incrementalmente, preservando compatibilidade com planos atuais.
16. Registrar fonte, identificador original, versão, data de consulta, estado de preparo, base de referência e revisão em registros nutricionais.
17. Usar TACO como primeira fonte brasileira, publicações de alimentos regionais como referência cultural, USDA para lacunas e cadastro próprio para itens da clínica.
18. Não fazer importação integral de TBCA nesta fase.
19. Tratar medidas caseiras como conversões explícitas para a base de referência, sem substituir o valor original.
20. Calcular preparações por ingredientes, quantidades, fatores aplicáveis, rendimento e número ou peso de porções.
21. Tratar combinações como estruturas reutilizáveis compostas por alimentos ou preparações.
22. Armazenar renders WebP otimizados no repositório e referenciá-los por chave estável do catálogo.
23. Padronizar enquadramento e dimensões dos renders e manter fallback visual para itens sem imagem.
24. Não usar imagens como fonte de informação nutricional.
25. Tratar substituição como alternativa prescrita, não como equivalência perfeita.
26. Calcular diferenças de substituição usando a mesma versão de catálogo e snapshot do plano.
27. Ranqueamento de substituições poderá considerar proximidade nutricional, papel culinário, restrições, preferências, cultura, custo, disponibilidade e facilidade de preparo.
28. Os pesos do ranqueamento serão configuráveis, mas a aprovação continuará manual.
29. Dado nutricional ausente nunca será tratado como zero.
30. A primeira fase incluirá: Alimentação Brasileira Equilibrada, Mediterrânea, DASH, Vegetariana, Vegana, Emagrecimento, Hipertrofia, Desempenho, Controle Glicêmico, Baixo Custo e Rotina Corrida.
31. Low FODMAP, Cetogênica, Renal, Bariátrica, Gestação, Lactação, Pediatria e outras abordagens clínicas especializadas ficarão para uma fase posterior.
32. A arquitetura de modelos deverá aceitar as abordagens futuras sem exigir outro editor ou outro fluxo de publicação.
33. O primeiro lote de catálogo deve ser pequeno o suficiente para revisão e amplo o suficiente para demonstrar a jornada completa; expansão em massa não bloqueia a primeira entrega.
34. O isolamento por organização e os limites dos papéis existentes permanecem obrigatórios.

## Testing Decisions

1. Testar comportamento observável, evitando testes acoplados à estrutura interna dos componentes.
2. Usar como fronteira principal um teste de integração do workspace nutricional: selecionar paciente, iniciar plano por modelo, adaptar refeições, revisar totais, salvar rascunho e publicar.
3. Estender a fronteira do portal do paciente para provar que somente o snapshot publicado, suas imagens e substituições aprovadas ficam visíveis.
4. Manter testes unitários apenas para cálculos puros de preparação, aplicação de regras e ranqueamento de substituições, onde erros numéricos seriam difíceis de localizar pela interface.
5. Cobrir contratos de banco e RLS com testes SQL existentes, incluindo isolamento de modelos pessoais, modelos da organização, catálogo próprio e rascunhos.
6. Provar que aplicar um modelo cria cópia independente e que editar o modelo depois não altera o plano.
7. Provar que criar modelo a partir de plano não copia dados pessoais do paciente.
8. Provar que dados ausentes permanecem ausentes nos cálculos e alertas.
9. Provar que versões publicadas permanecem imutáveis após alterações de catálogo, modelo ou render.
10. Provar que recepção não acessa modelos clínicos, nutrientes, planos nem substituições.
11. Reusar o padrão dos testes atuais do workspace nutricional, portal do paciente e migrations SQL.
12. Validar a apresentação desktop nas larguras principais e manter uma verificação funcional mínima no mobile.

## Out of Scope

1. Refinamento completo da experiência mobile.
2. Funcionalidades administrativas e gerenciais novas.
3. Importação integral e automática de TACO, TBCA ou USDA.
4. Scraping de bases nutricionais.
5. Geração automática de prescrição sem revisão profissional.
6. Diagnóstico ou decisão clínica automatizada.
7. Reconhecimento de alimentos por fotografia.
8. Geração dinâmica de renders dentro do produto.
9. Armazenamento das imagens do catálogo em serviço externo nesta fase.
10. Modelos Low FODMAP, Cetogênico, Renal, Bariátrico, Gestação, Lactação e Pediatria.
11. Marketplace público de modelos.
12. Edição colaborativa simultânea do mesmo plano.

## Further Notes

1. Esta especificação complementa a evolução anterior do editor avançado. Diário alimentar, fotos do diário, fila de acompanhamento e agenda não devem ser reimplementados aqui.
2. O catálogo extenso é uma direção contínua do produto. A primeira entrega deve provar o fluxo completo antes da expansão em massa.
3. A política existente de composição nutricional e as regras existentes de substituição continuam válidas.
4. O uso de WebP no GitHub é uma decisão deliberada para esta fase. Se o volume de imagens ameaçar o limite ou o desempenho do GitHub Pages, a migração para armazenamento de objetos será tratada em trabalho próprio.
5. Os modelos especializados da próxima fase devem permanecer visíveis apenas no backlog, sem oferecer uma prescrição incompleta ao usuário.
