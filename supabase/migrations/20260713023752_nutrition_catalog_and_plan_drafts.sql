create type public.plan_status as enum ('draft','in_review','reviewed','approved','scheduled','published','superseded','archived');
create type public.day_kind as enum ('standard','training','rest','shift','weekend','custom');

create table public.food_sources (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  license_name text not null,
  license_url text,
  attribution_text text not null,
  dataset_version text not null,
  released_on date,
  imported_at timestamptz not null default now()
);

create table public.nutrients (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  unit text not null check (unit in ('kcal','kJ','g','mg','µg')),
  decimals smallint not null default 2 check (decimals between 0 and 6),
  sort_order smallint not null default 0
);

create table public.foods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  source_id uuid references public.food_sources(id),
  source_food_code text,
  name text not null check (char_length(trim(name)) between 2 and 180),
  preparation_state text not null default 'unspecified',
  edible_portion_pct numeric(5,2) not null default 100 check (edible_portion_pct > 0 and edible_portion_pct <= 100),
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((organization_id is null and source_id is not null and created_by is null) or (organization_id is not null and created_by is not null))
);
create unique index foods_global_source_unique on public.foods(source_id, source_food_code) where organization_id is null;
create unique index foods_org_name_state_unique on public.foods(organization_id, lower(name), preparation_state) where organization_id is not null;
create index foods_search_idx on public.foods(lower(name));

create table public.food_nutrient_values (
  food_id uuid not null references public.foods(id) on delete cascade,
  nutrient_id uuid not null references public.nutrients(id),
  amount_per_100g numeric(18,6) check (amount_per_100g >= 0),
  source_basis text not null default '100g_edible' check (source_basis = '100g_edible'),
  data_version text not null,
  created_at timestamptz not null default now(),
  primary key (food_id, nutrient_id)
);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  created_by uuid not null references public.profiles(id),
  title text not null default 'Plano alimentar',
  status public.plan_status not null default 'draft',
  starts_on date,
  ends_on date,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  published_by uuid references public.profiles(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id),
  foreign key (patient_id, organization_id) references public.patients(id, organization_id) on delete restrict,
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);

create table public.plan_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_id uuid not null,
  version_no integer not null check (version_no > 0),
  change_summary text,
  created_by uuid not null references public.profiles(id),
  ai_generated boolean not null default false,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, organization_id),
  unique (plan_id, version_no),
  foreign key (plan_id, organization_id) references public.plans(id, organization_id) on delete cascade
);

create table public.plan_days (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_version_id uuid not null,
  day_index integer not null check (day_index >= 0),
  label text not null,
  kind public.day_kind not null default 'standard',
  weekday smallint check (weekday between 0 and 6),
  unique (id, organization_id),
  unique (plan_version_id, day_index),
  foreign key (plan_version_id, organization_id) references public.plan_versions(id, organization_id) on delete cascade
);

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_day_id uuid not null,
  position integer not null check (position >= 0),
  label text not null,
  suggested_time time,
  unique (id, organization_id),
  unique (plan_day_id, position),
  foreign key (plan_day_id, organization_id) references public.plan_days(id, organization_id) on delete cascade
);

create table public.meal_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  meal_id uuid not null,
  position integer not null check (position >= 0),
  food_id uuid references public.foods(id),
  description text not null,
  quantity numeric(12,4) not null check (quantity > 0),
  unit text not null check (unit in ('g','ml','unit','portion')),
  grams numeric(12,4) not null check (grams > 0),
  nutrient_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(nutrient_snapshot) = 'object'),
  notes text,
  unique (meal_id, position),
  foreign key (meal_id, organization_id) references public.meals(id, organization_id) on delete cascade
);

create index food_nutrients_food_idx on public.food_nutrient_values(food_id);
create index plans_patient_idx on public.plans(organization_id, patient_id, status);
create index plan_versions_plan_idx on public.plan_versions(plan_id, version_no desc);
create index plan_days_version_idx on public.plan_days(plan_version_id, day_index);
create index meals_day_idx on public.meals(plan_day_id, position);
create index meal_items_meal_idx on public.meal_items(meal_id, position);

create trigger foods_set_updated_at before update on public.foods for each row execute function private.set_updated_at();
create trigger plans_set_updated_at before update on public.plans for each row execute function private.set_updated_at();

create or replace function private.validate_meal_item_food_tenant()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare food_org uuid;
begin
  if new.food_id is null then return new; end if;
  select organization_id into food_org from public.foods where id = new.food_id;
  if not found or (food_org is not null and food_org <> new.organization_id) then
    raise exception 'Alimento não pertence à organização do plano';
  end if;
  return new;
end; $$;
create trigger meal_items_validate_food before insert or update on public.meal_items
for each row execute function private.validate_meal_item_food_tenant();

alter table public.food_sources enable row level security;
alter table public.nutrients enable row level security;
alter table public.foods enable row level security;
alter table public.food_nutrient_values enable row level security;
alter table public.plans enable row level security;
alter table public.plan_versions enable row level security;
alter table public.plan_days enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;

create policy food_sources_read on public.food_sources for select to authenticated using (true);
create policy nutrients_read on public.nutrients for select to authenticated using (true);
create policy food_values_read on public.food_nutrient_values for select to authenticated
using (exists (select 1 from public.foods f where f.id = food_id and (f.organization_id is null or private.is_active_member(f.organization_id))));

create policy foods_read on public.foods for select to authenticated
using (organization_id is null or private.is_active_member(organization_id));
create policy foods_insert_clinical on public.foods for insert to authenticated
with check (organization_id is not null and created_by = auth.uid() and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy foods_update_clinical on public.foods for update to authenticated
using (organization_id is not null and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]))
with check (organization_id is not null and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy food_values_insert_custom on public.food_nutrient_values for insert to authenticated
with check (exists (select 1 from public.foods f where f.id = food_id and f.organization_id is not null and f.created_by = auth.uid() and private.is_active_member(f.organization_id)));
create policy food_values_update_custom on public.food_nutrient_values for update to authenticated
using (exists (select 1 from public.foods f where f.id = food_id and f.organization_id is not null and private.has_organization_role(f.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])))
with check (exists (select 1 from public.foods f where f.id = food_id and f.organization_id is not null and private.has_organization_role(f.organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])));

create policy plans_read_clinical on public.plans for select to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy plans_insert_clinical on public.plans for insert to authenticated with check (created_by = auth.uid() and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy plans_update_clinical on public.plans for update to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

create policy versions_clinical on public.plan_versions for all to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])) with check (created_by = auth.uid() and private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy days_clinical on public.plan_days for all to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy meals_clinical on public.meals for all to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy items_clinical on public.meal_items for all to authenticated using (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id, array['owner','admin','nutritionist','student']::public.organization_role[]));

grant select on public.food_sources, public.nutrients to authenticated;
grant select, insert, update on public.foods, public.food_nutrient_values to authenticated;
grant select, insert, update on public.plans to authenticated;
grant select, insert, update, delete on public.plan_versions, public.plan_days, public.meals, public.meal_items to authenticated;
