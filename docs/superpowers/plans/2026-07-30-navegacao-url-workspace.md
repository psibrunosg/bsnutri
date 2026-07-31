# Navegação por URL do menu principal e do paciente selecionado — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Toda página principal do Dashboard e o paciente selecionado ficam representados na URL, com voltar/avançar do navegador funcionando, sem mudar nenhum comportamento visível hoje.

**Architecture:** Um hook próprio (`useAppRoute`) lê e escreve `page` e `patient` como `URLSearchParams`, sincroniza com `window.history.pushState` e o evento `popstate`. `App.tsx` troca os estados locais `page`/`selected` por esse hook. Nenhuma biblioteca de rotas é adicionada: o app tem 5 páginas fixas e 1 parâmetro de paciente, o que não justifica `react-router` (não está instalado; ver `package.json`).

**Tech Stack:** React 19, TypeScript, Vitest, @testing-library/react (já instalados). Nenhuma dependência nova.

## Global Constraints

- Não adicionar dependência nova para isto (`react-router` não está em `package.json`; History API nativa resolve o caso de 5 páginas + 1 parâmetro).
- Preservar 100% do comportamento atual do menu, incluindo a regra do papel `receptionist` ficar travado em `care`.
- Toda superfície principal precisa de URL própria; voltar e avançar do navegador devem funcionar (`docs/PLANO_REDESIGN_DESENVOLVIMENTO_AUTONOMO_BSNUTRI_V2.md`, seção 5.4).
- Nenhuma abstração especulativa: o hook cobre só `page` e `patientId`, não um sistema genérico de rotas.
- `npm test`, `npm run lint` e `npm run build` precisam passar sem erro ao final.
- Commits pequenos e intencionais, um por task.

---

## File Structure

- Create: `src/lib/appRoute.ts` — funções puras `parseAppRoute` e `routeToSearch` (sem React, fáceis de testar isoladas).
- Create: `src/lib/appRoute.test.ts` — testes das funções puras.
- Create: `src/lib/useAppRoute.ts` — hook React que liga `appRoute.ts` ao `window.location` e ao histórico.
- Create: `src/lib/useAppRoute.test.tsx` — testes do hook com `renderHook`.
- Modify: `src/App.tsx:134-224` (`Dashboard`) — troca `useState<'patients'|...>` e `useState<Patient|null>` pelo hook.
- Modify: `docs/PLANO_REDESIGN_DESENVOLVIMENTO_AUTONOMO_BSNUTRI_V2.md` — nenhuma mudança de conteúdo, só referência no handoff final (task 4).

---

### Task 1: Funções puras de rota (`appRoute.ts`)

**Files:**
- Create: `src/lib/appRoute.ts`
- Test: `src/lib/appRoute.test.ts`

**Interfaces:**
- Produces: `export type Page = 'patients' | 'nutrition' | 'care' | 'content' | 'settings'`
- Produces: `export type AppRoute = { page: Page; patientId: string | null }`
- Produces: `export function parseAppRoute(search: string, fallbackPage: Page): AppRoute`
- Produces: `export function routeToSearch(route: AppRoute): string` — retorna `''` ou `'?page=...&patient=...'`, sem `?` quando vazio.

- [ ] **Step 1: Write the failing test**

```typescript
// src/lib/appRoute.test.ts
import { describe, expect, it } from 'vitest'
import { parseAppRoute, routeToSearch } from './appRoute'

describe('parseAppRoute', () => {
  it('usa a página padrão quando não há query string', () => {
    expect(parseAppRoute('', 'patients')).toEqual({ page: 'patients', patientId: null })
  })

  it('lê a página informada na query string', () => {
    expect(parseAppRoute('?page=nutrition', 'patients')).toEqual({ page: 'nutrition', patientId: null })
  })

  it('ignora página desconhecida e usa a padrão', () => {
    expect(parseAppRoute('?page=inexistente', 'patients')).toEqual({ page: 'patients', patientId: null })
  })

  it('lê o paciente selecionado', () => {
    expect(parseAppRoute('?page=patients&patient=abc-123', 'patients')).toEqual({ page: 'patients', patientId: 'abc-123' })
  })
})

describe('routeToSearch', () => {
  it('serializa apenas a página quando não há paciente', () => {
    expect(routeToSearch({ page: 'care', patientId: null })).toBe('?page=care')
  })

  it('serializa página e paciente', () => {
    expect(routeToSearch({ page: 'patients', patientId: 'abc-123' })).toBe('?page=patients&patient=abc-123')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/lib/appRoute.test.ts`
Expected: FAIL with "Cannot find module './appRoute'"

- [ ] **Step 3: Write minimal implementation**

```typescript
// src/lib/appRoute.ts
export type Page = 'patients' | 'nutrition' | 'care' | 'content' | 'settings'
export type AppRoute = { page: Page; patientId: string | null }

const PAGES: Page[] = ['patients', 'nutrition', 'care', 'content', 'settings']

function isPage(value: string | null): value is Page {
  return value !== null && (PAGES as string[]).includes(value)
}

export function parseAppRoute(search: string, fallbackPage: Page): AppRoute {
  const params = new URLSearchParams(search)
  const rawPage = params.get('page')
  const page = isPage(rawPage) ? rawPage : fallbackPage
  const patientId = params.get('patient')
  return { page, patientId: patientId || null }
}

export function routeToSearch(route: AppRoute): string {
  const params = new URLSearchParams()
  params.set('page', route.page)
  if (route.patientId) params.set('patient', route.patientId)
  const value = params.toString()
  return value ? `?${value}` : ''
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/lib/appRoute.test.ts`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add src/lib/appRoute.ts src/lib/appRoute.test.ts
git commit -m "feat: adicionar funcoes puras de rota do app"
```

---

### Task 2: Hook `useAppRoute`

**Files:**
- Create: `src/lib/useAppRoute.ts`
- Test: `src/lib/useAppRoute.test.tsx`

**Interfaces:**
- Consumes: `parseAppRoute`, `routeToSearch`, `Page`, `AppRoute` from `./appRoute` (Task 1).
- Produces: `export function useAppRoute(fallbackPage: Page): [AppRoute, (next: AppRoute) => void]`. O segundo item navega: chama `window.history.pushState` quando a query muda e atualiza o estado local. Reage a `popstate` (voltar/avançar do navegador) atualizando o estado a partir de `window.location.search`.

- [ ] **Step 1: Write the failing test**

```typescript
// src/lib/useAppRoute.test.tsx
import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { useAppRoute } from './useAppRoute'

describe('useAppRoute', () => {
  beforeEach(() => {
    window.history.replaceState(null, '', '/')
  })

  afterEach(() => {
    window.history.replaceState(null, '', '/')
  })

  it('parte da página padrão quando a URL não tem parâmetros', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    expect(result.current[0]).toEqual({ page: 'patients', patientId: null })
  })

  it('lê a rota inicial a partir da URL atual', () => {
    window.history.replaceState(null, '', '/?page=nutrition&patient=abc')
    const { result } = renderHook(() => useAppRoute('patients'))
    expect(result.current[0]).toEqual({ page: 'nutrition', patientId: 'abc' })
  })

  it('navigate atualiza o estado e empilha uma entrada no histórico', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    act(() => result.current[1]({ page: 'care', patientId: null }))
    expect(result.current[0]).toEqual({ page: 'care', patientId: null })
    expect(window.location.search).toBe('?page=care')
  })

  it('popstate (botão voltar) atualiza o estado a partir da URL', () => {
    const { result } = renderHook(() => useAppRoute('patients'))
    act(() => result.current[1]({ page: 'nutrition', patientId: null }))
    act(() => {
      window.history.replaceState(null, '', '?page=patients')
      window.dispatchEvent(new PopStateEvent('popstate'))
    })
    expect(result.current[0]).toEqual({ page: 'patients', patientId: null })
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/lib/useAppRoute.test.tsx`
Expected: FAIL with "Cannot find module './useAppRoute'"

- [ ] **Step 3: Write minimal implementation**

```typescript
// src/lib/useAppRoute.ts
import { useCallback, useEffect, useState } from 'react'
import { parseAppRoute, routeToSearch, type AppRoute, type Page } from './appRoute'

export function useAppRoute(fallbackPage: Page): [AppRoute, (next: AppRoute) => void] {
  const [route, setRoute] = useState<AppRoute>(() => parseAppRoute(window.location.search, fallbackPage))

  useEffect(() => {
    const onPopState = () => setRoute(parseAppRoute(window.location.search, fallbackPage))
    window.addEventListener('popstate', onPopState)
    return () => window.removeEventListener('popstate', onPopState)
  }, [fallbackPage])

  const navigate = useCallback((next: AppRoute) => {
    const search = routeToSearch(next)
    if (search !== window.location.search) window.history.pushState(null, '', search || window.location.pathname)
    setRoute(next)
  }, [])

  return [route, navigate]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/lib/useAppRoute.test.tsx`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add src/lib/useAppRoute.ts src/lib/useAppRoute.test.tsx
git commit -m "feat: adicionar hook de rota sincronizado com o historico"
```

---

### Task 3: Ligar o hook ao `Dashboard` em `App.tsx`

**Files:**
- Modify: `src/App.tsx:134-224`

**Interfaces:**
- Consumes: `useAppRoute` de `./lib/useAppRoute` (Task 2); `Page` de `./lib/appRoute`.
- Produces: nenhuma interface nova — o comportamento visível do `Dashboard` continua idêntico. `page` e `selected` deixam de ser `useState` locais e passam a derivar do hook.

Comportamento atual que precisa ser preservado exatamente:
1. `isReceptionist` força `page` para `'care'` e `selected` para `null` (hoje via `useEffect`, linhas 172-177).
2. Clicar em um item do menu muda a página e limpa o paciente selecionado (`setPage(...); setSelected(null)`).
3. Clicar em um paciente na lista define `selected` (hoje via `setSelected(patient)`).
4. `onBack` do `PatientDetail` limpa `selected` (hoje `() => setSelected(null)`).
5. O paciente selecionado precisa sobreviver a um recarregamento de `patients` (hoje isso já funciona porque `selected` é um objeto React state independente da lista).

Como o hook guarda `patientId: string | null` e não o objeto `Patient`, o componente deriva o objeto selecionado a partir de `patients.find(p => p.id === route.patientId)`. Isso significa que, se a URL apontar para um paciente que ainda não carregou (ex.: link direto colado no navegador antes do `load()` terminar), `selected` fica `null` até `patients` chegar — está coberto pelo estado de carregamento (`loading`) já existente.

- [ ] **Step 1: Editar `Dashboard` para usar o hook**

Substituir em `src/App.tsx`:

```typescript
  const [page, setPage] = useState<'patients' | 'nutrition' | 'care' | 'content' | 'settings'>(isReceptionist ? 'care' : 'patients')
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<Patient | null>(null)
```

por:

```typescript
  const [route, navigateRoute] = useAppRoute(isReceptionist ? 'care' : 'patients')
  const page = route.page
  const selected = patients.find(p => p.id === route.patientId) ?? null
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)
```

Adicionar o import no topo do arquivo:

```typescript
import { useAppRoute } from './lib/useAppRoute'
```

Substituir o `useEffect` que força `care` para recepcionista (linhas 172-177):

```typescript
  useEffect(() => {
    if (isReceptionist && page !== 'care') {
      setPage('care')
      setSelected(null)
    }
  }, [isReceptionist, page])
```

por:

```typescript
  useEffect(() => {
    if (isReceptionist && page !== 'care') navigateRoute({ page: 'care', patientId: null })
  }, [isReceptionist, page, navigateRoute])
```

Trocar as quatro chamadas de menu (`setPage('patients'); setSelected(null); setMenu(false)` e equivalentes para `nutrition`, `content`, `settings`, `care`) por:

```typescript
onClick={() => { navigateRoute({ page: 'patients', patientId: null }); setMenu(false) }}
```

(mesma troca para `nutrition`, `content`, `settings`, `care`, mantendo `page === 'x' ? 'active' : ''` como está, já que `page` continua existindo como `const`).

Trocar `onSelect={setSelected}` do `PatientDirectory` por:

```typescript
onSelect={patient => navigateRoute({ page: 'patients', patientId: patient.id })}
```

Trocar `onBack={() => setSelected(null)}` do `PatientDetail` por:

```typescript
onBack={() => navigateRoute({ page: 'patients', patientId: null })}
```

- [ ] **Step 2: Rodar a suíte existente para garantir que nada quebrou**

Run: `npm test`
Expected: PASS — os três testes de `App.test.tsx` cobrem só a tela de autenticação, então continuam passando sem tocar `Dashboard`.

- [ ] **Step 3: Rodar lint e build**

Run: `npm run lint && npm run build`
Expected: PASS, sem erros de tipo (checar que `Patient` ainda é usado — se `Dashboard` não usar mais `Patient` diretamente em algum ponto o TypeScript acusa import não usado).

- [ ] **Step 4: Commit**

```bash
git add src/App.tsx
git commit -m "feat: navegar pelo menu e pelo paciente selecionado via URL"
```

---

### Task 4: Verificação manual e handoff

**Files:**
- Modify: `work/handoffs/bsnutri_redesign_audit_30_07_2026_1723.md` (adicionar entrada) — ou criar novo handoff se preferir manter o antigo intacto: `work/handoffs/bsnutri_navegacao_url_<data-da-execucao>.md`.

- [ ] **Step 1: Testar manualmente com o app rodando**

Run: `npm run dev`

Roteiro:
1. Entrar como profissional, confirmar que a URL vira `?page=patients`.
2. Clicar em "Nutrição e planos", confirmar `?page=nutrition`.
3. Abrir um paciente na lista de Pacientes, confirmar `?page=patients&patient=<id>`.
4. Clicar em "Voltar para pacientes" dentro do prontuário, confirmar que o parâmetro `patient` some da URL.
5. Usar o botão Voltar do navegador depois do passo 3, confirmar que o prontuário fecha e a lista volta.
6. Usar o botão Avançar do navegador, confirmar que o prontuário reabre no mesmo paciente.
7. Recarregar a página com `?page=nutrition` na URL, confirmar que o Dashboard abre direto em Nutrição.

- [ ] **Step 2: Registrar o resultado no handoff**

Escrever um handoff curto (data, o que foi feito, arquivos criados/alterados, resultado do roteiro manual, próxima fatia recomendada: mover Nutrição/Biblioteca de menu conforme seção 5.1 do plano mestre, e depois o workspace do paciente com abas).

- [ ] **Step 3: Commit**

```bash
git add work/handoffs/
git commit -m "docs: registrar handoff da navegacao por URL"
```

---

## Self-Review

**Spec coverage:** cobre "toda superfície importante precisa de URL própria" e "voltar e avançar do navegador devem funcionar" (seção 5.4 do plano mestre) para as 5 páginas do menu e o paciente selecionado. Não cobre ainda: abas do workspace do paciente (seção 5.2), reorganização de Biblioteca (seção 5.1 item 4), nem breadcrumbs — ficam para a próxima fatia, junto com a issue "medir jornada atual" que não é código.

**Placeholder scan:** nenhum "TBD" ou "implementar depois"; todo passo tem código completo.

**Type consistency:** `AppRoute`, `Page`, `parseAppRoute`, `routeToSearch` e `useAppRoute` usam a mesma assinatura em todas as tasks que os consomem.
