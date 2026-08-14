import type { ReactNode } from "react";
import { LayoutDashboard, Users, CalendarPlus, Layers, LogOut, Eye } from "lucide-react";
import { useStore, type View } from "../lib/store";

const NAV: { view: View; label: string; icon: typeof LayoutDashboard; match: string[] }[] = [
  { view: { name: "dashboard" }, label: "Visão geral", icon: LayoutDashboard, match: ["dashboard"] },
  { view: { name: "patients" }, label: "Pacientes", icon: Users, match: ["patients", "patient-new", "patient-detail"] },
  { view: { name: "plan-builder" }, label: "Novo plano", icon: CalendarPlus, match: ["plan-builder"] },
  { view: { name: "templates" }, label: "Modelos", icon: Layers, match: ["templates"] },
];

export function Shell({ children }: { children: ReactNode }) {
  const { view, go, setLoggedIn, patients } = useStore();
  const first = patients[0];

  return (
    <div className="flex min-h-screen bg-background">
      <aside className="fixed inset-y-0 left-0 z-40 flex w-60 flex-col bg-forest-800 text-cream-100">
        <div className="flex items-center gap-3 px-5 pt-6 pb-7">
          <img src="./app-icon.png" alt="BSNutri" className="h-11 w-11 rounded-full ring-2 ring-amber-400/60" />
          <div>
            <p className="font-display text-lg font-semibold leading-none">BSNutri</p>
            <p className="mt-1 font-mono text-[10px] uppercase tracking-[0.16em] text-cream-100/50">Consultório</p>
          </div>
        </div>

        <nav className="flex-1 space-y-1 px-3">
          {NAV.map(({ view: v, label, icon: Icon, match }) => {
            const active = match.includes(view.name);
            return (
              <button
                key={label}
                onClick={() => go(v)}
                className={`group flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-left text-sm font-medium transition-all duration-150 ${
                  active
                    ? "bg-forest-600 text-cream-50 shadow-warm"
                    : "text-cream-100/70 hover:bg-white/5 hover:text-cream-50"
                }`}
              >
                <Icon size={17} strokeWidth={2} className={active ? "text-amber-300" : "text-cream-100/50 group-hover:text-amber-300"} />
                {label}
              </button>
            );
          })}
        </nav>

        <div className="space-y-1 px-3 pb-6">
          {first && (
            <button
              onClick={() => go({ name: "portal", patientId: first.id })}
              className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium text-cream-100/70 transition-all hover:bg-white/5 hover:text-cream-50"
            >
              <Eye size={17} className="text-cream-100/50" />
              Visão do paciente
            </button>
          )}
          <button
            onClick={() => setLoggedIn(false)}
            className="flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium text-cream-100/70 transition-all hover:bg-white/5 hover:text-cream-50"
          >
            <LogOut size={17} className="text-cream-100/50" />
            Sair
          </button>
          <div className="mt-3 border-t border-white/10 px-3.5 pt-4">
            <p className="text-[13px] font-semibold">Nutricionista</p>
            <p className="text-xs text-cream-100/50">CRN a definir</p>
          </div>
        </div>
      </aside>

      <main className="ml-60 flex-1">
        <div className="mx-auto max-w-[1200px] px-8 py-8">{children}</div>
      </main>
    </div>
  );
}

export function PageHeader({ eyebrow, title, description, actions }: { eyebrow: string; title: string; description?: string; actions?: ReactNode }) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div>
        <p className="eyebrow mb-2">{eyebrow}</p>
        <h1 className="font-display text-[34px] font-semibold leading-tight text-foreground">{title}</h1>
        {description && <p className="mt-1.5 max-w-xl text-[15px] text-muted-foreground">{description}</p>}
      </div>
      {actions && <div className="flex items-center gap-3">{actions}</div>}
    </div>
  );
}
