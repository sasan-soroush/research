"""Build the Hyperterra MVP map from live Wikipedia data.

Fetches a curated set of hub articles plus articles that were trending during
the season window, the hyperlinks between them, a short summary of each, and
30 days of real daily page views. Writes data/graph.json.

Usage: python3 scripts/build_data.py [END_DATE as YYYYMMDD]
"""

import json
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

UA = "HyperterraMVP/0.1 (research prototype; contact via GitHub sasan-soroush/research)"
API = "https://en.wikipedia.org/w/api.php"
PV = "https://wikimedia.org/api/rest_v1/metrics/pageviews"
DAYS = 30
OUT = Path(__file__).resolve().parent.parent / "data" / "graph.json"

SEEDS = [
    # History and civilisations
    "Roman Empire", "Ancient Greece", "Ancient Egypt", "Byzantine Empire", "Ottoman Empire",
    "Mongol Empire", "British Empire", "Persian Empire", "Han dynasty", "Aztec Empire",
    "Inca Empire", "Vikings", "Middle Ages", "Renaissance", "Industrial Revolution",
    "French Revolution", "American Revolution", "World War I", "World War II", "Cold War",
    "Napoleon", "Julius Caesar", "Alexander the Great", "Genghis Khan", "Cleopatra",
    "Abraham Lincoln", "Winston Churchill", "Adolf Hitler", "Joseph Stalin", "Silk Road",
    # Science and nature
    "Physics", "Chemistry", "Biology", "Mathematics", "Astronomy", "Evolution",
    "Albert Einstein", "Isaac Newton", "Charles Darwin", "Marie Curie", "Quantum mechanics",
    "General relativity", "DNA", "Black hole", "Big Bang", "Solar System", "Moon", "Mars",
    "Sun", "Earth", "Climate change", "Dinosaur", "Volcano", "Earthquake", "Ocean",
    "Photosynthesis", "Periodic table", "Atom", "Electricity", "Vaccine",
    # Technology
    "Internet", "World Wide Web", "Computer", "Artificial intelligence", "Smartphone",
    "Google", "Apple Inc.", "Microsoft", "Amazon (company)", "Meta Platforms", "Tesla, Inc.",
    "Elon Musk", "Steve Jobs", "Bill Gates", "Alan Turing", "Video game", "Minecraft",
    "Nintendo", "PlayStation", "Wikipedia", "ChatGPT", "Bitcoin", "NASA", "SpaceX",
    # Geography
    "United States", "China", "India", "Russia", "United Kingdom", "France", "Germany",
    "Japan", "Brazil", "Canada", "Australia", "Italy", "Spain", "Mexico", "Egypt",
    "Nigeria", "South Africa", "Turkey", "Iran", "Israel", "Ukraine", "South Korea",
    "Europe", "Africa", "Asia", "Antarctica", "London", "Paris", "New York City", "Tokyo",
    "Rome", "Mount Everest", "Amazon River", "Sahara", "Pacific Ocean",
    # Culture, music, film
    "William Shakespeare", "Leonardo da Vinci", "Mona Lisa", "Wolfgang Amadeus Mozart",
    "Ludwig van Beethoven", "The Beatles", "Michael Jackson", "Taylor Swift", "Beyoncé",
    "Elvis Presley", "Jazz", "Rock music", "Hip hop music", "Hollywood", "Star Wars",
    "Harry Potter", "Marvel Cinematic Universe", "Disney", "The Simpsons", "Anime",
    "Netflix", "YouTube", "Bible", "Christianity", "Islam", "Buddhism", "Hinduism",
    "Greek mythology", "Philosophy", "Plato", "Aristotle",
    # Sports
    "Association football", "FIFA World Cup", "Olympic Games", "Basketball", "Cricket",
    "Tennis", "Formula One", "Lionel Messi", "Cristiano Ronaldo", "Michael Jordan",
    "LeBron James", "Real Madrid", "Manchester United F.C.", "National Football League",
    "Super Bowl", "Chess",
    # Everyday life
    "Pizza", "Coffee", "Tea", "Chocolate", "Cat", "Dog", "Horse", "Shark", "Lion",
    "Money", "Democracy", "United Nations", "European Union", "Language", "English language",
]

SKIP_PREFIXES = ("Special:", "Main_Page", "Wikipedia:", "File:", "Portal:", "Help:", "Template:", "Category:", "Talk:", "User:", "XXX", "Cleopatra_(")


def get_json(url):
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(2 ** attempt)
        except Exception:
            time.sleep(2 ** attempt)
    return None


def api(params):
    params = {**params, "format": "json", "formatversion": "2"}
    return get_json(API + "?" + urllib.parse.urlencode(params))


def resolve(titles):
    """Map requested titles to canonical titles, dropping missing ones."""
    out = {}
    for i in range(0, len(titles), 50):
        chunk = titles[i:i + 50]
        d = api({"action": "query", "titles": "|".join(chunk), "redirects": 1})
        q = d["query"]
        alias = {}
        for n in q.get("normalized", []):
            alias[n["from"]] = n["to"]
        for r in q.get("redirects", []):
            alias[r["from"]] = r["to"]
        missing = {p["title"] for p in q["pages"] if p.get("missing")}
        for t in chunk:
            c = t
            while c in alias:
                c = alias[c]
            if c not in missing:
                out[t] = c
    return out


def outgoing_links(title):
    links, cont = set(), {}
    while True:
        d = api({"action": "query", "titles": title, "prop": "links", "plnamespace": 0,
                 "pllimit": "max", "redirects": 1, **cont})
        if not d:
            break
        for p in d["query"]["pages"]:
            for l in p.get("links", []):
                links.add(l["title"])
        if "continue" not in d:
            break
        cont = d["continue"]
        time.sleep(0.05)
    return links


def summaries(titles):
    out = {}
    for t in titles:
        d = api({"action": "query", "titles": t, "prop": "extracts", "exintro": 1,
                 "explaintext": 1, "exsentences": 2, "redirects": 1})
        if d:
            for p in d["query"]["pages"]:
                out[t] = (p.get("extract") or "").strip()[:420]
        time.sleep(0.03)
    return out


def daily_views(title, start, end):
    t = urllib.parse.quote(title.replace(" ", "_"), safe="")
    d = get_json(f"{PV}/per-article/en.wikipedia/all-access/user/{t}/daily/{start}/{end}")
    by_day = {}
    for item in (d or {}).get("items", []):
        by_day[item["timestamp"][:8]] = item["views"]
    return by_day


def main():
    end = datetime.strptime(sys.argv[1], "%Y%m%d").date() if len(sys.argv) > 1 else date.today() - timedelta(days=2)
    days = [end - timedelta(days=DAYS - 1 - i) for i in range(DAYS)]
    keys = [d.strftime("%Y%m%d") for d in days]

    print("Resolving seeds...")
    canon = sorted(set(resolve(SEEDS).values()))
    print(f"  {len(canon)} seed articles")

    print("Collecting trending articles...")
    trend_hits = defaultdict(int)
    for d in days:
        top = get_json(f"{PV}/top/en.wikipedia/all-access/{d.year}/{d.month:02d}/{d.day:02d}")
        if not top:
            continue
        for a in top["items"][0]["articles"][:60]:
            name = a["article"]
            if name.startswith(SKIP_PREFIXES) or name.startswith("Deaths_in") or name.startswith("List_of"):
                continue
            trend_hits[name.replace("_", " ")] += 1
        time.sleep(0.05)
    trending = sorted(trend_hits, key=lambda t: -trend_hits[t])[:70]
    trending = sorted(set(resolve(trending).values()) - set(canon))
    print(f"  {len(trending)} trending candidates")

    candidates = canon + trending
    cset = set(candidates)
    print("Fetching links...")
    out_links = {}
    for i, t in enumerate(candidates):
        out_links[t] = outgoing_links(t) & cset
        if i % 25 == 0:
            print(f"  {i}/{len(candidates)}")

    # Keep trending articles only if they connect to at least 2 seeds.
    undirected = defaultdict(set)
    for a, ls in out_links.items():
        for b in ls:
            if a != b:
                undirected[a].add(b)
                undirected[b].add(a)
    keep = set(canon) | {t for t in trending if len(undirected[t] & set(canon)) >= 2}

    # Roads: mutual links. Nodes without any mutual link keep their links to the
    # two most-linked neighbours so nothing is stranded.
    def mutual(a, b):
        return b in out_links.get(a, ()) and a in out_links.get(b, ())

    edges = set()
    for a in keep:
        for b in undirected[a] & keep:
            if a < b and mutual(a, b):
                edges.add((a, b))
    deg = defaultdict(int)
    for a, b in edges:
        deg[a] += 1
        deg[b] += 1
    for a in keep:
        if deg[a] < 2:
            extra = sorted(undirected[a] & keep, key=lambda n: -len(undirected[n]))[:2]
            for b in extra:
                edges.add(tuple(sorted((a, b))))

    # Largest connected component only.
    adj = defaultdict(set)
    for a, b in edges:
        adj[a].add(b)
        adj[b].add(a)
    seen, best = set(), set()
    for n in keep:
        if n in seen:
            continue
        comp, stack = set(), [n]
        while stack:
            x = stack.pop()
            if x in comp:
                continue
            comp.add(x)
            stack.extend(adj[x] - comp)
        seen |= comp
        if len(comp) > len(best):
            best = comp
    nodes = sorted(best)
    edges = sorted((a, b) for a, b in edges if a in best and b in best)
    print(f"Map: {len(nodes)} articles, {len(edges)} roads")

    print("Fetching page views and summaries...")
    views = {}
    for i, t in enumerate(nodes):
        bd = daily_views(t, keys[0], keys[-1])
        views[t] = [bd.get(k, 0) for k in keys]
        if i % 25 == 0:
            print(f"  {i}/{len(nodes)}")
        time.sleep(0.03)
    summ = summaries(nodes)

    index = {t: i for i, t in enumerate(nodes)}
    data = {
        "source": "English Wikipedia: article links, intro extracts (CC BY-SA 4.0) and Wikimedia page views",
        "days": [d.isoformat() for d in days],
        "articles": [
            {"t": t, "s": summ.get(t, ""), "v": views[t], "trend": t in trending}
            for t in nodes
        ],
        "edges": [[index[a], index[b]] for a, b in edges],
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
