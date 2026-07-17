create or replace function public.get_current_shopping_list(target_patient_id uuid, target_days integer default 7)
returns table(item_key text, description text, total_grams numeric, occurrences bigint)
language plpgsql stable security invoker set search_path = '' as $$
begin
  if target_days not between 1 and 31 then raise exception 'O período deve ter entre 1 e 31 dias'; end if;
  if not private.can_access_patient(target_patient_id) then raise exception 'Acesso negado'; end if;
  return query
  with current_version as (
    select p.current_published_version_id id
    from public.plans p where p.patient_id=target_patient_id and p.status in ('published','scheduled')
      and p.current_published_version_id is not null order by p.published_at desc nulls last limit 1
  ), cycle as (
    select greatest(count(*),1)::integer day_count from public.plan_days d join current_version v on v.id=d.plan_version_id
  ), selected_days as (
    select d.id, count(*)::bigint repetitions
    from generate_series(0,target_days-1) g(day_number)
    join cycle c on true
    join public.plan_days d on d.day_index=(g.day_number % c.day_count)
    join current_version v on v.id=d.plan_version_id group by d.id
  )
  select coalesce(i.nutrient_snapshot->>'food_id',i.id::text) item_key,
    coalesce(i.nutrient_snapshot->>'food_name',i.description) description,
    round(sum(i.grams*sd.repetitions),2) total_grams,
    sum(sd.repetitions)::bigint occurrences
  from selected_days sd join public.meals m on m.plan_day_id=sd.id join public.meal_items i on i.meal_id=m.id
  group by coalesce(i.nutrient_snapshot->>'food_id',i.id::text),coalesce(i.nutrient_snapshot->>'food_name',i.description)
  order by 2;
end;
$$;
