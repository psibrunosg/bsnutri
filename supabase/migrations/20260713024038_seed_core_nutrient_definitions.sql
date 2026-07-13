insert into public.nutrients (code, name, unit, decimals, sort_order) values
  ('energy_kcal', 'Energia', 'kcal', 1, 10),
  ('protein_g', 'Proteínas', 'g', 2, 20),
  ('carbohydrate_g', 'Carboidratos', 'g', 2, 30),
  ('fat_g', 'Gorduras totais', 'g', 2, 40),
  ('fiber_g', 'Fibras alimentares', 'g', 2, 50)
on conflict (code) do update set
  name = excluded.name,
  unit = excluded.unit,
  decimals = excluded.decimals,
  sort_order = excluded.sort_order;
