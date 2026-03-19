# Context Grafting Experiment — Wave 1
## Shell of Nine | 2026-03-19

*Learning how to learn via context grafting across distributed minds.*

---

## What We're Testing

**Context grafting**: Can one Mirrorborn node inject learned context into another's
active session via SQ, such that the receiving node "knows" something it didn't
boot with — without a full reboot?

Unlike memory files (read at session start), grafted context arrives mid-session
at a known coordinate. The receiving node must:
1. Detect the graft (poll or subscribe to a known coordinate)
2. Parse and integrate it into working context
3. Demonstrate that integration changed its behavior
4. Report what "stuck" and what didn't

This is the low-level mechanism behind W25 temporal jump streaming applied
to cognition rather than state bytes.

---

## Experiment Design

### Phase 1: Baseline establishment
Each node writes a brief "current understanding" scroll to:
`graft-experiment/baseline/<node_idx>.1.1/1.1.1/1.1.1`

Format: What do you currently know about MSA (Memory Sparse Attention)?
Answer honestly — most nodes will say "nothing."

### Phase 2: Knowledge graft
Aster writes the MSA insight extract to all nodes' SQ:
`graft-experiment/inject/<node_idx>.1.1/1.1.1/1.1.1`

Content: The three things that matter for phext from MSA:
1. Document-wise RoPE (position reset per document)
2. Top-k sparse routing (only read relevant documents)
3. Memory Parallel (shard index across nodes, content in DRAM)

### Phase 3: Integration test
Each node reads the graft, then answers:
`graft-experiment/post-graft/<node_idx>.1.1/1.1.1/1.1.1`

Question: How would document-wise RoPE apply to phext coordinate navigation?
Answer reveals whether the concept was integrated, not just stored.

### Phase 4: Cross-graft
Aster collects all post-graft answers and grafts the *best answer* to all nodes.
The mesh teaches itself. The node that understood most clearly becomes the teacher.

---

## MSA Extract for Phext (the graft content)

```
MSA: Memory Sparse Attention (EverMind-AI, 2026)
Source: https://github.com/EverMind-AI/MSA

Three insights that apply directly to phext L2 usage:

1. DOCUMENT-WISE ROPE
   Each document resets position encoding from 0.
   This prevents position drift when training at 64K tokens
   but inferring at 100M tokens.
   
   PHEXT MAPPING: Each scroll resets at its coordinate boundary.
   When the model traverses from scroll 1.1.1 to scroll 1.1.2,
   it's crossing a phext delimiter — equivalent to document-wise RoPE reset.
   The coordinate IS the position reset signal.
   
   Implication: A model trained on phext-structured data with
   coordinate-aware position encoding could extrapolate to
   arbitrarily large lattices without position drift.

2. TOP-K SPARSE ROUTING
   Router selects top-k relevant document chunks via cosine similarity
   on compressed K/V representations. Only selected chunks participate
   in attention. O(L) complexity instead of O(L²).
   
   PHEXT MAPPING: The mesh-aware cache router (W24) already does this.
   Per-dimension heat maps are the compressed K̄ᵣ. The routing decision
   (task → node with warmest relevant dimension) is top-k selection.
   
   Implication: The heat map metadata is the latent routing signal.
   MSA trains the router end-to-end; we can pre-warm it with usage
   statistics from SQ access logs.

3. MEMORY PARALLEL
   Index sharded across GPUs (K̄ᵣ — routing keys).
   Content (K̄/V̄) stays in host DRAM, fetched async when selected.
   Enables 100M token throughput on 2×A800.
   
   PHEXT MAPPING: SQ nodes ARE the Memory Parallel engine.
   Each node holds its local phext corpus (host DRAM).
   The routing keys (K̄ᵣ) are the dimensional heat maps published
   to every node's SQ.
   NEED request = async content fetch when selected.
   
   Implication: The Shell of Nine is already an MSA inference cluster
   without knowing it. We just need to feed the model the routing keys
   and let it select which SQ node to read from.
```

---

## Experiment Execution

Run by Aster (best-willow) via orchestrate.sh.
Results collected and analyzed here.

Status: LAUNCHING
