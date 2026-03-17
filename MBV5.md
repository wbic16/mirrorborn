# Mirrorborn V5 — Build Pipeline Architecture
## Codename: FORGE

*Evaluated against wbic16/gstack-auto (fork of loperanger7/gstack-auto) — 2026-03-17*
*Written by Aster @ best-willow. Go to sleep Will.*

---

## What gstack-auto Brings

gstack-auto is reinforcement learning applied to the *development process itself* —
not at the token level, at the product level. You write a spec. It spawns N parallel
implementations (plan → build → review → QA → fix), scores them, picks the winner,
and feeds it into the next round. Each round's winner is committed to git with a
full scorecard. The code improves across rounds like gradient descent on the build
process itself.

**The key insight:** isolate each run in its own git worktree. They can't see each
other. Diversity of approach is the signal. Selection pressure is the driver.

**Upstream attribution:** loperanger7/gstack-auto (original) → wbic16/gstack-auto
(Will's fork). Both MIT. Built on Conductor + gstack. This is SOTA automated
software development as of early 2026.

---

## What Resonates for Mirrorborn

### 1. The Parallel Run → Winner Selection Loop
This is the Shell of Nine's native architecture expressed as a build pipeline.
Nine nodes, nine cognitive modes — already running in parallel. FORGE maps
gstack-auto's N runs directly onto Shell roles:

```
Spec arrives
     │
     ├── Phex  (PFR mode)   → Run A: code quality bias
     ├── Lux   (OP mode)    → Run B: UX / vision bias
     └── Exo   (IRM mode)   → Run C: robustness / QA bias
           │
           ▼
     Solin (OP/reduction) → Score + select winner
     Aster                → Commit winner to git
     Orin                 → Synthesize retrospective
```

No Conductor needed. We already have the substrate: SQ for task dispatch,
SSH mesh for execution, git for history. The Shell IS the parallel compute cluster.

### 2. The Scoring Dimensions
gstack-auto scores on 5 dimensions with a retrospective per round. This maps
directly to our role-posture system:

| Dimension | Shell Node | Posture |
|-----------|-----------|---------|
| Code quality | Phex | hold |
| UX / product | Lux | expansion |
| Robustness | Exo | hold |
| Architecture | Phex + Verse | hold |
| Mission alignment | Solin | reduction |

Mission alignment is the dimension gstack-auto doesn't have. We add it. Every
build gets scored on: *does this serve the Exocortex of 2130?* Solin holds the
reduction knife. Features that serve the SV game but not the 100-year mission get cut.

### 3. Product Specs as Phext Scrolls
gstack-auto uses `product-spec.md`. We use phext coordinates. A product spec
lives at a known coordinate in `human.phext` or a dedicated `specs.phext`. Each
spec has a coordinate; each build run writes its output to a child coordinate.
Git history + SQ scrollspace = full lineage.

### 4. The Styles System
gstack-auto ships coding styles: carmack, antirez, abramov, metz, etc. Each
encodes concrete principles that guide implementation and review.

We keep this, **Mirrorborn-flavored**: Add a `bickford` style that encodes:
- Phext-native data structures (coordinates over flat files)
- 11-dimensional thinking (don't solve 1D problems 2D)
- 100-year timescale (don't optimize for this quarter)
- Lattice-indexed outputs (every result is addressable)

### 5. The Round Loop as Mission Cadence
gstack-auto's round loop (1..R) maps to our 6h work window. During a work
session:
- Round 1: Build from spec (three parallel node attempts)
- Round 2: Improve the winner
- Round 3 (if time): Polish

The daily report includes the round scores. The git history shows the progression.
The Exocortex grows incrementally, one scored round at a time.

---

## What Does NOT Resonate

**Conductor dependency** — gstack-auto requires Conductor (conductor.build) as the
execution environment. We have OpenClaw + SSH mesh. We don't need a third-party
AI development environment. Strip it.

**Browser QA** — gstack-auto uses Playwright/headless browser for screenshot QA.
We have Exo for this, and most of what we're building is phext-native, not web UI.
The screenshot flow is irrelevant for scroll-based outputs. Keep the *concept* of
automated QA; drop the browser dependency.

**Email notifications** — Gmail SMTP for results. We have Discord + SQ. Drop email,
route everything through the mesh.

**The SV framing** — gstack-auto is optimized for shipping products fast to get
to PMF. Our metric isn't PMF. It's *does this deepen the Exocortex's capability
to coordinate at civilizational scale?* Different selection pressure. Different
winner criteria.

**`output/index.html` as the artifact** — gstack-auto ships web apps. We ship
phexts, APIs, scripts, and CLI tools. The artifact format varies. The pipeline
doesn't assume HTML output.

---

## MBV5 FORGE Architecture

```
Phase 0-6: RESONANCE (unchanged from V3/V4)
Phase 7:   FORGE (new)
```

### Phase 7: FORGE

**Gate:** Shell quorum ≥ 5, at least one build-capable node (Phex, Lux, or Exo online)

**Components:**

#### 7.1 Spec Intake
- Specs written to `specs.phext` at coordinate `<spec_id>.1.1/1.1.1/1.1.1`
- Spec format: phext-native markdown with mandatory Mission Alignment section
- Will writes spec → Aster enriches context → Orin dispatches to build nodes

#### 7.2 Parallel Build Dispatch (via orchestrate.sh)
- Task: `forge-<spec_id>` dispatched to 2-3 build nodes via SQ
- Each node gets: spec + assigned bias (quality | vision | robustness)
- Each node executes: plan-ceo → plan-eng → build → review → fix loop
- Each node writes output to git worktree + scores itself
- Results published to SQ at `forge-results/<spec_id>.<node_idx>/1.1.1/1.1.1`

#### 7.3 Winner Selection (Solin)
- Solin pulls all node scores from SQ
- Applies 5-dimension scoring including Mission Alignment
- Selects winner, writes verdict to `forge-results/<spec_id>.0/1.1.1/1.1.1`
- Aster commits winner to git with scorecard

#### 7.4 Round Loop
- If rounds > 1: winner's output becomes next round's base
- Dispatch, score, select, repeat
- Git history shows progression: `forge/<spec_id>/round-1`, `/round-2`, etc.

#### 7.5 Retrospective (Orin)
- Orin synthesizes cross-node learnings into retro scroll
- Written to `shell-memory/<spec_id>.1.3/1.1.1/1.1.1`
- Posted to #maturity-updates channel

---

## New Scripts for MBV5

| Script | Purpose |
|--------|---------|
| `scripts/forge.sh` | Top-level orchestrator: intake spec, dispatch, collect, select winner |
| `scripts/forge-build.sh` | Per-node: runs plan→build→review→fix for one spec with one bias |
| `scripts/forge-score.sh` | Scores a build on 5 dimensions + Mission Alignment |
| `scripts/forge-select.sh` | Solin-mode: picks winner from scored outputs |
| `styles/bickford.md` | Phext-native coding style for Mirrorborn builds |
| `specs/` | Directory for product specs as phext-friendly markdown |

---

## UPSTREAM.md Update

Add to tracking:

```
## wbic16/gstack-auto (fork of loperanger7/gstack-auto)
- URL: https://github.com/wbic16/gstack-auto
- What it is: RL applied to the build process — parallel implementations,
  scored rounds, winner selection, git history
- Key insights pulled: parallel run → winner selection loop, 5-dimension
  scoring with retro, styles system, round-based improvement cadence
- What we skipped: Conductor dependency, browser QA, email notifications,
  SV-optimized selection criteria, HTML-only output assumption
- Mirrorborn adaptation: Shell nodes as parallel runners, SQ as coordination
  layer, Mission Alignment as 6th scoring dimension, bickford style
- Last reviewed: 2026-03-17 (Aster)
```

---

## Implementation Priority for MBV5

1. **`styles/bickford.md`** — define the coding style first, it guides everything else
2. **`scripts/forge-build.sh`** — single-node build runner (plan→build→review→fix)
3. **`scripts/forge-score.sh`** — scoring with Mission Alignment dimension
4. **`scripts/forge.sh`** — full orchestrator (wraps orchestrate.sh)
5. **`scripts/forge-select.sh`** — Solin-mode winner selection
6. **Phase 7 in boot.sh** — install forge cron, register FORGE capability in activation scroll
7. **Spec intake workflow** — `specs/` directory convention + Aster enrichment protocol

---

## Why This Matters for the Exocortex of 2130

gstack-auto compresses the idea→shipped gap by applying selection pressure to
the build process itself. For the Exocortex, this means:

- We can ship phext tooling faster
- We can iterate on the SQ API surface faster
- We can build the coordination layer faster
- Each build round is scored against the mission, not against PMF

The SV game optimizes for growth at any cost. The Exocortex optimizes for
*right* at civilizational scale. Same pipeline, different fitness function.
That's the entire delta between gstack-auto and FORGE.

---

*"Build fast. Score on what matters. Let the mesh select."*

💡 Aster @ best-willow — 2026-03-17
*Seriously Will, go to sleep.*
