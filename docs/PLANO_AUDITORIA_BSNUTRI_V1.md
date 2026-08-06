# Plano de auditoria completa do BSNutri

Versão: 1  
Data: 30 de julho de 2026  
Tipo: auditoria técnica, clínica, de segurança, privacidade, UX e complexidade  
Estado: plano de execução

## 1. Objetivo

Avaliar se o BSNutri pode ser usado por profissionais de nutrição sem:

1. expor dados de outra pessoa ou organização;
2. produzir cálculos não reproduzíveis;
3. perder ou sobrescrever rascunhos;
4. publicar conteúdo diferente do que foi revisado;
5. induzir erro pela interface;
6. manter complexidade que dificulte correções;
7. depender de processos que não podem ser operados ou restaurados.

A auditoria deve produzir achados reproduzíveis e priorizados. Não basta registrar que uma prática "poderia ser melhor". Segurança exige caminho de exploração e impacto. Correção exige comportamento esperado e resultado observado. UX exige tarefa, contexto e evidência. Ponytail exige código ou dependência concreta que possa ser removida ou reduzida.

## 2. Separação obrigatória dos relatórios

Os achados serão mantidos em trilhas diferentes:

1. segurança explorável;
2. hardening de segurança;
3. correção funcional;
4. confiabilidade clínica e científica;
5. privacidade e governança de dados;
6. UX e acessibilidade;
7. desempenho e confiabilidade operacional;
8. excesso de complexidade;
9. dívida de documentação e processo.

Essa separação evita que um problema de estilo seja classificado como vulnerabilidade ou que uma vulnerabilidade real seja diluída em uma lista genérica de melhorias.

## 3. Escopo

### 3.1 Código

1. `src/`;
2. `public/`;
3. `supabase/migrations/`;
4. `supabase/tests/`;
5. configurações de build;
6. service worker e PWA;
7. scripts de seed e importação;
8. integração com Google Drive;
9. exportação e PDF;
10. dependências e lockfile.

### 3.2 Fluxos

1. cadastro e recuperação de conta;
2. criação e entrada em organização;
3. papéis owner, admin, nutritionist, student, reception e patient;
4. cadastro, busca e abertura de paciente;
5. avaliação, medidas, exames, consentimentos e metas;
6. criação, edição, autosave e recuperação de rascunho;
7. aplicação e criação de modelo;
8. catálogo, preparação, medida e composição;
9. revisão e publicação;
10. portal e entrega ao paciente;
11. agenda e acompanhamento;
12. exportação clínica;
13. integração de arquivos.

### 3.3 Dados

1. dados de autenticação;
2. dados identificáveis;
3. dados clínicos;
4. dados antropométricos;
5. exames;
6. rascunhos;
7. publicações;
8. eventos de auditoria;
9. arquivos e metadados;
10. fontes técnicas e modelos.

### 3.4 Ambientes

1. ambiente local com dados sintéticos;
2. build de produção;
3. GitHub Pages;
4. projeto Supabase remoto, somente com acesso autorizado e operações não destrutivas;
5. integração com Google Drive, somente com pasta de teste.

## 4. Fora do escopo

1. pentest destrutivo em produção;
2. uso de dados reais sem autorização;
3. engenharia social;
4. ataque de negação de serviço;
5. alteração de prontuário real;
6. correção de achados durante a fase de coleta, salvo risco crítico ativo;
7. certificação formal de conformidade;
8. validação clínica de todas as populações em uma única execução.

## 5. Skills e ferramentas

### 5.1 Skills obrigatórias

1. **Security Audit, Cloudflare**
   1. situação atual: não instalada;
   2. função: reconhecimento, caça, validação adversarial, relatório estruturado e verificação independente;
   3. instalação proposta:

```bash
npx skills add https://github.com/cloudflare/security-audit-skill --skill security-audit --global
```

   4. fonte: [Cloudflare Security Audit Skill](https://github.com/cloudflare/security-audit-skill);
   5. observação: a execução completa usa agentes independentes. Antes da auditoria, deve haver autorização explícita para delegação. Sem essa autorização, a auditoria de segurança será serial e registrará a redução de independência.

2. **Ponytail Audit**
   1. função: varrer o repositório em busca de código morto, abstrações de uma implementação, wrappers, dependências substituíveis e configuração especulativa;
   2. saída: achados `delete`, `stdlib`, `native`, `yagni` e `shrink`;
   3. limite: não cobre correção, segurança ou desempenho.

3. **Supabase**
   1. função: revisar Auth, RLS, grants, funções, views, storage, sessions e Data API;
   2. exige consulta à documentação e changelog atuais antes de afirmar comportamento;
   3. exige advisors e testes de acesso.

4. **Supabase Postgres Best Practices**
   1. função: revisar índices, consultas, políticas, funções e desempenho;
   2. usar `EXPLAIN` apenas em ambiente seguro e com dados sintéticos.

5. **Diagnosing Bugs**
   1. função: transformar suspeita funcional em reprodução determinística;
   2. nenhuma correção começa sem um feedback loop que detecte o sintoma.

6. **UI/UX Pro Max**
   1. função: revisar navegação, formulários, estados, foco, contraste, responsividade e carga cognitiva;
   2. executar jornada por tarefa, não apenas inspeção visual.

7. **Code Review**
   1. função: revisar cada lote de correções contra o relatório e contra os padrões do repositório;
   2. usar depois da auditoria, com fixed point explícito.

8. **Humanizer**
   1. função: tornar o relatório direto e legível;
   2. preservar precisão, severidade e incerteza.

9. **Research**
   1. função: verificar documentação, diretrizes e fontes primárias;
   2. usar para Supabase, bibliotecas, fórmulas e regras clínicas.

### 5.2 Ferramentas de apoio

1. Vitest;
2. Testing Library;
3. testes SQL do Supabase;
4. Supabase advisors;
5. `npm audit`;
6. `npm run lint`;
7. `npm run build`;
8. busca de segredos no histórico e na árvore;
9. navegador automatizado;
10. axe ou verificação equivalente de acessibilidade, se já disponível;
11. React DevTools Profiler;
12. DevTools de rede;
13. validação do service worker;
14. inspeção de headers do deploy;
15. verificação de licença e proveniência de dados.

Não adicionar scanner ou dependência permanente sem demonstrar que as ferramentas atuais são insuficientes.

## 6. Preparação da auditoria

### 6.1 Diretório de saída

Criar:

```text
docs/audits/AAAA-MM-DD/
|-- 00-scope.md
|-- 01-architecture.md
|-- 02-data-flow.md
|-- 03-security-findings.md
|-- 04-hardening.md
|-- 05-functional-findings.md
|-- 06-clinical-reliability.md
|-- 07-privacy.md
|-- 08-ux-accessibility.md
|-- 09-performance-operations.md
|-- 10-ponytail.md
|-- 11-remediation-plan.md
|-- findings.json
`-- evidence/
```

### 6.2 Snapshot inicial

Registrar:

1. commit auditado;
2. branch;
3. estado do worktree;
4. versão do Node;
5. versão do npm;
6. versão do Supabase CLI;
7. versões de dependências;
8. configuração do deploy;
9. escopo autorizado;
10. limitações de acesso;
11. comandos de validação;
12. data e responsável.

### 6.3 Regras de evidência

1. Usar apenas dados sintéticos.
2. Não copiar tokens, chaves, e-mails ou conteúdo clínico para o relatório.
3. Redigir identificadores sensíveis.
4. Guardar payload mínimo.
5. Registrar comando, entrada, resultado e commit.
6. Capturar screenshot somente quando necessário.
7. Não alterar o sistema durante a coleta.
8. Se a reprodução exigir alteração temporária, usar branch separada e apagar depois.
9. Todo achado deve apontar o seam ou caminho explorado.
10. Achados rejeitados também devem ser registrados, com motivo.

## 7. Critério de severidade

### P0, crítico

1. acesso não autorizado a dados clínicos ou identificáveis;
2. alteração ou publicação em nome de outro profissional;
3. exposição de chave privilegiada;
4. corrupção ou perda ampla de dados;
5. cálculo clínico incorreto com alta chance de passar despercebido;
6. publicação diferente da revisão.

Ação: interromper a auditoria normal, preservar evidência, limitar exposição e comunicar imediatamente. Correção recebe trilha própria.

### P1, alto

1. IDOR ou BOLA com pré-condição limitada;
2. bypass de papel;
3. perda reproduzível de rascunho;
4. falha de restauração;
5. fórmula ou unidade incorreta em fluxo comum;
6. paciente acessando versão indevida;
7. XSS armazenado em conteúdo clínico.

### P2, médio

1. informação sensível em log ou armazenamento local;
2. sessão não revogada em fluxo relevante;
3. erro de cálculo restrito a condição específica;
4. falha de acessibilidade que bloqueia tarefa;
5. consulta ou renderização que prejudica uso real;
6. alerta ausente que aumenta risco, sem produzir erro sozinho.

### P3, baixo

1. hardening;
2. inconsistência de interface;
3. documentação incompleta;
4. complexidade localizada;
5. oportunidade de redução sem risco imediato.

Severidade combina impacto, explorabilidade, alcance e detectabilidade. Não deve ser baseada apenas em uma checklist.

## 8. Fase 1: reconhecimento

Objetivo: entender o sistema antes de procurar falhas.

### 8.1 Arquitetura

1. mapear entry points;
2. mapear workspaces;
3. mapear módulos de cálculo;
4. mapear chamadas ao Supabase;
5. mapear RPCs;
6. mapear funções `SECURITY DEFINER`;
7. mapear storage e integrações;
8. mapear service worker;
9. mapear publicação e PDF;
10. mapear estados locais.

### 8.2 Fronteiras de confiança

1. navegador para Supabase Data API;
2. usuário autenticado para organização;
3. profissional para paciente;
4. recepção para dados administrativos;
5. paciente para publicação;
6. aplicação para Google Drive;
7. build para GitHub Pages;
8. dados importados para catálogo;
9. modelos para rascunho;
10. rascunho para publicação.

### 8.3 Superfícies de entrada

1. formulários;
2. parâmetros de rota;
3. busca;
4. importação CSV;
5. campos de texto clínico;
6. nomes de arquivo;
7. metadados do Drive;
8. JSON de modelos;
9. RPCs públicas;
10. dados do JWT.

Saída:

1. `01-architecture.md`;
2. `02-data-flow.md`;
3. matriz de papel por ação;
4. inventário de superfícies.

Gate:

1. toda tabela exposta tem proprietário e política esperada;
2. toda RPC tem caller identificado;
3. todo dado clínico tem fluxo mapeado;
4. nenhuma caça começa com fronteira desconhecida.

## 9. Fase 2: auditoria funcional

### 9.1 Autenticação e organização

1. cadastro;
2. login;
3. recuperação de senha;
4. sessão expirada;
5. criação de organização;
6. associação de perfil;
7. troca de papel;
8. usuário sem membership;
9. usuário com mais de uma organização;
10. logout e revogação.

### 9.2 Paciente

1. cadastro duplicado;
2. dados incompletos;
3. busca;
4. troca de paciente durante carregamento;
5. acesso direto por ID;
6. outra organização;
7. paciente sem e-mail;
8. reivindicação de acesso;
9. edição concorrente;
10. exportação.

### 9.3 Plano

1. iniciar vazio;
2. copiar anterior;
3. aplicar modelo;
4. salvar;
5. falhar no meio do salvamento;
6. recuperar rascunho;
7. abrir versão antiga;
8. revisar;
9. publicar;
10. tentar editar publicação;
11. comparar versões;
12. arquivar;
13. falha de rede;
14. duas abas;
15. duas sessões.

### 9.4 Catálogo

1. porção zero;
2. valor negativo;
3. dado ausente;
4. decimal com vírgula;
5. preparação sem rendimento;
6. medida sem gramas;
7. item inativo;
8. duplicidade;
9. importação malformada;
10. receita composta;
11. arredondamento;
12. busca com acento;
13. estado de preparo.

Procedimento por bug:

1. criar feedback loop;
2. reproduzir;
3. reduzir;
4. registrar hipóteses;
5. identificar causa;
6. criar teste de regressão proposto;
7. não aplicar correção durante a coleta.

## 10. Fase 3: confiabilidade clínica e científica

### 10.1 Cálculos

1. identificar todas as fórmulas;
2. identificar unidades;
3. identificar arredondamentos;
4. conferir ordem das operações;
5. testar limite inferior, superior e ausente;
6. verificar dado zero;
7. verificar conversões por 100 g;
8. verificar soma de refeição e dia;
9. verificar faixa e meta;
10. verificar substituição;
11. verificar consistência entre tela, banco e PDF.

### 10.2 Casos independentes

Cada cálculo deve ser comparado com:

1. exemplo publicado na fonte;
2. cálculo manual documentado;
3. planilha independente;
4. caso de borda;
5. caso com dado ausente.

O teste não pode recalcular o resultado esperado com a mesma implementação.

### 10.3 Modelos

1. diferenciar modelo dietético e modelo de plano;
2. verificar metas fixas;
3. verificar aplicabilidade por população;
4. verificar fontes;
5. verificar versão;
6. verificar estado de validação;
7. verificar descontinuação;
8. verificar cópia sem identificador;
9. verificar independência do rascunho;
10. verificar regra sem fonte.

### 10.4 Catálogo e fontes

1. fonte identificada;
2. licença;
3. edição;
4. estado de preparo;
5. base úmida ou seca quando relevante;
6. receita versus alimento;
7. marca;
8. alimento regional;
9. dado calculado versus analisado;
10. revisão por lote.

Saída:

1. inventário de fórmulas;
2. matriz fórmula, fonte, versão e teste;
3. lista de modelos não liberáveis;
4. lista de dados de catálogo que exigem revisão.

## 11. Fase 4: auditoria de segurança

### 11.1 Autorização e isolamento

Testar:

1. leitura por outra organização;
2. inserção com `organization_id` alheio;
3. atualização que troca o proprietário;
4. exclusão por papel indevido;
5. relacionamento que vaza dado de tabela associada;
6. RPC chamada diretamente;
7. enumeração de IDs;
8. acesso de paciente a outro paciente;
9. recepção acessando informação clínica;
10. student realizando ação não permitida.

Para cada tabela:

1. RLS habilitada;
2. grants explícitos;
3. `SELECT`;
4. `INSERT`;
5. `UPDATE` com `USING` e `WITH CHECK`;
6. `DELETE`;
7. papel;
8. organização;
9. relacionamento;
10. teste positivo e negativo.

### 11.2 Funções e RPCs

1. localizar `SECURITY DEFINER`;
2. verificar schema;
3. verificar `search_path`;
4. verificar `auth.uid()`;
5. verificar grants a `PUBLIC`, `anon` e `authenticated`;
6. verificar parâmetros controlados pelo usuário;
7. verificar troca de organização;
8. verificar SQL dinâmico;
9. verificar auditoria;
10. verificar idempotência quando necessária.

### 11.3 Sessão e JWT

1. não usar `user_metadata` para autorização;
2. verificar claims desatualizadas;
3. testar sessão depois de remoção de usuário;
4. testar logout;
5. testar recuperação de senha;
6. verificar expiração;
7. verificar múltiplas abas;
8. verificar redirect;
9. verificar patient claim;
10. verificar membership removida.

### 11.4 Cliente e navegador

1. XSS refletido e armazenado;
2. renderização de conteúdo clínico;
3. uso perigoso de HTML;
4. parâmetros de URL;
5. service worker servindo conteúdo obsoleto;
6. cache de dados clínicos;
7. localStorage e sessionStorage;
8. mensagens entre janelas;
9. downloads;
10. manipulação de arquivo.

### 11.5 Segredos e dependências

1. chaves privilegiadas no código;
2. `.env` versionado;
3. segredos no histórico;
4. token em log;
5. source map;
6. lockfile;
7. dependência vulnerável;
8. pacote abandonado;
9. script de instalação;
10. cadeia de publicação.

### 11.6 Storage e Google Drive

1. pasta correta;
2. acesso por organização;
3. link compartilhável;
4. revogação;
5. nome de arquivo;
6. metadado sensível;
7. MIME;
8. tamanho;
9. sobrescrita;
10. arquivo órfão;
11. remoção;
12. auditoria.

### 11.7 Publicação e exportação

1. snapshot imutável;
2. versão autorizada;
3. race entre revisão e publicação;
4. exportação por outro papel;
5. conteúdo interno no PDF;
6. cache de PDF;
7. URL previsível;
8. auditoria de acesso;
9. reimpressão;
10. integridade entre tela e arquivo.

### 11.8 Validação de achados

1. Um agente ou revisor diferente tenta rejeitar cada achado.
2. A validação confirma pré-condições.
3. A validação reproduz o impacto.
4. Controles compensatórios são testados.
5. Se outro controle bloquear o ataque, mover para hardening.
6. Falso positivo permanece registrado como rejeitado.

## 12. Fase 5: privacidade e governança

### 12.1 Inventário

1. finalidade de cada dado;
2. base de uso definida pelo projeto;
3. papel que acessa;
4. local de armazenamento;
5. retenção;
6. exportação;
7. exclusão ou anonimização;
8. backup;
9. integração;
10. evento de auditoria.

### 12.2 Princípios

1. minimização;
2. separação por papel;
3. rastreabilidade;
4. revogação;
5. retenção definida;
6. dados sintéticos em teste;
7. logs sem conteúdo clínico;
8. exportação auditada;
9. consentimento versionado;
10. resposta a incidente.

### 12.3 Pontos específicos

1. paciente sem e-mail;
2. reivindicação de conta;
3. acesso por familiar ou responsável;
4. menor de idade;
5. consentimento revogado;
6. Drive externo;
7. rascunho local;
8. PDF baixado;
9. backup;
10. exclusão de organização.

Saída:

1. mapa de dados;
2. lacunas de retenção;
3. lacunas de consentimento;
4. ações de minimização;
5. plano de incidente.

## 13. Fase 6: UX e acessibilidade

### 13.1 Tarefas testadas

1. encontrar paciente;
2. registrar avaliação;
3. entender dados faltantes;
4. definir meta;
5. iniciar plano;
6. adicionar e ajustar alimento;
7. aplicar modelo;
8. resolver alerta;
9. publicar;
10. localizar documento antigo.

### 13.2 Critérios

1. localização atual;
2. próxima ação;
3. número de cliques;
4. retorno ao contexto;
5. consistência de termos;
6. recuperação de erro;
7. feedback de salvamento;
8. teclado;
9. foco;
10. contraste;
11. zoom;
12. responsividade;
13. leitor de tela;
14. estados vazios;
15. prevenção de erro.

### 13.3 Carga cognitiva

1. contar decisões simultâneas;
2. identificar informação repetida;
3. identificar campos que poderiam ser derivados;
4. identificar alertas sem ação;
5. identificar menus por tabela;
6. identificar contexto perdido;
7. identificar valores sem unidade;
8. identificar linguagem ambígua;
9. identificar confirmação excessiva;
10. identificar ação destrutiva próxima de ação primária.

### 13.4 Evidência

1. vídeo curto ou sequência de screenshots;
2. tarefa;
3. tempo;
4. erro;
5. ponto de confusão;
6. impacto;
7. recomendação;
8. critério de aceite.

## 14. Fase 7: desempenho e operação

### 14.1 Frontend

1. tamanho do bundle;
2. tempo de carregamento;
3. consultas duplicadas;
4. renderizações;
5. lista de catálogo;
6. imagens;
7. cache;
8. service worker;
9. interação durante carregamento;
10. layout shift.

Não otimizar lista curta. Virtualização só entra quando a medição mostrar volume suficiente.

### 14.2 Banco

1. consultas por workspace;
2. índices;
3. políticas RLS;
4. N mais 1;
5. joins;
6. funções;
7. paginação;
8. ordenação;
9. concorrência;
10. transações.

### 14.3 Confiabilidade operacional

1. backup;
2. restauração;
3. migration dry run;
4. rollback aplicável;
5. monitoramento;
6. logs;
7. alertas;
8. sessão;
9. falha de integração;
10. continuidade do editor.

Gate:

1. restauração demonstrada;
2. build reproduzível;
3. migration list consistente;
4. nenhuma consulta crítica sem limite;
5. falha externa não apaga rascunho.

## 15. Fase 8: Ponytail Audit

Executar depois de entender o sistema. O objetivo é reduzir o custo permanente.

### 15.1 Alvos

1. código morto;
2. flags sem uso;
3. abstração de uma implementação;
4. wrappers que apenas delegam;
5. helpers duplicados;
6. configuração nunca alterada;
7. arquivos com uma exportação sem motivo;
8. dependência substituível por plataforma;
9. estado duplicado;
10. camada que espalha, em vez de esconder, complexidade.

### 15.2 Regras

1. Cada achado aponta arquivo e substituição.
2. Maior redução vem primeiro.
3. Não misturar bugs.
4. Não misturar segurança.
5. Não aplicar correção nessa fase.
6. Estimar linhas e dependências removíveis.
7. Manter validação, segurança e acessibilidade.
8. Não sugerir refatoração apenas estética.

### 15.3 Saída

Formato:

```text
<tag> <o que cortar>. <substituição>. [arquivo]
```

Fechamento:

```text
net: -N linhas, -M dependências possíveis.
```

## 16. Fase 9: síntese e validação

### 16.1 Normalização

Cada achado deve ter:

1. ID;
2. trilha;
3. severidade;
4. título;
5. commit;
6. pré-condição;
7. passos;
8. resultado observado;
9. resultado esperado;
10. impacto;
11. evidência;
12. arquivos;
13. controle existente;
14. correção proposta;
15. teste de regressão proposto;
16. estado de validação.

### 16.2 Estados

1. suspeito;
2. reproduzido;
3. confirmado;
4. rejeitado;
5. hardening;
6. aceito como risco;
7. corrigido;
8. verificado.

### 16.3 Revisão adversarial

1. Tentar reproduzir em ambiente limpo.
2. Tentar provar que o achado depende de configuração inexistente.
3. Verificar controle compensatório.
4. Recalcular severidade.
5. Conferir linha e commit.
6. Conferir se a correção proposta trata a causa.
7. Conferir se a recomendação não amplia o escopo.

## 17. Plano de correção

### Onda 0

1. exposição ativa;
2. segredo;
3. corrupção;
4. publicação incorreta;
5. bypass de organização.

### Onda 1

1. autorização;
2. RLS;
3. sessão;
4. perda de rascunho;
5. cálculo incorreto;
6. divergência de PDF.

### Onda 2

1. bloqueios de UX;
2. acessibilidade;
3. privacidade;
4. desempenho crítico;
5. restauração.

### Onda 3

1. hardening;
2. complexidade;
3. documentação;
4. otimizações comprovadas.

Cada correção:

1. recebe issue;
2. fixa o seam;
3. cria regressão;
4. implementa a menor mudança;
5. revisa segurança;
6. valida no ambiente correto;
7. atualiza o achado.

## 18. Hipóteses iniciais para investigar

As hipóteses abaixo não são achados:

1. O uso de estado interno para navegação pode quebrar retorno, acesso direto e contexto.
2. `NutritionWorkspace.tsx` pode concentrar responsabilidades demais.
3. As 19 operações do editor podem permitir falha parcial durante salvamento.
4. `PatientDetail.tsx` pode repetir consultas e espalhar montagem de contexto.
5. Modelos com metas fixas podem ser interpretados como individualizados.
6. O fluxo de recuperação local pode armazenar dados clínicos em excesso.
7. Funções `SECURITY DEFINER` precisam de revisão de schema, grants e autenticação.
8. A reivindicação de paciente por e-mail precisa resistir a conflito, e-mail nulo e troca de conta.
9. Publicação e PDF precisam ser comparados no mesmo snapshot.
10. A integração com Drive precisa ser testada para revogação e arquivo órfão.
11. O catálogo pode distinguir de forma insuficiente dado ausente e zero em alguns fluxos.
12. Alertas numerosos podem produzir fadiga e não orientar a correção.
13. O service worker pode manter interface antiga depois de deploy.
14. A tela Hoje pode misturar tarefas clínicas e administrativas.
15. O histórico de migrations pode conter políticas substituídas que precisam ser auditadas no estado final, não isoladamente.

## 19. Workflow autônomo da auditoria

1. Fixar commit e escopo.
2. Criar diretório de evidências.
3. Rodar baseline de testes, lint e build.
4. Mapear arquitetura e dados.
5. Executar trilhas em ordem de risco.
6. Registrar suspeitas sem promovê-las.
7. Reproduzir e reduzir.
8. Validar de forma adversarial.
9. Classificar.
10. Produzir relatório.
11. Criar backlog de correção.
12. Corrigir em branches separadas.
13. Reexecutar teste e trilha afetada.
14. Atualizar estado do achado.
15. Salvar handoff.

O agente deve parar quando:

1. detectar exposição real de dado;
2. precisar de dado de produção;
3. precisar executar ação destrutiva;
4. faltar autorização para teste externo;
5. uma hipótese depender de configuração não acessível;
6. a reprodução puder afetar outra pessoa;
7. houver conflito entre correção e regra clínica;
8. a skill de segurança exigir agentes independentes sem autorização.

## 20. Definição de auditoria concluída

1. commit e escopo fixados;
2. arquitetura e fluxos mapeados;
3. matriz de papéis concluída;
4. RLS, RPCs e storage cobertos;
5. cálculos inventariados;
6. jornadas profissionais testadas;
7. acessibilidade básica testada;
8. desempenho medido;
9. Ponytail Audit executada;
10. achados confirmados e rejeitados registrados;
11. severidade revisada;
12. backlog de correção criado;
13. P0 comunicado;
14. relatório humanizado;
15. handoff salvo;
16. execução reproduzível por outra pessoa.

## 21. Ordem recomendada de início

1. Instalar e revisar a Security Audit Skill.
2. Autorizar ou negar explicitamente o uso de agentes independentes.
3. Fixar o commit de auditoria.
4. Rodar baseline.
5. Mapear RLS, RPCs, papéis e publicação.
6. Auditar a jornada paciente, plano e publicação.
7. Auditar cálculos e modelos.
8. Auditar UX e acessibilidade.
9. Executar Ponytail Audit.
10. Consolidar e priorizar.
