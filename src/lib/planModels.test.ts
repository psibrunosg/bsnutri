import { describe, expect, it } from 'vitest'
import { builtInPlanModels, matchesModel } from './planModels'

describe('modelos de plano',()=>{
  it('oferece os modelos aprovados para a primeira fase',()=>{
    expect(builtInPlanModels).toHaveLength(11)
    expect(builtInPlanModels.map(model=>model.name)).toContain('Hipertrofia')
  })

  it('combina filtros sem confundir abordagem e objetivo',()=>{
    const models=builtInPlanModels.filter(model=>matchesModel(model,{approaches:['Flexível'],objectives:['Hipertrofia']}))
    expect(models.map(model=>model.id)).toEqual(['hypertrophy'])
  })
})
