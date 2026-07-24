import { describe, expect, it } from 'vitest'
import { comparePlanDays, comparePlanNutrition } from './planComparison'
import { emptyNutrients } from './nutrition'

const day=(grams:number)=>[{id:'d',label:'Dia 1',kind:'standard',meals:[{id:'m',name:'Almoço',items:[{id:'i',name:'Arroz',grams,nutrientsPer100g:{...emptyNutrients(),energyKcal:100}}]}]}]
describe('comparePlanDays',()=>{it('explica alteração de porção',()=>expect(comparePlanDays(day(100),day(120))).toEqual(['Alterado: Dia 1 · Almoço · Arroz, 100 g para 120 g.']))})
describe('comparePlanNutrition',()=>{it('mostra impacto nutricional agregado',()=>expect(comparePlanNutrition(day(100),day(200))).toContain('Energia: +100 kcal.'))})
