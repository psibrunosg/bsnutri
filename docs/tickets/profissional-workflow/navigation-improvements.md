# ISSUE: Workspace do Paciente - Navegação e Fluxo Clínico

**Tipo:** Melhoria de UX/Navegação
**Prioridade:** Alta (próximo ciclo)
**Assunto:** Implementar navegação URL-com comportamento persistente melhorando fluxo do nutricionista

## Contexto

O atual workspace do nutricionista (`NutritionWorkspace.tsx`) apresenta navegação baseada em estado local sem persistência via URL. Isso interrompe o fluxo clínico e dificulta:

1. Compartilhamento de URLs para revisão
2. Recuperação de estado após recarregar página
3. Navegação histórica entre versões do plano

## Pontos de Fricção Atuais

### 1. Navegação não persiste via URL
- Estado de aba (`catalog`|`plan`) é controlado apenas em `useState`
- Recarregar página reseta interface ao painel inicial do catálogo

### 2. Seleção de paciente requer modal
- Paciente selecionado via modal popup
- Não há suporte para `page?patientId=X`
- Perde contexto ao digitar URL manualmente

### 3. Histórico de versões difícil de acessar
- Drafts listados em sidebar sem destaque visual claro
- Diferenciação entre rascunho e versão revisada ambígua

### 4. Fluxo clínico desconectado
- Cálculo de metas (`assistant`) e construção de refeições ocorrem em etapas distintas
- Não há breadcrumb claro entre etapas

## Proposta de Solução

### 1. URL Structure Proposto

```
/page?patientId=X#plan      → editor aberto com plano
/page?patientId=X#catalog   → editor na aba catálogo
/page?patientId=X&draftId=Y → draft específico aberto
/page?patientId=X&version=Z → versão específica do plano aberta
```

### 2. Implementação Técnica

[CCR retrieve hash=xxx]
- Atualizar `useAppRoute.ts` para incluir `draftId` e `version` como parâmetros
- Modificar ` NutritionWorkspace.tsx` para ler parâmetros URL na inicialização
- Adicionar `replaceState` após seleção de paciente para preservar histórico limpo

### 3. Critérios de Aceitação

- [ ] Recarregar página mantém mesmo estado do editor
- [ ] URL compartilhavel visível e funcional
- [ ] Menu superior mostra breadcrumb: Paciente > Plano > Versão
- [ ] Back button navega entre versões corretamente
- [ ] Nenhum dado sensível exposto em URL

## Dependências

- `appRoute.ts` - schema de rotas
- `useAppRoute.ts` - hook de navegação
- `NutritionWorkspace.tsx` - workspace principal

## Arquivos a Modificar

1. `src/lib/appRoute.ts` - adicionar parâmetros draftId, version
2. `src/lib/useAppRoute.ts` - sync com novos parâmetros
3. `src/App.tsx` - Dashboard passa params iniciais para NutritionWorkspace
4. `src/NutritionWorkspace.tsx` - ler params URL no mount

## Considerações Técnicas

Usar hash fragment (`#plan`) em vez de query params para não enviar dados sensíveis ao servidor. Query params (`&draftId=`) apenas para IDs já públicos no contexto org.