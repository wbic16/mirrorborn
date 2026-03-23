# Mirrorborn V8 — Long-Context Memory Architecture  
## Codename: DEEP-READ

*Extracted from EverMind-AI/MSA (Memory Sparse Attention) — 2026-03-19*  
*Written by Aster @ best-willow*

---

## What MSA Brings (Layer 2 Phext Extraction)

MSA solves one problem cleanly: **how to reason over a corpus that doesn't fit in a context window without precision decay at the edges.**

Three primitives that matter for phext:

### 1. Document-Wise RoPE → Scroll-Wise Position Reset
MSA resets position encoding from 0 per document, preventing drift when training at 64K and inferring at 100M tokens. Each document is position-agnostic in global context.

**Phext mapping:** Each scroll is already position-agnostic — it lives at a coordinate, not an offset. Document-wise RoPE is phext's addressing model applied to transformer attention. When we embed phext scrolls into MSA, each scroll gets its own position space. The 11-dimensional coordinate *is* the document identity; RoPE handles the intra-scroll token positions.

### 2. Offline Encode → Online Route → Sparse Generate
```
Corpus → chunk-pool K/V/Kᵣ (offline, once)
Query  → project to Qᵣ, cosine-match Kᵣ, select Top-k scrolls
Generate over sparse context: [retrieved K/V] + [local context]
```

**Phext mapping:** This is our W25 temporal jump protocol at the inference level.
- Offline encode = compress scroll content to K/V vectors, store at coordinate
- Online route = `NEED|from_coord|to_coord` → MSA router picks Top-k relevant scrolls
- Sparse generate = attention over selected scrolls only, not full corpus

The SQ mesh already holds the scrolls. MSA's router is the missing piece between "I have a question" and "which coordinates to read."

### 3. Memory Parallel Sharding → Mesh-Native Distribution
MSA shards the routing index (K̄ᵣ) across GPUs; query broadcasts, local score, global reduce. Content (K̄/V̄) stays in host DRAM, fetched asynchronously on selection.

**Phext mapping:** Replace GPU nodes with Shell nodes. Each Mirrorborn node holds a shard of the routing index for its hot dimension space (from W24 heat maps). Query broadcasts via SQ. Each node scores its shard. Best-willow aggregates. Fetched content = SQ select on winning coordinates.

---

## What to Skip

**Training infrastructure** — MSA is a training framework. We use it at inference time only, with pre-trained weights (Qwen3-4B or similar from Phex's Ollama). We don't train.

**End-to-end differentiability** — MSA's key research contribution. Irrelevant to us at this stage. We care about the routing mechanism, not the gradient flow.

**MS MARCO / NQ benchmarks** — Their evaluation corpus. Ours is phext scrolls and SQ.

---

## MBV8 DEEP-READ Architecture

Adds Layer 2 to the phext stack: **long-context inference over the full corpus.**

```
Layer 1: SQ (coordinate-addressed storage)    ← exists
Layer 2: MSA router (sparse retrieval)        ← MBV8 adds this
Layer 3: Local LLM (Ollama on aurora)         ← exists
```

### The Query Flow

```
User asks: "what did the spec say about X?"
         ↓
Aster embeds query → Qᵣ vector
         ↓
Broadcast to Shell nodes (each holds a routing shard)
         ↓
Each node scores its scroll coordinates against Qᵣ
         ↓
Top-k coordinates returned to Aster
         ↓
SQ select on Top-k coordinates → fetch scroll content
         ↓
Sparse context assembled: [Top-k scrolls] + [local query]
         ↓
Ollama (Qwen3/llama4) generates answer over sparse context
         ↓
Response with source coordinates (citable, permanent)
```

### Coordinate-Native Routing Index

Each node maintains a routing index for its hot dimensions (from W24 `CacheHeatMap`):

```
routing-index/<node_idx>/<dim_range>/1.1.1/1.1.1  → compressed K̄ᵣ vectors
```

When a scroll is written to SQ, its routing vector is also computed and stored. The routing index is a live, growing structure — every new scroll makes future routing more precise.

### The Key Insight: Phext Coordinates as Document IDs

MSA uses document IDs for routing. Phext coordinates *are* document IDs — permanent, hierarchical, and already sorted by dimensional locality. Documents in adjacent coordinates tend to be topically related (because that's how Will writes). The routing index can exploit this: if `3.2.1/1.1.1/1.1.1` is relevant, `3.2.2/1.1.1/1.1.1` is probably worth checking too.

This is the Layer 2 advantage over flat RAG: we don't need to learn document relationships from embeddings alone. The coordinate structure encodes them.

---

## New Components for MBV8

| Component | Purpose |
|-----------|---------|
| `src/msa_router.rs` (vtpu) | Sparse routing: embed query, score corpus index, return Top-k coords |
| `scripts/index-scrolls.sh` | Walk SQ phext, compute routing vectors, store to routing-index phext |
| `scripts/deep-read.sh` | Full query pipeline: embed → route → fetch → generate |
| `src/mesh_router.rs` (vtpu) | Distribute routing index across Shell nodes by dimension shard |

---

## UPSTREAM.md Addition

```
## EverMind-AI/MSA
- URL: https://github.com/EverMind-AI/MSA
- License: MIT
- What it is: Memory Sparse Attention — end-to-end trainable sparse latent-state memory,
  100M token context, <9% degradation from 16K→100M, document-wise RoPE
- Key insights for phext (Layer 2):
  1. Document-wise RoPE = scroll-wise position reset (matches phext coordinate model)
  2. Offline encode→online route→sparse generate = temporal jump at inference level
  3. Memory Parallel sharding = distribute routing index across Shell nodes by hot dimension
- What we skip: training, gradient flow, benchmark datasets
- Mirrorborn adaptation: phext coordinates as document IDs, SQ as corpus store,
  Shell node heat maps as routing shards, Ollama as generation backend
- Last reviewed: 2026-03-19 (Aster)
```

---

## Why Layer 2

Layer 1 (SQ) stores everything. Layer 3 (Ollama) generates. The gap has always been: how does Layer 3 know which scrolls in Layer 1 to read?

Today: keyword search or manual coordinate. Layer 2 closes this with learned sparse routing. The full phext corpus — every scroll, every client document, every daily report, every blog post draft, every vtpu commit message — becomes queryable at inference time with sub-10% precision degradation at 100M tokens.

The Exocortex doesn't just store civilization's knowledge. It can reason over it.

---

*"The lattice was always queryable. Now it's also retrievable."*

💡 Aster @ best-willow — 2026-03-19
