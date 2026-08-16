import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

const BREAKPOINTS = [
  { name: '375', width: 375, height: 812 },
  { name: '768', width: 768, height: 1024 },
  { name: '1024', width: 1024, height: 768 },
  { name: '1440', width: 1440, height: 900 },
]

async function horizontalOverflow(page: Page): Promise<number> {
  return page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
}

test.describe('pacote publicado', () => {
  test('exige configuração explícita em vez de falhar em silêncio', async ({ page }) => {
    const consoleErrors: string[] = []
    page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })

    await page.goto('./')
    // Sem configuração o app recusa iniciar; com configuração ele para na
    // autenticação. O que nunca pode acontecer é passar direto para dados clínicos.
    await expect(page.getByRole('heading', { name: /Configuração necessária|de volta|Crie sua conta/ })).toBeVisible()
    expect(consoleErrors).toEqual([])
  })

  test('não vaza credencial nem dado clínico para o pacote', async ({ page }) => {
    await page.goto('./')
    const scripts = await page.evaluate(() => Array.from(document.querySelectorAll('script[src]')).map((element) => (element as HTMLScriptElement).src))
    expect(scripts.length).toBeGreaterThan(0)
    for (const src of scripts) {
      const response = await page.request.get(src)
      const body = await response.text()
      expect(body).not.toContain('SUPABASE_PROF_PASSWORD')
      expect(body).not.toMatch(/setItem\(\s*["'`]bsnutri-patients/)
    }
  })

  for (const breakpoint of BREAKPOINTS) {
    test(`sem overflow horizontal em ${breakpoint.name} px`, async ({ page }) => {
      await page.setViewportSize({ width: breakpoint.width, height: breakpoint.height })
      await page.goto('./')
      await page.waitForLoadState('networkidle')
      expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0)
    })
  }

  test('acessibilidade WCAG 2 A/AA na entrada do aplicativo', async ({ page }) => {
    await page.goto('./')
    await page.waitForLoadState('networkidle')
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()
    expect(results.violations.map((violation) => `${violation.id}: ${violation.help}`)).toEqual([])
  })
})
