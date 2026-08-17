import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { DietboxImportModal } from './DietboxImportModal'
import type { CatalogDataSource, CatalogFoodSummary } from '../lib/catalogSearch'
import type { DietboxImportDataSource } from '../lib/dietboxImportWrite'
import { initialAssistantState } from '../lib/planAssistant'
import type { DraftSummary, EditorDay } from '../lib/planDrafts'
import type { SubstitutionDataSource } from '../lib/substitutions'
import { initialWeek } from '../lib/usePlanDraft'

const PLAN_TEXT = `10:00 - Café da manhã
Café - 1 Xícara(s) de café (80ml) Ou escolha 1 porção do grupo 1 da lista de substituição.
Mamão formosa - 1 Fatia(s) média(s) (170g)
Banana prata - 1 Unidade(s) grande(s) (55g)`

function food(id: string, name: string): CatalogFoodSummary {
  return { id, name, preparationState: 'raw', isOwn: false, householdMeasureLabel: null, householdMeasureGrams: null, sourceName: 'TACO', nutrients: { energyKcal: 60 } }
}

const CAFE = food('f-cafe', 'Café')
const MAMAO = food('f-mamao', 'Mamão formosa')
const BANANA = food('f-banana', 'Banana prata')

function catalogSourceReturning(byQuery: Record<string, CatalogFoodSummary[]>): CatalogDataSource {
  return {
    searchFoods: vi.fn(async ({ query }) => ({
      data: { foods: byQuery[query] ?? [], total: (byQuery[query] ?? []).length, page: 1, pageSize: 30, pageCount: 1 },
      error: null,
    })),
  }
}

function writeSourceStub(overrides: Partial<DietboxImportDataSource> = {}): DietboxImportDataSource {
  return {
    saveDraft: vi.fn(async () => ({ data: { id: 'plan-1' }, error: null })),
    insertEquivalencyGroup: vi.fn(async () => ({ data: { id: 'list-1' }, error: null })),
    findEquivalencyListsByDietboxGroup: vi.fn(async () => new Map()),
    ...overrides,
  }
}

function substitutionSourceStub(overrides: Partial<SubstitutionDataSource> = {}): SubstitutionDataSource {
  return {
    listForVersion: vi.fn(async () => ({ data: [], error: null })),
    prescribe: vi.fn(async () => ({ error: null })),
    setActive: vi.fn(async () => ({ error: null })),
    ...overrides,
  }
}

function draftWithImportedDay(days: EditorDay[]): DraftSummary {
  return {
    id: 'plan-1',
    patientId: 'patient-1',
    title: 'Plano alimentar',
    status: 'draft',
    updatedAt: '2026-08-16T00:00:00.000Z',
    versionId: 'version-1',
    version: 1,
    targets: {},
    assistantState: initialAssistantState(),
    locked: false,
    days: days.map((day, index) => (index === 0
      ? { ...day, meals: [{ id: 'meal-real', name: 'Café da manhã', items: [{ id: 'real-cafe', name: 'Café', grams: 80, nutrientsPer100g: CAFE.nutrients as never }, { id: 'real-mamao', name: 'Mamão formosa', grams: 170, nutrientsPer100g: MAMAO.nutrients as never }] }] }
      : day)),
  }
}

function setup(props: Partial<Parameters<typeof DietboxImportModal>[0]> = {}) {
  const catalogSource = props.catalogSource ?? catalogSourceReturning({ Café: [CAFE], 'Mamão formosa': [MAMAO], 'Banana prata': [BANANA] })
  const writeSource = props.writeSource ?? writeSourceStub()
  const substitutionSource = props.substitutionSource ?? substitutionSourceStub()
  const days = initialWeek()
  const onImported = vi.fn()
  const loadDrafts = props.loadDrafts ?? vi.fn(async () => [draftWithImportedDay(days)])

  render(
    <DietboxImportModal
      organizationId="org-1"
      userId="user-1"
      catalogSource={catalogSource}
      writeSource={writeSource}
      substitutionSource={substitutionSource}
      patientId="patient-1"
      title="Plano alimentar"
      targets={{}}
      assistantState={initialAssistantState()}
      days={days}
      activeDayIndex={0}
      loadDrafts={loadDrafts}
      onImported={onImported}
      onClose={vi.fn()}
      {...props}
    />,
  )
  return { catalogSource, writeSource, substitutionSource, onImported, loadDrafts }
}

describe('DietboxImportModal', () => {
  afterEach(() => cleanup())

  it('imports the primary item of each slot and attaches the resolved alternative as a substitution', async () => {
    const { writeSource, substitutionSource, onImported } = setup()

    fireEvent.change(screen.getByLabelText('Texto colado do Dietbox'), { target: { value: PLAN_TEXT } })
    fireEvent.click(screen.getByRole('button', { name: 'Analisar' }))

    await screen.findByText(/Café → Café/)
    await screen.findByText(/Mamão formosa → Mamão formosa/)

    fireEvent.click(screen.getByRole('button', { name: 'Confirmar importação' }))

    await waitFor(() => expect(writeSource.saveDraft).toHaveBeenCalledTimes(1))
    const savePayload = (writeSource.saveDraft as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(savePayload.days[0].meals[0].items.map((item: { name: string }) => item.name)).toEqual(['Café', 'Mamão formosa'])

    await waitFor(() => expect(substitutionSource.prescribe).toHaveBeenCalledTimes(1))
    expect(substitutionSource.prescribe).toHaveBeenCalledWith(expect.objectContaining({ mealItemId: 'real-mamao', food: BANANA, grams: 55 }))

    await waitFor(() => expect(onImported).toHaveBeenCalledWith('plan-1'))
  })

  it('blocks confirmation until an item with no automatic match is resolved manually', async () => {
    const { onImported } = setup({
      catalogSource: catalogSourceReturning({
        Café: [CAFE],
        'Mamão formosa': [MAMAO, food('f-outro-mamao', 'Mamão papaya')],
        'Banana prata': [BANANA],
      }),
    })

    fireEvent.change(screen.getByLabelText('Texto colado do Dietbox'), { target: { value: PLAN_TEXT } })
    fireEvent.click(screen.getByRole('button', { name: 'Analisar' }))

    await screen.findByText(/não casado automaticamente/)
    expect(screen.getByRole('button', { name: 'Confirmar importação' })).toBeDisabled()

    fireEvent.click(screen.getByRole('button', { name: 'Mamão formosa' }))
    expect(screen.getByRole('button', { name: 'Confirmar importação' })).not.toBeDisabled()

    fireEvent.click(screen.getByRole('button', { name: 'Confirmar importação' }))
    await waitFor(() => expect(onImported).toHaveBeenCalled())
  })

  it('reports a failed substitution without blocking the rest of the import', async () => {
    const { substitutionSource, onImported } = setup({
      substitutionSource: substitutionSourceStub({ prescribe: vi.fn(async () => ({ error: { message: 'falha de rede' } })) }),
    })

    fireEvent.change(screen.getByLabelText('Texto colado do Dietbox'), { target: { value: PLAN_TEXT } })
    fireEvent.click(screen.getByRole('button', { name: 'Analisar' }))
    await screen.findByText(/Café → Café/)

    fireEvent.click(screen.getByRole('button', { name: 'Confirmar importação' }))

    await waitFor(() => expect(onImported).toHaveBeenCalledWith('plan-1'))
    expect(substitutionSource.prescribe).toHaveBeenCalledTimes(1)
    await screen.findByText(/falharam/)
  })
})
