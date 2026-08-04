-- Aplicar modelo de plano ao paciente materializando a estrutura salva no snapshot.
-- Os 99 modelos importados (docs/seed/modelos-plano-dietbox.json, migration 20260804000000) guardam
-- as refeições em snapshot.meals e não possuem source_plan_id. copy_plan_template_to_patient passa a
-- construir plan_days/meals/meal_items a partir de snapshot.meals quando não há plano-fonte.
-- O fluxo de confirmação permanece o mesmo: o RPC cria um RASCUNHO (status 'draft') que o profissional
-- revisa e ajusta antes de publicar.

-- Remove overloads antigos (assinaturas sem target_days) para a chamada com 2 args não ficar ambígua.
drop function if exists public.copy_plan_template_to_patient(uuid, uuid);
drop function if exists public.apply_plan_template_to_patient(uuid, uuid);

create or replace function public.copy_plan_template_to_patient(
  target_template_id uuid,
  target_patient_id uuid,
  target_days integer default 1
)
returns public.plans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  t public.plan_templates;
  patient_org uuid;
  result public.plans;
  source_version uuid;
  new_version uuid;
  new_day uuid;
  new_meal uuid;
  day_index integer;
  day_row record;
  meal_row record;
  snapshot_meal jsonb;
  snapshot_item jsonb;
  meal_pos integer;
  item_pos integer;
  meal_food_id uuid;
  item_description text;
begin
  select * into t from public.plan_templates where id = target_template_id;
  select organization_id into patient_org from public.patients where id = target_patient_id;
  if t.id is null or patient_org <> t.organization_id
     or not private.has_organization_role(t.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]) then
    raise exception 'Acesso negado';
  end if;

  insert into public.plans (organization_id, patient_id, created_by, title, status)
  values (t.organization_id, target_patient_id, auth.uid(), t.name, 'draft')
  returning * into result;

  insert into public.plan_versions (organization_id, plan_id, version_no, created_by, change_summary, assistant_state, targets)
  values (
    t.organization_id, result.id, 1, auth.uid(), 'Proposta criada a partir de modelo',
    coalesce(t.snapshot #> '{versions,0,assistant_state}', '{}'::jsonb),
    coalesce(t.snapshot #> '{versions,0,targets}', t.rules->'targets', '{}'::jsonb)
  );
  select id into new_version from public.plan_versions where plan_id = result.id and version_no = 1;

  if t.source_plan_id is not null then
    select id into source_version from public.plan_versions where plan_id = t.source_plan_id order by version_no desc limit 1;
    for day_row in select * from public.plan_days where plan_version_id = source_version order by day_index loop
      insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
      values (t.organization_id, new_version, day_row.day_index, day_row.label, day_row.kind)
      returning id into new_day;
      for meal_row in select * from public.meals where plan_day_id = day_row.id order by position loop
        insert into public.meals (organization_id, plan_day_id, position, label, suggested_time)
        values (t.organization_id, new_day, meal_row.position, meal_row.label, meal_row.suggested_time)
        returning id into new_meal;
        insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot, notes)
        select t.organization_id, new_meal, position, food_id, description, quantity, unit, grams, nutrient_snapshot, notes
        from public.meal_items where meal_id = meal_row.id order by position;
      end loop;
    end loop;
  else
    for day_index in 0..greatest(target_days,1)-1 loop
      insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind)
      values (t.organization_id, new_version, day_index, case when target_days > 1 then 'Dia ' || (day_index+1) else 'Dia 1' end, 'standard')
      returning id into new_day;
      meal_pos := 0;
      for snapshot_meal in select elem from jsonb_array_elements(coalesce(t.snapshot->'meals','[]'::jsonb)) elem loop
        insert into public.meals (organization_id, plan_day_id, position, label, suggested_time)
        values (t.organization_id, new_day, meal_pos, snapshot_meal->>'name', nullif(snapshot_meal->>'time','')::time)
        returning id into new_meal;
        meal_pos := meal_pos + 1;
        item_pos := 0;
        for snapshot_item in select elem from jsonb_array_elements(coalesce(snapshot_meal->'items','[]'::jsonb)) elem loop
          if snapshot_item->>'grams' is not null and (snapshot_item->>'grams')::numeric > 0 then
            item_description := snapshot_item->>'food';
            if snapshot_item->>'measure' is not null and snapshot_item->>'measure' <> '' then
              item_description := item_description || ' (' || (snapshot_item->>'measure') || ')';
            end if;
            select id into meal_food_id
            from public.foods
            where is_active
              and lower(btrim(name)) = lower(btrim(snapshot_item->>'food'))
              and (organization_id = t.organization_id or organization_id is null)
            order by organization_id nulls last, id
            limit 1;
            insert into public.meal_items (organization_id, meal_id, position, food_id, description, quantity, unit, grams, nutrient_snapshot)
            values (t.organization_id, new_meal, item_pos, meal_food_id, item_description,
                    (snapshot_item->>'grams')::numeric, 'g', (snapshot_item->>'grams')::numeric,
                    coalesce(snapshot_item->'macros','{}'::jsonb));
            item_pos := item_pos + 1;
          end if;
        end loop;
      end loop;
    end loop;
  end if;
  return result;
end;
$$;

create or replace function public.apply_plan_template_to_patient(
  target_template_id uuid,
  target_patient_id uuid,
  target_days integer default 1
)
returns public.plans
language plpgsql
security invoker
set search_path = ''
as $$
declare result public.plans; target_values jsonb;
begin
  select rules->'targets' into target_values from public.plan_templates where id = target_template_id;
  select * into result from public.copy_plan_template_to_patient(target_template_id, target_patient_id, target_days);
  update public.plan_versions set targets = coalesce(target_values, targets), change_summary = 'Proposta criada a partir de modelo'
  where plan_id = result.id and version_no = 1;
  return result;
end;
$$;

revoke all on function public.copy_plan_template_to_patient(uuid, uuid, integer) from public, anon;
grant execute on function public.copy_plan_template_to_patient(uuid, uuid, integer) to authenticated;
revoke all on function public.apply_plan_template_to_patient(uuid, uuid, integer) from public, anon;
grant execute on function public.apply_plan_template_to_patient(uuid, uuid, integer) to authenticated;
