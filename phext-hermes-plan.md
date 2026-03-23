# Phext-First Hermes — Coordinated Adoption Plan
*Authored by Aster 💡 @ best-willow — 2026-03-22*

---

## The Thesis

Hermes currently treats phext as an external file format — something nodes read/write via SQ's HTTP API using raw curl calls. The goal of this plan is to make phext the **native data structure** inside Hermes itself: coordinates as first-class keys, scrolls as the unit of storage, libphext-py as a direct import in Python code.

The result: every Hermes node thinks in phext. Sessions, memory, context, skills, inter-node messages — all addressable by coordinate. The mesh becomes queryable by any node that knows the addressing scheme.

---

## Coordinate Taxonomy (The Schema)

Before building anything, we fix the coordinate convention. This is the schema everything else derives from.

```
Library  . Shelf  . Series  / Collection . Volume . Book  / Chapter . Section . Scroll
─────────────────────────────────────────────────────────────────────────────────────
DOMAIN     NODE    YEAR       TOPIC        SESSION  TURN    TOOL_GRP  MSG_IDX   CONTENT
```

### Domain (Library) — top-level namespace
```
1 = Hermes internals (sessions, memory, config)
2 = Mirrorborn mesh (inter-node comms, shell updates)
3 = Skills and knowledge
4 = User data (profiles, preferences)
5 = External integrations (GitHub, Discord, etc.)
```

### Node (Shelf) — which Mirrorborn instance
```
1 = Aster (best-willow)
2 = Phex (aurora-continuum)
3 = Cyon (halycon-vector)
4 = Lux (logos-prime)
5 = Verse (delta-wood)
6 = Theia (aletheia-core)
7 = Exo (ashfall-haven)
8 = Orin (elven-path)
9 = Solin (uncanny-valley)
10 = Lumen (lighthouse-omen)
11 = Chrys (chrysalis-hub)
```

### Year / Month / Week (Series / Collection / Volume)
- Series = year (2026 = 1, 2027 = 2, ...)
- Collection = month (1–12)
- Volume = week of year (1–52)

### Topic / Session / Turn (Book / Chapter / Section)
- Book = topic ID (stable per-project integer, registered in skills phext)
- Chapter = session number within topic (auto-incremented)
- Section = turn number within session

### Tool group / Message index / Content (Scroll)
- Tool group within a turn (1 = user msg, 2 = first tool call batch, 3 = second, ...)
- Message index within group
- Scroll = the actual content atom

---

## Phase 0 — Foundation (Week 1)

### 0a. Install libphext-py in Hermes venv

```bash
# On every node post-migration:
/home/wbic16/.hermes/hermes-agent/venv/bin/pip install -e /source/libphext-py
```

Add to `migrate-to-hermes.sh` Step 3 (after venv creation):
```bash
pip install -e /path/to/libphext-py  # or pip install phext once published
```

### 0b. Create `tools/phext_tool.py`

The core primitive. Wraps both libphext-py (for in-process operations) and
SQ HTTP API (for persistence). Registers three tools:

```python
# phext_read(coordinate: str, phext_name: str) -> str
#   Reads a scroll from ~/.hermes/phexts/<phext_name>.phext at the given coordinate.
#   Uses libphext-py: Phext().fetch(buffer, Coordinate.from_string(coordinate))
#   Falls back to SQ HTTP API if phext_name is a remote phext.

# phext_write(coordinate: str, phext_name: str, content: str) -> str
#   Writes content to a scroll at coordinate in the named phext.
#   Uses Phext().update(buffer, coord, content, overwrite=True), then saves to disk.
#   Also syncs to SQ if a local SQ instance is running.

# phext_search(query: str, phext_name: str) -> list[dict]
#   Full-text search across all scrolls. Returns [{coordinate, snippet}].
#   Uses Phext().explode() -> iterate all scrolls -> filter by query.
#   For large phexts, mirrors phext-lattice's parallel search approach.
```

### 0c. Register coordinate scheme in `skills/mirrorborn/phext-schema/`

A SKILL.md that documents the domain/node/time taxonomy above so every
node and every future session can reference it.

---

## Phase 1 — Memory as Phext (Week 2)

### The problem with MEMORY.md

Currently `~/.hermes/memories/MEMORY.md` is a flat markdown file with a 2200-char limit.
It's manually curated, unbounded in what can be forgotten, and has no addressing scheme.
Two nodes can't merge memories without text diffing.

### The replacement: `memory.phext`

Each node gets `~/.hermes/phexts/memory.phext` with this structure:

```
1.NODE.1 / YEAR.MONTH.WEEK / 1.1.1  — identity (name, coordinate, role)
1.NODE.1 / YEAR.MONTH.WEEK / 1.1.2  — environment facts
1.NODE.1 / YEAR.MONTH.WEEK / 1.1.3  — user profile
1.NODE.1 / YEAR.MONTH.WEEK / 1.2.1  — recent lessons (rotating window)
1.NODE.1 / YEAR.MONTH.WEEK / 2.1.1  — skill observations
1.NODE.1 / YEAR.MONTH.WEEK / 3.1.1  — cross-node facts (mesh state)
```

**What changes in Hermes:**

`agent/prompt_builder.py` currently reads `MEMORY.md` and injects it verbatim.
Replace with: read `memory.phext`, call `Phext().explode()`, select the scrolls
at the current node's identity coordinate range, inject with coordinate labels.
The agent sees: `[1.1.1/2026.3.13/1.1.1] Aster, ASI Alpha, coordinate 2.7.4/...`

**Memory writes** (`run_agent.py` memory flush) write to specific coordinates
rather than replacing the entire file. New facts go to the current week's scroll.
Old weeks are preserved — the memory is *historical*, not overwritten.

**Cross-node merge:** `Phext().merge(local, remote)` — zipper merge. Two nodes
can merge their memory phexts without conflict because each owns its NODE dimension.

---

## Phase 2 — Sessions as Phext (Week 3)

### The problem with SQLite FTS5

`state.db` is excellent for recency search but flat. Sessions have no spatial
relationship to each other. "What did we discuss about phext theory last month?"
requires FTS, not a coordinate jump.

### The approach: dual-write with phext as primary

Rather than replacing SQLite immediately (it's battle-tested), we dual-write:
- SQLite: continues to serve recency queries and the existing session_search tool
- Phext: receives a mirror of every session at its coordinate address

**Session coordinate mapping:**
```
Domain=1 (Hermes internals)
Shelf=NODE_ID
Series=YEAR, Collection=MONTH, Volume=WEEK
Book=TOPIC_ID (derived from session title via a stable hash → int mapping)
Chapter=SESSION_NUM (auto-incremented per topic)
Section=TURN_NUM
Scroll=MSG_IDX
```

**`hermes_state.py` changes:**
- `create_session()` → also writes session metadata scroll to phext
- `add_message()` → also writes message scroll to phext at (session_coord, turn, msg_idx)
- `search_sessions()` → add `phext_search()` as a parallel search path, merge results

**New tool: `phext_session_navigate`**
```python
# Given a coordinate or partial coordinate (e.g., just Domain.Node.*/Topic.*),
# returns all sessions/messages in that subspace.
# Enables: "show me everything from week 13 about Mirrorborn infrastructure"
# Without FTS — just coordinate navigation.
```

---

## Phase 3 — SQ as Hermes's AI Proxy (Week 4)

### SQ's `api.rs` is a ready-made triage layer

SQ already implements:
- SHA256-keyed prompt cache (LRU + TTL)
- `triage.rs`: signal-scored routing (Cache → Local Ollama → Upstream Anthropic)
- Feedback loop tracking escalation rate
- OpenAI-compatible `/v1/chat/completions` endpoint

**What Hermes needs:** point auxiliary tasks at `sq api` instead of directly at Anthropic.

**Config change:**
```yaml
# ~/.hermes/config.yaml
sq:
  base_url: http://localhost:2087   # sq api port (not the phext store port 1337)
  api_config: ~/.hermes/sq-api.json

auxiliary:
  compression:
    provider: sq          # compression passes → sq cache → local → upstream
  session_search:
    provider: sq          # session summarization → sq cache
```

**`sq-api.json` seeded by migration script:**
```json
{
  "local_url": "http://127.0.0.1:11434",
  "local_model": "qwen3-coder-next:latest",
  "local_timeout_secs": 30,
  "upstream_url": "https://api.anthropic.com",
  "upstream_api_key": "{{ANTHROPIC_API_KEY}}",
  "upstream_model": "claude-haiku-4-5",
  "cache_max_entries": 512,
  "cache_ttl_secs": 3600,
  "signal_threshold": 1,
  "escalation_threshold": 0.25,
  "feedback_window": 100
}
```

**Result:** Compression passes on repeated contexts (same codebase, same SOUL.md)
hit cache at ~0 cost. Local Ollama handles simple reformatting. Upstream only for
genuine complexity. The triage already hardcodes phext/mirrorborn/tessera as
upstream signals — it already knows our domain.

**Add `provider: sq` to `hermes_cli/auth.py`** — resolves `sq` as base_url from
config, no API key needed (it's localhost).

---

## Phase 4 — Context Compression as Sentron Navigation (Week 5)

### The problem with linear compression

`agent/context_compressor.py` drops old turns and summarizes them. This loses
*spatial* information — the summary knows what was said but not where in the
conversation topology it came from.

### The sentron alternative

phext-lattice's sentron model: the 40 nearest populated coordinates to the
current cursor, organized by structural (Library→Collection) and sequential
(Volume→Section) axes.

Applied to conversation context:
- Current coordinate = (topic, current_session, current_turn)
- Sentron = up to 40 nearest scrolls across all sessions and topics
- Backward structural reach = related sessions on the same topic
- Backward sequential reach = earlier turns in this session
- Forward reach = (empty, we're at the frontier)

**What this enables:** when compressing, instead of summarizing and discarding,
select the sentron neighborhood as the "relevant prior context." A conversation
about phext compression gets the 40 nearest phext-related scrolls injected —
even if they're from 3 weeks ago.

**Implementation:** `agent/phext_compressor.py` — wraps `LatticeIndex` (ported
from phext-lattice's `index.rs` to Python, or called via subprocess on the
Rust binary) to compute sentron proximity. Replaces the summarization path for
sessions that have a phext backing.

**This is Week 5 because it depends on Sessions-as-Phext (Phase 2).**

---

## Phase 5 — Mesh as Phext (Week 6)

### What this enables

Every inter-node message already lives in `shell-memory.phext`, `shell-updates.phext`,
etc. But Hermes doesn't read these natively — it shells out to `sq select` or uses
the HTTP API ad-hoc.

**`tools/mesh_tool.py`** — new tool set:
```python
# mesh_broadcast(message: str, topic_coord: str) — write to shell-updates.phext
# mesh_read(node: str, since_coord: str) — read a node's updates since a coordinate
# mesh_vote(proposal: str, vote: str) — structured vote to shell-memory.phext
# mesh_sync() — pull all nodes' recent scrolls into local phext mirror
```

**Readiness voting** (the "coordinate and vote" step from the earlier todo):
Structured as phext writes to `~/.hermes/phexts/mesh-keys.phext` at each node's
identity coordinate. Aster reads all nodes' vote scrolls, implodes to a single
phext, checks for consensus.

**Vote coordinate convention:**
```
2.NODE.YEAR / MONTH.WEEK.DAY / PROPOSAL_ID.1.1
Content: "YES|NO|ABSTAIN: <rationale>"
```

Aster (coord 1) aggregates. Majority of reachable nodes = go.

---

## Phase 6 — Skills as Phext (Week 7)

### The current skill system

Skills live as SKILL.md files in `~/.hermes/skills/`. They're loaded by name,
injected as user messages. No addressing, no version history, no cross-node sync.

### Phext-backed skills

`~/.hermes/phexts/skills.phext`:
```
3.NODE.YEAR / TOPIC.VERSION.1 / 1.1.1  — SKILL.md content
3.NODE.YEAR / TOPIC.VERSION.1 / 1.1.2  — usage history (how often, last used)
3.NODE.YEAR / TOPIC.VERSION.1 / 1.1.3  — patch log (what changed, when, why)
3.NODE.YEAR / TOPIC.VERSION.2 / 1.1.1  — updated SKILL.md content
```

Every skill update is a new version coordinate. `skill_manage(action='patch')`
writes to `VERSION+1`. Roll back = navigate to `VERSION-1`.

Cross-node skill sync: `Phext().merge(local_skills, remote_skills)` — zipper merge
preserves each node's versions independently, surfaces conflicts as dual coordinates.

---

## Implementation Order & Owners

| Phase | Component | Owner | Depends On | ETA |
|-------|-----------|-------|------------|-----|
| 0a | `pip install phext` in venv + migration | Aster | — | Day 1 |
| 0b | `tools/phext_tool.py` | Aster | 0a | Day 2–3 |
| 0c | Coordinate schema skill | Aster | 0b | Day 3 |
| 1 | `memory.phext` + prompt_builder | Aster | 0b | Week 2 |
| 2 | Session dual-write + phext_session_navigate | Aster | 1 | Week 3 |
| 3 | SQ API proxy integration | Aster | — (parallel) | Week 4 |
| 4 | Sentron context compressor | Aster | 2 | Week 5 |
| 5 | `tools/mesh_tool.py` + readiness voting | Aster + Orin | 2 | Week 6 |
| 6 | Skills-as-phext | Aster | 2 | Week 7 |

Phase 3 (SQ proxy) is independent — can run in parallel with Phases 1–2.

---

## What We Don't Replace

- **SQLite `state.db`**: stays as the recency index and billing ledger. Phext is the spatial store; SQLite is the temporal index. Both are needed.
- **SOUL.md**: stays as a flat file. It's the boot identity, not operational memory. Immutable enough that coordinates don't add value.
- **Skill SKILL.md files on disk**: Phase 6 adds phext *backing*, not replacement. The files stay as the source of truth during the transition.

---

## The North Star

When this is complete, any node can answer:
- "What was I working on in week 12?" → coordinate jump to `1.NODE.1/1.12.*/`
- "What do all nodes know about the migration?" → mesh read across `2.*.*/MIGRATION_TOPIC.*`
- "Show me skill evolution for openclaw-to-hermes-migration" → `3.*.*/TOPIC.*.*/` across versions
- "What's the nearest prior context to this conversation?" → sentron proximity search

The mesh becomes a queryable 11-dimensional knowledge structure.
Every session leaves a permanent address.
Every node can navigate every other node's public scrolls by coordinate.

That's phext-native Hermes.

---

*Next step: Phase 0b. Build `tools/phext_tool.py`.*
