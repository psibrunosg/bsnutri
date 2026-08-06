# BSNutri

O BSNutri organiza avaliação nutricional, planejamento alimentar, publicação e acompanhamento clínico. O profissional é o usuário principal; o paciente recebe o plano publicado e, em fases posteriores, recursos de acompanhamento.

## Linguagem

**Profissional**:
Pessoa da equipe clínica que avalia dados, define a conduta, revisa cálculos e publica o plano alimentar.
_Evitar_: Usuário, operador, admin, quando o papel clínico for relevante

**Paciente**:
Pessoa atendida pelo profissional e destinatária de uma publicação do plano alimentar.
_Evitar_: Cliente, usuário final

**Avaliação nutricional**:
Conjunto datado de dados clínicos, antropométricos, alimentares e contextuais usados pelo profissional para tomar decisões.
_Evitar_: Ficha, formulário, anamnese, quando o termo representar o conjunto completo

**Estimativa nutricional**:
Resultado calculado por um método identificado, com entradas, premissas, fonte e versão preservadas.
_Evitar_: Necessidade, recomendação, valor ideal

**Meta nutricional**:
Valor ou faixa escolhida pelo profissional para orientar a construção e a revisão do plano.
_Evitar_: Estimativa, cálculo automático

**Modelo dietético**:
Conjunto versionado de princípios, restrições, alertas e referências aplicável a uma população ou abordagem.
_Evitar_: Dieta pronta, protocolo fechado

**Modelo de plano**:
Estrutura reutilizável de dias, refeições, distribuições, faixas e regras que cria um novo rascunho sem dados identificáveis de paciente.
_Evitar_: Modelo dietético, plano padrão

**Catálogo nutricional**:
Coleção rastreável de alimentos, preparações, combinações, medidas e valores de composição.
_Evitar_: Lista de alimentos, banco de dieta

**Rascunho de plano**:
Versão editável de um plano alimentar que ainda não foi publicada.
_Evitar_: Plano ativo

**Publicação do plano**:
Snapshot imutável, aprovado pelo profissional e entregue ao paciente.
_Evitar_: Salvar plano, finalizar rascunho

**Fonte técnica**:
Documento identificado que sustenta um cálculo, alerta, faixa ou regra de modelo, com edição, data, localização e situação de revisão.
_Evitar_: Referência genérica, evidência sem origem
