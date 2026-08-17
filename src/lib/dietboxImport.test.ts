import { describe, expect, it } from 'vitest'
import {
  detectDietboxTextKind,
  parseDietboxPlanText,
  parseDietboxSubstitutionListText,
} from './dietboxImport'

const PLAN_SAMPLE = `emagrecimento
Planejamento alimentar
07:30 - Hora de acordar
10:00 - Café da manhã
Opção principal Opção de substituição
Café - 1 Xícara(s) de café (80ml) Ou escolha 1 porção do grupo 1 da lista de substituição.
Ovo de galinha frito/mexido - 2 Unidade(s) média(s) (100g)
Ovo de galinha cozido - 2 Unidade(s) grande(s) (110g)
Peito de frango desfiado - 2 Colher(es) de sopa cheia(s) (50g)
Ou escolha 1 porção do grupo 4 da lista de substituição.
Mamão formosa - 1 Fatia(s) média(s) (170g)
Banana prata - 1 Unidade(s) grande(s) (55g)
Ou escolha 1 porção do grupo 9 da lista de substituição.
Observações:
No café da manhã podes fazer uma aveioca (aveia, ovo, tomatinho picado), torrada com pasta de ovos.
11:00 - Almoço`

const SUBSTITUTION_LIST_SAMPLE = `Lista de substituição
emagrecimento
Grupo 4: Carnes e Proteínas
Acém moído cozido
2 Colher(es) de sopa cheia(s) (55g)
Alcatra sem gordura grelhada
0.5 Bife(s) médio(s) (50g)
Asa de frango assada
2 Unidade(s) pequena(s) (60g)`

describe('detectDietboxTextKind', () => {
  it('recognizes a pasted cardápio by its time headers', () => {
    expect(detectDietboxTextKind(PLAN_SAMPLE)).toBe('plan')
  })

  it('recognizes a pasted substitution list by its group headers', () => {
    expect(detectDietboxTextKind(SUBSTITUTION_LIST_SAMPLE)).toBe('substitution_list')
  })

  it('reports unknown text instead of guessing', () => {
    expect(detectDietboxTextKind('qualquer coisa colada aqui')).toBe('unknown')
    expect(detectDietboxTextKind('')).toBe('unknown')
  })
})

describe('parseDietboxPlanText', () => {
  it('parses only real meals, skipping title lines and time markers with no items', () => {
    const { meals } = parseDietboxPlanText(PLAN_SAMPLE)
    expect(meals).toHaveLength(1)
    expect(meals[0].name).toBe('Café da manhã')
    expect(meals[0].time).toBe('10:00')
  })

  it('groups consecutive alternatives into one slot instead of summing them in the meal', () => {
    const { meals } = parseDietboxPlanText(PLAN_SAMPLE)
    const [meal] = meals
    expect(meal.slots).toHaveLength(3)

    const [coffee, protein, fruit] = meal.slots

    expect(coffee.primary).toEqual({ rawName: 'Café', quantity: 1, measure: 'Xícara(s) de café', grams: 80 })
    expect(coffee.alternatives).toEqual([])
    expect(coffee.dietboxGroupNo).toBe(1)

    expect(protein.primary.rawName).toBe('Ovo de galinha frito/mexido')
    expect(protein.primary.grams).toBe(100)
    expect(protein.alternatives.map((a) => a.rawName)).toEqual(['Ovo de galinha cozido', 'Peito de frango desfiado'])
    expect(protein.alternatives[0].grams).toBe(110)
    expect(protein.alternatives[1].grams).toBe(50)
    expect(protein.dietboxGroupNo).toBe(4)

    expect(fruit.primary.rawName).toBe('Mamão formosa')
    expect(fruit.alternatives.map((a) => a.rawName)).toEqual(['Banana prata'])
    expect(fruit.dietboxGroupNo).toBe(9)
  })

  it('captures the free-text note attached to the meal', () => {
    const { meals } = parseDietboxPlanText(PLAN_SAMPLE)
    expect(meals[0].notes).toBe(
      'No café da manhã podes fazer uma aveioca (aveia, ovo, tomatinho picado), torrada com pasta de ovos.',
    )
  })

  it('closes a slot with no group reference at the end of the meal block', () => {
    const text = `09:00 - Lanche\nÁgua de coco - 1 Copo(s) (200ml)`
    const { meals } = parseDietboxPlanText(text)
    expect(meals[0].slots).toEqual([
      { primary: { rawName: 'Água de coco', quantity: 1, measure: 'Copo(s)', grams: 200 }, alternatives: [], dietboxGroupNo: null },
    ])
  })

  it('accepts comma as a decimal separator in quantity', () => {
    const text = `09:00 - Lanche\nIogurte natural - 1,5 Pote(s) (180g)`
    const { meals } = parseDietboxPlanText(text)
    expect(meals[0].slots[0].primary.quantity).toBe(1.5)
  })

  it('returns no meals and no crash for empty or unrecognizable text', () => {
    expect(parseDietboxPlanText('')).toEqual({ meals: [], warnings: [] })
    expect(parseDietboxPlanText('texto qualquer sem formato').meals).toEqual([])
  })

  it('warns about a line it cannot parse instead of silently dropping it', () => {
    const text = `09:00 - Lanche\nlinha completamente fora do formato esperado sem parênteses`
    const { warnings } = parseDietboxPlanText(text)
    expect(warnings.some((w) => w.includes('linha completamente fora do formato'))).toBe(true)
  })
})

describe('parseDietboxSubstitutionListText', () => {
  it('parses groups with the two-line food shape (name, then quantity/measure)', () => {
    const { groups } = parseDietboxSubstitutionListText(SUBSTITUTION_LIST_SAMPLE)
    expect(groups).toHaveLength(1)
    const [group] = groups
    expect(group.groupNo).toBe(4)
    expect(group.title).toBe('Carnes e Proteínas')
    expect(group.foods).toEqual([
      { rawName: 'Acém moído cozido', quantity: 2, measure: 'Colher(es) de sopa cheia(s)', grams: 55 },
      { rawName: 'Alcatra sem gordura grelhada', quantity: 0.5, measure: 'Bife(s) médio(s)', grams: 50 },
      { rawName: 'Asa de frango assada', quantity: 2, measure: 'Unidade(s) pequena(s)', grams: 60 },
    ])
  })

  it('splits multiple groups pasted together', () => {
    const text = `${SUBSTITUTION_LIST_SAMPLE}\nGrupo 9: Frutas\nMamão formosa\n1 Fatia(s) média(s) (170g)`
    const { groups } = parseDietboxSubstitutionListText(text)
    expect(groups.map((g) => g.groupNo)).toEqual([4, 9])
    expect(groups[1].title).toBe('Frutas')
    expect(groups[1].foods).toEqual([
      { rawName: 'Mamão formosa', quantity: 1, measure: 'Fatia(s) média(s)', grams: 170 },
    ])
  })

  it('also accepts the single-line food shape for robustness', () => {
    const text = `Grupo 1: Bebidas\nCafé - 1 Xícara(s) de café (80ml)`
    const { groups } = parseDietboxSubstitutionListText(text)
    expect(groups[0].foods).toEqual([{ rawName: 'Café', quantity: 1, measure: 'Xícara(s) de café', grams: 80 }])
  })

  it('returns no groups for empty text', () => {
    expect(parseDietboxSubstitutionListText('')).toEqual({ groups: [], warnings: [] })
  })
})
