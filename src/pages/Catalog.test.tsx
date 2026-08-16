import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Catalog from './Catalog'
import { CATALOG_PAGE_SIZE, type CatalogDataSource, type CatalogFoodSummary, type CatalogSearchInput } from '../lib/catalogSearch'

function food(overrides: Partial<CatalogFoodSummary> = {}): CatalogFoodSummary {
  return {
    id: 'food-1',
    name: 'Arroz integral cozido',
    preparationState: 'cooked',
    isOwn: false,
    householdMeasureLabel: null,
    householdMeasureGrams: null,
    sourceName: 'TBCA',
    nutrients: { energyKcal: 112, proteinG: 2.6 },
    ...overrides,
  }
}

function source(total = 1, foods = [food()]) {
  const searchFoods = vi.fn(async ({ page }: CatalogSearchInput) => ({
    data: {
      foods,
      total,
      page,
      pageSize: CATALOG_PAGE_SIZE,
      pageCount: Math.max(1, Math.ceil(total / CATALOG_PAGE_SIZE)),
    },
    error: null,
  }))
  return { searchFoods } satisfies CatalogDataSource
}

describe('Catalog', () => {
  afterEach(() => cleanup())

  it('asks the database for one page of 30 and shows the visible range', async () => {
    const dataSource = source(75)
    render(<Catalog organizationId="org-1" dataSource={dataSource} />)

    await waitFor(() => expect(dataSource.searchFoods).toHaveBeenCalledWith({ organizationId: 'org-1', query: '', page: 1 }))
    expect(await screen.findByText('Exibindo 1–1 de 75')).toBeInTheDocument()
  })

  it('renders an absent nutrient as absent, never as zero', async () => {
    const dataSource = source(1, [food({ nutrients: { energyKcal: 112 } })])
    render(<Catalog organizationId="org-1" dataSource={dataSource} />)

    const row = (await screen.findByText('Arroz integral cozido')).closest('tr')
    expect(row).not.toBeNull()
    const cells = Array.from(row!.querySelectorAll('td')).map((cell) => cell.textContent)
    expect(cells).toContain('112')
    expect(cells.filter((cell) => cell === '—')).toHaveLength(3)
    expect(cells).not.toContain('0')
  })

  it('collapses keystrokes into a single query', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    try {
      const dataSource = source(1)
      render(<Catalog organizationId="org-1" dataSource={dataSource} />)
      await waitFor(() => expect(dataSource.searchFoods).toHaveBeenCalledTimes(1))

      const input = screen.getByLabelText('Buscar no catálogo')
      fireEvent.change(input, { target: { value: 'a' } })
      fireEvent.change(input, { target: { value: 'ar' } })
      fireEvent.change(input, { target: { value: 'arr' } })
      expect(dataSource.searchFoods).toHaveBeenCalledTimes(1)

      await vi.advanceTimersByTimeAsync(300)
      await waitFor(() => expect(dataSource.searchFoods).toHaveBeenCalledTimes(2))
      expect(dataSource.searchFoods).toHaveBeenLastCalledWith({ organizationId: 'org-1', query: 'arr', page: 1 })
    } finally {
      vi.useRealTimers()
    }
  })

  it('advances to the next page without refetching everything', async () => {
    const dataSource = source(75)
    render(<Catalog organizationId="org-1" dataSource={dataSource} />)
    await screen.findByText('Página 1 de 3')

    fireEvent.click(screen.getByRole('button', { name: 'Próxima página' }))
    await waitFor(() => expect(dataSource.searchFoods).toHaveBeenLastCalledWith({ organizationId: 'org-1', query: '', page: 2 }))
  })
})
