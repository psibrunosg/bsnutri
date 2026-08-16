import { pageRange } from './catalogSearch'
import { supabase } from './supabase'

export const TEMPLATE_PAGE_SIZE = 24

export type PlanTemplateStatus = 'needs_review' | 'approved' | 'archived'

export const TEMPLATE_STATUS_LABELS: Record<PlanTemplateStatus, string> = {
  needs_review: 'Pendente de revisão',
  approved: 'Aprovado',
  archived: 'Arquivado',
}

export interface PlanTemplateSummary {
  id: string
  name: string
  objective: string | null
  tags: string[]
  scope: string
  status: PlanTemplateStatus
  provenance: Record<string, unknown>
  reviewedAt: string | null
  reviewNotes: string | null
  catalogKey: string | null
}

export interface PlanTemplateSummaryRow {
  id: string
  name: string
  objective: string | null
  tags: string[] | null
  scope: string
  status: PlanTemplateStatus
  provenance: Record<string, unknown> | null
  reviewed_at: string | null
  review_notes: string | null
  catalog_key: string | null
}

export interface PlanTemplateDetail extends PlanTemplateSummary {
  snapshot: unknown
  rules: unknown
  dimensions: unknown
}

export interface PlanTemplatePage {
  templates: PlanTemplateSummary[]
  total: number
  page: number
  pageSize: number
  pageCount: number
}

export interface PlanTemplateSearchInput {
  organizationId: string
  query: string
  status: PlanTemplateStatus | 'all'
  page: number
  pageSize?: number
}

export interface PlanTemplateDataSource {
  listTemplates(input: PlanTemplateSearchInput): Promise<{ data: PlanTemplatePage | null; error: { message: string } | null }>
  getTemplateDetail(id: string): Promise<{ data: PlanTemplateDetail | null; error: { message: string } | null }>
  reviewTemplate(id: string, status: PlanTemplateStatus, notes: string | null): Promise<{ error: { message: string } | null }>
  applyTemplate(input: { templateId: string; patientId: string; weekdays: string[] }): Promise<{ data: { id: string } | null; error: { message: string } | null }>
}

/** Deliberadamente sem `snapshot`: a listagem não carrega a estrutura completa dos modelos. */
const SUMMARY_SELECT = 'id,name,objective,tags,scope,status,provenance,reviewed_at,review_notes,catalog_key'

export function mapPlanTemplate(row: PlanTemplateSummaryRow): PlanTemplateSummary {
  return {
    id: row.id,
    name: row.name,
    objective: row.objective,
    tags: row.tags ?? [],
    scope: row.scope,
    status: row.status,
    provenance: row.provenance ?? {},
    reviewedAt: row.reviewed_at,
    reviewNotes: row.review_notes,
    catalogKey: row.catalog_key,
  }
}

export function isTemplateUsable(template: Pick<PlanTemplateSummary, 'status'>): boolean {
  return template.status === 'approved'
}

export function provenanceLabel(provenance: Record<string, unknown>): string {
  const origin = typeof provenance.origin === 'string' ? provenance.origin : null
  if (origin === 'seed') {
    const key = typeof provenance.catalog_key === 'string' ? provenance.catalog_key : null
    return key ? `Importado do catálogo (${key})` : 'Importado do catálogo'
  }
  if (origin === 'plan') return 'Derivado de um plano da clínica'
  if (origin === 'manual') return 'Criado manualmente na clínica'
  return 'Origem não registrada'
}

export function createSupabasePlanTemplateDataSource(): PlanTemplateDataSource {
  return {
    async listTemplates({ organizationId, query, status, page, pageSize = TEMPLATE_PAGE_SIZE }) {
      const { from, to } = pageRange(page, pageSize)
      let request = supabase
        .from('plan_templates')
        .select(SUMMARY_SELECT, { count: 'exact' })
        .eq('organization_id', organizationId)
      if (status !== 'all') request = request.eq('status', status)
      const term = query.trim()
      if (term) request = request.ilike('name', `%${term}%`)
      const result = await request.order('name').range(from, to)
      if (result.error) return { data: null, error: { message: result.error.message } }
      const total = result.count ?? 0
      return {
        data: {
          templates: ((result.data ?? []) as unknown as PlanTemplateSummaryRow[]).map(mapPlanTemplate),
          total,
          page: Math.floor(from / pageSize) + 1,
          pageSize,
          pageCount: Math.max(1, Math.ceil(total / pageSize)),
        },
        error: null,
      }
    },

    async getTemplateDetail(id) {
      const result = await supabase
        .from('plan_templates')
        .select(`${SUMMARY_SELECT},snapshot,rules,dimensions`)
        .eq('id', id)
        .maybeSingle()
      if (result.error) return { data: null, error: { message: result.error.message } }
      if (!result.data) return { data: null, error: { message: 'Modelo não encontrado.' } }
      const row = result.data as unknown as PlanTemplateSummaryRow & { snapshot: unknown; rules: unknown; dimensions: unknown }
      return { data: { ...mapPlanTemplate(row), snapshot: row.snapshot, rules: row.rules, dimensions: row.dimensions }, error: null }
    },

    async reviewTemplate(id, status, notes) {
      const result = await supabase.rpc('review_plan_template', {
        target_template_id: id,
        target_status: status,
        target_notes: notes,
      })
      return { error: result.error ? { message: result.error.message } : null }
    },

    async applyTemplate({ templateId, patientId, weekdays }) {
      const result = await supabase.rpc('apply_plan_template_to_patient', {
        target_template_id: templateId,
        target_patient_id: patientId,
        target_days: Math.max(1, weekdays.length),
        target_weekdays: weekdays.length ? weekdays : undefined,
      })
      if (result.error) return { data: null, error: { message: result.error.message } }
      const plan = result.data as { id: string } | null
      return { data: plan, error: null }
    },
  }
}
