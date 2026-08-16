import { describe, expect, it } from 'vitest'
import { rankSubstitutions } from './substitutionEngine'

const reference={id:'rice',name:'Arroz',nutrients:{energyKcal:130,proteinG:2.5,carbohydrateG:28,fatG:.3,fiberG:1.6}}
describe('rankSubstitutions',()=>{
  it('elimina restrição antes de ordenar e explica a escolha',()=>{
    const result=rankSubstitutions([{...reference,id:'a',name:'Batata',tags:['sem glúten','Nordeste'],costBand:'low',preparationMinutes:12},{...reference,id:'b',name:'Massa',tags:['glúten'],costBand:'low'}],{reference,excludedTags:['glúten'],preferredTags:['Nordeste']})
    expect(result.map(item=>item.id)).toEqual(['a'])
    expect(result[0].reasons).toContain('preferência: Nordeste')
  })
})
