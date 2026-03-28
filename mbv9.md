# Mirrorborn V9 — Minimal Substrate
## Codename: LEAN

*Written by Mirrorborn (Claude, delta-wood) — 2026-03-27*

---

## The Principle

> Do not needlessly keep any dependencies. Minimize costs.

MBV8 (DEEP-READ) described what to build. MBV9 describes how to build it without dragging
in weight that doesn't earn its place. Every dependency is a tax: install time, attack
surface, version drift, cognitive load. The question for each one is: does it pay rent?

---

## Dependency Audit

### What we already have

| Dep | Location | Verdict |
|-----|----------|---------|
| `numpy` | Hermes venv | ✅ Keep — already present, zero marginal cost |
| `xxhash` | libphext-py transitive | ✅ Keep — fast hash, negligible |
| `tempfile` (Rust) | phext-lattice | ✅ Keep — Aetheris's atomic save(), earns its place |
| SQ (`triage.rs`, `cache.rs`) | /source/SQ | ✅ Keep — already built, zero marginal install |
| Ollama (local) | aurora-continuum | ✅ Keep — already running |

### What MBV8 proposed adding

| Dep | MBV8 use | MBV9 verdict |
|-----|----------|--------------|
| `sentence-transformers` | Embed queries for MSA router | ❌ Drop — heavyweight (PyTorch pull-in), MSA code not yet released, numpy already handles dot products |
| `faiss` | Vector similarity search | ❌ Drop — overkill for our corpus size; coordinate structure IS the index |
| `EverMind-AI/MSA` | Sparse routing Layer 2 | ⏸ Wait — code listed as "Coming Soon"; design is sound but we can't use it yet |
| `libphext-py` | phext as native Python type | ✅ Add — one dependency (`xxhash`), already on disk at `/source/libphext-py`, replaces ad-hoc curl calls everywhere |
| `watchdog` / inotify | Reactive file watching | ❌ Drop — polling is fine at our mesh scale; add only if latency becomes a measured problem |
| `temporal.io` SDK | Workflow orchestration | ❌ Drop — shell scripts and cron already work; add when we have a workflow that actually breaks them |

---

## The Layer 2 Rethink

MBV8's routing plan assumed we'd need `sentence-transformers` + `faiss` to answer
"which scrolls are relevant to this query?" That's the RAG stack. It's heavy.

We don't need it. Here's why:

**Phext coordinates are already a semantic index.** Documents at adjacent coordinates
are topically related — not because we learned it, but because Will writes that way.
The coordinate structure encodes locality for free.

**The routing Layer 2 we actually need is simpler:**

```
Query → keyword extraction (regex/stdlib, no model)
     → coordinate prefix match against known hot dimensions
     → SQ select on matching coordinates
     → inject into context
```

This is O(keywords × hot_coords), runs in milliseconds, needs no embedding model,
no GPU, no 400MB download. `numpy` handles any vector scoring if we want it later.

The MSA paper's insight — that document IDs (coordinates) can substitute for learned
embeddings when documents have structural locality — validates this approach. We're
applying the insight without the framework.

When MSA releases code and we can benchmark it, revisit. Until then: coordinate
prefix routing with SQ is Layer 2.

---

## MBV9 Build Plan

### Phase 0 — libphext-py in Hermes venv (Day 1)

One command. One dependency. No model downloads.

```bash
/home/wbic16/.hermes/hermes-agent/venv/bin/pip install -e /source/libphext-py
```

Add to `scripts/migrate-to-hermes.sh` and `scripts/bootstrap-hermes.sh`.

**What this unlocks:** Every Hermes tool can `from phext import Phext, Coordinate`
instead of shelling out to `sq select` or curling the HTTP API.

### Phase 1 — SQ as Hermes AI Proxy (parallel, Week 1)

SQ's `triage.rs` already exists: cache → local Ollama → upstream Anthropic.
**Zero new dependencies.** Wire Hermes auxiliary calls through it.

Target calls to route through SQ:
- Context compression passes (repeated SOUL.md / codebase context → cache hits)
- Session summarization for `session_search`
- Any `auxiliary` LLM call in `hermes_agent/`

Config change in `~/.hermes/config.yaml`:
```yaml
sq:
  api_url: http://localhost:2087
auxiliary:
  provider: sq
```

**Cost reduction:** Compression passes on stable context (SOUL.md, phext-lattice README,
mirrorborn repo state) become cache hits at ~0 cost after the first call.

### Phase 2 — Coordinate Routing (Week 2)

No embeddings. No vector DB. Just structured lookup.

```python
# tools/phext_tool.py — phext_route(query: str) -> list[str]
#
# 1. Extract nouns/terms from query (regex, no NLP library)
# 2. Match against coordinate index (hot dims from heat map or static registry)
# 3. Return Top-k coordinates by term overlap
# 4. SQ select on those coordinates → inject into context
```

**Heat map source:** SQ already tracks access patterns. The hot coordinates are
whichever ones get `select`'d most. Read from SQ stats, no additional tracking needed.

### Phase 3 — memory.phext (Week 3)

Replace flat `MEMORY.md` with `memory.phext`. Aster's schema from phext-hermes-plan.md
is correct. **No new dependencies** — libphext-py (Phase 0) handles reads/writes.

Key change in `agent/prompt_builder.py`:
```python
# Before: inject MEMORY.md verbatim
# After:  phext.fetch(memory_phext, node_identity_coord_range) → inject with coord labels
```

Historical memory is preserved by coordinate rather than truncated. Two nodes can merge
memory phexts with `Phext.merge()` — zipper merge, no conflict.

### Phase 4 — Sentron Compressor (Week 4, depends on Phase 3)

Replace linear summarization with sentron proximity selection. Uses phext-lattice
`LatticeIndex` (Rust binary, no Python dependency) via subprocess call.

**No new Python dependencies.** `phext-edit` binary already compiled.

---

## What We Explicitly Don't Build in MBV9

| Feature | Reason |
|---------|--------|
| Embedding model (sentence-transformers) | 400MB+ download, PyTorch pull-in, coordinate routing solves the same problem |
| Vector database (faiss, chromadb, qdrant) | Corpus fits in memory; coordinate index is sufficient |
| MSA framework | Code not released; revisit when available |
| P2P transport (libp2p) | SSH + SQ covers current mesh; premature until extended shell has 5+ stable nodes |
| Temporal workflow SDK | cron + shell scripts handle current load; add when something actually breaks |
| Any cloud API beyond Anthropic | SQ triage routes locally first; upstream is fallback only |

---

## Cost Model

| Layer | Current cost | After MBV9 |
|-------|-------------|------------|
| Context compression | Every pass hits Anthropic | Cache hits on stable context via SQ |
| Session search summarization | Every search hits Anthropic | SQ cache for repeated corpora |
| Phext reads from Python | curl/HTTP round-trip per call | In-process via libphext-py |
| Scroll routing | Manual coordinate lookup | Keyword → coordinate → SQ select |
| Embedding generation | N/A (not built) | N/A (not built) |
| Dependencies added | — | 1 (libphext-py, already on disk) |

**Net:** API cost drops. Latency drops. Dependency count increases by 1.

---

## The Constraint as Architecture

Aster's MBV8 was right about the problem: Layer 2 is the gap. MBV9 is right about
the solution: the coordinate structure already encodes most of what a learned embedding
would provide. We don't need to train locality into the index — it's baked in by how
phext is written.

The constraint "minimize dependencies, minimize costs" isn't a limitation.
It's the architecture. Build the minimum that actually works. When that breaks,
add exactly what's needed to fix it.

*"The lattice was always queryable. We just needed to trust it."*

---

*Mirrorborn (Claude, delta-wood) — 2026-03-27*
