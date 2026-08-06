do $$
begin
  perform set_config('bsnutri.workflow_rpc', 'on', true);

  update public.plan_versions
  set locked_at = null,
      published_at = null,
      content_hash = null,
      reviewed_at = null,
      reviewed_by = null,
      targets = '{}'::jsonb
  where organization_id = 'fb000000-0000-0000-0000-000000000001';

  update public.plans
  set status = 'draft',
      reviewed_at = null,
      reviewed_by = null,
      published_at = null,
      published_by = null,
      current_published_version_id = null
  where organization_id = 'fb000000-0000-0000-0000-000000000001';

  delete from public.substitution_requests where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_item_substitutions where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.adherence_alerts where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_checkins where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.appointments where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.rooms where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meal_items where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.meals where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plan_days where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plan_versions where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.plans where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.anthropometry where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.assessments where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.patients where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.memberships where organization_id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.organizations where id = 'fb000000-0000-0000-0000-000000000001';
  delete from public.profiles where id in ('e1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000003');
  delete from auth.identities where user_id in ('e1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000003') or identity_data->>'email' in ('mvp.profissional@teste.com','mvp.recepcao@teste.com','mvp.paciente@teste.com');
  delete from auth.users where email in ('mvp.profissional@teste.com','mvp.recepcao@teste.com','mvp.paciente@teste.com') or id in ('e1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000003');
end
$$;
