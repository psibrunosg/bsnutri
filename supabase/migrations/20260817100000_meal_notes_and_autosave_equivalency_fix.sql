-- Duas mudanças relacionadas ao importador de plano a partir de texto Dietbox:
--
-- 1. `meals.notes` — o cardápio exportado do Dietbox traz uma observação de texto livre
--    por refeição ("Observações: ..."). Sem uma coluna própria, essa informação se perderia
--    na importação.
--
-- 2. Correção de bug pré-existente: `autosave_plan_version` reconstrói `plan_days`/`meals`/
--    `meal_items` a cada gravação automática, mas o `insert into public.meals` nunca incluiu
--    `equivalency_list_id` — diferente de `save_plan_draft`, que sempre gravou essa coluna.
--    Resultado: qualquer refeição vinculada a uma lista de substituição perdia esse vínculo
--    silenciosamente na primeira gravação automática seguinte. Isso anularia o mapeamento de
--    grupos de substituição feito pelo importador Dietbox assim que o profissional editasse
--    qualquer coisa no plano.

alter table public.meals
  add column notes text check (notes is null or char_length(notes) <= 2000);

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

      insert into public.meals (organization_id, plan_day_id, position, label, equivalency_list_id, notes)
      values (
        target_organization_id,
        new_day,
        coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', meal_json->>'name', 'Refeição'),
        eq_list_id,
        nullif(trim(meal_json->>'notes'), '')
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

revoke all on function public.save_plan_draft(uuid, uuid, text, text, jsonb, jsonb, jsonb, uuid) from public, anon;
grant execute on function public.save_plan_draft(uuid, uuid, text, text, jsonb, jsonb, jsonb, uuid) to authenticated;

create or replace function public.autosave_plan_version(
  target_plan_id uuid,
  target_version_id uuid,
  target_assistant_state jsonb,
  target_targets jsonb,
  target_days jsonb
) returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  plan_row public.plans;
  new_day uuid;
  new_meal uuid;
  day_json jsonb;
  meal_json jsonb;
  item_json jsonb;
  day_idx integer := 0;
  meal_pos integer;
  item_pos integer;
  eq_list_id uuid;
begin
  select * into plan_row from public.plans where id = target_plan_id;
  if plan_row.id is null
     or not private.has_organization_role(plan_row.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado ao plano' using errcode = '42501';
  end if;

  if plan_row.status <> 'draft' then
    raise exception 'Somente rascunho aceita gravação automática' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.plan_versions
     where id = target_version_id and plan_id = target_plan_id and locked_at is null
  ) then
    raise exception 'Versão inválida ou bloqueada' using errcode = '42501';
  end if;

  if jsonb_array_length(coalesce(target_days, '[]'::jsonb)) = 0 then
    raise exception 'Estrutura de dias vazia no plano';
  end if;

  delete from public.plan_days where plan_version_id = target_version_id;

  for day_json in select elem from jsonb_array_elements(target_days) elem loop
    insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
    values (
      plan_row.organization_id,
      target_version_id,
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

      insert into public.meals (organization_id, plan_day_id, position, label, equivalency_list_id, notes)
      values (
        plan_row.organization_id, new_day, coalesce((meal_json->>'position')::integer, meal_pos),
        coalesce(meal_json->>'label', 'Refeição'), eq_list_id, nullif(trim(meal_json->>'notes'), '')
      )
      returning id into new_meal;
      meal_pos := meal_pos + 1;

      item_pos := 0;
      for item_json in select elem from jsonb_array_elements(coalesce(meal_json->'items', '[]'::jsonb)) elem loop
        if coalesce((item_json->>'grams')::numeric, 0) > 0 then
          insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot)
          values (
            plan_row.organization_id, new_meal, coalesce((item_json->>'position')::integer, item_pos),
            nullif(item_json->>'food_id', '')::uuid,
            coalesce(item_json->>'description', 'Item'),
            (item_json->>'grams')::numeric, 'g', (item_json->>'grams')::numeric,
            coalesce(item_json->'nutrient_snapshot', '{}'::jsonb)
          );
          item_pos := item_pos + 1;
        end if;
      end loop;
    end loop;
  end loop;

  update public.plan_versions
     set assistant_state = coalesce(target_assistant_state, assistant_state),
         targets = coalesce(target_targets, targets)
   where id = target_version_id;

  update public.plans set updated_at = now() where id = target_plan_id;

  return now();
end;
$$;

revoke all on function public.autosave_plan_version(uuid, uuid, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.autosave_plan_version(uuid, uuid, jsonb, jsonb, jsonb) to authenticated;
