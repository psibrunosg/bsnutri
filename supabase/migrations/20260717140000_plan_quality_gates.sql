create or replace function private.plan_target_value(targets jsonb, keys text[])
returns numeric language sql immutable set search_path = '' as $$
  select max((value::text)::numeric)
  from jsonb_each(targets) item(key, value)
  where key = any(keys) and jsonb_typeof(value) = 'number';
$$;

revoke all on function private.plan_target_value(jsonb,text[]) from public, anon, authenticated;

create or replace function private.validate_version_ready(target_version_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare state jsonb; target_targets jsonb;
begin
  select assistant_state, targets into state, target_targets from public.plan_versions where id=target_version_id;
  if not private.plan_assistant_has_steps(state, array['objective','targets','meals','equivalents']) then
    raise exception 'Conclua o assistente do plano antes de revisar';
  end if;
  if not exists (
    select 1 from public.plan_days d join public.meals m on m.plan_day_id=d.id join public.meal_items i on i.meal_id=m.id
    where d.plan_version_id=target_version_id
  ) then raise exception 'A versao precisa ter ao menos um dia, refeicao e item'; end if;
  if exists (
    select 1 from jsonb_each(target_targets) e
    where jsonb_typeof(e.value) <> 'number' or (e.value::text)::numeric < 0
  ) then raise exception 'Metas nutricionais invalidas'; end if;
  if coalesce(private.plan_target_value(target_targets,array['energyKcal','energy_kcal']),0) <= 0
    or coalesce(private.plan_target_value(target_targets,array['proteinG','protein_g']),0) <= 0
    or coalesce(private.plan_target_value(target_targets,array['carbohydrateG','carbohydrate_g']),0) <= 0
    or coalesce(private.plan_target_value(target_targets,array['fatG','fat_g']),0) <= 0
    or coalesce(private.plan_target_value(target_targets,array['fiberG','fiber_g']),0) <= 0
    or coalesce(private.plan_target_value(target_targets,array['waterMl','water_ml','water']),0) <= 0 then
    raise exception 'Informe energia, macros, fibras e agua antes de publicar';
  end if;
  if coalesce(jsonb_array_length(coalesce(state->'priorityMicronutrients','[]'::jsonb)),0) = 0 then
    raise exception 'Informe micronutrientes prioritarios antes de publicar';
  end if;
end;
$$;
