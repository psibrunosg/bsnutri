# 05 - Controles de visibilidade do plano no portal

**What to build:** o nutricionista escolhe por plano se o paciente verá kcal totais, macros totais e cálculos por refeição. O portal respeita a configuração salva na versão publicada.

**Blocked by:** 04 - Gates de qualidade para publicação.

**Status:** implemented

- [x] A revisão do plano mostra os três controles de visibilidade.
- [x] A configuração fica salva no snapshot da versão publicada.
- [x] O portal oculta cálculos não liberados.
- [x] O portal mostra cálculos liberados sem expor dados técnicos internos.
- [x] Há teste cobrindo as combinações principais de visibilidade.

**Implementation notes**

- Controles adicionados ao assistente em `assistant_state.visibility`.
- O portal lê a configuração da versão publicada e mostra apenas resumos liberados.
- Totais exibidos são resumidos para paciente: kcal e/ou macros, sem expor snapshot técnico bruto.
- `PatientPortal.test.tsx` cobre combinações principais de visibilidade.
