create type public.clinical_draft_kind as enum ('summary','guidance','plan_structure');
create type public.clinical_draft_status as enum ('draft','approved','discarded');

create table public.clinical_drafts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null,
  kind public.clinical_draft_kind not null,
  source_snapshot jsonb not null default '{}'::jsonb,
  body text not null check (char_length(trim(body)) between 2 and 12000),
  provider text not null default 'structured-local',
  status public.clinical_draft_status not null default 'draft',
  created_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint clinical_drafts_patient_tenant_fkey foreign key (patient_id,organization_id) references public.patients(id,organization_id) on delete cascade,
  check ((status='draft' and reviewed_by is null and reviewed_at is null) or (status in ('approved','discarded') and reviewed_by is not null and reviewed_at is not null))
);

create table public.organization_branding (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  public_name text not null check (char_length(trim(public_name)) between 2 and 120),
  primary_color text not null default '#3e6b5c' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  logo_url text,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);

create index clinical_drafts_patient_idx on public.clinical_drafts(patient_id,created_at desc);
alter table public.clinical_drafts enable row level security;
alter table public.organization_branding enable row level security;

create policy clinical_drafts_select_team on public.clinical_drafts for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy clinical_drafts_insert_team on public.clinical_drafts for insert to authenticated with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy clinical_drafts_update_team on public.clinical_drafts for update to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy organization_branding_member_read on public.organization_branding for select to authenticated using (public.is_active_member(organization_id) or exists(select 1 from public.patients p where p.organization_id=organization_branding.organization_id and private.can_access_patient(p.id)));
create policy organization_branding_admin_write on public.organization_branding for all to authenticated using (private.has_organization_role(organization_id,array['owner','admin']::public.organization_role[])) with check (updated_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin']::public.organization_role[]));

create or replace function public.review_clinical_draft(target_draft_id uuid,target_status public.clinical_draft_status)
returns public.clinical_drafts language plpgsql security invoker set search_path='' as $$
declare result public.clinical_drafts;
begin
 if target_status not in ('approved','discarded') then raise exception 'Status de revisão inválido'; end if;
 update public.clinical_drafts set status=target_status,reviewed_by=auth.uid(),reviewed_at=now() where id=target_draft_id and status='draft' and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) returning * into result;
 if result.id is null then raise exception 'Rascunho indisponível'; end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(result.organization_id,auth.uid(),'clinical_draft_'||target_status::text,'clinical_draft',result.id,jsonb_build_object('kind',result.kind,'provider',result.provider));
 return result;
end; $$;

create or replace function public.audit_clinical_export(target_patient_id uuid,target_kind text)
returns void language plpgsql security invoker set search_path='' as $$
declare org_id uuid;
begin
 select organization_id into org_id from public.patients where id=target_patient_id;
 if org_id is null or not private.has_organization_role(org_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 insert into public.audit_events(organization_id,actor_id,action,entity_type,entity_id,metadata) values(org_id,auth.uid(),'clinical_export','patient',target_patient_id,jsonb_build_object('kind',target_kind));
end; $$;

grant select,insert,update,delete on public.clinical_drafts,public.organization_branding to authenticated;
grant execute on function public.review_clinical_draft(uuid,public.clinical_draft_status),public.audit_clinical_export(uuid,text) to authenticated;
