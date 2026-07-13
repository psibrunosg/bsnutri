create type public.substitution_request_status as enum ('requested','approved','rejected','cancelled');

create table public.meal_item_substitutions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_version_id uuid not null,
  meal_item_id uuid not null,
  substitute_food_id uuid references public.foods(id) on delete restrict,
  description text not null check (char_length(trim(description)) between 2 and 180),
  grams numeric(12,4) not null check (grams > 0),
  unit text not null default 'g' check (unit in ('g','ml','unit','portion')),
  professional_note text check (professional_note is null or char_length(professional_note) <= 500),
  nutrient_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(nutrient_snapshot) = 'object'),
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  unique (meal_item_id, substitute_food_id),
  foreign key (plan_version_id, organization_id) references public.plan_versions(id, organization_id) on delete restrict,
  foreign key (meal_item_id, organization_id) references public.meal_items(id, organization_id) on delete restrict
);

create table public.substitution_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  plan_version_id uuid not null,
  meal_item_id uuid not null,
  substitution_id uuid not null,
  requested_by uuid not null references public.profiles(id),
  status public.substitution_request_status not null default 'requested',
  patient_note text check (patient_note is null or char_length(patient_note) <= 500),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  professional_note text check (professional_note is null or char_length(professional_note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete restrict,
  foreign key (plan_version_id, organization_id) references public.plan_versions(id, organization_id) on delete restrict,
  foreign key (meal_item_id, organization_id) references public.meal_items(id, organization_id) on delete restrict,
  foreign key (substitution_id, organization_id) references public.meal_item_substitutions(id, organization_id) on delete restrict
);

create unique index one_open_substitution_request
  on public.substitution_requests(patient_id, meal_item_id)
  where status = 'requested';
create index substitutions_version_idx on public.meal_item_substitutions(plan_version_id, meal_item_id) where is_active;
create index substitution_requests_patient_idx on public.substitution_requests(patient_id, created_at desc);
create index substitution_requests_org_status_idx on public.substitution_requests(organization_id, status, created_at desc);

create trigger substitutions_updated_at before update on public.meal_item_substitutions
for each row execute function private.set_updated_at();
create trigger substitution_requests_updated_at before update on public.substitution_requests
for each row execute function private.set_updated_at();

create or replace function private.validate_substitution_chain()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare food_org uuid;
begin
  if not exists (
    select 1 from public.meal_items i
    join public.meals m on m.id=i.meal_id
    join public.plan_days d on d.id=m.plan_day_id
    join public.plan_versions v on v.id=d.plan_version_id
    where i.id=new.meal_item_id and v.id=new.plan_version_id
      and v.organization_id=new.organization_id
  ) then raise exception 'A substituição deve pertencer ao item e à versão informados'; end if;
  if new.substitute_food_id is not null then
    select organization_id into food_org from public.foods where id=new.substitute_food_id and is_active;
    if not found or (food_org is not null and food_org<>new.organization_id) then
      raise exception 'Alimento substituto indisponível para esta organização';
    end if;
  end if;
  return new;
end; $$;
create trigger substitutions_validate before insert or update on public.meal_item_substitutions
for each row execute function private.validate_substitution_chain();

create or replace function private.guard_published_substitution()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare target_version uuid := case when tg_op='DELETE' then old.plan_version_id else new.plan_version_id end;
begin
  if exists(select 1 from public.plan_versions where id=target_version and locked_at is not null) then
    raise exception 'Alternativas de uma versão publicada são imutáveis';
  end if;
  return case when tg_op='DELETE' then old else new end;
end; $$;
create trigger substitutions_lock_guard before insert or update or delete on public.meal_item_substitutions
for each row execute function private.guard_published_substitution();

create or replace function private.snapshot_substitutions_on_publication()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.locked_at is null and new.locked_at is not null then
    update public.meal_item_substitutions s set nutrient_snapshot=jsonb_build_object(
      'food_id',f.id,'food_name',f.name,'preparation_state',f.preparation_state,'grams',s.grams,
      'source',coalesce(fs.name,'Cadastro profissional'),
      'nutrients',coalesce((select jsonb_agg(jsonb_build_object('code',n.code,'unit',n.unit,'amount_per_100g',v.amount_per_100g,'amount',round(v.amount_per_100g*s.grams/100,6)) order by n.sort_order) from public.food_nutrient_values v join public.nutrients n on n.id=v.nutrient_id where v.food_id=f.id),'[]'::jsonb)
    ) from public.foods f left join public.food_sources fs on fs.id=f.source_id
    where s.plan_version_id=new.id and s.substitute_food_id=f.id;
  end if;
  return new;
end; $$;
create trigger versions_snapshot_substitutions before update of locked_at on public.plan_versions
for each row execute function private.snapshot_substitutions_on_publication();

create or replace function private.validate_substitution_request_chain()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if not exists (
    select 1 from public.meal_item_substitutions s
    join public.plans p on p.current_published_version_id=s.plan_version_id
    where s.id=new.substitution_id and s.organization_id=new.organization_id
      and s.plan_version_id=new.plan_version_id and s.meal_item_id=new.meal_item_id
      and s.is_active and p.patient_id=new.patient_id and p.status in ('published','scheduled')
  ) then raise exception 'Substituição indisponível para o plano vigente'; end if;
  return new;
end; $$;
create trigger substitution_requests_validate before insert or update of organization_id,patient_id,plan_version_id,meal_item_id,substitution_id
on public.substitution_requests for each row execute function private.validate_substitution_request_chain();

create or replace function private.guard_substitution_request_workflow()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.organization_id<>new.organization_id or old.patient_id<>new.patient_id
    or old.plan_version_id<>new.plan_version_id or old.meal_item_id<>new.meal_item_id
    or old.substitution_id<>new.substitution_id or old.requested_by<>new.requested_by then
    raise exception 'O conteúdo da solicitação é imutável';
  end if;
  if old.status<>'requested' or new.status not in ('approved','rejected','cancelled') then
    raise exception 'Transição de solicitação inválida';
  end if;
  return new;
end; $$;
create trigger substitution_request_workflow before update on public.substitution_requests
for each row execute function private.guard_substitution_request_workflow();

create or replace function public.review_substitution_request(target_request_id uuid, target_status public.substitution_request_status, target_note text default null)
returns public.substitution_requests language plpgsql security invoker set search_path = '' as $$
declare result public.substitution_requests;
begin
  if target_status not in ('approved','rejected') then raise exception 'Decisão inválida'; end if;
  update public.substitution_requests r set status=target_status, professional_note=nullif(trim(target_note),''),
    reviewed_by=(select auth.uid()), reviewed_at=now()
  where r.id=target_request_id and r.status='requested'
    and private.has_organization_role(r.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  returning * into result;
  if result.id is null then raise exception 'Solicitação não encontrada ou já revisada'; end if;
  return result;
end; $$;

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
    round(sum(i.grams*sd.repetitions),2) total_grams, sum(sd.repetitions) occurrences
  from selected_days sd join public.meals m on m.plan_day_id=sd.id join public.meal_items i on i.meal_id=m.id
  group by coalesce(i.nutrient_snapshot->>'food_id',i.id::text),coalesce(i.nutrient_snapshot->>'food_name',i.description)
  order by 2;
end; $$;

alter table public.meal_item_substitutions enable row level security;
alter table public.substitution_requests enable row level security;

create policy substitutions_select on public.meal_item_substitutions for select to authenticated using (
  private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  or (is_active and exists(select 1 from public.plans p where p.current_published_version_id=plan_version_id and p.status in ('published','scheduled') and private.can_access_patient(p.patient_id)))
);
create policy substitutions_insert on public.meal_item_substitutions for insert to authenticated with check (
  created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
);
create policy substitutions_update on public.meal_item_substitutions for update to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy substitution_requests_select on public.substitution_requests for select to authenticated using (
  private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])
  or private.can_access_patient(patient_id)
);
create policy substitution_requests_insert on public.substitution_requests for insert to authenticated with check (
  requested_by=(select auth.uid()) and status='requested' and reviewed_by is null and reviewed_at is null
  and private.can_access_patient(patient_id)
);
create policy substitution_requests_review on public.substitution_requests for update to authenticated
using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

grant select,insert,update on public.meal_item_substitutions,public.substitution_requests to authenticated;
revoke all on function public.review_substitution_request(uuid,public.substitution_request_status,text) from public,anon;
grant execute on function public.review_substitution_request(uuid,public.substitution_request_status,text) to authenticated;
revoke all on function public.get_current_shopping_list(uuid,integer) from public,anon;
grant execute on function public.get_current_shopping_list(uuid,integer) to authenticated;
