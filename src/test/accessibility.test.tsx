import { cleanup, render, screen, waitFor } from '@testing-library/react'
import axe from 'axe-core'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('../lib/supabase', async () => {
  const { supabaseStub } = await import('./supabaseStub')
  return { isSupabaseConfigured: true, supabase: supabaseStub() }
})

const { Shell } = await import('../components/Shell')
const { default: Login } = await import('../pages/Login')
const { default: Patients } = await import('../pages/Patients')
const { default: PatientWizard } = await import('../pages/PatientWizard')

const workspace = {
  organizationId: 'organization-1',
  organizationName: 'Clínica Aurora',
  memberName: 'Dra. Ana',
  role: 'nutritionist' as const,
}

const dataSource = {
  listPatients: vi.fn().mockResolvedValue({ data: [], error: null }),
  createPatientIntake: vi.fn().mockResolvedValue({ data: 'patient-1', error: null }),
}

/** Roda o axe apenas nas regras estáveis em jsdom (contraste depende de layout real). */
async function auditFor(container: HTMLElement) {
  const result = await axe.run(container, {
    runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] },
    rules: { 'color-contrast': { enabled: false }, region: { enabled: false } },
  })
  return result.violations.map((violation) => `${violation.id}: ${violation.help}`)
}

describe('acessibilidade das jornadas críticas', () => {
  afterEach(() => cleanup())

  it('tela de acesso sem violações WCAG A/AA verificáveis', async () => {
    const { container } = render(<Login />)
    await screen.findByRole('heading', { level: 2 })
    expect(await auditFor(container)).toEqual([])
  })

  it('shell profissional sem violações WCAG A/AA verificáveis', async () => {
    const { container } = render(
      <Shell route={{ page: 'dashboard' }} workspace={workspace} onNavigate={vi.fn()} onLogout={vi.fn()}>
        <h1>Visão geral</h1>
      </Shell>,
    )
    expect(await auditFor(container)).toEqual([])
  })

  it('diretório de pacientes sem violações WCAG A/AA verificáveis', async () => {
    const { container } = render(
      <Patients patients={[]} loading={false} error="" onOpenPatient={vi.fn()} onCreatePatient={vi.fn()} />,
    )
    expect(await auditFor(container)).toEqual([])
  })

  it('cadastro clínico sem violações WCAG A/AA verificáveis', async () => {
    const { container } = render(
      <PatientWizard organizationId="org-1" dataSource={dataSource} onCancel={vi.fn()} onCreated={vi.fn()} />,
    )
    await waitFor(() => expect(screen.getByLabelText('Nome completo *')).toBeInTheDocument())
    expect(await auditFor(container)).toEqual([])
  })
})
