-- Correlação entre alimentos e modelos de prática dietética (docs/seed/*.csv + praticas-dieteticas.json):
-- foods.diet_tags guarda os approaches (mediterranean, dash, mind, ketogenic, low_carb, vegan, paleo, guia_br)
-- em que o alimento é usado; plan_templates.catalog_key identifica o modelo seed correspondente,
-- permitindo à UI filtrar foods por diet_tags && array[catalog_key] ao carregar um modelo.

alter table public.foods
  add column diet_tags text[] not null default '{}';

create index foods_diet_tags_idx on public.foods using gin (diet_tags);

alter table public.plan_templates
  add column catalog_key text;

create unique index plan_templates_org_catalog_key_unique
  on public.plan_templates(organization_id, catalog_key)
  where catalog_key is not null;
