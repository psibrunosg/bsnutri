export interface ParsedFoodLine {
  rawName: string
  quantity: number
  measure: string
  grams: number
}

export interface ParsedSlot {
  primary: ParsedFoodLine
  alternatives: ParsedFoodLine[]
  dietboxGroupNo: number | null
}

export interface ParsedDietboxMeal {
  name: string
  time: string | null
  notes: string | null
  slots: ParsedSlot[]
}

export interface ParsedDietboxGroup {
  groupNo: number
  title: string
  foods: ParsedFoodLine[]
}

const MEAL_HEADER_RE = /^(\d{1,2}:\d{2})\s*-\s*(.+)$/
const GROUP_HEADER_RE = /^Grupo\s+(\d+)\s*:\s*(.+)$/i
const TABLE_HEADER_RE = /^Op[cç][ãa]o principal\s+Op[cç][ãa]o de substitui[cç][ãa]o$/i
const OBSERVACOES_RE = /^Observa[cç][õo]es:?\s*$/i
const GROUP_REF_RE = /ou escolha[^.]*grupo\s+(\d+)\b[^.]*substitui[^.]*\.?/i
const SUBSTITUTION_LIST_TITLE_RE = /^Lista de substitui[cç][ãa]o$/i

// `(80ml)`/`(100g)` — o parênteses final é sempre a única leitura possível porque é a
// única âncora presa ao fim da linha; medidas caseiras como "Unidade(s)" têm parênteses
// no meio, mas não terminam a linha com dígitos+g/ml, então o backtracking do regex
// sempre resolve para o parênteses correto.
const ONE_LINE_FOOD_RE = /^(.+?)\s*-\s*([\d.,]+)\s+(.+?)\s*\(([\d.,]+)\s*(?:g|ml)\)\s*$/i
const QTY_LINE_RE = /^([\d.,]+)\s+(.+?)\s*\(([\d.,]+)\s*(?:g|ml)\)\s*$/i

function parseNum(raw: string): number {
  return Number(raw.replace(',', '.'))
}

function splitLines(text: string): string[] {
  return text
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
}

function parseOneLineFood(line: string): ParsedFoodLine | null {
  const match = ONE_LINE_FOOD_RE.exec(line)
  if (!match) return null
  return { rawName: match[1].trim(), quantity: parseNum(match[2]), measure: match[3].trim(), grams: parseNum(match[4]) }
}

/** Lê um alimento a partir da linha `index`: formato de uma linha, ou nome + medida em duas linhas. */
function takeFoodLine(lines: string[], index: number): { food: ParsedFoodLine; consumed: number } | null {
  const oneLine = parseOneLineFood(lines[index])
  if (oneLine) return { food: oneLine, consumed: 1 }
  const next = lines[index + 1]
  if (next === undefined) return null
  const qtyMatch = QTY_LINE_RE.exec(next)
  if (!qtyMatch) return null
  return {
    food: { rawName: lines[index].trim(), quantity: parseNum(qtyMatch[1]), measure: qtyMatch[2].trim(), grams: parseNum(qtyMatch[3]) },
    consumed: 2,
  }
}

export function detectDietboxTextKind(text: string): 'plan' | 'substitution_list' | 'unknown' {
  const lines = splitLines(text)
  if (lines.some((line) => GROUP_HEADER_RE.test(line) || SUBSTITUTION_LIST_TITLE_RE.test(line))) return 'substitution_list'
  if (lines.some((line) => MEAL_HEADER_RE.test(line))) return 'plan'
  return 'unknown'
}

function closeSlot(pending: ParsedFoodLine[], groupNo: number | null): ParsedSlot {
  const [primary, ...alternatives] = pending
  return { primary, alternatives, dietboxGroupNo: groupNo }
}

function parseMealBlock(lines: string[], warnings: string[]): { slots: ParsedSlot[]; notes: string | null } {
  const slots: ParsedSlot[] = []
  let pending: ParsedFoodLine[] = []
  let notes: string | null = null
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    if (OBSERVACOES_RE.test(line)) {
      notes = lines.slice(i + 1).join(' ').trim() || null
      break
    }
    if (TABLE_HEADER_RE.test(line)) {
      i += 1
      continue
    }
    const groupMatch = GROUP_REF_RE.exec(line)
    if (groupMatch) {
      const foodPart = line.slice(0, groupMatch.index).trim()
      if (foodPart) {
        const food = parseOneLineFood(foodPart)
        if (food) pending.push(food)
        else warnings.push(`Linha não reconhecida: "${line}"`)
      }
      if (pending.length) {
        slots.push(closeSlot(pending, Number(groupMatch[1])))
        pending = []
      }
      i += 1
      continue
    }
    const taken = takeFoodLine(lines, i)
    if (taken) {
      pending.push(taken.food)
      i += taken.consumed
      continue
    }
    warnings.push(`Linha não reconhecida: "${line}"`)
    i += 1
  }
  if (pending.length) slots.push(closeSlot(pending, null))
  return { slots, notes }
}

export function parseDietboxPlanText(text: string): { meals: ParsedDietboxMeal[]; warnings: string[] } {
  const lines = splitLines(text)
  const firstHeader = lines.findIndex((line) => MEAL_HEADER_RE.test(line))
  if (firstHeader === -1) return { meals: [], warnings: [] }

  type RawBlock = { time: string; name: string; lines: string[] }
  const blocks: RawBlock[] = []
  for (let i = firstHeader; i < lines.length; i += 1) {
    const headerMatch = MEAL_HEADER_RE.exec(lines[i])
    if (headerMatch) {
      blocks.push({ time: headerMatch[1], name: headerMatch[2].trim(), lines: [] })
      continue
    }
    blocks[blocks.length - 1].lines.push(lines[i])
  }

  const warnings: string[] = []
  const meals: ParsedDietboxMeal[] = []
  for (const block of blocks) {
    const { slots, notes } = parseMealBlock(block.lines, warnings)
    if (!slots.length) continue
    meals.push({ name: block.name, time: block.time, notes, slots })
  }
  return { meals, warnings }
}

export function parseDietboxSubstitutionListText(text: string): { groups: ParsedDietboxGroup[]; warnings: string[] } {
  const lines = splitLines(text)
  const firstHeader = lines.findIndex((line) => GROUP_HEADER_RE.test(line))
  if (firstHeader === -1) return { groups: [], warnings: [] }

  type RawBlock = { groupNo: number; title: string; lines: string[] }
  const blocks: RawBlock[] = []
  for (let i = firstHeader; i < lines.length; i += 1) {
    const headerMatch = GROUP_HEADER_RE.exec(lines[i])
    if (headerMatch) {
      blocks.push({ groupNo: Number(headerMatch[1]), title: headerMatch[2].trim(), lines: [] })
      continue
    }
    blocks[blocks.length - 1].lines.push(lines[i])
  }

  const warnings: string[] = []
  const groups: ParsedDietboxGroup[] = []
  for (const block of blocks) {
    const foods: ParsedFoodLine[] = []
    let i = 0
    while (i < block.lines.length) {
      const taken = takeFoodLine(block.lines, i)
      if (taken) {
        foods.push(taken.food)
        i += taken.consumed
        continue
      }
      warnings.push(`Linha não reconhecida no grupo ${block.groupNo}: "${block.lines[i]}"`)
      i += 1
    }
    groups.push({ groupNo: block.groupNo, title: block.title, foods })
  }
  return { groups, warnings }
}
