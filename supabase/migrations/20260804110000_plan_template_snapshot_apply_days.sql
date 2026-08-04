-- Aplicar modelo de plano com escolha de N dias da semana.
-- copy_plan_template_to_patient passa a aceitar target_weekdays text[] (códigos ISO: mon..sun).
-- Quando informado, cria um dia por dia da semana selecionado, grava plan_days.weekday
-- (smallint: 0=Segunda-feira ... 6=Domingo) e usa o nome do dia como label.
-- Sem target_weekdays, mantém o comportamento anterior (target_days genéricos "Dia N").

drop function if exists public.copy_plan_template_to_patient(uuid, uuid);
drop function if exists public.copy_plan_template_to_patient(uuid, uuid, integer);
drop function if exists public.apply_plan_template_to_patient(uuid, uuid);
drop function if exists public.apply_plan_template_to_patient(uuid, uuid, integer);

create or replace function public.copy_plan_template_to_patient(
  target_template_id uuid,
  target_patient_id uuid,
  target_days integer default 1,
  target_weekdays text[] default null
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
  day_desc jsonb;
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
    if target_weekdays is not null and array_length(target_weekdays, 1) > 0 then
      select coalesce(jsonb_agg(jsonb_build_object('index', w.idx, 'label', w.label, 'weekday', w.code) order by w.idx), '[]'::jsonb)
      into day_desc
      from (
        select un.idx, un.wd,
               case un.wd when 'mon' then 'Segunda-feira' when 'tue' then 'Terça-feira' when 'wed' then 'Quarta-feira'
                          when 'thu' then 'Quinta-feira' when 'fri' then 'Sexta-feira' when 'sat' then 'Sábado'
                          when 'sun' then 'Domingo' end as label,
               case un.wd when 'mon' then 0 when 'tue' then 1 when 'wed' then 2 when 'thu' then 3
                          when 'fri' then 4 when 'sat' then 5 when 'sun' then 6 end as code
        from unnest(target_weekdays) with ordinality as un(wd, idx)
      ) w
      where w.label is not null;
    else
      select jsonb_agg(jsonb_build_object('index', g, 'label', case when target_days > 1 then 'Dia ' || (g+1) else 'Dia 1' end, 'weekday', null))
      into day_desc
      from generate_series(0, greatest(target_days, 1) - 1) g;
    end if;

    for day_row in
      select (elem->>'index')::int as day_index, elem->>'label' as label, (elem->>'weekday')::smallint as weekday
      from jsonb_array_elements(coalesce(day_desc, '[]'::jsonb)) elem
    loop
      insert into public.plan_days (organization_id, plan_version_id, day_index, label, kind, weekday)
      values (t.organization_id, new_version, day_row.day_index, day_row.label, 'standard', day_row.weekday)
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
  target_days integer default 1,
  target_weekdays text[] default null
)
returns public.plans
language plpgsql
security invoker
set search_path = ''
as $$
declare result public.plans; target_values jsonb;
begin
  select rules->'targets' into target_values from public.plan_templates where id = target_template_id;
  select * into result from public.copy_plan_template_to_patient(target_template_id, target_patient_id, target_days, target_weekdays);
  update public.plan_versions set targets = coalesce(target_values, targets), change_summary = 'Proposta criada a partir de modelo'
  where plan_id = result.id and version_no = 1;
  return result;
end;
$$;

revoke all on function public.copy_plan_template_to_patient(uuid, uuid, integer, text[]) from public, anon;
grant execute on function public.copy_plan_template_to_patient(uuid, uuid, integer, text[]) to authenticated;
revoke all on function public.apply_plan_template_to_patient(uuid, uuid, integer, text[]) from public, anon;
grant execute on function public.apply_plan_template_to_patient(uuid, uuid, integer, text[]) to authenticated;
