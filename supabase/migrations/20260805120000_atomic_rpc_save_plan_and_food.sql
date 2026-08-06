-- Funções RPC atômicas para salvamento do rascunho do plano e cadastro de alimentos customizados.
-- Garante transações atômicas com verificação de permissão no RLS, sem falhas parciais.

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
      insert into public.meals (organization_id, plan_day_id, position, label)
      values (
        target_organization_id,
        new_day,
        coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', meal_json->>'name', 'Refeição')
      )
      returning id into new_meal;
      meal_pos := meal_pos + 1;

      item_pos := 0;
      for item_json in select elem from jsonb_array_elements(coalesce(meal_json->'items', '[]'::jsonb)) elem loop
        item_food_id := nullif(coalesce(item_json->>'food_id', item_json->>'foodId'), '')::uuid;
        insert into public.meal_items (
          organization_id, meal_id, position, food_id, description,
          quantity, unit, grams, nutrient_snapshot
        )
        values (
          target_organization_id,
          new_meal,
          coalesce((item_json->>'position')::integer, item_pos),
          item_food_id,
          coalesce(item_json->>'description', item_json->>'name', 'Item alimentar'),
          coalesce((item_json->>'quantity')::numeric, (item_json->>'grams')::numeric, 0),
          coalesce(item_json->>'unit', 'g'),
          coalesce((item_json->>'grams')::numeric, 0),
          coalesce(item_json->'nutrient_snapshot', item_json->'nutrientsPer100g', '{}'::jsonb)
        );
        item_pos := item_pos + 1;
      end loop;
    end loop;
  end loop;

  return result;
end;
$$;

create or replace function public.add_custom_catalog_food(
  target_food jsonb,
  target_nutrients jsonb default '[]'::jsonb,
  target_components jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  org_id uuid;
  new_food_id uuid;
  n_item jsonb;
  c_item jsonb;
begin
  org_id := (target_food->>'organization_id')::uuid;
  if org_id is null or not private.has_organization_role(org_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ou organização inválida para cadastro de alimento';
  end if;

  insert into public.foods (
    organization_id, source_id, source_reference, source_accessed_on,
    source_reliability, review_status, reviewed_by, name,
    preparation_state, search_terms, cultural_tags, restriction_tags,
    preference_tags, availability_tags, cost_band, catalog_kind,
    yield_grams, serving_grams, portion_count,
    household_measure_label, household_measure_grams, render_path, created_by
  )
  values (
    org_id,
    nullif(target_food->>'source_id', '')::uuid,
    nullif(target_food->>'source_reference', ''),
    nullif(target_food->>'source_accessed_on', '')::date,
    nullif(target_food->>'source_reliability', '')::smallint,
    coalesce(nullif(target_food->>'review_status', ''), 'pending_review'),
    nullif(target_food->>'reviewed_by', '')::uuid,
    target_food->>'name',
    coalesce(nullif(target_food->>'preparation_state', ''), 'unspecified'),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'search_terms', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'cultural_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'restriction_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'preference_tags', '[]'::jsonb))), '{}'::text[]),
    coalesce(array(select jsonb_array_elements_text(coalesce(target_food->'availability_tags', '[]'::jsonb))), '{}'::text[]),
    nullif(target_food->>'cost_band', ''),
    coalesce((target_food->>'catalog_kind')::public.catalog_kind, 'food'::public.catalog_kind),
    nullif(target_food->>'yield_grams', '')::numeric,
    nullif(target_food->>'serving_grams', '')::numeric,
    nullif(target_food->>'portion_count', '')::numeric,
    nullif(target_food->>'household_measure_label', ''),
    nullif(target_food->>'household_measure_grams', '')::numeric,
    target_food->>'render_path',
    auth.uid()
  )
  returning id into new_food_id;

  for n_item in select elem from jsonb_array_elements(target_nutrients) elem loop
    insert into public.food_nutrient_values (
      food_id, nutrient_id, amount_per_100g, data_version
    )
    values (
      new_food_id,
      (n_item->>'nutrient_id')::uuid,
      coalesce((n_item->>'amount_per_100g')::numeric, 0),
      coalesce(nullif(n_item->>'data_version', ''), 'custom-v1')
    );
  end loop;

  for c_item in select elem from jsonb_array_elements(target_components) elem loop
    insert into public.food_components (
      organization_id, parent_food_id, component_food_id, grams, position
    )
    values (
      org_id,
      new_food_id,
      (c_item->>'component_food_id')::uuid,
      coalesce((c_item->>'grams')::numeric, 0),
      coalesce((c_item->>'position')::integer, 0)
    );
  end loop;

  return new_food_id;
end;
$$;
