-- Exigir revisão de um modelo que o próprio profissional acabou de criar a partir
-- do plano dele é burocracia sem ganho clínico: ele já revisou ao montar o plano.
-- A revisão continua obrigatória para o que vem de fora (seeds e importações),
-- que é onde o risco de conteúdo não conferido realmente está.

create or replace function private.auto_approve_own_plan_template()
returns trigger language plpgsql security definer set search_path = '' as $$
declare origin text := new.provenance->>'origin';
begin
  -- Modelo importado ou semeado continua nascendo pendente de revisão.
  if new.catalog_key is not null or origin = 'seed' then
    return new;
  end if;

  if new.created_by = (select auth.uid()) then
    new.status := 'approved';
    new.reviewed_by := new.created_by;
    new.reviewed_at := now();
    new.review_notes := coalesce(new.review_notes, 'Aprovado automaticamente: criado pelo próprio profissional.');
    if new.provenance = '{}'::jsonb then
      new.provenance := jsonb_build_object('origin', case when new.source_plan_id is not null then 'plan' else 'manual' end);
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.auto_approve_own_plan_template() from public, anon, authenticated;

create trigger plan_templates_auto_approve_own
before insert on public.plan_templates
for each row execute function private.auto_approve_own_plan_template();
