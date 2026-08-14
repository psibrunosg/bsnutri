import { useState } from "react";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import { useStore } from "../lib/store";

export default function Login() {
  const { setLoggedIn } = useStore();
  const [email, setEmail] = useState("helena@bsnutri.com.br");
  const [pass, setPass] = useState("");

  return (
    <div className="flex min-h-screen bg-background">
      {/* Left — brand panel */}
      <div className="relative hidden w-[46%] flex-col justify-between overflow-hidden bg-forest-800 p-12 lg:flex">
        <div
          className="pointer-events-none absolute -right-40 -top-40 h-[480px] w-[480px] rounded-full opacity-[0.07]"
          style={{ background: "radial-gradient(circle, #d9a44a, transparent 65%)" }}
        />
        <div
          className="pointer-events-none absolute -bottom-52 -left-32 h-[520px] w-[520px] rounded-full opacity-10"
          style={{ background: "radial-gradient(circle, #749966, transparent 65%)" }}
        />
        <div className="flex items-center gap-3">
          <img src="./app-icon.png" alt="BSNutri" className="h-12 w-12 rounded-full ring-2 ring-amber-400/60" />
          <span className="font-display text-xl font-semibold text-cream-50">BSNutri</span>
        </div>
        <div className="relative">
          <p className="eyebrow mb-4 !text-amber-300">01 — Planejamento nutricional</p>
          <h1 className="font-display text-[44px] font-medium leading-[1.08] text-cream-50">
            Planos alimentares que o paciente <em className="italic text-amber-300">segue de verdade</em>.
          </h1>
          <p className="mt-5 max-w-md text-[16px] leading-relaxed text-cream-100/70">
            Monte a semana em minutos, aplique modelos prontos e entregue um PDF claro — com mapa de substituições incluído.
          </p>
        </div>
        <img src="./app-icon.png" alt="" className="relative h-56 w-56 self-center rounded-full shadow-warm-lg" />
        <p className="font-mono text-[11px] uppercase tracking-[0.14em] text-cream-100/40">BSNutri · Protótipo v2</p>
      </div>

      {/* Right — form */}
      <div className="flex flex-1 items-center justify-center p-8">
        <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="w-full max-w-sm">
          <img src="./app-icon.png" alt="BSNutri" className="mb-6 h-16 w-16 rounded-full lg:hidden" />
          <p className="eyebrow mb-2">Acesso do profissional</p>
          <h2 className="font-display text-3xl font-semibold">Bem-vinda de volta</h2>
          <p className="mt-2 text-sm text-muted-foreground">Entre para continuar cuidando dos seus pacientes.</p>

          <form
            className="mt-8 space-y-4"
            onSubmit={(e) => {
              e.preventDefault();
              setLoggedIn(true);
            }}
          >
            <div>
              <label className="label-warm">E-mail</label>
              <input className="input-warm" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div>
              <label className="label-warm">Senha</label>
              <input className="input-warm" type="password" value={pass} onChange={(e) => setPass(e.target.value)} placeholder="••••••••" />
            </div>
            <button type="submit" className="btn-primary w-full !py-3">
              Entrar no consultório <ArrowRight size={16} />
            </button>
          </form>
          <p className="mt-6 text-center text-xs text-muted-foreground">
            Protótipo de interface — qualquer senha funciona. Dados ficam apenas neste navegador.
          </p>
        </motion.div>
      </div>
    </div>
  );
}
