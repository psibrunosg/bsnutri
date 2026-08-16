import { useState, type FormEvent } from 'react'
import { Droplets, LogOut } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { today, usePatientPortal, type PortalMeal } from '../lib/usePatientPortal'
import type { PatientAccess } from '../types'

type TabId = 'hoje' | 'plano' | 'diario' | 'compras' | 'conteudos' | 'preconsulta'

const TABS: { id: TabId; label: string }[] = [
  { id: 'hoje', label: 'Hoje' },
  { id: 'plano', label: 'Meu plano' },
  { id: 'diario', label: 'Diário' },
  { id: 'compras', label: 'Compras' },
  { id: 'conteudos', label: 'Conteúdos' },
  { id: 'preconsulta', label: 'Pré-consulta' },
]

const WATER_STEPS = [200, 300, 500]

function isTab(value: string | undefined): value is TabId {
  return TABS.some((tab) => tab.id === value)
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="card-warm p-6">
      <h2 className="font-display text-xl font-semibold">{title}</h2>
      <div className="mt-4">{children}</div>
    </section>
  )
}

export interface PortalProps {
  patient: PatientAccess
  tab: string | undefined
  onSelectTab: (tab: string) => void
  onLogout: () => void
}

export default function Portal({ patient, tab, onSelectTab, onLogout }: PortalProps) {
  const { state, loading, errors, reload } = usePatientPortal(patient.id)
  const [message, setMessage] = useState('')
  const active: TabId = isTab(tab) ? tab : 'hoje'
  const days = state.plan?.plan_versions?.plan_days ?? []
  const meals: PortalMeal[] = days.flatMap((day) => day.meals)
  const displayName = patient.relationship === 'patient' ? patient.fullName : 'Acesso de responsável'

  async function addWater(amount: number) {
    const session = await supabase.auth.getSession()
    const userId = session.data.session?.user.id
    if (!userId) return setMessage('Sessão expirada. Entre novamente.')
    const result = await supabase.from('patient_water_logs').upsert({
      organization_id: patient.organizationId,
      patient_id: patient.id,
      occurred_on: today(),
      amount_ml: state.waterMl + amount,
      created_by: userId,
    }, { onConflict: 'patient_id,occurred_on' })
    if (result.error) return setMessage(result.error.message)
    setMessage('')
    await reload()
  }

  async function registerCheckin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const element = event.currentTarget
    const form = new FormData(element)
    const mealId = String(form.get('meal'))
    const meal = meals.find((item) => item.id === mealId)
    const versionId = state.plan?.plan_versions?.id
    if (!meal || !versionId) return setMessage('Seu plano publicado precisa estar disponível para registrar o diário.')
    const session = await supabase.auth.getSession()
    const userId = session.data.session?.user.id
    if (!userId) return setMessage('Sessão expirada. Entre novamente.')
    const result = await supabase.from('meal_checkins').upsert({
      organization_id: patient.organizationId,
      patient_id: patient.id,
      plan_version_id: versionId,
      meal_id: mealId,
      occurred_on: String(form.get('date') || today()),
      state: String(form.get('state')) as 'completed' | 'adapted' | 'skipped',
      note: String(form.get('note') || '').trim() || null,
      created_by: userId,
    }, { onConflict: 'patient_id,meal_id,occurred_on' })
    if (result.error) return setMessage(result.error.message)
    element.reset()
    setMessage('Registro salvo.')
    await reload()
  }

  async function requestSubstitution(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const element = event.currentTarget
    const form = new FormData(element)
    const substitutionId = String(form.get('substitution'))
    const versionId = state.plan?.plan_versions?.id
    const item = meals.flatMap((meal) => meal.meal_items).find((mealItem) => mealItem.meal_item_substitutions.some((option) => option.id === substitutionId))
    if (!item || !versionId) return setMessage('Escolha uma substituição prescrita pelo seu profissional.')
    const session = await supabase.auth.getSession()
    const userId = session.data.session?.user.id
    if (!userId) return setMessage('Sessão expirada. Entre novamente.')
    const result = await supabase.from('substitution_requests').insert({
      organization_id: patient.organizationId,
      patient_id: patient.id,
      plan_version_id: versionId,
      meal_item_id: item.id,
      substitution_id: substitutionId,
      requested_by: userId,
      patient_note: String(form.get('note') || '').trim() || null,
    })
    if (result.error) return setMessage(result.error.message)
    element.reset()
    setMessage('Pedido enviado. Seu profissional vai revisar antes de valer.')
    await reload()
  }

  async function submitForm(assignmentId: string, event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const element = event.currentTarget
    const form = new FormData(element)
    const values: Record<string, string> = {}
    for (const [key, value] of form.entries()) values[key] = String(value)
    const result = await supabase.rpc('save_form_response', { target_assignment_id: assignmentId, target_values: values, target_submit: true })
    if (result.error) return setMessage(result.error.message)
    setMessage('Pré-consulta enviada.')
    await reload()
  }

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border bg-card/60 px-5 py-4 backdrop-blur lg:px-8">
        <div className="mx-auto flex max-w-[1000px] items-center justify-between gap-4">
          <div>
            <p className="eyebrow">Portal do paciente</p>
            <p className="font-display text-xl font-semibold">{displayName}</p>
          </div>
          <button type="button" className="btn-ghost" onClick={onLogout}><LogOut size={16} /> Sair</button>
        </div>
      </header>

      <main className="mx-auto max-w-[1000px] px-5 py-8 lg:px-8">
        <nav aria-label="Seções do portal" className="mb-6 flex flex-wrap gap-2">
          {TABS.map((item) => (
            <button
              key={item.id}
              type="button"
              aria-current={active === item.id ? 'page' : undefined}
              onClick={() => onSelectTab(item.id)}
              className={`rounded-full px-4 py-2 text-sm font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 ${
                active === item.id ? 'bg-forest-500 text-cream-50 shadow-warm' : 'bg-cream-200 text-muted-foreground hover:text-foreground'
              }`}
            >
              {item.label}
            </button>
          ))}
        </nav>

        {errors.map((item) => <p key={item} className="mb-3 rounded-xl border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive" role="alert">{item}</p>)}
        {message && <p className="mb-3 rounded-xl border border-border bg-cream-100/60 p-3 text-sm" role="status">{message}</p>}
        {loading && <p className="mb-3 text-sm text-muted-foreground" role="status">Carregando seu acompanhamento...</p>}

        {active === 'hoje' && (
          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <Card title="Água de hoje">
              <p className="font-display text-4xl font-semibold text-forest-600">{state.waterMl} <span className="text-base font-normal text-muted-foreground">ml</span></p>
              <div className="mt-4 flex flex-wrap gap-2">
                {WATER_STEPS.map((amount) => (
                  <button key={amount} type="button" className="btn-ghost" onClick={() => void addWater(amount)}>
                    <Droplets size={16} /> +{amount} ml
                  </button>
                ))}
              </div>
            </Card>

            <Card title="Minhas metas">
              {state.goals.length === 0 && <p className="text-sm text-muted-foreground">Nenhuma meta ativa no momento.</p>}
              <ul className="space-y-2">
                {state.goals.map((goal) => (
                  <li key={goal.id} className="rounded-xl border border-border p-3">
                    <p className="font-medium">{goal.title}</p>
                    <p className="text-sm text-muted-foreground">{goal.kind}{goal.target_value === null ? '' : ` · ${goal.target_value} ${goal.target_unit ?? ''}`}</p>
                  </li>
                ))}
              </ul>
            </Card>

            <div className="md:col-span-2">
              <Card title="Resumo da semana">
                {state.weekly ? (
                  <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                    <div><p className="eyebrow">Refeições</p><p className="font-mono text-lg font-semibold">{state.weekly.completed_meals}</p></div>
                    <div><p className="eyebrow">Registros</p><p className="font-mono text-lg font-semibold">{state.weekly.meal_checkins}</p></div>
                    <div><p className="eyebrow">Água</p><p className="font-mono text-lg font-semibold">{state.weekly.water_ml} ml</p></div>
                    <div><p className="eyebrow">Metas ativas</p><p className="font-mono text-lg font-semibold">{state.weekly.active_goals}</p></div>
                  </div>
                ) : <p className="text-sm text-muted-foreground">Resumo indisponível no momento.</p>}
              </Card>
            </div>
          </div>
        )}

        {active === 'plano' && (
          <div className="space-y-5">
            {!state.plan && <Card title="Plano alimentar"><p className="text-sm text-muted-foreground">Você ainda não tem um plano publicado. Rascunhos do profissional nunca aparecem aqui.</p></Card>}
            {state.plan && (
              <>
                <Card title={state.plan.title}>
                  <p className="text-sm text-muted-foreground">
                    Versão publicada {state.plan.plan_versions?.version_no}
                    {state.plan.published_at ? ` em ${new Date(state.plan.published_at).toLocaleDateString('pt-BR')}` : ''}
                  </p>
                </Card>
                {days.map((day) => (
                  <Card key={day.id} title={day.label}>
                    <ul className="space-y-3">
                      {day.meals.map((meal) => (
                        <li key={meal.id} className="rounded-xl border border-border p-4">
                          <p className="font-semibold">{meal.label}{meal.suggested_time ? ` · ${meal.suggested_time.slice(0, 5)}` : ''}</p>
                          <ul className="mt-2 space-y-1 text-sm">
                            {meal.meal_items.map((item) => (
                              <li key={item.id}>
                                {item.description} · {item.grams} g
                                {item.meal_item_substitutions.filter((option) => option.is_active).length > 0 && (
                                  <span className="block text-xs text-muted-foreground">
                                    Trocas liberadas: {item.meal_item_substitutions.filter((option) => option.is_active).map((option) => `${option.description} (${option.grams} ${option.unit})`).join(' · ')}
                                  </span>
                                )}
                              </li>
                            ))}
                          </ul>
                        </li>
                      ))}
                    </ul>
                  </Card>
                ))}

                <Card title="Pedir uma troca">
                  <form className="space-y-4" onSubmit={requestSubstitution}>
                    <div>
                      <label className="label-warm" htmlFor="substitution">Substituição prescrita</label>
                      <select id="substitution" name="substitution" className="input-warm" required>
                        <option value="">Selecione</option>
                        {meals.flatMap((meal) => meal.meal_items).flatMap((item) => item.meal_item_substitutions.filter((option) => option.is_active).map((option) => (
                          <option key={option.id} value={option.id}>{item.description} → {option.description}</option>
                        )))}
                      </select>
                    </div>
                    <div>
                      <label className="label-warm" htmlFor="substitution-note">Observação</label>
                      <input id="substitution-note" name="note" className="input-warm" maxLength={500} />
                    </div>
                    <button className="btn-primary">Enviar pedido</button>
                  </form>
                  <ul className="mt-4 space-y-2">
                    {state.requests.map((request) => (
                      <li key={request.id} className="rounded-xl border border-border p-3 text-sm">
                        <p className="font-medium">{request.status}</p>
                        {request.professional_note && <p className="text-muted-foreground">{request.professional_note}</p>}
                      </li>
                    ))}
                  </ul>
                </Card>
              </>
            )}
          </div>
        )}

        {active === 'diario' && (
          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <Card title="Registrar refeição">
              <form className="space-y-4" onSubmit={registerCheckin}>
                <div>
                  <label className="label-warm" htmlFor="checkin-meal">Refeição</label>
                  <select id="checkin-meal" name="meal" className="input-warm" required>
                    <option value="">Selecione</option>
                    {meals.map((meal) => <option key={meal.id} value={meal.id}>{meal.label}</option>)}
                  </select>
                </div>
                <div>
                  <label className="label-warm" htmlFor="checkin-date">Data</label>
                  <input id="checkin-date" name="date" type="date" className="input-warm" defaultValue={today()} />
                </div>
                <div>
                  <label className="label-warm" htmlFor="checkin-state">Como foi</label>
                  <select id="checkin-state" name="state" className="input-warm" defaultValue="completed">
                    <option value="completed">Segui o plano</option>
                    <option value="adapted">Adaptei</option>
                    <option value="skipped">Não fiz</option>
                  </select>
                </div>
                <div>
                  <label className="label-warm" htmlFor="checkin-note">Observação</label>
                  <textarea id="checkin-note" name="note" className="input-warm min-h-[80px] resize-y" maxLength={500} />
                </div>
                <button className="btn-primary w-full">Salvar registro</button>
              </form>
            </Card>

            <Card title="Fotos do diário">
              {!state.canUploadPhotos && (
                <p className="text-sm text-muted-foreground">
                  O envio de fotos depende do Google Drive conectado pelo seu profissional. Enquanto isso, registre a refeição em texto.
                </p>
              )}
              {state.photos.length === 0 && state.canUploadPhotos && <p className="text-sm text-muted-foreground">Nenhuma foto enviada ainda.</p>}
              <ul className="mt-3 space-y-2">
                {state.photos.map((photo) => (
                  <li key={photo.id} className="flex items-center justify-between gap-3 rounded-xl border border-border p-3 text-sm">
                    <span className="truncate">{photo.file_name}</span>
                    {photo.drive_web_url
                      ? <a className="shrink-0 font-medium text-forest-600 underline" href={photo.drive_web_url} target="_blank" rel="noreferrer">Abrir</a>
                      : <span className="shrink-0 text-muted-foreground">{new Date(`${photo.occurred_on}T12:00:00`).toLocaleDateString('pt-BR')}</span>}
                  </li>
                ))}
              </ul>
            </Card>

            <Card title="Últimos registros">
              {state.checkins.length === 0 && <p className="text-sm text-muted-foreground">Nenhum registro ainda.</p>}
              <ul className="space-y-2">
                {state.checkins.map((checkin) => (
                  <li key={checkin.id} className="rounded-xl border border-border p-3 text-sm">
                    <time dateTime={checkin.occurred_on} className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
                      {new Date(`${checkin.occurred_on}T12:00:00`).toLocaleDateString('pt-BR')}
                    </time>
                    <p className="font-medium">{checkin.state}</p>
                    {checkin.note && <p className="text-muted-foreground">{checkin.note}</p>}
                  </li>
                ))}
              </ul>
            </Card>
          </div>
        )}

        {active === 'compras' && (
          <Card title="Lista de compras da semana">
            {state.shoppingList.length === 0 && <p className="text-sm text-muted-foreground">A lista aparece quando há um plano publicado vigente.</p>}
            <ul className="space-y-2">
              {state.shoppingList.map((item) => (
                <li key={item.item_key} className="flex items-center justify-between gap-3 rounded-xl border border-border p-3 text-sm">
                  <span>{item.description}</span>
                  <span className="font-mono text-muted-foreground">{Math.round(item.total_grams)} g</span>
                </li>
              ))}
            </ul>
          </Card>
        )}

        {active === 'conteudos' && (
          <Card title="Conteúdos do seu profissional">
            {state.contents.length === 0 && <p className="text-sm text-muted-foreground">Nenhum conteúdo enviado ainda.</p>}
            <ul className="space-y-3">
              {state.contents.map((content) => (
                <li key={content.id} className="rounded-xl border border-border p-4">
                  <time dateTime={content.delivered_at} className="font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
                    {new Date(content.delivered_at).toLocaleDateString('pt-BR')}
                  </time>
                  <p className="mt-1 font-semibold">{content.snapshot?.title ?? 'Conteúdo'}</p>
                  {content.snapshot?.body && <p className="mt-1 text-sm text-muted-foreground">{content.snapshot.body}</p>}
                </li>
              ))}
            </ul>
          </Card>
        )}

        {active === 'preconsulta' && (
          <div className="space-y-5">
            {state.assignments.length === 0 && <Card title="Pré-consulta"><p className="text-sm text-muted-foreground">Nenhum formulário atribuído.</p></Card>}
            {state.assignments.map((assignment) => (
              <Card key={assignment.id} title={assignment.form_template_versions?.title ?? 'Pré-consulta'}>
                <p className="mb-4 text-sm text-muted-foreground">Situação: {assignment.status}</p>
                <form className="space-y-4" onSubmit={(event) => void submitForm(assignment.id, event)}>
                  {(assignment.form_template_versions?.form_fields ?? []).slice().sort((left, right) => left.position - right.position).map((field) => (
                    <div key={field.id}>
                      <label className="label-warm" htmlFor={`field-${field.id}`}>{field.label}</label>
                      <input
                        id={`field-${field.id}`}
                        name={field.id}
                        className="input-warm"
                        required={field.required}
                        type={field.field_type === 'number' || field.field_type === 'scale' ? 'number' : field.field_type === 'date' ? 'date' : 'text'}
                        defaultValue={assignment.form_responses[0]?.values?.[field.id] ?? ''}
                      />
                    </div>
                  ))}
                  <button className="btn-primary">Enviar respostas</button>
                </form>
              </Card>
            ))}
          </div>
        )}
      </main>
    </div>
  )
}
