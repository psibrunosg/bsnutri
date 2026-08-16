import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import PatientWizard from './PatientWizard'
import type { PatientDataSource, PatientIntakeInput } from '../lib/patients'

function dataSource(overrides: Partial<PatientDataSource> = {}): PatientDataSource {
  return {
    listPatients: vi.fn().mockResolvedValue({ data: [], error: null }),
    createPatientIntake: vi.fn().mockResolvedValue({ data: 'patient-1', error: null }),
    ...overrides,
  }
}

function fill(label: string, value: string) {
  fireEvent.change(screen.getByLabelText(label), { target: { value } })
}

describe('PatientWizard', () => {
  afterEach(() => cleanup())

  it('blocks advancing without a usable name', () => {
    render(<PatientWizard organizationId="org-1" dataSource={dataSource()} onCancel={vi.fn()} onCreated={vi.fn()} />)
    expect(screen.getByRole('button', { name: /Continuar/ })).toBeDisabled()
    fill('Nome completo *', 'Mariana Lopes')
    expect(screen.getByRole('button', { name: /Continuar/ })).toBeEnabled()
  })

  it('sends only the measures that were actually informed', async () => {
    const create = vi.fn().mockResolvedValue({ data: 'patient-1', error: null })
    const created = vi.fn()
    render(<PatientWizard organizationId="org-1" dataSource={dataSource({ createPatientIntake: create })} onCancel={vi.fn()} onCreated={created} />)

    fill('Nome completo *', 'Mariana Lopes')
    fill('Data de nascimento', '1990-05-10')
    fireEvent.click(screen.getByRole('button', { name: /Continuar/ }))

    fill('Peso corporal (kg)', '68,5')
    fill('Circunferência do quadril (cm)', '96')
    fireEvent.click(screen.getByRole('button', { name: /Continuar/ }))

    fireEvent.click(screen.getByRole('button', { name: 'Perda de peso' }))
    fireEvent.click(screen.getByRole('button', { name: /Concluir cadastro/ }))

    await waitFor(() => expect(create).toHaveBeenCalledOnce())
    const input = create.mock.calls[0][0] as PatientIntakeInput
    expect(input.fullName).toBe('Mariana Lopes')
    expect(input.birthDate).toBe('1990-05-10')
    expect(input.weightKg).toBe(68.5)
    expect(input.hipCm).toBe(96)
    expect(input.heightCm).toBeNull()
    expect(input.armCm).toBeNull()
    expect(input.bodyFatPercent).toBeNull()
    expect(input.objective).toBe('Perda de peso')
    await waitFor(() => expect(created).toHaveBeenCalledWith('patient-1'))
  })

  it('keeps the live reading empty until both measures exist', () => {
    render(<PatientWizard organizationId="org-1" dataSource={dataSource()} onCancel={vi.fn()} onCreated={vi.fn()} />)
    fill('Nome completo *', 'Mariana Lopes')
    fireEvent.click(screen.getByRole('button', { name: /Continuar/ }))

    expect(screen.getByText('Informe peso e estatura')).toBeInTheDocument()
    fill('Peso corporal (kg)', '68')
    expect(screen.getByText('Informe peso e estatura')).toBeInTheDocument()
    fill('Estatura (cm)', '168')
    expect(screen.getByText('Eutrofia')).toBeInTheDocument()
  })

  it('surfaces the transaction error instead of navigating away', async () => {
    const created = vi.fn()
    const create = vi.fn().mockResolvedValue({ data: null, error: { message: 'RLS negou a gravação' } })
    render(<PatientWizard organizationId="org-1" dataSource={dataSource({ createPatientIntake: create })} onCancel={vi.fn()} onCreated={created} />)

    fill('Nome completo *', 'Mariana Lopes')
    fireEvent.click(screen.getByRole('button', { name: /Continuar/ }))
    fireEvent.click(screen.getByRole('button', { name: /Continuar/ }))
    fireEvent.click(screen.getByRole('button', { name: /Concluir cadastro/ }))

    expect(await screen.findByRole('alert')).toHaveTextContent('RLS negou a gravação')
    expect(created).not.toHaveBeenCalled()
  })
})
