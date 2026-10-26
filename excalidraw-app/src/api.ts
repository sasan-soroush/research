import { supabase } from "./supabase";

export type Project = { id: string; name: string; updated_at: string };
export type DrawingMeta = { id: string; name: string; project_id: string | null; updated_at: string };
export type Scene = { elements?: unknown[]; appState?: Record<string, unknown>; files?: Record<string, unknown> };
export type Drawing = DrawingMeta & { scene: Scene };

function check<T>({ data, error }: { data: T | null; error: { message: string } | null }): T {
  if (error) throw new Error(error.message);
  return data as T;
}

export const listProjects = async () =>
  check<Project[]>(await supabase.from("projects").select("id, name, updated_at").order("name"));

export const createProject = async (name: string) =>
  check<Project>(await supabase.from("projects").insert({ name }).select("id, name, updated_at").single());

export const renameProject = async (id: string, name: string) =>
  check(await supabase.from("projects").update({ name }).eq("id", id));

// Drawings in the project become unfiled (FK is ON DELETE SET NULL).
export const deleteProject = async (id: string) =>
  check(await supabase.from("projects").delete().eq("id", id));

export const listDrawings = async () =>
  check<DrawingMeta[]>(
    await supabase.from("drawings").select("id, name, project_id, updated_at").order("updated_at", { ascending: false }),
  );

export const createDrawing = async (project_id: string | null) =>
  check<DrawingMeta>(
    await supabase.from("drawings").insert({ project_id }).select("id, name, project_id, updated_at").single(),
  );

export const getDrawing = async (id: string) => {
  const d = check<Drawing | null>(
    await supabase.from("drawings").select("id, name, project_id, updated_at, scene").eq("id", id).maybeSingle(),
  );
  if (!d) throw new Error("Drawing not found.");
  return d;
};

export const updateDrawing = async (id: string, patch: Partial<Pick<Drawing, "name" | "project_id" | "scene">>) =>
  check(await supabase.from("drawings").update(patch).eq("id", id));

export const deleteDrawing = async (id: string) =>
  check(await supabase.from("drawings").delete().eq("id", id));
