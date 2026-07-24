import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { SettingsWorkspace } from './SettingsWorkspace'

const { fromMock, rpcMock } = vi.hoisted(() => ({ fromMock: vi.fn(), rpcMock: vi.fn() }))
vi.mock('./lib/supabase', () => ({ supabase: { from: fromMock, rpc: rpcMock } }))

function queryResult(data: unknown[] = []) {
  return { select: vi.fn().mockReturnThis(), order: vi.fn().mockResolvedValue({ data, error: null }), or: vi.fn().mockReturnThis(), eq: vi.fn().mockResolvedValue({ data, error: null }) }
}

describe('SettingsWorkspace', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    fromMock.mockImplementation((table: string) => queryResult(table === 'food_sources' ? [{ id: 'source-1', name: 'TACO', code: 'taco', dataset_version: 'v1' }] : []))
    rpcMock.mockResolvedValue({ error: null })
  })

  afterEach(() => document.body.replaceChildren())

  it('mantém a importação nas configurações e libera somente a prévia válida', async () => {
    render(<SettingsWorkspace organizationId="org-1" />)
    fireEvent.change(await screen.findByLabelText('Dados para importação'), { target: { value: 'nome;preparo;energia;proteína;carboidrato;gordura\nArroz;cozido;130;2,5;28;0,3' } })
    const button=screen.getByRole('button', { name: 'Importar prévia validada' })
    expect(button).toBeDisabled()
    fireEvent.change(screen.getByLabelText('Fonte da importação'), { target: { value: 'source-1' } })
    expect(button).toBeEnabled()
  })
})
