import { describe, expect, it, vi } from 'vitest'
import { printClinicalDocument } from './clinicalExport'

describe('printClinicalDocument',()=>{
  it('escapa o conteúdo antes de abrir a impressão',()=>{
    const write=vi.fn(),print=vi.fn(),focus=vi.fn()
    vi.spyOn(window,'open').mockReturnValue({document:{write,close:vi.fn()},print,focus} as unknown as Window)
    expect(printClinicalDocument('Plano <teste>','Paciente','Arroz & feijão')).toBe(true)
    expect(write).toHaveBeenCalledWith(expect.stringContaining('Plano &lt;teste&gt;'))
    expect(write).toHaveBeenCalledWith(expect.stringContaining('Arroz &amp; feijão'))
  })
})
