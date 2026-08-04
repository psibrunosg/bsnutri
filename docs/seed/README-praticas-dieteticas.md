# Modelos de Práticas Dietéticas — BSNutri

Seed de modelos dietéticos baseados em evidência, prontos para importar no BSNutri.

## Arquivos

| Arquivo | Conteúdo |
|---------|----------|
| `praticas-dieteticas.json` | Seed para `plan_templates` (8 modelos com `dimensions` e `rules`) |
| `mediterranea.csv` | 53 alimentos típicos da dieta Mediterrânea |
| `dash.csv` | 51 alimentos da dieta DASH |
| `mind.csv` | 43 alimentos da dieta MIND |
| `cetogenica.csv` | 45 alimentos da dieta Cetogênica |
| `low_carb.csv` | 50 alimentos da dieta Low Carb |
| `vegana.csv` | 63 alimentos da dieta Vegana |
| `paleo.csv` | 63 alimentos da dieta Paleolítica |
| `guia_br.csv` | 82 alimentos do Guia Alimentar para a População Brasileira |

**Total:** 450 alimentos validados contra o parser do BSNutri (zero erros, zero duplicatas).

---

## Modelos (A — plan_templates JSON)

O arquivo `praticas-dieteticas.json` segue a estrutura das migrations `20260717160000` (tabela `plan_templates`) e `20260723190844` (colunas `dimensions` e `rules`).

### Estrutura de cada modelo

```json
{
  "name": "Dieta Mediterrânea",
  "objective": "Prevenção cardiovascular...",
  "tags": ["mediterranean"],
  "scope": "organization",
  "dimensions": {
    "approaches": ["mediterranean"],
    "objectives": ["cardiovascular_prevention"],
    "restrictions": [],
    "preferences": ["plant_forward"],
    "contexts": ["outpatient"]
  },
  "rules": {
    "targets": { "protein_pct": {"min": 15, "max": 20}, ... },
    "guidance": ["...", "..."]
  },
  "evidence": "PREDIMED...",
  "source": "...",
  "food_csv": "mediterranea.csv"
}
```

### Modelos incluídos

| # | Modelo | Approach | Evidência | Objetivo primário |
|---|--------|----------|-----------|-------------------|
| 1 | Mediterrânea | `mediterranean` | Forte (PREDIMED) | Cardiovascular |
| 2 | DASH | `dash` | Forte (NHLBI) | Hipertensão |
| 3 | MIND | `mind` | Moderada (Morris 2015) | Neuroproteção |
| 4 | Cetogênica | `ketogenic` | Moderada curto prazo | Controle glicêmico DM2 |
| 5 | Low Carb | `low_carb` | Moderada | Glicemia / perda de peso |
| 6 | Vegana | `vegan` | Forte (Academy 2016) | Saúde geral, ética |
| 7 | Paleolítica | `paleo` | Baixa-moderada | Saúde metabólica |
| 8 | Guia Alimentar BR | `guia_br` | Oficial MS 2014 | Alimentação saudável populacional |

---

## Como usar

### A) Importar alimentos de um modelo

1. BSNutri → Biblioteca da clínica → **Importar alimentos**
2. Fonte: criar/selecionar (ex.: `TBCA-Mediterrânea`, `NHLBI-DASH`)
3. Cole o conteúdo do CSV escolhido (ex.: `mediterranea.csv`)
4. Prévia → **Importar prévia validada**
5. Repita para outros modelos (cada CSV é independente)

### B) Usar plan_templates (JSON)

O JSON é seed para a tabela `plan_templates`. Para carregar via Supabase SQL:

```sql
-- Exemplo simplificado: inserir manualmente o modelo Mediterrânea
insert into public.plan_templates (
  organization_id, name, objective, tags, snapshot,
  created_by, scope, dimensions, rules
) values (
  '<uuid-da-org>',
  'Dieta Mediterrânea',
  'Prevenção cardiovascular e saúde cardiometabólica',
  array['mediterranean','cardiovascular','plant_forward'],
  '{}'::jsonb,
  '<uuid-do-criador>',
  'organization',
  '{"approaches":["mediterranean"],"objectives":["cardiovascular_prevention"],"restrictions":[],"preferences":["plant_forward","olive_oil","fish","legumes"],"contexts":["outpatient","clinical","prevention"]}'::jsonb,
  '{"targets":{"protein_pct":{"min":15,"max":20}},"guidance":["Basear alimentação em alimentos in natura..."]}'::jsonb
);
```

Adapte `organization_id` e `created_by` por clínica. Os 8 modelos podem ser carregados por script percorrendo o JSON.

### C) Aplicar modelo a paciente

Use a função `apply_plan_template_to_patient(template_id, patient_id)` (definida em `20260723190844_plan_template_profiles.sql`) para criar um plano a partir do modelo.

---

## Fontes dos valores nutricionais

Valores **aproximados** baseados em **TBCA/USP** e **USDA SR Legacy**. Porção de referência: 100 g. Não são dados oficiais de lote.

> ⚠️ **Revisão obrigatória por nutricionista** antes de uso clínico. Modelos são referenciais populacionais baseados em evidência — **não substituem prescrição individualizada** (atividade privativa do nutricionista, Lei 8.234/1991, CFN 600/2018).

## Referências

- **Mediterrânea**: Estruch R et al. NEJM 2018 (PREDIMED). U.S. News Best Diets 2025 #1.
- **DASH**: Appel LJ et al. NEJM 1997. NHLBI. Sibai GH et al. (DASH-Sodium).
- **MIND**: Morris MC et al. Alzheimer's Dement 2015.
- **Cetogênica**: Feinman RD et al. Nutrition 2015.
- **Vegana**: Melina V et al. J Acad Nutr Diet 2016 (Academy of Nutrition and Dietetics).
- **Paleolítica**: Cordain L. Revisões 2015-2019.
- **Guia BR**: Ministério da Saúde. Guia Alimentar para a População Brasileira (2014). CFN reaffirmação 2024-2026.

## Licença

Dados de composição: domínio público (TBCA/USDA). Modelos dietéticos: baseados em literatura científica aberta. Uso livre no BSNutri.