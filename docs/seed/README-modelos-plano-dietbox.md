# Modelos de Plano BSNutri (importados de Dietbox)

Base estruturada contendo **99 modelos de plano** convertidos para o vocabulário e a estrutura do BSNutri. Origem: ambiente profissional Dietbox (importação para testes e homologação). **Todos os nomes foram normalizados como BSNutri** — o sufixo de marca de terceiros ("(Modelo de Cardápio do Dietbox)", "(Modelo de Cardápio Expert Dietbox - <autor>)", "(Seu Modelo de Cardápio)", "(importado)", "(duplicado)") foi removido.

## Arquivo de Dados

- `modelos-plano-dietbox.json`: Modelos estruturados com refeições, horários, alimentos, porções caseiras, macros e micronutrientes calculados e listas de substituições equivalentes. Mantém a estrutura original do import (chaves `refeicoes`, `itens`, `alimento`), com `descricao` já normalizada.
- `scripts/convert-dietbox-seed.mjs` (raiz do repositório): Converte este arquivo no formato `plan_templates` do BSNutri e regenera a migration `supabase/migrations/20260804000000_plan_template_dietbox_seed.sql` (idempotente). Rode `node scripts/convert-dietbox-seed.mjs` para regenerar ambos.

## Estatísticas

- **Total de modelos**: 99 (105 originais − 6 duplicados idênticos, removidos)
- **Refeições**: 570 · **Itens**: 2.108 · **Alimentos distintos**: 621
- **Modelos da clínica (Meus cardápios)**: 3 (Low Carb 1500 kcal, Dieta 1800 kcal e Dieta de Carga Glicêmica Leve e Hiperproteica 1900 kcal)
- **Modelos de referência**: 96 (padrões calóricos de 1.000 kcal a 3.500 kcal, abordagens clínicas como DASH, Mediterrâneo, Low FODMAPs, anti-inflamatória, renal, pediátrica, gestacional, hipertrofia e esportiva)

## Estrutura do Objeto

Cada modelo de plano na base possui a seguinte estrutura hierárquica:

```json
{
  "id": 26642622,
  "descricao": "Dieta 1.800 Kcal (20% PTN)",
  "ativo": false,
  "publico": false,
  "criadoEm": "2025-12-16T17:31:07.74",
  "refeicoes": [
    {
      "id": 298911759,
      "descricao": "Café da manhã",
      "horario": "07:00",
      "observacao": null,
      "alertaPaciente": true,
      "itens": [
        {
          "id": 1066738828,
          "alimentoId": 48022,
          "descricao": "Suco de laranja (1 Copo Pequeno)",
          "quantidade": 165,
          "ordem": 0,
          "grupoAlimento": null,
          "medidaCaseiraQtd": 1,
          "alimento": {
            "id": 48022,
            "calorias": 41.826,
            "proteinas": 0.588,
            "carboidratos": 9.809,
            "gorduras": 0.139,
            "fibras": 0.309,
            "sodio": 1.992,
            "calcio": 7.967,
            "ferro": 0.438,
            "tabelaOrigem": 3,
            "quantidadeBaseGrama": 100
          },
          "substituicoes": []
        }
      ]
    }
  ]
}
```

## Uso no BSNutri

Conforme o glossário em `CONTEXT.md`, este conjunto atua como **modelo de plano**: uma estrutura reutilizável de dias, refeições, distribuições, faixas e regras que permite criar um novo rascunho de plano sem dados identificáveis de paciente.

### Carga no banco (migration `20260804000000`)

A migration `supabase/migrations/20260804000000_plan_template_dietbox_seed.sql` cria a função `seed_plan_templates_dietbox(organization_id, created_by)` e carrega os 99 modelos na tabela `plan_templates` (scope `organization`), com:

- `name`, `objective`, `tags` e `dimensions`/`rules` derivados do nome (kcal-alvo em `rules.targets.energyKcal`)
- `snapshot` no formato BSNutri com a estrutura completa das refeições:
  ```json
  {
    "dietboxId": 26642622,
    "originalName": "Dieta 1.800 Kcal (20% PTN)",
    "kcalTotal": 1805,
    "summary": { "energyKcal": 1804.8, "proteinG": 91.6, "carbohydrateG": 273.9, "fatG": 40.9, "fiberG": 20.2, "sodiumMg": 1678, "calciumMg": 923.3, "ironMg": 16.2, "potassiumMg": 2520.6 },
    "meals": [
      { "name": "Café da manhã", "time": "07:00",
        "items": [
          { "food": "Suco de laranja", "measure": "1 Copo Pequeno", "grams": 165,
            "macros": { "energyKcal": 41.83, "proteinG": 0.59, "carbohydrateG": 9.81, "fatG": 0.14, "fiberG": 0.31, "sodiumMg": 1.99, "calciumMg": 7.97, "ironMg": 0.44, "potassiumMg": 0 } }
        ] }
    ]
  }
  ```
  `macros` são valores **por 100 g** (padrão `nutrient_snapshot` do app); `grams` é a porção do item. A carga é **idempotente** via unique index `(organization_id, snapshot->>'dietboxId')`.

Os alimentos presentes em cada item referenciam itens que podem ser mapeados no **catálogo nutricional** do projeto. O profissional deve revisar cada estimativa nutricional e ajustar a meta nutricional antes de proceder com a publicação do plano para o paciente.

## Conformidade e Revisão

De acordo com a política de dados de composição nutricional do projeto (`docs/nutrition-data-policy.md`), os valores numéricos originam-se de tabelas de referência compiladas pelo serviço de origem e atuam exclusivamente para acelerar o planejamento clínico do profissional. A publicação do plano final depende de aprovação explícita da equipe clínica.
