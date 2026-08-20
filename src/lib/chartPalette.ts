/**
 * Cores usadas dentro de SVG e canvas, onde classe do Tailwind não chega.
 *
 * `PALETTE` repete, em hex, os tokens declarados em `tailwind.config.js`. Quem mexer na
 * paleta do tema precisa mexer aqui também — não há como um arquivo ler o outro em tempo
 * de execução sem carregar a configuração do Tailwind no bundle.
 *
 * `EARTH` é a rampa exclusiva de gráfico: tons de terra que dão contraste entre séries
 * vizinhas e não existem no tema porque nada fora de gráfico os usa.
 */

export const PALETTE = {
  forest400: '#749966',
  forest500: '#4a6741',
  forest800: '#28371f',
  amber400: '#d9a44a',
  amber500: '#c98f2f',
  amber600: '#a97324',
  amber700: '#85591d',
  cream50: '#fffdf8',
  cream100: '#faf8f2',
  cream300: '#e9e1cd',
} as const

export const EARTH = {
  /** Verde-folha, um passo mais claro que forest500, para a primeira fatia de macro. */
  leaf: '#4f7c43',
  /** Verde-broto, usado nas barras de adesão semanal. */
  sprout: '#a8c489',
  /** Terracota clara: gordura no gráfico de macros. */
  clay: '#e08a5e',
  /** Terracota: faixa de alerta alto de IMC. */
  terracotta: '#b35c33',
  /** Tijolo: faixa crítica de IMC. */
  brick: '#a03a2a',
  /** Cinza-oliva para rótulo de eixo, legível sobre creme. */
  axis: '#8a8577',
  /** Cinza-oliva mais escuro, para texto sem dado. */
  axisStrong: '#7a7568',
} as const
