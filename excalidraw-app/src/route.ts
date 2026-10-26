import { useEffect, useState } from "react";

// Hash routes: #/ (all), #/unfiled, #/p/<projectId>, #/d/<drawingId>
export type Route =
  | { view: "list"; filter: "all" | "unfiled" | { projectId: string } }
  | { view: "drawing"; id: string };

function parse(hash: string): Route {
  const [, kind, id] = hash.replace(/^#/, "").split("/");
  if (kind === "d" && id) return { view: "drawing", id };
  if (kind === "p" && id) return { view: "list", filter: { projectId: id } };
  if (kind === "unfiled") return { view: "list", filter: "unfiled" };
  return { view: "list", filter: "all" };
}

export function useRoute(): Route {
  const [route, setRoute] = useState(() => parse(location.hash));
  useEffect(() => {
    const onHash = () => setRoute(parse(location.hash));
    addEventListener("hashchange", onHash);
    return () => removeEventListener("hashchange", onHash);
  }, []);
  return route;
}

export const go = (hash: string) => {
  location.hash = hash;
};
