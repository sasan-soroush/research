"""Inline data/graph.json into src/game.html and write dist/index.html."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
html = (ROOT / "src" / "game.html").read_text()
data = (ROOT / "data" / "graph.json").read_text().replace("</", "<\\/")
out = ROOT / "dist" / "index.html"
out.write_text(html.replace("/*DATA*/null", data, 1))
print(f"Wrote {out} ({out.stat().st_size // 1024} KB)")
