import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { NutritionWorkspace } from './NutritionWorkspace'

const { fromMock, rpcMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({ supabase: { from: fromMock, rpc: rpcMock } }))

function queryResult(data: unknown[] = []) {
  return {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    or: vi.fn().mockReturnThis(),
    order: vi.fn().mockResolvedValue({ data, error: null }),
    upsert: vi.fn().mockResolvedValue({ error: null }),
  }
}

const session = { user: { id: 'user-1' } }
const patients = [{ id: 'patient-1', anonymous_code: 'P01', full_name: 'Paciente Teste' }]

describe('NutritionWorkspace editor modes', () => {
  afterEach(() => cleanup())

  beforeEach(() => {
    vi.clearAllMocks()
    localStorage.clear()
    fromMock.mockImplementation(() => queryResult([]))
    rpcMock.mockResolvedValue({ error: null })
  })

  it('alterna densidade sem perder dados do rascunho', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))

    const quickMode = await screen.findByRole('tab', { name: /Consulta rapida/i })
    expect(quickMode).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByText('Metas nutricionais').closest('section')).toHaveAttribute('aria-hidden', 'true')

    const objective = screen.getByLabelText(/Objetivo/i)
    fireEvent.change(objective, { target: { value: 'Hipertrofia com rotina simples' } })

    fireEvent.click(screen.getByRole('tab', { name: /Tecnico/i }))
    expect(screen.getByText('Metas nutricionais').closest('section')).toHaveAttribute('aria-hidden', 'false')
    expect(screen.getByText('Pendencias tecnicas').closest('section')).toHaveAttribute('aria-hidden', 'false')
    expect(screen.getByDisplayValue('Hipertrofia com rotina simples')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('tab', { name: /Consulta rapida/i }))
    expect(screen.getByDisplayValue('Hipertrofia com rotina simples')).toBeInTheDocument()
  })

  it('duplica dia e refeicao no editor rapido', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))

    fireEvent.click(await screen.findByRole('button', { name: /Duplicar dia/i }))
    expect(screen.getByRole('tab', { name: /Dia 1 copia/i })).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: /Duplicar Caf/i }))
    expect(screen.getByDisplayValue(/Caf.*copia/i)).toBeInTheDocument()
  })

  it('edita gramas e troca alimento sem remover item', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'foods' ? [{
      id: 'food-1',
      name: 'Arroz',
      preparation_state: 'cozido',
      food_nutrient_values: [
        { amount_per_100g: 130, nutrients: { id: 'n-1', code: 'energy_kcal', name: 'Energia', unit: 'kcal' } },
        { amount_per_100g: 2.5, nutrients: { id: 'n-2', code: 'protein_g', name: 'Proteina', unit: 'g' } },
        { amount_per_100g: 28, nutrients: { id: 'n-3', code: 'carbohydrate_g', name: 'Carboidrato', unit: 'g' } },
        { amount_per_100g: 0.3, nutrients: { id: 'n-4', code: 'fat_g', name: 'Gordura', unit: 'g' } },
      ],
    }, {
      id: 'food-2',
      name: 'Batata',
      preparation_state: 'cozida',
      food_nutrient_values: [
        { amount_per_100g: 86, nutrients: { id: 'n-1', code: 'energy_kcal', name: 'Energia', unit: 'kcal' } },
        { amount_per_100g: 1.7, nutrients: { id: 'n-2', code: 'protein_g', name: 'Proteina', unit: 'g' } },
        { amount_per_100g: 20, nutrients: { id: 'n-3', code: 'carbohydrate_g', name: 'Carboidrato', unit: 'g' } },
        { amount_per_100g: 0.1, nutrients: { id: 'n-4', code: 'fat_g', name: 'Gordura', unit: 'g' } },
      ],
    }] : []))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Buscar alimento'), { target: { value: 'arr' } })
    expect(screen.getByRole('option', { name: 'Arroz' })).toBeInTheDocument()
    expect(screen.queryByRole('option', { name: 'Batata' })).not.toBeInTheDocument()
    fireEvent.change(await screen.findByLabelText('Alimento'), { target: { value: 'food-1' } })
    fireEvent.change(screen.getByLabelText('Gramas'), { target: { value: '100' } })
    fireEvent.click(screen.getByRole('button', { name: /Item/i }))

    fireEvent.change(screen.getByLabelText('Gramas de Arroz'), { target: { value: '200' } })

    expect(screen.getByDisplayValue('200')).toBeInTheDocument()
    expect(screen.getAllByText(/260 kcal/).length).toBeGreaterThan(0)

    fireEvent.change(screen.getByLabelText('Alimento de Arroz'), { target: { value: 'food-2' } })

    expect(screen.getByLabelText('Alimento de Batata')).toHaveValue('food-2')
    expect(screen.getAllByText(/172 kcal/).length).toBeGreaterThan(0)
  })

  it('filtra catálogo por sinônimo e mostra favoritos pessoais', async () => {
    const food = { id: 'food-1', name: 'Mandioca', preparation_state: 'cozida', catalog_kind: 'food', serving_grams: 80, household_measure_label: '1 concha', household_measure_grams: 80, search_terms: ['aipim', 'macaxeira'], cultural_tags: ['Nordeste'], restriction_tags: ['sem glúten'], preference_tags: [], availability_tags: [], cost_band: 'low', food_nutrient_values: [] }
    fromMock.mockImplementation((table: string) => queryResult(table === 'foods' ? [food] : table === 'food_user_preferences' ? [{ food_id: 'food-1', is_favorite: true, last_used_at: '2026-07-24T12:00:00Z' }] : []))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.change(await screen.findByLabelText('Buscar no catálogo'), { target: { value: 'macaxeira' } })
    expect(screen.getByText('Mandioca')).toBeInTheDocument()
    expect(screen.getByText(/1 concha · 80 g/)).toBeInTheDocument()
    fireEvent.click(screen.getByText('Favoritos').closest('button')!)
    expect(screen.getByText('Mandioca')).toBeInTheDocument()
  })

  it('inicia um plano em branco pelo atalho lateral', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText(/Objetivo/i), { target: { value: 'Objetivo antigo' } })
    fireEvent.change(screen.getByLabelText('Título'), { target: { value: 'Plano antigo' } })

    fireEvent.click(screen.getByRole('button', { name: /Em branco/i }))

    expect(screen.getByDisplayValue('Plano alimentar')).toBeInTheDocument()
    expect(screen.queryByDisplayValue('Objetivo antigo')).not.toBeInTheDocument()
    expect(screen.getByText(/Novo plano em branco/i)).toBeInTheDocument()
  })

  it('usa o plano aberto como base para novo rascunho', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? [{
      id: 'plan-1',
      patient_id: 'patient-1',
      title: 'Plano anterior',
      status: 'reviewed',
      updated_at: '2026-07-17T10:00:00Z',
      plan_versions: [{
        id: 'version-1',
        version_no: 1,
        targets: {},
        assistant_state: { currentStep: 'objective', completedSteps: [], objective: 'Hipertrofia', clinicalPresets: [], priorityMicronutrients: [] },
        locked_at: null,
        plan_days: [{ id: 'day-1', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{ id: 'meal-1', label: 'Almoco', position: 0, meal_items: [] }] }],
      }],
    }] : []))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.click(await screen.findByText('Plano anterior'))
    fireEvent.click(screen.getByRole('button', { name: /Usar plano aberto/i }))

    expect(screen.getByDisplayValue('Plano anterior copia')).toBeInTheDocument()
    expect(screen.getByText(/Salve para criar um novo rascunho/i)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /^Salvar rascunho$/i })).toBeInTheDocument()
  })

  it('restaura rascunho local salvo no navegador', async () => {
    localStorage.setItem('bsnutri:plan-draft:org-1', JSON.stringify({
      patientId: 'patient-1',
      title: 'Plano local',
      days: [{ id: 'day-local', label: 'Dia local', kind: 'standard', meals: [{ id: 'meal-local', name: 'Jantar', items: [] }] }],
      activeDay: 0,
      targets: { energyKcal: 1800, proteinG: 120, carbohydrateG: 180, fatG: 60, fiberG: 25, waterMl: 2200 },
      assistant: { currentStep: 'objective', completedSteps: [], objective: 'Rascunho de consulta', clinicalPresets: [], priorityMicronutrients: [], visibility: { showTotalKcal: true, showTotalMacros: true, showMealCalculations: false } },
      editorMode: 'quick',
      savedAt: '2026-07-23T14:00:00.000Z',
    }))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(await screen.findByRole('button', { name: /Restaurar/i }))

    expect(screen.getByDisplayValue('Plano local')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Rascunho de consulta')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Jantar')).toBeInTheDocument()
    expect(screen.getByText(/Rascunho local restaurado/i)).toBeInTheDocument()
  })

  it('salva automaticamente o rascunho em edicao', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Título'), { target: { value: 'Plano autosalvo' } })

    await waitFor(() => expect(localStorage.getItem('bsnutri:plan-draft:org-1')).toContain('Plano autosalvo'))
  })

  it('abre o rascunho criado ao copiar modelo para paciente', async () => {
    let copied = false
    fromMock.mockImplementation((table: string) => queryResult(
      table === 'plan_templates' ? [{ id: 'template-1', name: 'Modelo pratico', objective: 'Hipertrofia', tags: ['hipertrofia'], created_at: '2026-07-23T10:00:00Z' }] :
      table === 'plans' && copied ? [{
        id: 'plan-copy',
        patient_id: 'patient-1',
        title: 'Modelo pratico',
        status: 'draft',
        updated_at: '2026-07-23T10:00:00Z',
        plan_versions: [{
          id: 'version-copy',
          version_no: 1,
          targets: {},
          assistant_state: { currentStep: 'objective', completedSteps: [], objective: 'Hipertrofia', clinicalPresets: [], priorityMicronutrients: [] },
          locked_at: null,
          plan_days: [{ id: 'day-copy', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{ id: 'meal-copy', label: 'Almoco', position: 0, meal_items: [] }] }],
        }],
      }] : [],
    ))
    rpcMock.mockImplementation(async () => { copied = true; return { data: { id: 'plan-copy' }, error: null } })
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Paciente'), { target: { value: 'patient-1' } })
    const modelCard=(await screen.findByText('Modelo pratico')).closest('article')
    fireEvent.click(within(modelCard!).getByRole('button', { name: 'Aplicar' }))

    expect(await screen.findByText(/Modelo aplicado em rascunho independente/i)).toBeInTheDocument()
    expect(screen.getByDisplayValue('Modelo pratico')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Almoco')).toBeInTheDocument()
  })

  it('exige confirmacao extra ao publicar sem substituicoes revisadas', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? [{
      id: 'plan-1',
      patient_id: 'patient-1',
      title: 'Plano A',
      status: 'reviewed',
      updated_at: '2026-07-17T10:00:00Z',
      plan_versions: [{
        id: 'version-1',
        version_no: 1,
        targets: { energyKcal: 2000, proteinG: 100, carbohydrateG: 220, fatG: 70, fiberG: 30, waterMl: 2500 },
        assistant_state: { currentStep: 'review', completedSteps: ['objective', 'targets', 'meals', 'equivalents', 'review'], objective: 'Plano clinico', clinicalPresets: ['hypertrophy'], priorityMicronutrients: ['Ferro'] },
        locked_at: null,
        plan_days: [{ id: 'day-1', label: 'Dia 1', kind: 'standard', day_index: 0, meals: [{ id: 'meal-1', label: 'Almoco', position: 0, meal_items: [{ id: 'item-1', description: 'Arroz', grams: 100, nutrient_snapshot: { energyKcal: 130 }, meal_item_substitutions: [] }] }] }],
      }],
    }] : []))

    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.click(await screen.findByText('Plano A'))

    fireEvent.click(screen.getByRole('button', { name: /^Publicar$/i }))
    expect(await screen.findByText(/sem substituicoes revisadas/i)).toBeInTheDocument()
    expect(rpcMock).not.toHaveBeenCalled()

    fireEvent.click(screen.getByRole('button', { name: /Confirmar publica/i }))
    expect(rpcMock).toHaveBeenCalledWith('publish_plan_version', { target_plan_id: 'plan-1', target_version_id: 'version-1' })
  })

  it('recolhe e expande as areas laterais do construtor desktop', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))

    expect(await screen.findByRole('complementary', { name: 'Contexto do plano' })).toBeInTheDocument()
    expect(screen.getByRole('complementary', { name: 'Análise nutricional' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Recolher contexto' }))
    expect(screen.queryByText('Contexto clínico')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Expandir contexto' }))
    expect(screen.getByText('Contexto clínico')).toBeInTheDocument()
  })

  it('alterna cadastro entre alimento, preparação e combinação', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    const preparation = await screen.findByRole('radio', { name: 'Preparação' })
    fireEvent.click(preparation)
    expect(preparation).toHaveAttribute('aria-checked', 'true')
    expect(screen.getByLabelText('Rendimento total (g)')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('radio', { name: 'Combinação' }))
    expect(screen.getByRole('button', { name: 'Cadastrar combinação' })).toBeDisabled()
  })

  it('usa a relação de versões do plano ao carregar rascunhos', async () => {
    const plansQuery = queryResult([])
    fromMock.mockImplementation((table: string) => table === 'plans' ? plansQuery : queryResult([]))
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    await waitFor(() => expect(plansQuery.select).toHaveBeenCalledWith(expect.stringContaining('plan_versions!plan_versions_plan_id_organization_id_fkey')))
  })

  it('não recria um rascunho local depois de descartá-lo sem editar', async () => {
    const key = 'bsnutri:plan-draft:org-1'
    localStorage.setItem(key, JSON.stringify({ patientId: 'patient-1', title: 'Rascunho antigo', days: [], activeDay: 0, targets: {}, assistant: {}, editorMode: 'quick', savedAt: '2026-07-24T17:30:03.000Z' }))
    const first = render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)

    fireEvent.click(await screen.findByRole('button', { name: 'Descartar' }))
    await new Promise(resolve => setTimeout(resolve, 20))
    expect(localStorage.getItem(key)).toBeNull()
    first.unmount()

    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    await new Promise(resolve => setTimeout(resolve, 20))
    expect(screen.queryByText(/Há um rascunho local salvo/i)).not.toBeInTheDocument()
  })

  it('filtra e aplica modelo padrão como rascunho revisável', async () => {
    render(<NutritionWorkspace session={session as never} organizationId="org-1" patients={patients}/>)
    fireEvent.click(screen.getByRole('button', { name: /Editor de plano/i }))
    fireEvent.change(await screen.findByLabelText('Paciente'), { target: { value: 'patient-1' } })
    const gallery=screen.getByRole('region', { name: 'Galeria de modelos' })
    fireEvent.click(within(gallery).getByRole('checkbox', { name: 'Hipertrofia' }))
    fireEvent.click(within(gallery).getByRole('button', { name: 'Aplicar' }))
    expect(screen.getAllByDisplayValue('Hipertrofia')).toHaveLength(2)
    expect(screen.getByText(/Modelo aplicado em rascunho local/i)).toBeInTheDocument()
  })
})
