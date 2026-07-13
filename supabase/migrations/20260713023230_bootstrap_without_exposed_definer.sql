create or replace function private.bootstrap_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or new.created_by <> auth.uid() then
    raise exception 'Organização deve ser criada pelo usuário autenticado';
  end if;
  if exists (select 1 from public.memberships where user_id = auth.uid() and status = 'active') then
    raise exception 'Usuário já possui uma organização ativa';
  end if;
  insert into public.memberships (organization_id, user_id, role, status)
  values (new.id, auth.uid(), 'owner', 'active');
  return new;
end;
$$;

revoke all on function private.bootstrap_owner_membership() from public, anon, authenticated;

create trigger organizations_bootstrap_owner
after insert on public.organizations
for each row execute function private.bootstrap_owner_membership();

create or replace function public.bootstrap_organization(
  full_name_input text,
  organization_name_input text,
  organization_slug_input text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  new_organization_id uuid;
begin
  if current_user_id is null then
    raise exception 'Autenticação obrigatória';
  end if;
  if char_length(trim(full_name_input)) < 2 then
    raise exception 'Nome completo inválido';
  end if;
  if char_length(trim(organization_name_input)) < 2 then
    raise exception 'Nome da clínica inválido';
  end if;
  if organization_slug_input !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Identificador da clínica inválido';
  end if;

  insert into public.profiles (id, full_name)
  values (current_user_id, trim(full_name_input))
  on conflict (id) do update set full_name = excluded.full_name;

  insert into public.organizations (name, slug, created_by)
  values (trim(organization_name_input), organization_slug_input, current_user_id)
  returning id into new_organization_id;

  return new_organization_id;
end;
$$;
