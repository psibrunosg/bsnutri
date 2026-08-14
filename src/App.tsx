import { StoreProvider, useStore } from "./lib/store";
import { Shell } from "./components/Shell";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Patients from "./pages/Patients";
import PatientWizard from "./pages/PatientWizard";
import PatientDetail from "./pages/PatientDetail";
import PlanBuilder from "./pages/PlanBuilder";
import Templates from "./pages/Templates";
import Portal from "./pages/Portal";

function Root() {
  const { loggedIn, view } = useStore();

  if (!loggedIn) return <Login />;

  let page: React.ReactNode;
  switch (view.name) {
    case "dashboard": page = <Dashboard />; break;
    case "patients": page = <Patients />; break;
    case "patient-new": page = <PatientWizard />; break;
    case "patient-detail": page = <PatientDetail patientId={view.patientId} />; break;
    case "plan-builder": page = <PlanBuilder planId={view.planId} patientId={view.patientId} templateId={view.templateId} />; break;
    case "templates": page = <Templates />; break;
    case "portal": page = <Portal patientId={view.patientId} />; break;
  }

  const bare = view.name === "patient-new";
  return bare ? <div className="min-h-screen bg-background px-6 py-8">{page}</div> : <Shell>{page}</Shell>;
}

export default function App() {
  return (
    <StoreProvider>
      <Root />
    </StoreProvider>
  );
}
