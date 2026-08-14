import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { Patient, PatientPlan, PlanTemplate } from "./types";
import { SEED_PATIENTS, SEED_PLANS, TEMPLATES } from "./data";

export type View =
  | { name: "dashboard" }
  | { name: "patients" }
  | { name: "patient-new" }
  | { name: "patient-detail"; patientId: string }
  | { name: "plan-builder"; planId?: string; patientId?: string; templateId?: string }
  | { name: "templates" }
  | { name: "portal"; patientId: string };

interface Store {
  loggedIn: boolean;
  setLoggedIn: (v: boolean) => void;
  view: View;
  go: (v: View) => void;
  patients: Patient[];
  addPatient: (p: Patient) => void;
  updatePatient: (p: Patient) => void;
  plans: PatientPlan[];
  savePlan: (p: PatientPlan) => void;
  getPatient: (id?: string) => Patient | undefined;
  templates: PlanTemplate[];
}

const Ctx = createContext<Store | null>(null);

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

export function StoreProvider({ children }: { children: ReactNode }) {
  const [loggedIn, setLoggedIn] = useState(false);
  const [view, setView] = useState<View>({ name: "dashboard" });
  const [patients, setPatients] = useState<Patient[]>(() => load("bsnutri-patients", SEED_PATIENTS));
  const [plans, setPlans] = useState<PatientPlan[]>(() => load("bsnutri-plans", SEED_PLANS));

  useEffect(() => localStorage.setItem("bsnutri-patients", JSON.stringify(patients)), [patients]);
  useEffect(() => localStorage.setItem("bsnutri-plans", JSON.stringify(plans)), [plans]);

  const store = useMemo<Store>(
    () => ({
      loggedIn,
      setLoggedIn,
      view,
      go: setView,
      patients,
      addPatient: (p) => setPatients((prev) => [...prev, p]),
      updatePatient: (p) => setPatients((prev) => prev.map((x) => (x.id === p.id ? p : x))),
      plans,
      savePlan: (p) =>
        setPlans((prev) => {
          const i = prev.findIndex((x) => x.id === p.id);
          if (i >= 0) {
            const copy = [...prev];
            copy[i] = p;
            return copy;
          }
          return [...prev, p];
        }),
      getPatient: (id) => patients.find((p) => p.id === id),
      templates: TEMPLATES,
    }),
    [loggedIn, view, patients, plans]
  );

  return <Ctx.Provider value={store}>{children}</Ctx.Provider>;
}

export function useStore(): Store {
  const s = useContext(Ctx);
  if (!s) throw new Error("store");
  return s;
}

export function uid(prefix: string) {
  return `${prefix}-${Math.random().toString(36).slice(2, 8)}`;
}
