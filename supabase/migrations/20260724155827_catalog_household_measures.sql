alter table public.foods
  add column household_measure_label text,
  add column household_measure_grams numeric(12,3) check (household_measure_grams is null or household_measure_grams > 0),
  add constraint foods_household_measure_complete check (
    (household_measure_label is null and household_measure_grams is null)
    or (length(trim(household_measure_label)) > 0 and household_measure_grams is not null)
  );
