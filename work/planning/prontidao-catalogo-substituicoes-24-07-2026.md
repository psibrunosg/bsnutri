# Prontidão: catálogo, modelos e substituições

Data: 24/07/2026  
Escopo: auditoria de issues #3 a #6 e #10 a #16. Nenhum arquivo de produto foi alterado.

## Conclusão

O repositório já possui uma boa base vertical para catálogo, modelos e substituições curadas manualmente. Ela ainda não atende integralmente os contratos das issues abertas. A próxima execução não deve ser o motor de ranqueamento (#15): ele depende de metadados, conversões e faixas que ainda não existem no domínio.

**Próxima issue executável recomendada: #3, como fechamento de contrato do catálogo.** Ela já está aberta, bloqueia #4, #10, #11 e #12, e sua conclusão real deixa a sequência #10 → #11 → #12 → #13 → #15 → #16 implementável sem retrabalho.

## Estado por issue

| Issue | Estado | Evidências presentes | Lacunas para aceite |
| --- | --- | --- | --- |
| #3 Catálogo com alimento, preparação e combinação | Parcial | `catalog_kind`, `food_components`, RLS clínica, formulário para os três tipos, cálculo puro e render WebP em `20260723184909_catalog_entities.sql`, `catalog.ts` e `NutritionWorkspace.tsx`. | Não há teste de integração cobrindo cadastro → cálculo → uso no plano → isolamento. Não há proteção contra ciclos indiretos de componentes. A tela carrega somente itens da organização, sem demonstrar o uso simultâneo de itens globais existentes. Componentes não carregam fonte, revisão ou medidas, logo ainda não sustentam #10 e #12. |
| #4 Galeria e dimensões | Parcial | Modelos padrão, galeria, cópia de modelo e persistência de `dimensions` e `rules` em `planModels.ts`, `NutritionWorkspace.tsx` e migration de perfis. | A interface filtra apenas abordagem, objetivo e contexto. Restrição e preferência existem no JSON, mas não são filtráveis. Custo e rotina foram modelados como objetivo/contexto, não como dimensões próprias. Não há teste de interface para os filtros completos nem prova de modelos padrão mais modelos persistidos sob todos os filtros. |
| #5 Aplicação adaptável | Parcial | `apply_plan_template_to_patient`, rascunho independente e teste de UI para abrir a cópia. | `rules` só substitui `targets`; não representa faixas, distribuição de refeições ou marcadores qualitativos revisáveis. Não há teste de independência após editar o modelo de origem, nem de revisão de regras no editor. |
| #6 Modelos pessoais e da clínica | Maioritariamente pronto | `scope`, política de leitura pessoal/organização, RPC de criação e teste SQL de invisibilidade do modelo pessoal. | Não há prova de UI para modelo pessoal versus compartilhado, nem teste SQL explícito de leitura do modelo de clínica por outro profissional clínico. Permissão para compartilhar é ampla para todos os papéis clínicos, o que precisa permanecer decisão explícita do produto. |
| #10 Procedência, revisão e importação segura | Não iniciado | A tabela base já possui `source_id` e `food_nutrient_values.data_version`; o catálogo novo preserva estado de preparo. | Não há campos/fluxo para fonte visível, versão, data de consulta, confiabilidade, revisão, prévia de importação, validação de duplicidade ou publicação segura. |
| #11 Busca cultural, tags, favoritos e renders resilientes | Parcial apenas em render | `render_path` com restrição WebP local, fallback visual e testes unitários em `catalog.ts`. | Busca é somente por nome no editor. Não há sinônimos, região, preparo, custo, disponibilidade, restrições, preferências, favoritos ou recentes. A imagem não possui tratamento de `onError`, então um caminho válido porém arquivo ausente pode quebrar o render visual. |
| #12 Receitas, rendimento e medidas caseiras | Parcial | Preparações e combinações guardam componentes, rendimento e porção; cálculo puro preserva nutriente ausente. | Não há modelo de receita distinto, fatores, número de porções, conversões de medida caseira, base original, nem prova de snapshot estável da preparação usada no plano após alteração do catálogo. |
| #13 Faixas nutricionais e edição rápida | Parcial de edição rápida | Duplicação de dia/refeição, edição de item e aviso de publicação sem substituições revisadas. | Não existem faixas, distribuição por refeição, aplicação em lote de dias/refeições, alertas explicáveis por faixa nem justificativa clínica persistida. |
| #14 Comparação, pré-visualização e auditoria | Não auditada a fundo nesta fronteira | Publicação imutável já é parte do domínio anterior. | Depende de #13; não deve entrar na próxima fatia de catálogo. |
| #15 Motor explicável de substituições | Base manual pronta; motor não iniciado | `meal_item_substitutions`, snapshots na publicação, RLS, tela de inclusão manual e pedido/revisão do paciente. | Não há candidatos filtrados por alergia/restrição, cálculo de impacto, papel culinário, cultura, custo, disponibilidade, preparo, pesos/tolerâncias configuráveis, razões ou regras puras de ranqueamento. |
| #16 Curadoria e uso de substituições pelo paciente | Parcial | Profissional adiciona opção em rascunho; portal exibe opções ativas publicadas; paciente envia solicitação; profissional revisa. | Não há ordem, bloqueio, limite por item/refeição, motivo nutricional mostrado ao paciente, nem registro de uso efetivo ligado à ocorrência. A solicitação aprovada não é o mesmo que registro de que a alternativa foi utilizada. |

## Dependências reais

```text
#3 fechar contrato do catálogo
 ├─ #4 filtros completos e dimensões coerentes
 ├─ #10 procedência/revisão/importação
 ├─ #11 tags, busca, favoritos e render resiliente
 └─ #12 receitas, rendimento e medidas caseiras
      └─ #13 faixas e edição por refeição
           └─ #15 motor explicável de substituições
                └─ #16 curadoria e registro de uso pelo paciente
```

`#5` e `#6` podem ser concluídas em paralelo ao fechamento de #3, mas a ampliação de regras do modelo deve acompanhar #13, porque faixas e distribuição ainda não têm representação no editor nem no banco.

## Próxima issue executável: #3 — fechamento de contrato do catálogo

Manter a issue #3 como próxima fatia e fechar estes pontos, sem criar abstrações novas:

1. Permitir leitura do catálogo global e próprio de forma explícita no carregamento, preservando o isolamento de itens próprios.
2. Impedir ciclos em `food_components` no banco, incluindo ciclos indiretos.
3. Definir e testar o contrato de componente repetido, optando por permitir posições repetidas ou consolidar gramas antes de gravar.
4. Acrescentar um único teste de integração de interface: cadastrar alimento, criar preparação, criar combinação e inserir a combinação no plano.
5. Ampliar o teste SQL para provar RLS clínica, isolamento entre organizações e bloqueio de componente pertencente a outra organização.
6. Validar a migration e a suíte SQL em Supabase antes de fechar a issue.

## Critério para considerar a fronteira pronta

Só iniciar #10, #11 ou #12 quando #3 tiver prova automatizada de:

1. três tipos de entidade e cálculo rastreável;
2. composição sem ciclo e sem nutriente ausente convertido em zero;
3. uso de alimento, preparação e combinação no plano;
4. isolamento de dados próprios entre organizações;
5. fluxo atual de plano sem regressão.

## Evidências auditadas

- Issues GitHub #3, #4, #5, #6, #10, #11, #12, #13, #14, #15 e #16.
- `src/lib/catalog.ts`, `src/lib/planModels.ts`, `src/NutritionWorkspace.tsx`, `src/SubstitutionWorkspace.tsx`, `src/PatientPortal.tsx` e testes associados.
- Migrations `20260723184909_catalog_entities.sql`, `20260723190844_plan_template_profiles.sql`, `20260723201500_food_render_paths.sql` e `20260713032602_controlled_substitutions.sql`.
- Testes SQL `catalog_entities.test.sql` e `plan_template_profiles.test.sql` e regras em `docs/substitutions-shopping-list-rules.md`.
