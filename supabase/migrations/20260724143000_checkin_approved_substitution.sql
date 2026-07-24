alter table public.meal_checkins add column substitution_request_id uuid references public.substitution_requests(id) on delete set null;

create or replace function private.validate_checkin_substitution()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.substitution_request_id is not null and not exists (
    select 1 from public.substitution_requests r
    where r.id=new.substitution_request_id and r.organization_id=new.organization_id
      and r.patient_id=new.patient_id and r.plan_version_id=new.plan_version_id
      and r.meal_item_id in (select i.id from public.meal_items i where i.meal_id=new.meal_id)
      and r.status='approved'
  ) then raise exception 'A troca registrada deve ser aprovada e pertencer a esta refeição'; end if;
  return new;
end; $$;
create trigger meal_checkins_validate_substitution before insert or update of substitution_request_id,organization_id,patient_id,plan_version_id,meal_id on public.meal_checkins
for each row execute function private.validate_checkin_substitution();
