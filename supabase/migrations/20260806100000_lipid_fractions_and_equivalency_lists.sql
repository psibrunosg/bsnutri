-- Atualizar constraint da coluna unit de nutrients para aceitar 'mcg'
alter table public.nutrients drop constraint if exists nutrients_unit_check;
alter table public.nutrients add constraint nutrients_unit_check check (unit in ('kcal','kJ','g','mg','µg','mcg'));

-- Expandir tabela de nutrientes para cobrir frações lipídicas e micronutrientes do complexo B
insert into public.nutrients (code, name, unit, decimals, sort_order) values
  ('energy_kcal', 'Energia', 'kcal', 1, 10),
  ('protein_g', 'Proteínas', 'g', 2, 20),
  ('carbohydrate_g', 'Carboidratos', 'g', 2, 30),
  ('fat_g', 'Gorduras totais', 'g', 2, 40),
  ('fiber_g', 'Fibras alimentares', 'g', 2, 50),
  ('sodium_mg', 'Sódio', 'mg', 0, 60),
  ('calcium_mg', 'Cálcio', 'mg', 0, 70),
  ('iron_mg', 'Ferro', 'mg', 2, 80),
  ('potassium_mg', 'Potássio', 'mg', 0, 90),
  ('vitamin_c_mg', 'Vitamina C', 'mg', 1, 100),
  ('saturated_fat_g', 'Gordura saturada', 'g', 2, 110),
  ('monounsaturated_fat_g', 'Gordura monoinsaturada', 'g', 2, 120),
  ('polyunsaturated_fat_g', 'Gordura poli-insaturada', 'g', 2, 130),
  ('trans_fat_g', 'Gordura trans', 'g', 2, 140),
  ('vitamin_b1_mg', 'Vitamina B1 (Tiamina)', 'mg', 2, 150),
  ('vitamin_b2_mg', 'Vitamina B2 (Riboflavina)', 'mg', 2, 160),
  ('vitamin_b3_mg', 'Vitamina B3 (Niacina)', 'mg', 2, 170),
  ('vitamin_b6_mg', 'Vitamina B6 (Piridoxina)', 'mg', 2, 180),
  ('vitamin_b9_mcg', 'Vitamina B9 (Folato)', 'mcg', 1, 190),
  ('vitamin_b12_mcg', 'Vitamina B12 (Cobalamina)', 'mcg', 2, 200)
on conflict (code) do update set
  name = excluded.name,
  unit = excluded.unit,
  decimals = excluded.decimals,
  sort_order = excluded.sort_order;

-- Estruturar tabela de Listas de Substituição autônomas (Sistema de Trocas Clínicas por equivalência calórica)
create table if not exists public.equivalency_lists (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  title text not null check (char_length(trim(title)) >= 2),
  macro_group text not null,
  target_calories numeric(10, 2) not null check (target_calories >= 0),
  calorie_tolerance_pct numeric(5, 2) not null default 15 check (calorie_tolerance_pct >= 0),
  description text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id)
);

create table if not exists public.equivalency_list_items (
  id uuid primary key default gen_random_uuid(),
  equivalency_list_id uuid not null references public.equivalency_lists(id) on delete cascade,
  food_id uuid references public.foods(id) on delete set null,
  description text not null,
  grams numeric(12, 4) not null check (grams > 0),
  household_measure text,
  calories_per_portion numeric(10, 2) not null default 0,
  position integer not null default 0,
  unique (id),
  unique (equivalency_list_id, position)
);

alter table public.equivalency_lists enable row level security;
alter table public.equivalency_list_items enable row level security;

create policy "Equivalency lists accessible by tenant members or global" on public.equivalency_lists
  for select using (
    organization_id is null
    or private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
    or exists (select 1 from public.patients p where p.organization_id = equivalency_lists.organization_id and private.can_access_patient(p.id))
  );

create policy "Equivalency lists modifiable by professional roles" on public.equivalency_lists
  for all using (
    organization_id is not null and
    private.has_organization_role(organization_id, array['owner','admin','nutritionist']::public.organization_role[])
  );

create policy "Equivalency list items accessible when list accessible" on public.equivalency_list_items
  for select using (
    exists (select 1 from public.equivalency_lists l where l.id = equivalency_list_id and (
      l.organization_id is null
      or private.has_organization_role(l.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
      or exists (select 1 from public.patients p where p.organization_id = l.organization_id and private.can_access_patient(p.id))
    ))
  );

create policy "Equivalency list items modifiable when list modifiable" on public.equivalency_list_items
  for all using (
    exists (select 1 from public.equivalency_lists l where l.id = equivalency_list_id and
      l.organization_id is not null and
      private.has_organization_role(l.organization_id, array['owner','admin','nutritionist']::public.organization_role[])
    )
  );

create index if not exists equivalency_lists_org_idx on public.equivalency_lists(organization_id) where is_active;
create index if not exists equivalency_list_items_list_idx on public.equivalency_list_items(equivalency_list_id, position);

-- Vincular listas de equivalência às refeições
alter table public.meals add column if not exists equivalency_list_id uuid references public.equivalency_lists(id) on delete set null;

-- Seed das listas padrão do sistema de trocas clínicas
do $$
declare
  carb_id uuid := gen_random_uuid();
  prot_id uuid := gen_random_uuid();
  fruit_id uuid := gen_random_uuid();
  fat_id uuid := gen_random_uuid();
begin
  if not exists (select 1 from public.equivalency_lists where title = 'Grupo dos Carboidratos Complexos (~100 kcal)' and organization_id is null) then
    insert into public.equivalency_lists (id, organization_id, title, macro_group, target_calories, calorie_tolerance_pct, description)
    values (carb_id, null, 'Grupo dos Carboidratos Complexos (~100 kcal)', 'carbohydrate', 100.00, 15.00, 'Trocas autônomas equivalentes a ~100 kcal de carboidratos complexos');

    insert into public.equivalency_list_items (equivalency_list_id, description, grams, household_measure, calories_per_portion, position)
    values
      (carb_id, 'Arroz branco cozido', 75.0000, '3 colheres de sopa cheias', 97.50, 0),
      (carb_id, 'Arroz integral cozido', 80.0000, '3 colheres de sopa cheias', 99.20, 1),
      (carb_id, 'Batata doce cozida', 115.0000, '1 unidade média', 98.90, 2),
      (carb_id, 'Aveia em flocos', 25.0000, '2 colheres de sopa', 98.00, 3),
      (carb_id, 'Mandioquinha / Batata baroa cozida', 125.0000, '1 unidade média', 100.00, 4);
  end if;

  if not exists (select 1 from public.equivalency_lists where title = 'Grupo das Proteínas Magras (~120 kcal)' and organization_id is null) then
    insert into public.equivalency_lists (id, organization_id, title, macro_group, target_calories, calorie_tolerance_pct, description)
    values (prot_id, null, 'Grupo das Proteínas Magras (~120 kcal)', 'protein', 120.00, 15.00, 'Trocas autônomas equivalentes a ~120 kcal de fontes proteicas');

    insert into public.equivalency_list_items (equivalency_list_id, description, grams, household_measure, calories_per_portion, position)
    values
      (prot_id, 'Peito de frango grelhado', 75.0000, '1 filé pequeno', 119.25, 0),
      (prot_id, 'Peixe branco grelhado (tilápia ou merluza)', 120.0000, '1 filé médio', 117.60, 1),
      (prot_id, 'Ovo de galinha cozido', 80.0000, '1 ovo grande + 1 clara', 116.00, 2),
      (prot_id, 'Tofu fresco', 160.0000, '2 fatias grossas', 121.60, 3);
  end if;

  if not exists (select 1 from public.equivalency_lists where title = 'Grupo de Frutas Frescas (~60 kcal)' and organization_id is null) then
    insert into public.equivalency_lists (id, organization_id, title, macro_group, target_calories, calorie_tolerance_pct, description)
    values (fruit_id, null, 'Grupo de Frutas Frescas (~60 kcal)', 'fruit', 60.00, 15.00, 'Trocas autônomas equivalentes a ~60 kcal de frutas');

    insert into public.equivalency_list_items (equivalency_list_id, description, grams, household_measure, calories_per_portion, position)
    values
      (fruit_id, 'Banana prata', 65.0000, '1 unidade pequena', 63.70, 0),
      (fruit_id, 'Maçã fuji ou gala', 115.0000, '1 unidade pequena', 59.80, 1),
      (fruit_id, 'Mamão formosa', 140.0000, '1 fatia grande', 56.00, 2),
      (fruit_id, 'Morango', 200.0000, '10 unidades grandes', 60.00, 3);
  end if;

  if not exists (select 1 from public.equivalency_lists where title = 'Gorduras Saudáveis e Óleos (~45 kcal)' and organization_id is null) then
    insert into public.equivalency_lists (id, organization_id, title, macro_group, target_calories, calorie_tolerance_pct, description)
    values (fat_id, null, 'Gorduras Saudáveis e Óleos (~45 kcal)', 'fat', 45.00, 15.00, 'Trocas autônomas equivalentes a ~45 kcal de gorduras boas');

    insert into public.equivalency_list_items (equivalency_list_id, description, grams, household_measure, calories_per_portion, position)
    values
      (fat_id, 'Azeite de oliva extravirgem', 5.0000, '1 colher de chá', 44.20, 0),
      (fat_id, 'Castanha do Pará', 7.0000, '2 unidades pequenas', 45.90, 1),
      (fat_id, 'Abacate fresco', 30.0000, '1 colher de sopa cheia', 48.00, 2);
  end if;
end $$;

-- Atualizar RPC atômico para salvar equivalency_list_id nas refeições
create or replace function public.save_plan_draft(
  target_organization_id uuid,
  target_patient_id uuid,
  target_title text,
  target_change_summary text,
  target_assistant_state jsonb,
  target_targets jsonb,
  target_days jsonb,
  target_created_by uuid default auth.uid()
)
returns public.plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  patient_org uuid;
  result public.plans;
  new_version uuid;
  new_day uuid;
  new_meal uuid;
  day_json jsonb;
  meal_json jsonb;
  item_json jsonb;
  day_idx integer := 0;
  meal_pos integer;
  item_pos integer;
  item_food_id uuid;
  eq_list_id uuid;
begin
  select organization_id into patient_org from public.patients where id = target_patient_id;
  if patient_org is null or patient_org <> target_organization_id
     or not private.has_organization_role(target_organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ao paciente ou organização';
  end if;

  if jsonb_array_length(coalesce(target_days, '[]'::jsonb)) = 0 then
    raise exception 'Estrutura de dias vazia no plano';
  end if;

  insert into public.plans (organization_id, patient_id, created_by, title, status)
  values (target_organization_id, target_patient_id, coalesce(target_created_by, auth.uid()), coalesce(nullif(trim(target_title), ''), 'Plano alimentar'), 'draft')
  returning * into result;

  insert into public.plan_versions (organization_id, plan_id, version_no, created_by, change_summary, assistant_state, targets)
  values (
    target_organization_id, result.id, 1, coalesce(target_created_by, auth.uid()), coalesce(target_change_summary, 'Versão inicial'),
    coalesce(target_assistant_state, '{}'::jsonb),
    coalesce(target_targets, '{}'::jsonb)
  )
  returning id into new_version;

  for day_json in select elem from jsonb_array_elements(target_days) elem loop
    insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
    values (
      target_organization_id,
      new_version,
      coalesce((day_json->>'day_index')::integer, day_idx),
      coalesce(day_json->>'label', 'Dia ' || (day_idx + 1)),
      coalesce((day_json->>'kind')::public.day_kind, 'standard'::public.day_kind)
    )
    returning id into new_day;
    day_idx := day_idx + 1;

    meal_pos := 0;
    for meal_json in select elem from jsonb_array_elements(coalesce(day_json->'meals', '[]'::jsonb)) elem loop
      eq_list_id := null;
      if (meal_json->>'equivalencyListId') is not null and (meal_json->>'equivalencyListId') <> '' then
        eq_list_id := (meal_json->>'equivalencyListId')::uuid;
      elsif (meal_json->>'equivalency_list_id') is not null and (meal_json->>'equivalency_list_id') <> '' then
        eq_list_id := (meal_json->>'equivalency_list_id')::uuid;
      end if;

      insert into public.meals (organization_id, plan_day_id, position, label, equivalency_list_id)
      values (
        target_organization_id,
        new_day,
        coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', meal_json->>'name', 'Refeição'),
        eq_list_id
      )
      returning id into new_meal;
      meal_pos := meal_pos + 1;

      item_pos := 0;
      for item_json in select elem from jsonb_array_elements(coalesce(meal_json->'items', '[]'::jsonb)) elem loop
        item_food_id := nullif(coalesce(item_json->>'food_id', item_json->>'foodId', ''), '')::uuid;

        insert into public.meal_items (
          organization_id,
          meal_id,
          position,
          food_id,
          description,
          quantity,
          unit,
          grams,
          nutrient_snapshot
        )
        values (
          target_organization_id,
          new_meal,
          coalesce((item_json->>'position')::integer, item_pos),
          item_food_id,
          coalesce(item_json->>'description', item_json->>'name', 'Item alimentar'),
          coalesce((item_json->>'grams')::numeric(12,4), 100),
          'g',
          coalesce((item_json->>'grams')::numeric(12,4), 100),
          coalesce(item_json->'nutrientsPer100g', item_json->'nutrient_snapshot', '{}'::jsonb)
        );

        item_pos := item_pos + 1;
      end loop;
    end loop;
  end loop;

  return result;
end;
$$;
