# Comparativo: referências Nutri x BSNutri

Data: 24/07/2026  
Escopo: 11 repositórios indicados em `C:\Users\ACPO Empreendimentos\Desktop\Nutri.txt`. Foram considerados somente fluxos descritos nos READMEs ou identificáveis no código público. Não são recomendações para copiar código nem para automatizar decisão clínica.

## Base de comparação

O BSNutri já supera a maior parte das referências em plano versionado e revisável, catálogo com procedência, receitas e medidas, ranking de substituições, portal com check-ins, pré-consulta, conteúdos, exames anexos, PWA, agenda, papéis/RLS e modelos especializados. Evidências locais: `src/NutritionWorkspace.tsx`, `src/PatientPortal.tsx`, `src/PatientDetail.tsx`, `src/lib/catalog.ts`, `src/lib/planModels.ts` e migrations em `supabase/migrations/`.

## O que agrega de fato

| Prioridade | Incremento | Referência primária | Lacuna concreta no BSNutri | Recorte mínimo recomendado |
| --- | --- | --- | --- | --- |
| Alta | **Importador reproduzível de composição brasileira** | [nutribr](https://github.com/pedrorichil/nutribr) declara base TACO/IBGE, filtros por nutrientes e VDR no [README](https://github.com/pedrorichil/nutribr/blob/main/README.md). | Há catálogo, procedência e revisão, mas não ficou evidenciada integração/importação reproduzível de uma fonte brasileira externa. | Importador administrativo versionado: fonte, licença, release, mapeamento, validação e revisão humana antes de publicar. Não consultar API direto no navegador. |
| Alta | **Foto de refeição como rascunho de diário** | [agente_nutri](https://github.com/silviolima07/agente_nutri) implementa fluxo de upload, identificação multimodal e avaliação; ver [README](https://github.com/silviolima07/agente_nutri/blob/main/README.md). [IA Nutricionista](https://github.com/asimov-academy/ia-nutricionista) também descreve `FoodImageAnalyzerTool` no [README](https://github.com/asimov-academy/ia-nutricionista/blob/main/README.md). | O portal aceita foto no check-in, mas não há extração estruturada de itens/porções para o paciente confirmar. | Upload → candidatos e incerteza → paciente confirma/corrige → salva no diário. Nunca lançar nutrientes ou substituir o plano automaticamente. |
| Média | **Lembretes recorrentes e resumo semanal acionável** | [IA Nutricionista](https://github.com/asimov-academy/ia-nutricionista) descreve `ReminderTool`, registro de peso/refeições e relatório semanal no [README](https://github.com/asimov-academy/ia-nutricionista/blob/main/README.md). | Há fila, metas e tela Hoje, mas não foi evidenciado agendamento de lembretes, notificação PWA nem resumo longitudinal automático. | Preferências de horário por paciente + notificações opt-in + resumo semanal com adesão, água, check-ins e meta. Profissional escolhe se libera ao paciente. |
| Média | **Assinatura e modelos de documentos além do plano** | [PRElias/nutri](https://github.com/PRElias/nutri) descreve assinatura na tela, documentos, receitas e reutilização de dados no [README](https://github.com/PRElias/nutri/blob/master/README.md). | O BSNutri já gera/imprime plano e tem marca, mas não ficou evidenciada assinatura capturada nem editor de modelos para outros documentos. | Assinatura salva como ativo da clínica, aplicada apenas no PDF final; modelos para receita, declaração e solicitação/resumo de exames, todos versionados. |
| Média | **Exportação tabular de dados próprios** | [PRElias/nutri](https://github.com/PRElias/nutri) lista exportação Excel no [README](https://github.com/PRElias/nutri/blob/master/README.md). | Não há evidência de exportação CSV/XLSX de pacientes, evolução, check-ins e agenda. | Exportação CSV por tela, filtrada pela clínica e com colunas mínimas. XLSX só se houver demanda real. |
| Baixa | **Pedido de inclusão de alimento** | [Nutricode](https://github.com/joaopedro1422/Nutricode) prevê solicitação de alimento ao administrador no [README](https://github.com/joaopedro1422/Nutricode/blob/main/README.md). | Há curadoria/importação, mas não ficou evidenciado pedido rastreável vindo do profissional ou paciente. | Botão “não encontrou?” cria solicitação com sinônimo, marca/foto e contexto; curador aprova, une ou recusa. |
| Baixa | **Visualização longitudinal explícita de evolução** | [NutriLab-Django](https://github.com/LucasFeliciano02/NutriLab-Django) descreve linha de peso/gordura e dados laboratoriais no [README](https://github.com/LucasFeliciano02/NutriLab-Django/blob/main/README.md). | Há antropometria, exames e linha do tempo, mas não ficou evidenciado gráfico comparativo de medidas e exames selecionados. | Um gráfico simples por indicador, com período e unidades coerentes. Sem “score” clínico automático. |

## Ideias avaliadas e descartadas agora

1. Gerador de dieta semanal por IA sem revisão, de [Diet-IA](https://github.com/Rafael-M-Silva/Diet-IA): o BSNutri já privilegia rascunho e aprovação profissional. A geração só vale como proposta auditável, nunca publicação direta.
2. Chatbot genérico, de [NutriBot-IA](https://github.com/Lybnih/NutriBot-IA): adiciona superfície de risco e pouco resolve antes de lembretes, resumo e foto confirmável.
3. Aplicar Deep Learning diretamente para “avaliar conteúdo nutricional”, de [Nutricao-Inteligente](https://github.com/michele-andrade/Nutricao-Inteligente): útil como pesquisa, não como dado clínico confiável sem confirmação de porção e alimento.
4. Reimplementar agenda, PDF, PWA, diário, modelos clínicos ou catálogo: já existentes no BSNutri e as referências são mais simples nesses pontos.

## Ordem sugerida

1. Importador de fonte brasileira com release e curadoria.
2. Lembretes opt-in e resumo semanal.
3. Foto de refeição confirmável.
4. CSV e documentos assináveis.
5. Pedidos de alimento e gráficos de evolução.

## Repositórios lidos

1. [Nutricao-Inteligente](https://github.com/michele-andrade/Nutricao-Inteligente)
2. [IA Nutricionista](https://github.com/asimov-academy/ia-nutricionista)
3. [Nutricode](https://github.com/joaopedro1422/Nutricode)
4. [Diet-IA](https://github.com/Rafael-M-Silva/Diet-IA)
5. [NutriBot-IA](https://github.com/Lybnih/NutriBot-IA)
6. [nutrIA](https://github.com/HenriqueFerreira06/nutrIA)
7. [NutriLab-Django](https://github.com/LucasFeliciano02/NutriLab-Django)
8. [agente_nutri](https://github.com/silviolima07/agente_nutri)
9. [nutri](https://github.com/PRElias/nutri)
10. [SIG-DietPlan](https://github.com/Diego-Axel/SIG-DietPlan)
11. [nutribr](https://github.com/pedrorichil/nutribr)
