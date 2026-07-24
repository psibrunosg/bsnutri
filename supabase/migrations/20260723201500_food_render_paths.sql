alter table public.foods
  add column if not exists render_path text;

alter table public.foods
  drop constraint if exists foods_render_path_webp;

alter table public.foods
  add constraint foods_render_path_webp
  check (render_path is null or render_path ~ '^/food-renders/[a-z0-9][a-z0-9-]*\\.webp$');

comment on column public.foods.render_path is
  'Caminho público de render WebP curado e versionado no repositório, por exemplo /food-renders/arroz-integral.webp.';
