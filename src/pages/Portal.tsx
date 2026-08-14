import { ArrowLeft, FileDown, CheckCircle2 } from "lucide-react";
import { useState } from "react";
import { useStore } from "../lib/store";
import { WEEK_DAYS, MEAL_TYPES, planTotals } from "../lib/types";
import { FOODS } from "../lib/data";
import { exportPlanPdf, exportEquivalencyPdf, exportSubstitutionMapPdf } from "../lib/pdf";
import { DB_EQUIV } from "../lib/realdata";

export default function Portal({ patientId }: { patientId: string }) {
  const { getPatient, plans, go } = useStore();
  const p = getPatient(patientId);
  const plan = plans.filter((x) => x.patientId === patientId && x.status === "publicado").pop() ?? plans.filter((x) => x.patientId === patientId).pop();
  const [activeDay, setActiveDay] = useState<string>(WEEK_DAYS[new Date().getDay() === 0 ? 6 : new Date().getDay() - 1]);
  const [checked, setChecked] = useState<Record<string, boolean>>({});

  if (!p) return <p className="text-muted-foreground">Paciente não encontrado.</p>;

  return (
    <>
      <button className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={() => go({ name: "patient-detail", patientId: p.id })}>
        <ArrowLeft size={15} /> Voltar ao consultório
      </button>

      <div className="rounded-3xl bg-forest-800 p-8 text-cream-50 shadow-warm-lg">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="eyebrow mb-2 !text-amber-300">Visão do paciente</p>
            <h1 className="font-display text-3xl font-semibold">Olá, {p.name.split(" ")[0]}</h1>
            <p className="mt-1.5 text-cream-100/70">{plan ? plan.name : "Você ainda não tem um plano publicado."}</p>
          </div>
          <img src="./app-icon.png" alt="BSNutri" className="h-14 w-14 rounded-full ring-2 ring-amber-400/60" />
        </div>
        {plan && (
          <div className="mt-6 flex flex-wrap gap-2.5">
            <button className="btn-amber !py-2 text-sm" onClick={() => exportPlanPdf(plan, p, FOODS)}>
              <FileDown size={15} /> Baixar plano em PDF
            </button>
            <button className="inline-flex items-center gap-2 rounded-xl border border-cream-100/25 px-4 py-2 text-sm font-medium text-cream-100 transition-all hover:bg-white/10" onClick={() => (DB_EQUIV.length ? exportEquivalencyPdf(p, DB_EQUIV) : exportSubstitutionMapPdf(p, FOODS))}>
              <FileDown size={15} /> Mapa de substituições
            </button>
          </div>
        )}
      </div>

      {plan && (
        <>
          {/* Day tabs */}
          <div className="mt-8 flex gap-2 overflow-x-auto pb-1">
            {WEEK_DAYS.map((d) => {
              const active = activeDay === d;
              const doneCount = MEAL_TYPES.filter((m) => checked[`${d}-${m}`]).length;
              return (
                <button
                  key={d}
                  onClick={() => setActiveDay(d)}
                  className={`relative shrink-0 rounded-xl px-4 py-2.5 text-sm font-medium transition-all ${
                    active ? "bg-forest-500 text-cream-50 shadow-warm" : "bg-card border border-border text-muted-foreground hover:border-forest-300"
                  }`}
                >
                  {d}
                  {doneCount > 0 && (
                    <span className={`absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold ${active ? "bg-amber-400 text-forest-900" : "bg-forest-500 text-cream-50"}`}>
                      {doneCount}
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          <div className="mt-5 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
            {MEAL_TYPES.map((meal) => {
              const items = plan.plan[activeDay]?.[meal] ?? [];
              const done = checked[`${activeDay}-${meal}`];
              return (
                <div key={meal} className={`card-warm p-5 transition-all ${done ? "opacity-70" : ""}`}>
                  <div className="mb-3 flex items-center justify-between">
                    <p className="font-display text-lg font-semibold">{meal}</p>
                    <button
                      onClick={() => setChecked((c) => ({ ...c, [`${activeDay}-${meal}`]: !done }))}
                      className={`flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold transition-all ${
                        done ? "bg-forest-500 text-cream-50" : "border border-border text-muted-foreground hover:border-forest-300 hover:text-forest-600"
                      }`}
                    >
                      <CheckCircle2 size={13} /> {done ? "Feito!" : "Marcar"}
                    </button>
                  </div>
                  {items.length > 0 ? (
                    <ul className="space-y-2">
                      {items.map((it, i) => {
                        const f = FOODS.find((x) => x.id === it.foodId);
                        if (!f) return null;
                        return (
                          <li key={i} className={`flex items-baseline justify-between gap-3 border-b border-border/60 pb-2 last:border-0 ${done ? "line-through decoration-forest-300" : ""}`}>
                            <span className="text-sm font-medium">{it.qty > 1 && <span className="font-mono text-amber-600">{it.qty}× </span>}{f.name}</span>
                            <span className="shrink-0 font-mono text-xs text-muted-foreground">{f.unit}</span>
                          </li>
                        );
                      })}
                    </ul>
                  ) : (
                    <p className="text-sm text-muted-foreground">Sem refeição registrada.</p>
                  )}
                </div>
              );
            })}
          </div>

          {plan.notes && (
            <div className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-5">
              <p className="eyebrow mb-1.5">Recado da sua nutricionista</p>
              <p className="text-sm leading-relaxed text-amber-700">{plan.notes}</p>
            </div>
          )}

          <div className="mt-6 flex items-center gap-6 rounded-2xl border border-border bg-card p-5">
            <p className="eyebrow">Meta diária</p>
            {(() => {
              const t = planTotals(plan.plan, FOODS);
              return (
                <div className="flex flex-wrap gap-x-6 gap-y-1 font-mono text-sm">
                  <span><strong>{t.kcal}</strong> kcal</span>
                  <span>Proteína <strong>{t.protein}g</strong></span>
                  <span>Carboidrato <strong>{t.carbs}g</strong></span>
                  <span>Gordura <strong>{t.fat}g</strong></span>
                </div>
              );
            })()}
          </div>
        </>
      )}
    </>
  );
}
