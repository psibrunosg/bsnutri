alter table public.foods
  add column portion_count numeric(12,3) check (portion_count is null or portion_count > 0);
