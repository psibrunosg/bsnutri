import { motion } from "framer-motion";
import { ArrowRight, CalendarPlus, FileDown, TrendingDown, TrendingUp, UserPlus, Users } from "lucide-react";
import { useStore } from "../lib/store";
import { PageHeader } from "../components/Shell";
import { imc } from "../lib/types";

export default function Dashboard() {
  const { patients, plans, go } = useStore();
  const published = plans.filter((p) => p.status === "publicado").length;

  const cards = [
    { label: "Pacientes ativos", value: String(patients.length), icon: Users },
    { label: "Planos publicados", value: String(published), icon: FileDown },
    { label: "Rascunhos em aberto", value: String(plans.length - published), icon: CalendarPlus },
  ];

  return (
    <>
      <PageHeader
        eyebrow="Bom dia, Dra. Helena"
        title="Visão geral do consultório"
        description="Acompanhe seus pacientes, publique planos e mantenha a semana de todo mundo organizada."
        actions={
          <>
            <button className="btn-ghost" onClick={() => go({ name: "patient-new" })}>
              <UserPlus size={16} /> Novo paciente
            </button>
            <button className="btn-primary" onClick={() => go({ name: "plan-builder" })}>
              <CalendarPlus size={16} /> Novo plano
            </button>
          </>
        }
      />

      <div className="mb-10 grid grid-cols-1 gap-4 sm:grid-cols-3">
        {cards.map((c, i) => (
          <motion.div
            key={c.label}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.07 }}
            className="card-warm p-5"
          >
            <div className="flex items-center justify-between">
              <p className="eyebrow">{c.label}</p>
              <c.icon size={18} className="text-forest-400" />
            </div>
            <p className="mt-3 font-display text-4xl font-semibold">{c.value}</p>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-5">
        {/* Patients */}
        <div className="lg:col-span-3">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-display text-xl font-semibold">Seus pacientes</h2>
            <button className="text-sm font-medium text-forest-500 hover:text-forest-600" onClick={() => go({ name: "patients" })}>
              Ver todos →
            </button>
          </div>
          <div className="space-y-3">
            {patients.map((p) => {
              const m = p.measurements[p.measurements.length - 1];
              const prev = p.measurements[p.measurements.length - 2];
              const delta = prev ? m.weight - prev.weight : 0;
              const plan = plans.find((x) => x.patientId === p.id);
              const v = imc(m.weight, m.height);
              return (
                <button
                  key={p.id}
                  onClick={() => go({ name: "patient-detail", patientId: p.id })}
                  className="card-warm group flex w-full items-center gap-4 p-4 text-left transition-all duration-150 hover:-translate-y-0.5 hover:shadow-warm-md"
                >
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-forest-100 font-display text-lg font-semibold text-forest-600">
                    {p.name.split(" ").map((n) => n[0]).slice(0, 2).join("")}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{p.name}</p>
                    <p className="truncate text-sm text-muted-foreground">{p.goal}</p>
                  </div>
                  <div className="hidden text-right sm:block">
                    <p className="font-mono text-sm font-medium">{m.weight.toFixed(1)} kg</p>
                    <p className={`flex items-center justify-end gap-1 text-xs ${delta < 0 ? "text-forest-500" : delta > 0 ? "text-amber-600" : "text-muted-foreground"}`}>
                      {delta < 0 ? <TrendingDown size={12} /> : delta > 0 ? <TrendingUp size={12} /> : null}
                      {delta === 0 ? "estável" : `${delta > 0 ? "+" : ""}${delta.toFixed(1)} kg`}
                    </p>
                  </div>
                  <div className="hidden text-right md:block">
                    <p className="font-mono text-sm font-medium">IMC {v.toFixed(1)}</p>
                    <p className="text-xs text-muted-foreground">{plan ? plan.status === "publicado" ? "Plano publicado" : "Rascunho" : "Sem plano"}</p>
                  </div>
                  <ArrowRight size={16} className="text-muted-foreground/50 transition-transform group-hover:translate-x-1 group-hover:text-forest-500" />
                </button>
              );
            })}
          </div>
        </div>

        {/* Recent plans */}
        <div className="lg:col-span-2">
          <h2 className="mb-4 font-display text-xl font-semibold">Planos recentes</h2>
          <div className="space-y-3">
            {plans.map((pl) => {
              const p = patients.find((x) => x.id === pl.patientId);
              return (
                <button
                  key={pl.id}
                  onClick={() => go({ name: "plan-builder", planId: pl.id })}
                  className="card-warm w-full p-4 text-left transition-all duration-150 hover:-translate-y-0.5 hover:shadow-warm-md"
                >
                  <div className="flex items-center justify-between gap-2">
                    <p className="truncate font-semibold">{pl.name}</p>
                    <span className={`chip shrink-0 ${pl.status === "publicado" ? "!border-forest-200 !bg-forest-50 text-forest-600" : "!border-amber-200 !bg-amber-50 text-amber-700"}`}>
                      {pl.status}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">{p?.name}</p>
                  <p className="mt-2 font-mono text-[11px] uppercase tracking-wider text-muted-foreground/70">
                    Criado em {new Date(pl.createdAt + "T12:00:00").toLocaleDateString("pt-BR")}
                  </p>
                </button>
              );
            })}
            <button onClick={() => go({ name: "templates" })} className="w-full rounded-2xl border border-dashed border-forest-300 bg-forest-50/50 p-4 text-sm font-medium text-forest-600 transition-all hover:bg-forest-50">
              Explorar modelos de plano →
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
