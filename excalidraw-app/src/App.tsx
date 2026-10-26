import { lazy, Suspense, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { useRoute } from "./route";
import Login from "./Login";
import Dashboard from "./Dashboard";

// The editor is large; load it only when a drawing is opened.
const Editor = lazy(() => import("./Editor"));

export default function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  const route = useRoute();

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  if (session === undefined) return <div className="center muted">Loading…</div>;
  if (!session) return <Login />;
  if (route.view === "drawing")
    return (
      <Suspense fallback={<div className="center muted">Loading…</div>}>
        <Editor key={route.id} id={route.id} />
      </Suspense>
    );
  return <Dashboard filter={route.filter} email={session.user.email ?? ""} />;
}
