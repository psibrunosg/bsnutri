import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import Templates from './Templates'
import type { PatientSummary } from '../lib/patients'
import {
  TEMPLATE_PAGE_SIZE,
  type PlanTemplateDataSource,
  type PlanTemplateStatus,
  type PlanTemplateSummary,
} from '../lib/planTemplates'

function template(overrides: Partial<PlanTemplateSummary> = {}): PlanTemplateSummary {
  return {
    id: 'template-1',
    name: 'Low carb · definição',
    objective: 'Recomposição corporal',
    tags: [],
    scope: 'organization',
    status: 'needs_review',
    provenance: { origin: 'seed', catalog_key: 'dietbox-12' },
    reviewedAt: null,
    reviewNotes: null,
    catalogKey: 'dietbox-12',
    ...overrides,
  }
}

const patients: PatientSummary[] = [
  { id: 'patient-1', anonymousCode: 'P0001', fullName: 'Mariana Lopes', email: null, phone: null, birthDate: null, status: 'active', tags: [], objective: null, measurements: [] },
]

function source(templates: PlanTemplateSummary[], total = templates.length): PlanTemplateDataSource & {
  listTemplates: ReturnType<typeof vi.fn>
  getTemplateDetail: ReturnType<typeof vi.fn>
  reviewTemplate: ReturnType<typeof vi.fn>
  applyTemplate: ReturnType<typeof vi.fn>
} {
  return {
    listTemplates: vi.fn(async ({ page }: { page: number }) => ({
      data: { templates, total, page, pageSize: TEMPLATE_PAGE_SIZE, pageCount: Math.max(1, Math.ceil(total / TEMPLATE_PAGE_SIZE)) },
      error: null,
    })),
    getTemplateDetail: vi.fn(async (id: string) => ({
      data: { ...templates.find((item) => item.id === id)!, snapshot: {}, rules: {}, dimensions: {} },
      error: null,
    })),
    reviewTemplate: vi.fn(async () => ({ error: null })),
    applyTemplate: vi.fn(async () => ({ data: { id: 'plan-1' }, error: null })),
  }
}

describe('Templates', () => {
  afterEach(() => cleanup())

  it('lists 24 templates per page and names the provenance of each one', async () => {
    const dataSource = source([template()], 50)
    render(<Templates organizationId="org-1" dataSource={dataSource} patients={patients} canReview onPlanCreated={vi.fn()} />)

    await waitFor(() => expect(dataSource.listTemplates).toHaveBeenCalledWith({ organizationId: 'org-1', query: '', status: 'all', page: 1 }))
    expect(await screen.findByText('Importado do catálogo (dietbox-12)')).toBeInTheDocument()
    expect(screen.getByText('Página 1 de 3')).toBeInTheDocument()
  })

  it('blocks applying a template that was not reviewed', async () => {
    const dataSource = source([template()])
    render(<Templates organizationId="org-1" dataSource={dataSource} patients={patients} canReview onPlanCreated={vi.fn()} />)

    fireEvent.click(await screen.findByRole('button', { name: 'Ver detalhes' }))
    expect(await screen.findByText(/A aplicação está bloqueada na interface e também no banco de dados/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Criar proposta de plano' })).not.toBeInTheDocument()
  })

  it('lets an approved template become a plan proposal', async () => {
    const approved = template({ status: 'approved' as PlanTemplateStatus, reviewedAt: '2026-08-16T12:00:00Z', reviewNotes: 'Conferido' })
    const dataSource = source([approved])
    const created = vi.fn()
    render(<Templates organizationId="org-1" dataSource={dataSource} patients={patients} canReview onPlanCreated={created} />)

    fireEvent.click(await screen.findByRole('button', { name: 'Ver detalhes' }))
    fireEvent.change(await screen.findByLabelText('Paciente'), { target: { value: 'patient-1' } })
    fireEvent.click(screen.getByRole('button', { name: 'Criar proposta de plano' }))

    await waitFor(() => expect(dataSource.applyTemplate).toHaveBeenCalledWith({ templateId: 'template-1', patientId: 'patient-1', weekdays: ['mon'] }))
    expect(created).toHaveBeenCalledWith('plan-1', 'patient-1')
  })

  it('requires a written review before approving', async () => {
    const dataSource = source([template()])
    const prompt = vi.spyOn(window, 'prompt').mockReturnValue('')
    render(<Templates organizationId="org-1" dataSource={dataSource} patients={patients} canReview onPlanCreated={vi.fn()} />)

    fireEvent.click(await screen.findByRole('button', { name: 'Revisar e aprovar' }))
    expect(await screen.findByText('A aprovação exige o registro da revisão.')).toBeInTheDocument()
    expect(dataSource.reviewTemplate).not.toHaveBeenCalled()
    prompt.mockRestore()
  })

  it('hides review actions from roles that cannot approve', async () => {
    const dataSource = source([template()])
    render(<Templates organizationId="org-1" dataSource={dataSource} patients={patients} canReview={false} onPlanCreated={vi.fn()} />)

    await screen.findByRole('button', { name: 'Ver detalhes' })
    expect(screen.queryByRole('button', { name: 'Revisar e aprovar' })).not.toBeInTheDocument()
  })
})
