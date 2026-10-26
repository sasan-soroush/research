import { useCallback, useEffect, useState } from "react";
import { supabase } from "./supabase";
import { go, type Route } from "./route";
import * as api from "./api";

type Filter = Extract<Route, { view: "list" }>["filter"];

const timeAgo = (iso: string) => {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return new Date(iso).toLocaleDateString();
};

export default function Dashboard({ filter, email }: { filter: Filter; email: string }) {
  const [projects, setProjects] = useState<api.Project[]>([]);
  const [drawings, setDrawings] = useState<api.DrawingMeta[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [p, d] = await Promise.all([api.listProjects(), api.listDrawings()]);
      setProjects(p);
      setDrawings(d);
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Run a mutation, then refresh; surface failures instead of swallowing them.
  const run = async (fn: () => Promise<unknown>) => {
    try {
      await fn();
    } catch (e) {
      setError((e as Error).message);
    }
    await load();
  };

  const projectId = typeof filter === "object" ? filter.projectId : null;
  const current = projects.find((p) => p.id === projectId);
  const shown = (drawings ?? []).filter((d) =>
    filter === "all" ? true : filter === "unfiled" ? d.project_id === null : d.project_id === projectId,
  );
  const title = filter === "all" ? "All drawings" : filter === "unfiled" ? "Unfiled" : (current?.name ?? "Project");

  const newProject = () => {
    const name = prompt("Project name")?.trim();
    if (name) run(async () => go(`/p/${(await api.createProject(name)).id}`));
  };

  const newDrawing = async () => {
    try {
      const d = await api.createDrawing(projectId);
      go(`/d/${d.id}`);
    } catch (e) {
      setError((e as Error).message);
    }
  };

  const renameDrawing = (d: api.DrawingMeta) => {
    const name = prompt("Rename drawing", d.name)?.trim();
    if (name && name !== d.name) run(() => api.updateDrawing(d.id, { name }));
  };

  const removeDrawing = (d: api.DrawingMeta) => {
    if (confirm(`Delete "${d.name}"? This cannot be undone.`)) run(() => api.deleteDrawing(d.id));
  };

  const renameCurrent = () => {
    if (!current) return;
    const name = prompt("Rename project", current.name)?.trim();
    if (name && name !== current.name) run(() => api.renameProject(current.id, name));
  };

  const deleteCurrent = () => {
    if (!current) return;
    if (confirm(`Delete project "${current.name}"? Its drawings are kept and moved to Unfiled.`))
      run(async () => {
        await api.deleteProject(current.id);
        go("/");
      });
  };

  const navItem = (label: string, hash: string, active: boolean, count?: number) => (
    <a key={hash} href={`#${hash}`} className={active ? "nav active" : "nav"}>
      <span>{label}</span>
      {count !== undefined && <span className="count">{count}</span>}
    </a>
  );

  return (
    <div className="dash">
      <aside>
        <div className="brand">Drawings</div>
        {navItem("All drawings", "/", filter === "all", drawings?.length)}
        {navItem("Unfiled", "/unfiled", filter === "unfiled", drawings?.filter((d) => !d.project_id).length)}
        <div className="section">
          <span>Projects</span>
          <button className="icon" title="New project" onClick={newProject}>
            +
          </button>
        </div>
        {projects.map((p) =>
          navItem(p.name, `/p/${p.id}`, p.id === projectId, drawings?.filter((d) => d.project_id === p.id).length),
        )}
        {projects.length === 0 && <p className="muted small">No projects yet.</p>}
        <div className="account">
          <span className="muted small">{email}</span>
          <button onClick={() => supabase.auth.signOut()}>Sign out</button>
        </div>
      </aside>

      <main>
        <header>
          <h1>{title}</h1>
          <div className="actions">
            {current && <button onClick={renameCurrent}>Rename</button>}
            {current && <button onClick={deleteCurrent}>Delete project</button>}
            <button className="primary" onClick={newDrawing}>
              New drawing
            </button>
          </div>
        </header>

        {error && <p className="error">{error}</p>}
        {drawings === null && !error && <p className="muted">Loading…</p>}
        {drawings !== null && shown.length === 0 && <p className="muted">No drawings here yet.</p>}

        <ul className="grid">
          {shown.map((d) => (
            <li key={d.id} className="card drawing">
              <a href={`#/d/${d.id}`} className="open">
                <strong>{d.name}</strong>
                <span className="muted small">Edited {timeAgo(d.updated_at)}</span>
              </a>
              <div className="row">
                <select
                  aria-label="Project"
                  value={d.project_id ?? ""}
                  onChange={(e) => run(() => api.updateDrawing(d.id, { project_id: e.target.value || null }))}
                >
                  <option value="">Unfiled</option>
                  {projects.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
                <button onClick={() => renameDrawing(d)}>Rename</button>
                <button onClick={() => removeDrawing(d)}>Delete</button>
              </div>
            </li>
          ))}
        </ul>
      </main>
    </div>
  );
}
