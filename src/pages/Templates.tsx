import { useMemo, useState } from "react";
import { CalendarPlus, Search } from "lucide-react";
import { useStore } from "../lib/store";
import { PageHeader } from "../components/Shell";
import { MEAL_TYPES } from "../lib/types";
import { FOODS } from "../lib/data";

export default function Templates() {
  const { templates, patients, go } = useStore();
  const [target, setTarget] = useState<string>("");
  const [q, setQ] = useState("");
  const [tag, setTag] = useState<string | null>(null);

  const allTags = useMemo(() => [...new Set(templates.flatMap((t) => t.tags))].slice(0, 24), [templates]);
  const list = useMemo(
    () =>
      templates.filter(
        (t) =>
          (!tag || t.tags.includes(tag)) &&
          (t.name.toLowerCase().includes(q.toLowerCase()) || t.description.toLowerCase().includes(q.toLowerCase()))
      ),
    [templates, q, tag]
  );

  return (
    <>
      <PageHeader
        eyebrow="Biblioteca · dados reais do Supabase"
        title="Modelos de plano"
        description={`${templates.length} modelos prontos para aplicar a qualquer paciente em um clique — e ajustar depois no construtor.`}
      />

      <div className="mb-5 flex flex-wrap items-center gap-3">
        <div className="relative min-w-[280px] flex-1 max-w-md">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input className="input-warm !pl-10" placeholder="Buscar modelo por nome ou objetivo..." value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
        <div className="flex items-center gap-2 rounded-xl border border-amber-200 bg-amber-50 px-3 py-1.5">
          <p className="text-[13px] font-medium text-amber-700">Aplicar em:</p>
          <select className="bg-transparent text-sm font-medium text-amber-700 outline-none" value={target} onChange={(e) => setTarget(e.target.value)}>
            <option value="">Escolher depois</option>
            {patients.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        </div>
      </div>

      <div className="mb-6 flex flex-wrap gap-1.5">
        <button className={`chip ${!tag ? "!border-forest-300 !bg-forest-50 text-forest-600" : "text-muted-foreground"}`} onClick={() => setTag(null)}>Todos</button>
        {allTags.map((t) => (
          <button key={t} className={`chip ${tag === t ? "!border-forest-300 !bg-forest-50 text-forest-600" : "text-muted-foreground"}`} onClick={() => setTag(tag === t ? null : t)}>
            {t.replace(/_/g, " ")}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3">
        {list.map((t) => {
          const firstDay = t.plan["Segunda"];
          const previewMeal = firstDay["Almoço"]?.length ? "Almoço" : MEAL_TYPES.find((m) => firstDay[m]?.length) ?? "Almoço";
          const previewItems = firstDay[previewMeal] ?? [];
          return (
            <div key={t.id} className="card-warm flex flex-col overflow-hidden transition-all duration-150 hover:-translate-y-1 hover:shadow-warm-md">
              <div className="h-1.5" style={{ background: t.color }} />
              <div className="flex flex-1 flex-col p-5">
                <p className="font-display text-lg font-semibold leading-snug">{t.name}</p>
                <p className="mt-1.5 line-clamp-2 min-h-[40px] text-sm leading-relaxed text-muted-foreground">{t.description || "Modelo sem descrição."}</p>
                {t.tags.length > 0 && (
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {t.tags.slice(0, 4).map((tg) => <span key={tg} className="chip !py-0.5 !text-[10.5px] text-muted-foreground">{tg.replace(/_/g, " ")}</span>)}
                  </div>
                )}
                <div className="mt-4 flex-1 rounded-xl bg-cream-100 p-3.5">
                  <p className="eyebrow mb-2 !text-[10px]">Prévia · {previewMeal}</p>
                  {previewItems.slice(0, 4).map((it, i) => {
                    const f = FOODS.find((x) => x.id === it.foodId);
                    return f ? <p key={i} className="truncate text-[13px] text-foreground/80">· {it.qty > 1 && <span className="font-mono text-amber-600">{it.qty}× </span>}{f.name} <span className="text-muted-foreground">({f.unit})</span></p> : null;
                  })}
                  <p className="mt-2 font-mono text-[11px] text-muted-foreground">{MEAL_TYPES.filter((m) => firstDay[m]?.length).length} refeições/dia × 7 dias</p>
                </div>
                <div className="mt-4 flex items-center justify-between border-t border-border pt-4">
                  <p className="font-mono text-sm font-semibold">{t.kcalTarget ? `≈ ${t.kcalTarget} kcal` : "—"}<span className="text-xs font-normal text-muted-foreground">{t.kcalTarget ? "/dia" : ""}</span></p>
                  <button className="btn-primary !px-3.5 !py-2 text-xs" onClick={() => go({ name: "plan-builder", patientId: target || undefined, templateId: t.id })}>
                    <CalendarPlus size={13} /> Usar modelo
                  </button>
                </div>
              </div>
            </div>
          );
        })}
        {list.length === 0 && (
          <div className="col-span-full rounded-2xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
            Nenhum modelo encontrado para “{q}”.
          </div>
        )}
      </div>
    </>
  );
}
