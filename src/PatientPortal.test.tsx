import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
const { fromMock, rpcMock, uploadMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn(), uploadMock: vi.fn() }))

vi.mock('./lib/supabase', () => ({
  supabase: {
    from: fromMock,
    rpc: rpcMock,
    auth: { getSession: vi.fn().mockResolvedValue({ data: { session: { user: { id: 'patient-user-1' } } } }) },
  },
}))

vi.mock('./lib/driveClient', async () => {
  const actual = await vi.importActual<typeof import('./lib/driveClient')>('./lib/driveClient')
  return { ...actual, createDriveClient: () => ({ uploadDiaryPhoto: uploadMock }) }
})

import { PatientPortal } from './PatientPortal'

function queryResult(data: unknown[] = []) {
  return {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    in: vi.fn().mockReturnThis(),
    order: vi.fn().mockResolvedValue({ data, error: null }),
  }
}

function mutationResult(data: unknown = null) {
  return {
    upsert: vi.fn().mockReturnThis(),
    insert: vi.fn().mockResolvedValue({ data, error: null }),
    select: vi.fn().mockReturnThis(),
    single: vi.fn().mockResolvedValue({ data, error: null }),
  }
}

const patient = { id: 'patient-1', full_name: 'Paciente Teste', anonymous_code: 'P01', organization_id: 'org-1', professional_id: 'pro-1' }

function plan(visibility: unknown) {
  return [{
    id: 'plan-1',
    title: 'Plano A',
    published_at: '2026-07-17T10:00:00Z',
    plan_versions: {
      id: 'version-1',
      version_no: 1,
      assistant_state: { visibility },
      plan_days: [{
        id: 'day-1',
        label: 'Dia 1',
        day_index: 0,
        meals: [{
          id: 'meal-1',
          label: 'Almoco',
          position: 0,
          suggested_time: null,
          meal_items: [{
            id: 'item-1',
            description: 'Arroz',
            grams: 100,
            nutrient_snapshot: { food_name: 'Arroz', nutrients: [{ code: 'energy_kcal', amount: 130 }, { code: 'protein_g', amount: 5 }, { code: 'carbohydrate_g', amount: 30 }, { code: 'fat_g', amount: 2 }] },
            meal_item_substitutions: [],
          }],
        }],
      }],
    },
  }]
}

describe('PatientPortal visibility controls', () => {
  afterEach(() => cleanup())

  beforeEach(() => {
    vi.clearAllMocks()
    rpcMock.mockResolvedValue({ data: [{ status: 'missing', can_upload_photos: false }], error: null })
    uploadMock.mockResolvedValue({ fileId: 'drive-file-1', webViewLink: 'https://drive/foto' })
  })

  it.each([
    [{ showTotalKcal: false, showTotalMacros: false, showMealCalculations: false }, false, false],
    [{ showTotalKcal: true, showTotalMacros: true, showMealCalculations: false }, true, false],
    [{ showTotalKcal: false, showTotalMacros: false, showMealCalculations: true }, false, true],
  ])('respeita visibilidade %j', async (visibility, showsPlanTotal, showsMealTotal) => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? plan(visibility) : []))

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')

    expect(screen.queryAllByText('130 kcal').length).toBe((showsPlanTotal ? 1 : 0) + (showsMealTotal ? 1 : 0))
  })

  it('desabilita foto quando Drive nao esta conectado e mantem diario textual', async () => {
    fromMock.mockImplementation((table: string) => queryResult(table === 'plans' ? plan({}) : []))

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')
    fireEvent.click(screen.getByRole('button', { name: /Registrar como foi/i }))

    expect(screen.getByLabelText(/Foto do diario/i)).toBeDisabled()
    expect(screen.getByLabelText(/Nota/i)).toBeEnabled()
  })

  it('envia foto para Drive conectado e salva metadados', async () => {
    const photoInsert = vi.fn().mockResolvedValue({ data: null, error: null })
    fromMock.mockImplementation((table: string) => {
      if (table === 'plans') return queryResult(plan({}))
      if (table === 'meal_checkins') return mutationResult({ id: 'checkin-123456789' })
      if (table === 'meal_checkin_photos') return { insert: photoInsert }
      return queryResult([])
    })
    rpcMock.mockResolvedValue({ data: [{ status: 'connected', can_upload_photos: true }], error: null })

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')
    fireEvent.click(screen.getByRole('button', { name: /Registrar como foi/i }))
    fireEvent.change(screen.getByLabelText(/Foto do diario/i), { target: { files: [new File(['foto'], 'foto.jpg', { type: 'image/jpeg' })] } })
    fireEvent.click(screen.getByRole('button', { name: /Salvar check-in/i }))

    await screen.findByText('Check-in salvo.')
    expect(uploadMock).toHaveBeenCalled()
    expect(photoInsert).toHaveBeenCalledWith(expect.objectContaining({ drive_file_id: 'drive-file-1', meal_checkin_id: 'checkin-123456789', created_by: 'patient-user-1' }))
  })

  it('nao cria metadado quando upload no Drive falha', async () => {
    const photoInsert = vi.fn().mockResolvedValue({ data: null, error: null })
    uploadMock.mockRejectedValueOnce(new Error('Drive fora'))
    fromMock.mockImplementation((table: string) => {
      if (table === 'plans') return queryResult(plan({}))
      if (table === 'meal_checkins') return mutationResult({ id: 'checkin-erro' })
      if (table === 'meal_checkin_photos') return { insert: photoInsert }
      return queryResult([])
    })
    rpcMock.mockResolvedValue({ data: [{ status: 'connected', can_upload_photos: true }], error: null })

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')
    fireEvent.click(screen.getByRole('button', { name: /Registrar como foi/i }))
    fireEvent.change(screen.getByLabelText(/Foto do diario/i), { target: { files: [new File(['foto'], 'foto.jpg', { type: 'image/jpeg' })] } })
    fireEvent.click(screen.getByRole('button', { name: /Salvar check-in/i }))

    await screen.findByText('Drive fora')
    expect(photoInsert).not.toHaveBeenCalled()
  })

  it('envia diario ampliado sem foto', async () => {
    const upsert = vi.fn().mockReturnThis()
    fromMock.mockImplementation((table: string) => {
      if (table === 'plans') return queryResult(plan({}))
      if (table === 'meal_checkins') return { upsert, select: vi.fn().mockReturnThis(), single: vi.fn().mockResolvedValue({ data: { id: 'checkin-texto' }, error: null }) }
      return queryResult([])
    })

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Plano A')
    fireEvent.click(screen.getByRole('button', { name: /Registrar como foi/i }))
    fireEvent.change(screen.getByLabelText(/Realiza/i), { target: { value: 'adapted' } })
    fireEvent.change(screen.getByLabelText(/Fome antes/i), { target: { value: '8' } })
    fireEvent.change(screen.getByLabelText(/Saciedade depois/i), { target: { value: '5' } })
    fireEvent.change(screen.getByLabelText(/Sintomas/i), { target: { value: 'Azia' } })
    fireEvent.change(screen.getByLabelText(/Intensidade do sintoma/i), { target: { value: '7' } })
    fireEvent.click(screen.getByLabelText(/Preciso de ajuda/i))
    fireEvent.click(screen.getByRole('button', { name: /Salvar check-in/i }))

    await screen.findByText('Check-in salvo.')
    expect(upsert).toHaveBeenCalledWith(expect.objectContaining({ state: 'adapted', hunger_before: 8, satiety_after: 5, symptoms: 'Azia', symptom_intensity: 7, help_requested: true }), { onConflict: 'patient_id,meal_id,occurred_on' })
    expect(uploadMock).not.toHaveBeenCalled()
  })

  it('salva rascunho e envia pre-consulta', async () => {
    const assignment = {
      id: 'assignment-1',
      status: 'pending',
      form_template_versions: {
        title: 'Anamnese adulto',
        form_fields: [
          { id: 'field-1', label: 'Objetivo principal', field_type: 'short_text', required: true, position: 0 },
          { id: 'field-2', label: 'Rotina alimentar', field_type: 'long_text', required: false, position: 1 },
        ],
      },
      form_responses: [],
    }
    fromMock.mockImplementation((table: string) => {
      if (table === 'plans') return queryResult(plan({}))
      if (table === 'form_assignments') return queryResult([assignment])
      return queryResult([])
    })

    render(<PatientPortal patient={patient}/>)
    await screen.findByText('Anamnese adulto')
    fireEvent.change(screen.getByLabelText(/Objetivo principal/i), { target: { value: 'Hipertrofia' } })
    fireEvent.click(screen.getByRole('button', { name: /Salvar rascunho/i }))
    expect(rpcMock).toHaveBeenCalledWith('save_form_response', expect.objectContaining({ target_assignment_id: 'assignment-1', target_submit: false }))

    fireEvent.click(screen.getByRole('button', { name: /Enviar pre-consulta/i }))
    expect(rpcMock).toHaveBeenCalledWith('save_form_response', expect.objectContaining({ target_assignment_id: 'assignment-1', target_submit: true }))
  })
})
