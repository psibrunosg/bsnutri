create type public.catalog_kind as enum ('food','preparation','combination');

alter table public.foods
  add column catalog_kind public.catalog_kind not null default 'food',
  add column yield_grams numeric(12,3) check (yield_grams is null or yield_grams > 0),
  add column serving_grams numeric(12,3) check (serving_grams is null or serving_grams > 0),
  add constraint foods_composite_yield_check check (
    (catalog_kind = 'food' and yield_grams is null)
    or (catalog_kind in ('preparation','combination') and yield_grams is not null)
  );

create table public.food_components (
  parent_food_id uuid not null references public.foods(id) on delete cascade,
  component_food_id uuid not null references public.foods(id),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  grams numeric(12,3) not null check (grams > 0),
  position smallint not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  primary key (parent_food_id, component_food_id),
  check (parent_food_id <> component_food_id)
);

create index food_components_organization_idx on public.food_components(organization_id);
create index food_components_component_idx on public.food_components(component_food_id);

alter table public.food_components enable row level security;

create policy food_components_read on public.food_components
for select to authenticated
using (
  private.is_active_member(organization_id)
  and exists (
    select 1 from public.foods parent
    where parent.id = parent_food_id
      and parent.organization_id = food_components.organization_id
      and parent.catalog_kind in ('preparation','combination')
  )
);

create policy food_components_insert_clinical on public.food_components
for insert to authenticated
with check (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and exists (
    select 1 from public.foods parent
    where parent.id = parent_food_id
      and parent.organization_id = food_components.organization_id
      and parent.catalog_kind in ('preparation','combination')
  )
  and exists (
    select 1 from public.foods component
    where component.id = component_food_id
      and (component.organization_id is null or component.organization_id = food_components.organization_id)
  )
);

create policy food_components_update_clinical on public.food_components
for update to authenticated
using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (
  private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])
  and exists (
    select 1 from public.foods parent
    where parent.id = parent_food_id
      and parent.organization_id = food_components.organization_id
      and parent.catalog_kind in ('preparation','combination')
  )
  and exists (
    select 1 from public.foods component
    where component.id = component_food_id
      and (component.organization_id is null or component.organization_id = food_components.organization_id)
  )
);

create policy food_components_delete_clinical on public.food_components
for delete to authenticated
using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

grant select, insert, update, delete on public.food_components to authenticated;
