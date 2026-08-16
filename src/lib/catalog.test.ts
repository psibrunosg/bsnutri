import { describe, expect, it } from 'vitest'
import { catalogRenderSrc, describeCatalogServing, deriveCatalogNutrients, deriveServingNutrients, foodRenderSrc, matchesCatalogSearch, parseCatalogImport } from './catalog'
import { emptyNutrients } from './nutrition'

describe('deriveCatalogNutrients',()=>{
  it('calcula a composição por 100 g usando ingredientes e rendimento',()=>{
    const rice={...emptyNutrients(),energyKcal:130,proteinG:2.5}
    const beans={...emptyNutrients(),energyKcal:76,proteinG:4.8}
    const result=deriveCatalogNutrients([
      {grams:200,nutrients:rice,available:['energyKcal','proteinG']},
      {grams:100,nutrients:beans,available:['energyKcal','proteinG']},
    ],300)
    expect(result.nutrients.energyKcal).toBeCloseTo(112)
    expect(result.nutrients.proteinG).toBeCloseTo(3.27,2)
  })

  it('mantém ausente o nutriente desconhecido em qualquer componente',()=>{
    const ingredient={...emptyNutrients(),energyKcal:100}
    const result=deriveCatalogNutrients([{grams:100,nutrients:ingredient,available:['energyKcal']}],100)
    expect(result.available).toEqual(['energyKcal'])
    expect(result.available).not.toContain('proteinG')
  })
})

describe('catalogRenderSrc',()=>{
  it('aceita somente renders WebP locais e versionados',()=>{
    expect(catalogRenderSrc('/food-renders/arroz-integral.webp')).toBe('/food-renders/arroz-integral.webp')
    expect(catalogRenderSrc('https://example.com/arroz.webp')).toBeNull()
    expect(catalogRenderSrc('/food-renders/arroz.png')).toBeNull()
  })
})

describe('foodRenderSrc',()=>{
  it('usa o render curado de peixe quando o item ainda não tem caminho próprio',()=>{
    expect(foodRenderSrc(null,'Peixe grelhado')).toBe('/food-renders/peixe-grelhado-legumes.webp')
    expect(foodRenderSrc(null,'Arroz integral')).toBeNull()
  })
})

describe('matchesCatalogSearch',()=>{
  const item={name:'Mandioca',preparationState:'cozida',searchTerms:['aipim','macaxeira'],culturalTags:['Nordeste'],restrictionTags:['sem glúten'],preferenceTags:['vegetariano'],availabilityTags:['safra local']}
  it('encontra sinônimos, acentos e metadados culturais',()=>{
    expect(matchesCatalogSearch(item,'macaxeira')).toBe(true)
    expect(matchesCatalogSearch(item,'sem gluten')).toBe(true)
    expect(matchesCatalogSearch(item,'cozida')).toBe(true)
    expect(matchesCatalogSearch(item,'peixe')).toBe(false)
  })
})

describe('deriveServingNutrients',()=>{
  it('calcula nutrientes da porção a partir da composição por 100 g',()=>{
    const result=deriveServingNutrients({...emptyNutrients(),energyKcal:112,proteinG:3.27},['energyKcal','proteinG'],150)
    expect(result.energyKcal).toBeCloseTo(168)
    expect(result.proteinG).toBeCloseTo(4.905)
  })
})

describe('describeCatalogServing',()=>{
  it('mostra medida caseira somente quando peso explícito existe',()=>{
    expect(describeCatalogServing({servingGrams:80,householdMeasureLabel:'1 concha',householdMeasureGrams:80})).toBe('1 concha · 80 g')
    expect(describeCatalogServing({servingGrams:80,householdMeasureLabel:null,householdMeasureGrams:null})).toBe('80 g · medida caseira não informada')
  })
})

describe('parseCatalogImport',()=>{
  it('gera uma prévia segura e bloqueia duplicidade ou nutrientes inválidos',()=>{
    const result=parseCatalogImport('nome;preparo;energia;proteína;carboidrato;gordura\nArroz;cozido;130;2,5;28;0,3\nArroz;cozido;130;2;28;0\nFeijão;cozido;-1;4;14;0,5',[{name:'Batata',preparationState:'cozida'}])
    expect(result.rows).toEqual([{name:'Arroz',preparationState:'cozido',energyKcal:130,proteinG:2.5,carbohydrateG:28,fatG:0.3}])
    expect(result.errors).toHaveLength(2)
  })
})
