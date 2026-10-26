import { useEffect, useRef, useState } from "react";
import { Excalidraw, serializeAsJSON } from "@excalidraw/excalidraw";
import type { ExcalidrawInitialDataState } from "@excalidraw/excalidraw/types";
import "@excalidraw/excalidraw/index.css";
import * as api from "./api";
import { go } from "./route";

type Status = "saved" | "unsaved" | "saving" | "error";
const SAVE_DELAY_MS = 1500;

export default function Editor({ id }: { id: string }) {
  const [drawing, setDrawing] = useState<api.Drawing | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [status, setStatus] = useState<Status>("saved");

  // Serialized scenes: the latest one in the editor and the last one confirmed saved.
  const latest = useRef<string | null>(null);
  const saved = useRef<string | null>(null);
  const timer = useRef<number | undefined>(undefined);
  const saving = useRef<Promise<void> | null>(null);

  useEffect(() => {
    api.getDrawing(id).then(
      (d) => {
        setDrawing(d);
        setName(d.name);
      },
      (e: Error) => setLoadError(e.message),
    );
  }, [id]);

  const flush = async (): Promise<void> => {
    window.clearTimeout(timer.current);
    if (saving.current) await saving.current;
    const json = latest.current;
    if (json === null || json === saved.current) return;
    setStatus("saving");
    saving.current = api
      .updateDrawing(id, { scene: JSON.parse(json) })
      .then(() => {
        saved.current = json;
        if (latest.current === json) setStatus("saved");
        else {
          setStatus("unsaved");
          timer.current = window.setTimeout(flush, SAVE_DELAY_MS);
        }
      })
      .catch(() => {
        setStatus("error");
        timer.current = window.setTimeout(flush, 5000);
      })
      .finally(() => {
        saving.current = null;
      });
    await saving.current;
  };

  // Save when the tab is hidden/closed, and warn if something is still unsaved.
  useEffect(() => {
    const onHide = () => document.visibilityState === "hidden" && flush();
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      if (latest.current !== saved.current) {
        flush();
        e.preventDefault();
      }
    };
    document.addEventListener("visibilitychange", onHide);
    addEventListener("beforeunload", onBeforeUnload);
    return () => {
      document.removeEventListener("visibilitychange", onHide);
      removeEventListener("beforeunload", onBeforeUnload);
      flush();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const onChange: React.ComponentProps<typeof Excalidraw>["onChange"] = (elements, appState, files) => {
    const json = serializeAsJSON(elements, appState, files, "local");
    if (json === latest.current) return; // e.g. selection, scroll or zoom only
    const first = latest.current === null;
    latest.current = json;
    if (first) {
      saved.current = json; // the loaded scene itself is not a change
      return;
    }
    if (json === saved.current) {
      window.clearTimeout(timer.current);
      if (!saving.current) setStatus("saved");
      return;
    }
    setStatus("unsaved");
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(flush, SAVE_DELAY_MS);
  };

  const saveName = async () => {
    const trimmed = name.trim();
    if (!drawing || !trimmed || trimmed === drawing.name) return setName(drawing?.name ?? "");
    try {
      await api.updateDrawing(id, { name: trimmed });
      setDrawing({ ...drawing, name: trimmed });
    } catch {
      setName(drawing.name);
      setStatus("error");
    }
  };

  const back = async () => {
    await flush();
    go(drawing?.project_id ? `/p/${drawing.project_id}` : "/");
  };

  if (loadError)
    return (
      <div className="center">
        <p className="error">{loadError}</p>
        <a href="#/">Back to drawings</a>
      </div>
    );
  if (!drawing) return <div className="center muted">Loading…</div>;

  const label = { saved: "Saved", unsaved: "Unsaved changes", saving: "Saving…", error: "Save failed, retrying…" }[status];

  return (
    <div className="editor">
      <header>
        <button onClick={back} aria-label="Back to drawings">
          ← Drawings
        </button>
        <input
          className="title"
          aria-label="Drawing name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onBlur={saveName}
          onKeyDown={(e) => e.key === "Enter" && e.currentTarget.blur()}
        />
        <span className={`status ${status}`}>{label}</span>
      </header>
      <div className="canvas">
        <Excalidraw
          initialData={drawing.scene as ExcalidrawInitialDataState}
          onChange={onChange}
          UIOptions={{ canvasActions: { loadScene: true, saveToActiveFile: false } }}
        />
      </div>
    </div>
  );
}
