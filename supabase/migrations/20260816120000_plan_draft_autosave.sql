-- Task 5: autosave do rascunho aberto no próprio banco.
-- O autosave anterior gravava o plano inteiro em localStorage. Nenhum dado clínico
-- pode permanecer no navegador, então a gravação automática passa a acontecer na
-- versão de rascunho aberta, sem criar um novo plano a cada tecla.
-- Versão bloqueada ou plano publicado continuam imutáveis.

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
      insert into public.meals (organization_id, plan_day_id, position, label)
      values (plan_row.organization_id, new_day, coalesce((meal_json->>'position')::integer, meal_pos), coalesce(meal_json->>'label', 'Refeição'))
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
