-- `20260717140000_plan_quality_gates.sql` acrescentou a `validate_version_ready` a
-- exigência de metas obrigatórias (energia, macros, fibra e água) e de
-- micronutrientes prioritários. Vinte minutos depois,
-- `20260717163138_plan_assistant_shell.sql` recriou a mesma função sem essas
-- verificações, revertendo o portão em silêncio.
--
-- Esta migration restaura a definição completa: revisão e publicação voltam a
-- exigir metas informadas, como a suíte `publication_portal` sempre esperou.

create or replace function private.validate_version_ready(target_version_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare state jsonb; target_targets jsonb;
begin
  select assistant_state, targets into state, target_targets from public.plan_versions where id = target_version_id;

  if not private.plan_assistant_has_steps(state, array['objective','targets','meals','equivalents']) then
    raise exception 'Conclua o assistente do plano antes de revisar';
  end if;

  if not exists (
    select 1 from public.plan_days d
      join public.meals m on m.plan_day_id = d.id
      join public.meal_items i on i.meal_id = m.id
    where d.plan_version_id = target_version_id
  ) then
    raise exception 'A versao precisa ter ao menos um dia, refeicao e item';
  end if;

  if exists (
    select 1 from jsonb_each(target_targets) e
    where jsonb_typeof(e.value) <> 'number' or (e.value::text)::numeric < 0
  ) then
    raise exception 'Metas nutricionais invalidas';
  end if;

  if coalesce(private.plan_target_value(target_targets, array['energyKcal','energy_kcal']), 0) <= 0
    or coalesce(private.plan_target_value(target_targets, array['proteinG','protein_g']), 0) <= 0
    or coalesce(private.plan_target_value(target_targets, array['carbohydrateG','carbohydrate_g']), 0) <= 0
    or coalesce(private.plan_target_value(target_targets, array['fatG','fat_g']), 0) <= 0
    or coalesce(private.plan_target_value(target_targets, array['fiberG','fiber_g']), 0) <= 0
    or coalesce(private.plan_target_value(target_targets, array['waterMl','water_ml','water']), 0) <= 0 then
    raise exception 'Informe energia, macros, fibras e agua antes de publicar';
  end if;

  if coalesce(jsonb_array_length(coalesce(state->'priorityMicronutrients','[]'::jsonb)), 0) = 0 then
    raise exception 'Informe micronutrientes prioritarios antes de publicar';
  end if;
end;
$$;

revoke all on function private.validate_version_ready(uuid) from public, anon;
grant execute on function private.validate_version_ready(uuid) to authenticated;
