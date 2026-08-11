# Estabilização da semana automática e da release

## Objetivo

Restabelecer a validação e a publicação da `main` preservando o novo fluxo do profissional: todo rascunho de plano começa automaticamente com sete dias e seis refeições por dia.

## Usuário principal

O profissional que configura, edita, revisa e publica o plano alimentar. O paciente continua recebendo somente a publicação imutável.

## Problema confirmado

O commit `a56748c` introduziu abas laterais e a semana automática, mas a suíte de interface continuou navegando pela estrutura anterior. O GitHub Actions registra doze testes com falha. A semana automática também expôs seis conjuntos de controles com os mesmos nomes acessíveis, tornando cada refeição difícil de distinguir em testes e tecnologias assistivas.

## Decisões

1. Um plano novo, um modelo interno aplicado e um fallback sem dias usam sete dias, de segunda-feira a domingo.
2. Cada dia começa com Café da manhã, Lanche da manhã, Almoço, Lanche da tarde, Jantar e Ceia.
3. Modelos persistidos são aplicados diretamente aos sete dias, sem diálogo intermediário.
4. Rascunhos existentes preservam os dias e refeições gravados; a semana padrão só cobre estados vazios ou novos.
5. As abas Configuração, Modelos, Planos e Assistente continuam sendo a navegação lateral do editor.
6. Controles repetidos recebem nomes acessíveis contextualizados pela refeição.
7. Nenhuma dependência, migration ou nova abstração será adicionada.

## Jornada do profissional

1. Abrir o Editor de plano.
2. Ver sete abas de dia e seis refeições no dia ativo.
3. Usar Configuração para escolher paciente e título.
4. Usar Modelos para aplicar uma estrutura aos sete dias, ou Planos para abrir, copiar ou iniciar outro rascunho.
5. Usar Assistente para objetivo e critérios clínicos.
6. Adicionar ou editar alimentos em uma refeição identificável.
7. Salvar, revisar e publicar pelo fluxo imutável existente.

## Mudanças de interface

- Cada painel de refeição será uma região nomeada pelo nome da refeição.
- `Buscar alimento`, `Alimento` e `Gramas` incluirão o nome da refeição no nome acessível.
- As abas laterais terão um `tablist` nomeado e painéis associados por `aria-controls` e `aria-labelledby`.
- A duplicação do primeiro dia produzirá `Segunda-feira copia`.

## Testes

Os testes de `NutritionWorkspace.ui.test.tsx` navegarão pelas abas antes de interagir com conteúdo condicional. A cobertura deverá provar:

1. sete dias e seis refeições no plano inicial;
2. controles de alimento distinguíveis por refeição;
3. persistência do estado ao alternar densidade;
4. duplicação do dia e da refeição ativos;
5. abertura, cópia e restauração de rascunhos;
6. aplicação direta de modelo aos sete dias;
7. publicação, lista de compras, g/kg e salvamento atômico no fluxo com abas.

## Gates

1. Teste direcionado do workspace verde.
2. `npm test` verde.
3. `npm run lint` verde.
4. `npm run build` verde.
5. Revisão independente de acessibilidade e escopo.
6. Workflow do GitHub Actions verde após integração na `main`.
7. Site público servindo o commit integrado.

## Fora do escopo

- Refatoração ampla do `PlanEditor`.
- Alterações de banco ou regras clínicas.
- Otimização do bundle.
- Atualização das Actions por causa do aviso de Node 20.
- Reconciliação das issues antigas.
