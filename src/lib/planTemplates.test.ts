import { describe, expect, it } from 'vitest'
import {
  TEMPLATE_PAGE_SIZE,
  isTemplateUsable,
  mapPlanTemplate,
  provenanceLabel,
  type PlanTemplateSummaryRow,
} from './planTemplates'

function row(overrides: Partial<PlanTemplateSummaryRow> = {}): PlanTemplateSummaryRow {
  return {
    id: 'template-1',
    name: 'Low carb · definição',
    objective: null,
    tags: null,
    scope: 'organization',
    status: 'needs_review',
    provenance: null,
    reviewed_at: null,
    review_notes: null,
    catalog_key: null,
    ...overrides,
  }
}

describe('mapPlanTemplate', () => {
  it('defaults missing tags and provenance without inventing content', () => {
    const mapped = mapPlanTemplate(row())
    expect(mapped.tags).toEqual([])
    expect(mapped.provenance).toEqual({})
    expect(mapped.reviewedAt).toBeNull()
  })
})

describe('isTemplateUsable', () => {
  it('only lets an approved template reach a patient', () => {
    expect(isTemplateUsable({ status: 'approved' })).toBe(true)
    expect(isTemplateUsable({ status: 'needs_review' })).toBe(false)
    expect(isTemplateUsable({ status: 'archived' })).toBe(false)
  })
})

describe('provenanceLabel', () => {
  it('names where the template came from', () => {
    expect(provenanceLabel({ origin: 'seed', catalog_key: 'dietbox-12' })).toBe('Importado do catálogo (dietbox-12)')
    expect(provenanceLabel({ origin: 'seed' })).toBe('Importado do catálogo')
    expect(provenanceLabel({ origin: 'plan' })).toBe('Derivado de um plano da clínica')
    expect(provenanceLabel({ origin: 'manual' })).toBe('Criado manualmente na clínica')
  })

  it('says the origin is unknown instead of guessing', () => {
    expect(provenanceLabel({})).toBe('Origem não registrada')
  })
})

describe('TEMPLATE_PAGE_SIZE', () => {
  it('lists 24 templates per page', () => {
    expect(TEMPLATE_PAGE_SIZE).toBe(24)
  })
})
