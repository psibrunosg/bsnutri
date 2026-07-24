import { describe, expect, it } from 'vitest'
import { builtInPlanModels, matchesModel } from './planModels'

describe('modelos de plano',()=>{
  it('oferece modelos gerais e especializados revisáveis',()=>{
    expect(builtInPlanModels).toHaveLength(18)
    expect(builtInPlanModels.map(model=>model.name)).toContain('Hipertrofia')
    const renal=builtInPlanModels.find(model=>model.id==='renal')
    expect(renal?.sources).toContain('KDIGO 2024 CKD Guideline')
    expect(renal?.limits?.[0]).toMatch(/contexto/i)
  })

  it('combina filtros sem confundir abordagem e objetivo',()=>{
    const models=builtInPlanModels.filter(model=>matchesModel(model,{approaches:['Flexível'],objectives:['Hipertrofia']}))
    expect(models.map(model=>model.id)).toEqual(['hypertrophy'])
  })
})
