import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, Check, FileDown, Layers, Plus, Save, Search, Trash2, X } from "lucide-react";
import { useStore, uid } from "../lib/store";
import type { PatientPlan, WeekPlan } from "../lib/types";
import { MEAL_TYPES, WEEK_DAYS, dayTotals, emptyWeekPlan, planTotals } from "../lib/types";
import { FOODS, FOOD_GROUPS } from "../lib/data";
import { exportPlanPdf } from "../lib/pdf";

export default function PlanBuilder({ planId, patientId, templateId }: { planId?: string; patientId?: string; templateId?: string }) {
  const { plans, patients, savePlan, getPatient, templates, go } = useStore();

  const existing = plans.find((p) => p.id === planId);
  const initialTemplate = !existing && templateId ? templates.find((t) => t.id === templateId) : undefined;
  const [plan, setPlan] = useState<PatientPlan>(
    () =>
      existing ?? {
        id: uid("pl"),
        patientId: patientId ?? patients[0]?.id ?? "",
        name: initialTemplate ? `Plano · ${initialTemplate.name}` : "Novo plano alimentar",
        templateId: initialTemplate?.id,
        createdAt: new Date().toISOString().slice(0, 10),
        status: "rascunho",
        plan: initialTemplate ? JSON.parse(JSON.stringify(initialTemplate.plan)) : emptyWeekPlan(),
        notes: "",
      }
  );
  const [picker, setPicker] = useState<{ day: string; meal: string } | null>(null);
  const [showTemplates, setShowTemplates] = useState(false);
  const [templateQuery, setTemplateQuery] = useState("");
  const [q, setQ] = useState("");
  const [group, setGroup] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const patient = getPatient(plan.patientId);
  const totals = useMemo(() => planTotals(plan.plan, FOODS), [plan.plan]);

  function setWeekPlan(fn: (wp: WeekPlan) => WeekPlan) {
    setPlan((p) => ({ ...p, plan: fn(p.plan) }));
  }

  function addFood(day: string, meal: string, foodId: string) {
    setWeekPlan((wp) => ({
      ...wp,
      [day]: { ...wp[day], [meal]: [...wp[day][meal], { foodId, qty: 1 }] },
    }));
  }

  function removeFood(day: string, meal: string, idx: number) {
    setWeekPlan((wp) => ({
      ...wp,
      [day]: { ...wp[day], [meal]: wp[day][meal].filter((_, i) => i !== idx) },
    }));
  }

  function changeQty(day: string, meal: string, idx: number, delta: number) {
    setWeekPlan((wp) => ({
      ...wp,
      [day]: {
        ...wp[day],
        [meal]: wp[day][meal].map((it, i) => (i === idx ? { ...it, qty: Math.max(1, it.qty + delta) } : it)),
      },
    }));
  }

  function copyDay(from: string, to: string) {
    setWeekPlan((wp) => ({ ...wp, [to]: JSON.parse(JSON.stringify(wp[from])) }));
  }

  function applyTemplate(tid: string) {
    const t = templates.find((x) => x.id === tid);
    if (!t) return;
    setPlan((p) => ({
      ...p,
      templateId: t.id,
      name: p.name === "Novo plano alimentar" ? `Plano · ${t.name}` : p.name,
      plan: JSON.parse(JSON.stringify(t.plan)),
    }));
    setShowTemplates(false);
  }

  function persist(status?: "rascunho" | "publicado") {
    const next = status ? { ...plan, status } : plan;
    savePlan(next);
    setPlan(next);
    setSaved(true);
    setTimeout(() => setSaved(false), 1600);
  }

  const filteredFoods = FOODS.filter(
    (f) => (!group || f.group === group) && f.name.toLowerCase().includes(q.toLowerCase())
  );

  return (
    <>
      <button className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={() => (patient ? go({ name: "patient-detail", patientId: patient.id }) : go({ name: "dashboard" }))}>
        <ArrowLeft size={15} /> Voltar
      </button>

      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div className="flex-1">
          <p className="eyebrow mb-2">Construtor de plano</p>
          <input
            className="w-full max-w-lg bg-transparent font-display text-3xl font-semibold outline-none border-b border-transparent focus:border-forest-300 transition-colors"
            value={plan.name}
            onChange={(e) => setPlan({ ...plan, name: e.target.value })}
          />
          <div className="mt-2 flex items-center gap-3">
            <select className="input-warm !w-auto !py-1.5 text-sm" value={plan.patientId} onChange={(e) => setPlan({ ...plan, patientId: e.target.value })}>
              {patients.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
            <span className={`chip ${plan.status === "publicado" ? "text-forest-600" : "text-amber-700"}`}>● {plan.status}</span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2.5">
          <button className="btn-ghost" onClick={() => setShowTemplates(true)}><Layers size={16} /> Aplicar modelo</button>
          <button className="btn-ghost" onClick={() => persist()}><Save size={16} /> {saved ? "Salvo ✓" : "Salvar rascunho"}</button>
          <button className="btn-ghost" disabled={!patient} onClick={() => patient && exportPlanPdf(plan, patient, FOODS)}><FileDown size={16} /> PDF</button>
          <button className="btn-amber" onClick={() => persist("publicado")}><Check size={16} /> Publicar</button>
        </div>
      </div>

      {/* Macro bar */}
      <div className="card-warm mb-6 flex flex-wrap items-center gap-x-8 gap-y-3 px-5 py-4">
        <p className="eyebrow">Média diária</p>
        {[
          { l: "Calorias", v: `${totals.kcal} kcal`, c: "#4a6741" },
          { l: "Proteína", v: `${totals.protein} g`, c: "#85591d" },
          { l: "Carboidrato", v: `${totals.carbs} g`, c: "#c98f2f" },
          { l: "Gordura", v: `${totals.fat} g`, c: "#749966" },
        ].map((m) => (
          <div key={m.l} className="flex items-baseline gap-2">
            <span className="h-2.5 w-2.5 rounded-full" style={{ background: m.c }} />
            <span className="text-[13px] text-muted-foreground">{m.l}</span>
            <span className="font-mono text-sm font-semibold">{m.v}</span>
          </div>
        ))}
        <textarea
          className="ml-auto min-w-[260px] flex-1 rounded-lg border border-border bg-cream-100/70 px-3 py-1.5 text-xs text-muted-foreground outline-none focus:border-forest-300"
          rows={1}
          placeholder="Observações para o paciente (hidratação, horários...)"
          value={plan.notes}
          onChange={(e) => setPlan({ ...plan, notes: e.target.value })}
        />
      </div>

      {/* Weekly grid */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-7 xl:gap-3">
        {WEEK_DAYS.map((day) => {
          const dt = dayTotals(plan.plan, day, FOODS);
          return (
            <div key={day} className="rounded-2xl border border-border bg-card shadow-warm">
              <div className="flex items-center justify-between border-b border-border px-3.5 py-2.5">
                <p className="font-display text-[15px] font-semibold">{day}</p>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-[10.5px] text-muted-foreground">{dt.kcal} kcal</span>
                  <select
                    className="cursor-pointer text-muted-foreground/60 hover:text-forest-500 bg-transparent"
                    title="Copiar dia para..."
                    value=""
                    onChange={(e) => e.target.value && copyDay(day, e.target.value)}
                  >
                    <option value="" disabled>Copiar →</option>
                    {WEEK_DAYS.filter((d) => d !== day).map((d) => <option key={d} value={d}>→ {d}</option>)}
                  </select>
                </div>
              </div>
              <div className="space-y-3 p-3">
                {MEAL_TYPES.map((meal) => {
                  const items = plan.plan[day][meal];
                  return (
                    <div key={meal}>
                      <p className="mb-1 font-mono text-[10px] font-medium uppercase tracking-wider text-amber-700">{meal}</p>
                      <div className="space-y-1.5">
                        <AnimatePresence initial={false}>
                          {items.map((it, i) => {
                            const f = FOODS.find((x) => x.id === it.foodId);
                            if (!f) return null;
                            return (
                              <motion.div
                                key={`${it.foodId}-${i}`}
                                initial={{ opacity: 0, scale: 0.95 }}
                                animate={{ opacity: 1, scale: 1 }}
                                exit={{ opacity: 0, scale: 0.9 }}
                                className="group rounded-lg bg-cream-100 px-2.5 py-2"
                              >
                                <p className="text-[12.5px] font-medium leading-snug">{f.name}</p>
                                <div className="mt-1 flex items-center justify-between gap-1">
                                  <p className="min-w-0 truncate text-[10.5px] text-muted-foreground">{f.unit} · {f.kcal * it.qty} kcal</p>
                                  <div className="flex shrink-0 items-center gap-0.5 text-muted-foreground">
                                    <button className="rounded px-1 hover:bg-cream-200" onClick={() => changeQty(day, meal, i, -1)}>−</button>
                                    <span className="font-mono text-[11px]">{it.qty}</span>
                                    <button className="rounded px-1 hover:bg-cream-200" onClick={() => changeQty(day, meal, i, 1)}>+</button>
                                    <button className="rounded p-0.5 text-muted-foreground/0 transition-colors group-hover:text-destructive hover:!text-destructive" onClick={() => removeFood(day, meal, i)}>
                                      <Trash2 size={12} />
                                    </button>
                                  </div>
                                </div>
                              </motion.div>
                            );
                          })}
                        </AnimatePresence>
                        <button
                          onClick={() => setPicker({ day, meal })}
                          className="flex w-full items-center justify-center gap-1 rounded-lg border border-dashed border-border py-1.5 text-[11px] font-medium text-muted-foreground transition-all hover:border-forest-300 hover:bg-forest-50 hover:text-forest-600"
                        >
                          <Plus size={11} /> adicionar
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>

      {/* Food picker modal */}
      <AnimatePresence>
        {picker && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-50 flex items-center justify-center bg-forest-900/40 p-4 backdrop-blur-sm" onClick={() => setPicker(null)}>
            <motion.div initial={{ scale: 0.95, y: 12 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-lg rounded-2xl bg-card p-5 shadow-warm-lg" onClick={(e) => e.stopPropagation()}>
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <p className="font-display text-lg font-semibold">Adicionar alimento</p>
                  <p className="text-xs text-muted-foreground">{picker.day} · {picker.meal}</p>
                </div>
                <button className="rounded-lg p-1.5 hover:bg-cream-200" onClick={() => setPicker(null)}><X size={16} /></button>
              </div>
              <div className="relative mb-3">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                <input autoFocus className="input-warm !pl-9" placeholder="Buscar alimento..." value={q} onChange={(e) => setQ(e.target.value)} />
              </div>
              <div className="mb-3 flex flex-wrap gap-1.5">
                <button className={`chip ${!group ? "!border-forest-300 !bg-forest-50 text-forest-600" : "text-muted-foreground"}`} onClick={() => setGroup(null)}>Todos</button>
                {FOOD_GROUPS.map((g) => (
                  <button key={g} className={`chip ${group === g ? "!border-forest-300 !bg-forest-50 text-forest-600" : "text-muted-foreground"}`} onClick={() => setGroup(g)}>{g}</button>
                ))}
              </div>
              <div className="max-h-72 space-y-1 overflow-y-auto pr-1">
                {filteredFoods.map((f) => (
                  <button
                    key={f.id}
                    className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-forest-50"
                    onClick={() => { addFood(picker.day, picker.meal, f.id); setPicker(null); setQ(""); }}
                  >
                    <div>
                      <p className="text-sm font-medium">{f.name}</p>
                      <p className="text-xs text-muted-foreground">{f.unit}</p>
                    </div>
                    <div className="text-right font-mono text-xs text-muted-foreground">
                      <p className="font-semibold text-foreground">{f.kcal} kcal</p>
                      <p>P{f.protein} C{f.carbs} G{f.fat}</p>
                    </div>
                  </button>
                ))}
                {filteredFoods.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">Nada encontrado no catálogo.</p>}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Templates modal */}
      <AnimatePresence>
        {showTemplates && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-50 flex items-center justify-center bg-forest-900/40 p-4 backdrop-blur-sm" onClick={() => setShowTemplates(false)}>
            <motion.div initial={{ scale: 0.95, y: 12 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-2xl rounded-2xl bg-card p-6 shadow-warm-lg" onClick={(e) => e.stopPropagation()}>
              <div className="mb-5 flex items-center justify-between">
                <div>
                  <p className="eyebrow mb-1">Biblioteca de modelos</p>
                  <p className="font-display text-xl font-semibold">Aplicar modelo a {patient?.name ?? "paciente"}</p>
                </div>
                <button className="rounded-lg p-1.5 hover:bg-cream-200" onClick={() => setShowTemplates(false)}><X size={16} /></button>
              </div>
              <div className="relative mb-4">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                <input autoFocus className="input-warm !pl-9" placeholder={`Buscar entre ${templates.length} modelos...`} value={templateQuery} onChange={(e) => setTemplateQuery(e.target.value)} />
              </div>
              <div className="max-h-[55vh] space-y-3 overflow-y-auto pr-1">
                {templates.filter((t) => t.name.toLowerCase().includes(templateQuery.toLowerCase()) || t.description.toLowerCase().includes(templateQuery.toLowerCase())).map((t) => (
                  <button
                    key={t.id}
                    onClick={() => applyTemplate(t.id)}
                    className="group flex w-full items-center gap-4 rounded-2xl border border-border p-4 text-left transition-all hover:-translate-y-0.5 hover:border-forest-300 hover:shadow-warm-md"
                  >
                    <span className="h-11 w-2 shrink-0 rounded-full" style={{ background: t.color }} />
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold">{t.name}</p>
                      <p className="line-clamp-1 text-sm text-muted-foreground">{t.description}</p>
                      <div className="mt-1.5 flex gap-1.5">
                        {t.tags.map((tag) => <span key={tag} className="chip !py-0.5 !text-[10.5px] text-muted-foreground">{tag}</span>)}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-mono text-sm font-semibold">≈ {t.kcalTarget} kcal</p>
                      <p className="text-xs font-medium text-forest-500 opacity-0 transition-opacity group-hover:opacity-100">Aplicar →</p>
                    </div>
                  </button>
                ))}
              </div>
              <p className="mt-4 text-xs text-muted-foreground">Aplicar um modelo substitui o conteúdo atual da semana — você ainda pode editar cada refeição depois.</p>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
