// Self-host Excalidraw's fonts instead of loading them from a CDN.
import { cpSync } from "node:fs";

cpSync("node_modules/@excalidraw/excalidraw/dist/prod/fonts", "public/fonts", { recursive: true });
