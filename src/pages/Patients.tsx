import { useState } from "react";
import { motion } from "framer-motion";
import { Plus, Search } from "lucide-react";
import { useStore } from "../lib/store";
import { PageHeader } from "../components/Shell";
import { imc, imcCategory } from "../lib/types";

export default function Patients() {
  const { patients, plans, go } = useStore();
  const [q, setQ] = useState("");

  const list = patients.filter(
    (p) => p.name.toLowerCase().includes(q.toLowerCase()) || p.goal.toLowerCase().includes(q.toLowerCase()) || p.tags.some((t) => t.includes(q.toLowerCase()))
  );

  return (
    <>
      <PageHeader
        eyebrow="Gestão clínica"
        title="Pacientes"
        description="Cadastre, acompanhe medidas antropométricas e acesse os planos de cada pessoa."
        actions={
          <button className="btn-primary" onClick={() => go({ name: "patient-new" })}>
            <Plus size={16} /> Cadastrar paciente
          </button>
        }
      />

      <div className="relative mb-6 max-w-md">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
        <input className="input-warm !pl-10" placeholder="Buscar por nome, objetivo ou tag..." value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {list.map((p, i) => {
          const m = p.measurements[p.measurements.length - 1];
          const v = imc(m.weight, m.height);
          const cat = imcCategory(v);
          const plan = plans.find((x) => x.patientId === p.id);
          const age = Math.floor((Date.now() - new Date(p.birthDate).getTime()) / (365.25 * 24 * 3600 * 1000));
          return (
            <motion.button
              key={p.id}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.05 }}
              onClick={() => go({ name: "patient-detail", patientId: p.id })}
              className="card-warm p-5 text-left transition-all duration-150 hover:-translate-y-1 hover:shadow-warm-md"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-forest-100 font-display text-lg font-semibold text-forest-600">
                    {p.name.split(" ").map((n) => n[0]).slice(0, 2).join("")}
                  </div>
                  <div>
                    <p className="font-semibold">{p.name}</p>
                    <p className="text-xs text-muted-foreground">{age} anos · {p.sex}</p>
                  </div>
                </div>
                <span className="chip" style={{ color: cat.color, borderColor: `${cat.color}44`, background: `${cat.color}11` }}>{cat.label}</span>
              </div>
              <p className="mt-3 line-clamp-2 text-sm text-muted-foreground">{p.goal}</p>
              <div className="mt-4 grid grid-cols-3 gap-2 border-t border-border pt-3">
                <div>
                  <p className="font-mono text-sm font-semibold">{m.weight.toFixed(1)}</p>
                  <p className="text-[11px] text-muted-foreground">kg</p>
                </div>
                <div>
                  <p className="font-mono text-sm font-semibold">{v.toFixed(1)}</p>
                  <p className="text-[11px] text-muted-foreground">IMC</p>
                </div>
                <div>
                  <p className="font-mono text-sm font-semibold">{m.bodyFat ? `${m.bodyFat}%` : "—"}</p>
                  <p className="text-[11px] text-muted-foreground">Gordura</p>
                </div>
              </div>
              <div className="mt-3 flex flex-wrap gap-1.5">
                {p.tags.map((t) => (
                  <span key={t} className="chip !bg-cream-100 text-muted-foreground">{t}</span>
                ))}
                {plan && (
                  <span className={`chip ${plan.status === "publicado" ? "text-forest-600" : "text-amber-700"}`}>
                    ● plano {plan.status}
                  </span>
                )}
              </div>
            </motion.button>
          );
        })}
        {list.length === 0 && (
          <div className="col-span-full rounded-2xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground">
            Nenhum paciente encontrado para “{q}”.
          </div>
        )}
      </div>
    </>
  );
}
