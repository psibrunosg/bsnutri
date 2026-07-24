alter table public.foods
  add column search_terms text[] not null default '{}',
  add column cultural_tags text[] not null default '{}',
  add column restriction_tags text[] not null default '{}',
  add column preference_tags text[] not null default '{}',
  add column availability_tags text[] not null default '{}',
  add column cost_band text check (cost_band in ('low','medium','high'));

create index foods_search_terms_idx on public.foods using gin (search_terms);
create index foods_cultural_tags_idx on public.foods using gin (cultural_tags);
create index foods_restriction_tags_idx on public.foods using gin (restriction_tags);
create index foods_preference_tags_idx on public.foods using gin (preference_tags);
create index foods_availability_tags_idx on public.foods using gin (availability_tags);

create table public.food_user_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  food_id uuid not null references public.foods(id) on delete cascade,
  is_favorite boolean not null default false,
  last_used_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, food_id)
);

create index food_user_preferences_recent_idx on public.food_user_preferences(user_id, last_used_at desc nulls last);

alter table public.food_user_preferences enable row level security;

create policy food_user_preferences_own on public.food_user_preferences
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.food_user_preferences to authenticated;
