create type public.form_field_type as enum ('short_text','long_text','number','scale','select','date');
create type public.form_assignment_status as enum ('pending','draft','submitted');

create table public.form_templates (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null check (char_length(trim(name)) between 2 and 120),
 purpose text not null default 'pre_consultation',
 status text not null default 'draft' check (status in ('draft','published','archived')),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now()
);

create table public.form_template_versions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 template_id uuid not null references public.form_templates(id) on delete cascade,
 version_no integer not null,
 title text not null,
 published_at timestamptz not null default now(),
 published_by uuid not null references public.profiles(id),
 unique(template_id,version_no)
);

create table public.form_fields (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 version_id uuid not null references public.form_template_versions(id) on delete cascade,
 position integer not null,
 label text not null check (char_length(trim(label)) between 2 and 160),
 field_type public.form_field_type not null,
 required boolean not null default false,
 options jsonb not null default '[]'::jsonb,
 unique(version_id,position)
);

create table public.form_assignments (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null,
 version_id uuid not null references public.form_template_versions(id),
 status public.form_assignment_status not null default 'pending',
 assigned_by uuid not null references public.profiles(id),
 assigned_at timestamptz not null default now(),
 submitted_at timestamptz,
 constraint form_assignments_patient_tenant_fkey foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete cascade
);

create table public.form_responses (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 assignment_id uuid not null references public.form_assignments(id) on delete cascade,
 patient_id uuid not null,
 version_id uuid not null references public.form_template_versions(id),
 values jsonb not null default '{}'::jsonb,
 status public.form_assignment_status not null default 'draft',
 created_by uuid not null references public.profiles(id),
 updated_at timestamptz not null default now(),
 submitted_at timestamptz,
 constraint form_responses_patient_tenant_fkey foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete cascade
);

create table public.consultation_summaries (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 patient_id uuid not null,
 summary text not null check (char_length(trim(summary)) between 2 and 4000),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 constraint consultation_summaries_patient_tenant_fkey foreign key(patient_id,organization_id) references public.patients(id,organization_id) on delete cascade
);

create table public.plan_templates (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 source_plan_id uuid references public.plans(id) on delete set null,
 name text not null check (char_length(trim(name)) between 2 and 140),
 objective text,
 tags text[] not null default '{}',
 snapshot jsonb not null,
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table public.form_templates enable row level security;
alter table public.form_template_versions enable row level security;
alter table public.form_fields enable row level security;
alter table public.form_assignments enable row level security;
alter table public.form_responses enable row level security;
alter table public.consultation_summaries enable row level security;
alter table public.plan_templates enable row level security;

create policy form_templates_clinical on public.form_templates for all to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_versions_clinical on public.form_template_versions for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_versions_insert_clinical on public.form_template_versions for insert to authenticated with check (published_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_fields_clinical on public.form_fields for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or exists(select 1 from public.form_assignments a where a.version_id=form_fields.version_id and private.can_access_patient(a.patient_id)));
create policy form_fields_insert_clinical on public.form_fields for insert to authenticated with check (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_assignments_select on public.form_assignments for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or private.can_access_patient(patient_id));
create policy form_assignments_insert_clinical on public.form_assignments for insert to authenticated with check (assigned_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_assignments_update_patient on public.form_assignments for update to authenticated using (private.can_access_patient(patient_id) or private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (private.can_access_patient(patient_id) or private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy form_responses_select on public.form_responses for select to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) or private.can_access_patient(patient_id));
create policy form_responses_insert_patient on public.form_responses for insert to authenticated with check (created_by=(select auth.uid()) and private.can_access_patient(patient_id));
create policy form_responses_update_patient on public.form_responses for update to authenticated using (created_by=(select auth.uid()) and private.can_access_patient(patient_id) and status<>'submitted') with check (created_by=(select auth.uid()) and private.can_access_patient(patient_id));
create policy consultation_summaries_clinical on public.consultation_summaries for all to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));
create policy plan_templates_clinical on public.plan_templates for all to authenticated using (private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[])) with check (created_by=(select auth.uid()) and private.has_organization_role(organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]));

create unique index form_responses_one_per_assignment on public.form_responses(assignment_id);

create or replace function private.assert_form_required_fields(target_version_id uuid,target_values jsonb)
returns void language plpgsql stable set search_path='' as $$
begin
 if exists(select 1 from public.form_fields f where f.version_id=target_version_id and f.required and nullif(trim(coalesce(target_values->>(f.id::text),'')),'') is null) then
  raise exception 'Campos obrigatorios pendentes';
 end if;
end; $$;

create or replace function public.save_form_response(target_assignment_id uuid,target_values jsonb,target_submit boolean default false)
returns public.form_responses language plpgsql security invoker set search_path='' as $$
declare a public.form_assignments; result public.form_responses; next_status public.form_assignment_status := case when target_submit then 'submitted'::public.form_assignment_status else 'draft'::public.form_assignment_status end;
begin
 select * into a from public.form_assignments where id=target_assignment_id;
 if a.id is null or not private.can_access_patient(a.patient_id) then raise exception 'Acesso negado'; end if;
 if target_submit then perform private.assert_form_required_fields(a.version_id,target_values); end if;
 insert into public.form_responses(organization_id,assignment_id,patient_id,version_id,values,status,created_by,submitted_at)
 values(a.organization_id,a.id,a.patient_id,a.version_id,target_values,next_status,auth.uid(),case when target_submit then now() else null end)
 on conflict (assignment_id) do update set values=excluded.values,status=excluded.status,updated_at=now(),submitted_at=excluded.submitted_at
 returning * into result;
 update public.form_assignments set status=next_status,submitted_at=case when target_submit then now() else submitted_at end where id=a.id;
 return result;
end; $$;

create or replace function public.create_plan_template_from_plan(target_plan_id uuid,target_name text,target_objective text default null,target_tags text[] default '{}')
returns public.plan_templates language plpgsql security invoker set search_path='' as $$
declare p public.plans; snapshot jsonb; result public.plan_templates;
begin
 select * into p from public.plans where id=target_plan_id;
 if p.id is null or not private.has_organization_role(p.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 select jsonb_build_object('plan',to_jsonb(p),'versions',coalesce(jsonb_agg(to_jsonb(v) order by v.version_no),'[]'::jsonb)) into snapshot from public.plan_versions v where v.plan_id=p.id;
 insert into public.plan_templates(organization_id,source_plan_id,name,objective,tags,snapshot,created_by)
 values(p.organization_id,p.id,nullif(trim(target_name),''),nullif(trim(coalesce(target_objective,'')),''),coalesce(target_tags,'{}'),snapshot,auth.uid())
 returning * into result;
 return result;
end; $$;

create or replace function public.copy_plan_template_to_patient(target_template_id uuid,target_patient_id uuid)
returns public.plans language plpgsql security invoker set search_path='' as $$
declare t public.plan_templates; patient_org uuid; result public.plans; source_version uuid; new_version uuid; day_row record; meal_row record; new_day uuid; new_meal uuid;
begin
 select * into t from public.plan_templates where id=target_template_id;
 select organization_id into patient_org from public.patients where id=target_patient_id;
 if t.id is null or patient_org<>t.organization_id or not private.has_organization_role(t.organization_id,array['owner','admin','nutritionist','student']::public.organization_role[]) then raise exception 'Acesso negado'; end if;
 select id into source_version from public.plan_versions where plan_id=t.source_plan_id order by version_no desc limit 1;
 insert into public.plans(organization_id,patient_id,created_by,title,status)
 values(t.organization_id,target_patient_id,auth.uid(),t.name,'draft') returning * into result;
 insert into public.plan_versions(organization_id,plan_id,version_no,created_by,change_summary,assistant_state,targets)
 values(t.organization_id,result.id,1,auth.uid(),'Copiado de modelo',coalesce(t.snapshot #> '{versions,0,assistant_state}','{}'::jsonb),coalesce(t.snapshot #> '{versions,0,targets}','{}'::jsonb));
 select id into new_version from public.plan_versions where plan_id=result.id and version_no=1;
 for day_row in select * from public.plan_days where plan_version_id=source_version order by day_index loop
  insert into public.plan_days(organization_id,plan_version_id,day_index,label,kind) values(t.organization_id,new_version,day_row.day_index,day_row.label,day_row.kind) returning id into new_day;
  for meal_row in select * from public.meals where plan_day_id=day_row.id order by position loop
   insert into public.meals(organization_id,plan_day_id,position,label,suggested_time,notes) values(t.organization_id,new_day,meal_row.position,meal_row.label,meal_row.suggested_time,meal_row.notes) returning id into new_meal;
   insert into public.meal_items(organization_id,meal_id,position,food_id,description,quantity,unit,grams,nutrient_snapshot,notes)
   select t.organization_id,new_meal,position,food_id,description,quantity,unit,grams,nutrient_snapshot,notes from public.meal_items where meal_id=meal_row.id order by position;
  end loop;
 end loop;
 return result;
end; $$;

grant select,insert,update,delete on public.form_templates,public.form_template_versions,public.form_fields,public.form_assignments,public.form_responses,public.consultation_summaries,public.plan_templates to authenticated;
grant execute on function public.save_form_response(uuid,jsonb,boolean),public.create_plan_template_from_plan(uuid,text,text,text[]),public.copy_plan_template_to_patient(uuid,uuid) to authenticated;
