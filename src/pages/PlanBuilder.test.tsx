import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('../lib/supabase', async () => {
  const { supabaseStub } = await import('../test/supabaseStub')
  return { isSupabaseConfigured: true, supabase: supabaseStub() }
})

const { default: PlanBuilder } = await import('./PlanBuilder')

const WEEK = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo']
const MEALS = ['Café da manhã', 'Lanche da manhã', 'Almoço', 'Lanche da tarde', 'Jantar', 'Ceia']

const food = {
  id: 'food-1',
  name: 'Arroz branco',
  preparationState: 'cooked',
  isOwn: false,
  householdMeasureLabel: null,
  householdMeasureGrams: null,
  sourceName: 'TBCA',
  nutrients: { energyKcal: 130, proteinG: 2.7 },
}

function sources() {
  return {
    catalogSource: { searchFoods: vi.fn().mockResolvedValue({ data: { foods: [food], total: 1, page: 1, pageSize: 30, pageCount: 1 }, error: null }) },
    templateSource: {
      listTemplates: vi.fn().mockResolvedValue({ data: { templates: [], total: 0, page: 1, pageSize: 24, pageCount: 1 }, error: null }),
      getTemplateDetail: vi.fn(),
      reviewTemplate: vi.fn(),
      applyTemplate: vi.fn(),
    },
  }
}

function setup() {
  const { catalogSource, templateSource } = sources()
  const view = render(
    <PlanBuilder
      organizationId="org-1"
      userId="user-1"
      patients={[{ id: 'p1', anonymousCode: 'P0001', fullName: 'Mariana Lopes', email: null, phone: null, birthDate: null, status: 'active', tags: [], objective: null, measurements: [] }]}
      catalogSource={catalogSource}
      templateSource={templateSource}
      canReview
      onBack={vi.fn()}
    />,
  )
  return { view, catalogSource, templateSource }
}

describe('PlanBuilder — quadro semanal', () => {
  afterEach(() => cleanup())

  it('mostra os sete dias da semana lado a lado', async () => {
    setup()
    for (const day of WEEK) {
      expect(await screen.findByText(day)).toBeInTheDocument()
    }
  })

  it('mostra as seis refeições em cada dia', () => {
    setup()
    for (const meal of MEALS) {
      expect(screen.getAllByText(meal)).toHaveLength(WEEK.length)
    }
  })

  it('oferece um botão de adicionar por refeição de cada dia', () => {
    setup()
    expect(screen.getAllByRole('button', { name: /adicionar/ })).toHaveLength(WEEK.length * MEALS.length)
  })

  it('mantém a faixa de média diária com os quatro macros', () => {
    setup()
    expect(screen.getByText('Média diária')).toBeInTheDocument()
    for (const label of ['Calorias', 'Proteína', 'Carboidrato', 'Gordura']) {
      expect(screen.getByText(label)).toBeInTheDocument()
    }
  })

  it('permite copiar um dia para outro a partir do cabeçalho do dia', () => {
    setup()
    expect(screen.getByLabelText('Copiar Segunda-feira para outro dia')).toBeInTheDocument()
    expect(screen.getByLabelText('Copiar Domingo para outro dia')).toBeInTheDocument()
  })

  it('adiciona um alimento pelo seletor e mostra a quantidade em gramas', async () => {
    const { catalogSource } = setup()
    fireEvent.click(screen.getAllByRole('button', { name: /adicionar/ })[0])

    await waitFor(() => expect(catalogSource.searchFoods).toHaveBeenCalled())
    fireEvent.click(await screen.findByRole('button', { name: /Arroz branco/ }))

    const item = await screen.findByText('Arroz branco')
    const card = item.parentElement as HTMLElement
    expect(within(card).getByText('100 g')).toBeInTheDocument()
    expect(within(card).getByText('130 kcal')).toBeInTheDocument()
  })

  it('ajusta a quantidade em passos de 10 g', async () => {
    setup()
    fireEvent.click(screen.getAllByRole('button', { name: /adicionar/ })[0])
    fireEvent.click(await screen.findByRole('button', { name: /Arroz branco/ }))

    fireEvent.click(await screen.findByRole('button', { name: 'Aumentar Arroz branco' }))
    expect(await screen.findByText('110 g')).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: 'Diminuir Arroz branco' }))
    expect(await screen.findByText('100 g')).toBeInTheDocument()
  })

  it('esconde o assistente até ser pedido, para o quadro ficar limpo', async () => {
    setup()
    expect(screen.queryByText('Micronutrientes prioritários')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: /Assistente/ }))
    expect(await screen.findByText('Micronutrientes prioritários')).toBeInTheDocument()
  })
})

describe('PlanBuilder — PDF', () => {
  afterEach(() => cleanup())

  it('explica por que o PDF não sai em vez de ficar cinza sem motivo', async () => {
    setup()
    fireEvent.click(screen.getByRole('button', { name: /PDF/ }))
    expect(await screen.findByText('Abra um plano da lista ao lado para gerar o PDF.')).toBeInTheDocument()
  })
})
