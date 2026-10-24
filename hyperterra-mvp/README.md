# Hyperterra MVP

A playable single-player prototype of **Hyperterra**, the top pick in `../novel-web-game-ideas.md`: a territory war fought over the real link structure of Wikipedia, where real reader numbers are the economy and real news drives the events.

## What the MVP shows

| Core idea | How the MVP does it |
|---|---|
| **The internet is the map** | About 200 real English Wikipedia articles. A line is a two-way link: A links to B *and* B links to A. Troops can only travel along those lines. |
| **Real attention is the economy** | Each in-game day replays one real day: the 30 days ending 22 Oct 2026. Every territory earns `√(that day's real page views) ÷ 12` troops. |
| **The news is the live ops** | Articles that really trended in that window are on the map. Each day's biggest real spikes (up 60% or more on their recent average) glow orange and pay out more that day. |
| **Skill, not just numbers** | An optional *knowledge duel* before each attack: name an article that links both ways with the target. Right gives +50% power, wrong gives −25%. |
| **A history that piles up** | A season chronicle records every conquest and every real-world spike. This is the start of the Heirloom-style history layer. |
| **Seasons** | 30 days, then final standings. The winner is the clan that reached the most readers in total. |

Three rival AI clans (Violet Archive, Redlink Raiders, Amber Index) stand in for the real players and clans of the full game.

## How to play

1. Pick a homeland article.
2. Select one of your blue articles, then send half or all of its troops at a linked article. You take it if your power beats its defenders.
3. Press **End day**. Rivals move, and every territory earns troops from the next real day's readers.
4. Watch the orange "Trending" strip. Those articles are worth grabbing *today*.

## Files

- `scripts/build_data.py` fetches the map from live Wikipedia and Wikimedia APIs and writes `data/graph.json`. Run it with an end date to build a new season: `python3 scripts/build_data.py 20261022`.
- `src/game.html` is the game: one HTML file, using d3 for the map.
- `scripts/assemble.py` inlines the data and writes `dist/index.html`, a single self-contained file.

## Not in the MVP yet

- **Real multiplayer**: shared live seasons, human clans, chat and diplomacy. This needs a server; Colyseus or Nakama would suit.
- **Live data**: running against *today's* Wikipedia instead of replaying a past window.
- **A bigger map**: the ~10,000 most-linked articles, with regions and capitals.
- **Shareable territory links**: one URL per article, for example "come take Taylor Swift from us".
- **Monetisation**: clan subscriptions, cosmetic banners, season pass.

## What to test with it

Do people understand the hook in under a minute? Do they watch the trending strip and change plans because of real news? Do they want another season? If yes, build the multiplayer slice next.

Article text excerpts come from Wikipedia under CC BY-SA 4.0; page views come from the Wikimedia REST API. This prototype is not affiliated with or endorsed by Wikipedia or the Wikimedia Foundation.
